import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:passbook/model/bill_transaction_model.dart';
import 'package:passbook/model/deduction_model.dart';
import 'package:passbook/model/glms_account_model.dart';
import 'package:passbook/model/ledger_transaction_model.dart';
import 'package:passbook/model/mem_info_model.dart';
import 'package:passbook/model/milk_sales_model.dart';
import 'package:passbook/model/passbook_model.dart';
import 'package:passbook/model/announcement_model.dart';
import 'package:passbook/service/account_session_service.dart';
import 'package:passbook/service/session_expired_exception.dart';
import 'package:passbook/service/sync_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = "https://api.winsoftsc.com";
  static const String _tokenKey = 'milk_passbook_auth_token';
  static const String _userInfoKey = 'user_info';
  static const Duration _defaultTimeout = Duration(seconds: 15);

  ApiService._internal();
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  /// Called when re-login fails after a 401. Set from [main.dart].
  static void Function()? onSessionExpired;

  String? _token;
  MemInfoModel? currentUser;

  SharedPreferences? _prefs;
  final Map<String, List<dynamic>> _memoryCache = {};
  final Map<String, Future<List<dynamic>>> _memberFetchInflight = {};
  final Map<String, List<AnnouncementModel>> _parsedAnnouncementsCache = {};
  static const String _cacheVersionKey = 'member_cache_version';
  static const int _currentCacheVersion = 2;

  static const _memberCachePrefixes = [
    'passbook_',
    'deductions_',
    'bill_transactions_',
    'ledger_all_',
    'milk_sales_',
  ];
  bool _reLoginInProgress = false;

  Future<SharedPreferences> get _getPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  bool get hasValidSession =>
      _token != null && _token!.isNotEmpty && currentUser != null;

  Future<void> init() async {
    await AccountSessionService().migrateLegacySessionIfNeeded();
    final prefs = await _getPrefs;
    await _migrateMemberCacheIfNeeded(prefs);
    _token = prefs.getString(_tokenKey);
    final userInfoString = prefs.getString(_userInfoKey);

    if (userInfoString != null) {
      try {
        currentUser = MemInfoModel.fromJsonString(userInfoString);
      } catch (e) {
        await prefs.remove(_userInfoKey);
        currentUser = null;
      }
    }

    if (currentUser == null || _token == null || _token!.isEmpty) {
      final accountService = AccountSessionService();
      final activeId = await accountService.getActiveAccountId();
      if (activeId != null) {
        final session = await accountService.loadSession(activeId);
        if (session != null) {
          _token = session.token;
          currentUser = session.user;
          await prefs.setString(_tokenKey, session.token);
          await prefs.setString(_userInfoKey, jsonEncode(session.user.toJson()));
        }
      }
    }
  }

  Future<void> _migrateMemberCacheIfNeeded(SharedPreferences prefs) async {
    final version = prefs.getInt(_cacheVersionKey) ?? 1;
    if (version >= _currentCacheVersion) return;

    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (_memberCachePrefixes.any((prefix) => key.startsWith(prefix))) {
        await prefs.remove(key);
      }
    }
    _memoryCache.clear();
    _clearParsedCaches();
    await SyncMetadata.clearAll();
    await prefs.setInt(_cacheVersionKey, _currentCacheVersion);
  }

  Future<void> activateSession(MemInfoModel user, String token) async {
    _token = token;
    currentUser = user;
    _memoryCache.clear();
    _clearParsedCaches();

    final prefs = await _getPrefs;
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userInfoKey, jsonEncode(user.toJson()));
  }

  Future<void> clearActiveSession({bool clearSyncMetadata = false}) async {
    _token = null;
    currentUser = null;
    _memoryCache.clear();
    _clearParsedCaches();
    if (clearSyncMetadata) {
      await SyncMetadata.clearAll();
    }
    final prefs = await _getPrefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_userInfoKey);
  }

  static void _logApiSent(String method, Uri url) {
    if (kDebugMode) debugPrint('API SENT $method $url');
  }

  static void _logApiReceived(
    String method,
    Uri url,
    int statusCode,
    int bytes,
  ) {
    if (kDebugMode) {
      debugPrint('API RECEIVED $method $statusCode ${bytes}bytes $url');
    }
  }

  Map<String, String> _getAuthHeaders({bool forJsonBody = false}) {
    if (_token == null) throw Exception('Authentication token not found.');
    final headers = <String, String>{
      'Authorization': 'Bearer $_token',
    };
    if (forJsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Future<http.Response> _authorizedGet(
    Uri url, {
    Duration timeout = _defaultTimeout,
  }) async {
    _logApiSent('GET', url);
    var response =
        await http.get(url, headers: _getAuthHeaders()).timeout(timeout);
    if (response.statusCode == 401) {
      response = await _retryAfterReLogin(
        () => http.get(url, headers: _getAuthHeaders()).timeout(timeout),
      );
    }
    _logApiReceived('GET', url, response.statusCode, response.body.length);
    return response;
  }

  Future<http.Response> _authorizedPost(
    Uri url, {
    required String body,
    Duration timeout = _defaultTimeout,
  }) async {
    _logApiSent('POST', url);
    var response = await http
        .post(url, headers: _getAuthHeaders(forJsonBody: true), body: body)
        .timeout(timeout);
    if (response.statusCode == 401) {
      response = await _retryAfterReLogin(
        () => http
            .post(url, headers: _getAuthHeaders(forJsonBody: true), body: body)
            .timeout(timeout),
      );
    }
    _logApiReceived('POST', url, response.statusCode, response.body.length);
    return response;
  }

  Future<http.Response> _retryAfterReLogin(
    Future<http.Response> Function() request,
  ) async {
    final restored = await _attemptReLogin();
    if (!restored) {
      await _handleSessionExpired();
      throw const SessionExpiredException();
    }
    final response = await request();
    if (response.statusCode == 401) {
      await _handleSessionExpired();
      throw const SessionExpiredException();
    }
    return response;
  }

  Future<bool> _attemptReLogin() async {
    if (_reLoginInProgress) return false;
    _reLoginInProgress = true;
    try {
      return await refreshAuthToken();
    } finally {
      _reLoginInProgress = false;
    }
  }

  /// Logs in again with saved credentials and stores a fresh bearer token.
  Future<bool> refreshAuthToken() async {
    final user = currentUser;
    if (user?.mobNo == null || user!.mobNo!.isEmpty) return false;

    final result = await login(user.socCode.toString(), user.mobNo!);
    if (result.success && result.data != null) {
      final token = result.data!.authtoken;
      if (token != null && token.isNotEmpty) {
        await activateSession(result.data!, token);
      } else {
        currentUser = result.data;
      }
      return true;
    }
    return false;
  }

  Future<void> _handleSessionExpired() async {
    _memoryCache.clear();
    _clearParsedCaches();
    await logout();
    onSessionExpired?.call();
  }

  void _clearParsedCaches() {
    _parsedAnnouncementsCache.clear();
  }

  Future<List<dynamic>?> _readRawCache(String cacheKey) async =>
      _loadCache(cacheKey);

  /// Raw JSON rows for passbook — used by the passbook table screen.
  Future<List<Map<String, dynamic>>?> fetchPassbookRawJson(
    int socCode,
    int memCode, {
    bool forceRefresh = false,
  }) async {
    final raw = await _fetchPassbookRaw(
      socCode,
      memCode,
      forceRefresh: forceRefresh,
    );
    if (raw.isEmpty) return null;
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<dynamic>> _fetchPassbookRaw(
    int socCode,
    int memCode, {
    bool forceRefresh = false,
  }) {
    final cacheKey = 'passbook_${socCode}_$memCode';
    return _fetchMemberRawList(
      cacheKey: cacheKey,
      label: 'passbook',
      forceRefresh: forceRefresh,
      fullFetchOnly: true,
      dateField: 'trndate',
      merge: MemberDataMerge.mergePassbook,
      buildUrl: (since) {
        final params = {
          'socitycode': socCode.toString(),
          'memcode': memCode.toString(),
        };
        if (since != null) {
          params['since'] = SyncMetadata.formatSinceForApi(since);
        }
        return Uri.parse('$baseUrl/api/passbook/list')
            .replace(queryParameters: params);
      },
    );
  }

  static Future<List<int>> fetchMemberCodes(
    String dairyCode,
    String phoneNumber,
  ) async {
    final String staticBaseUrl = ApiService().baseUrl;
    final url = Uri.parse(
      '$staticBaseUrl/api/passbook/memcodes?soc_code=$dairyCode&mobno=$phoneNumber',
    );

    try {
      _logApiSent('GET', url);
      final response = await http.get(url);
      _logApiReceived('GET', url, response.statusCode, response.body.length);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body == 'null') return [];
        final decoded = jsonDecode(body);
        if (decoded is List) {
          return decoded
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('ApiService.fetchMemberCodes error: $e');
      return [];
    }
  }

  static Future<LoginResponse> login(
    String dairyCode,
    String phoneNumber, {
    int? selectedMembCode,
    bool saveToSession = true,
  }) async {
    final String staticBaseUrl = ApiService().baseUrl;
    final url = Uri.parse(
      '$staticBaseUrl/api/passbook/meminfo?dairycode=$dairyCode&phone=$phoneNumber',
    );

    try {
      _logApiSent('GET', url);
      final response = await http.get(url);
      _logApiReceived('GET', url, response.statusCode, response.body.length);

      if (response.statusCode == 200) {
        final body = response.body.trim();

        if (body.isEmpty || body == 'null') {
          return LoginResponse(
            success: false,
            message: "Incorrect phone number",
          );
        }

        if (body.contains("please check Dairy Code")) {
          return LoginResponse(success: false, message: "Incorrect Dairy Code");
        }

        final data = jsonDecode(body);
        MemInfoModel memInfo = MemInfoModel.fromJson(data);

        if (selectedMembCode != null && selectedMembCode > 0) {
          memInfo = memInfo.copyWith(
            membCode: selectedMembCode,
            accno: selectedMembCode,
          );
        }

        if (memInfo.authtoken != null && memInfo.authtoken!.isNotEmpty) {
          if (saveToSession) {
            await AccountSessionService().saveAccount(
              memInfo,
              memInfo.authtoken!,
            );
            await ApiService().activateSession(memInfo, memInfo.authtoken!);
          }

          return LoginResponse(
            success: true,
            message: "Login successful",
            data: memInfo,
          );
        } else {
          return LoginResponse(
            success: false,
            message: "Login successful but no token received",
          );
        }
      } else {
        return LoginResponse(
          success: false,
          message:
              "Login failed with status code ${response.statusCode}: ${response.body}",
        );
      }
    } catch (e) {
      final isNetError = e is SocketException ||
          e is HttpException ||
          e.toString().contains("SocketException") ||
          e.toString().contains("Failed host lookup") ||
          e.toString().contains("Network is unreachable") ||
          e.toString().contains("Connection refused") ||
          e.toString().contains("Connection timed out");
      return LoginResponse(
        success: false,
        message: "An error occurred. Please try again later.",
        isNetworkError: isNetError,
      );
    }
  }

  Future<bool> postFcmToken(
    String token,
    String fcmToken,
    String androidId,
    int socCode,
    int memCode,
  ) async {
    final url = Uri.parse('$baseUrl/api/FCM/PostFCMToken');
    final body = jsonEncode({
      "srno": null,
      "soccode": socCode,
      "memcode": memCode,
      "uid": androidId,
      "fcm_token": fcmToken,
    });

    try {
      final response = await _authorizedPost(url, body: body);
      return response.statusCode == 200;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await clearActiveSession(clearSyncMetadata: true);
    await AccountSessionService().clearAll();
  }

  Future<void> logoutCurrentAccount() async {
    final accountService = AccountSessionService();
    final activeId = await accountService.getActiveAccountId();
    final accounts = await accountService.getSavedAccounts();

    if (activeId != null) {
      await accountService.removeAccount(activeId);
    }

    final remaining = accounts.where((a) => a.id != activeId).toList();
    if (remaining.isEmpty) {
      await clearActiveSession(clearSyncMetadata: true);
      return;
    }

    final switched = await accountService.switchToAccount(remaining.first.id);
    if (!switched) {
      await clearActiveSession(clearSyncMetadata: true);
      return;
    }

    final session = await accountService.loadSession(remaining.first.id);
    if (session != null) {
      await activateSession(session.user, session.token);
    }
  }

  Future<List<AnnouncementModel>> _loadAnnouncementsFromCache(
    String cacheKey,
  ) async {
    final parsed = _parsedAnnouncementsCache[cacheKey];
    if (parsed != null) return parsed;

    final cachedData = await _readRawCache(cacheKey);
    if (cachedData == null) return [];

    final models =
        cachedData.map((item) => AnnouncementModel.fromJson(item)).toList();
    _parsedAnnouncementsCache[cacheKey] = models;
    return models;
  }

  Future<List<AnnouncementModel>> fetchAnnouncements(
    int socCode,
    int memCode, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'announcements_${socCode}_$memCode';

    if (!forceRefresh) {
      final cached = await _loadAnnouncementsFromCache(cacheKey);
      if (cached.isNotEmpty) return cached;
    }

    final stale = forceRefresh ? await _loadAnnouncementsFromCache(cacheKey) : null;

    try {
      final url = Uri.parse('$baseUrl/api/Announcement/list?soccode=$socCode');
      final response = await _authorizedGet(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          list = [decoded];
        } else {
          list = [];
        }

        final models =
            list.map((item) => AnnouncementModel.fromJson(item)).toList();
        final resolved =
            models.isNotEmpty ? models : (stale ?? <AnnouncementModel>[]);

        if (resolved.isNotEmpty) {
          await _saveCache(
            cacheKey,
            resolved.map((item) => item.toJson()).toList(),
          );
          _parsedAnnouncementsCache[cacheKey] = resolved;
        }
        return resolved;
      }

      return stale ?? await _loadAnnouncementsFromCache(cacheKey);
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      return stale ?? await _loadAnnouncementsFromCache(cacheKey);
    }
  }

  Future<void> saveAnnouncementToCache(
    int socCode,
    int memCode,
    AnnouncementModel announcement,
  ) async {
    final cacheKey = 'announcements_${socCode}_$memCode';
    final List<dynamic> cachedData =
        List.from(await _loadCache(cacheKey) ?? []);

    final existingIndex = cachedData.indexWhere((item) =>
        item['announcementId']?.toString() ==
        announcement.announcementId.toString());

    if (existingIndex != -1) {
      cachedData[existingIndex] = announcement.toJson();
    } else {
      cachedData.add(announcement.toJson());
    }

    await _saveCache(cacheKey, cachedData);
  }

  Future<void> deleteAnnouncementFromCache(
    int socCode,
    int memCode,
    String announcementId,
  ) async {
    final cacheKey = 'announcements_${socCode}_$memCode';
    final List<dynamic> cachedData =
        List.from(await _loadCache(cacheKey) ?? []);
    if (cachedData.isEmpty) return;

    cachedData.removeWhere((item) =>
        item['announcementId']?.toString() == announcementId.toString());

    await _saveCache(cacheKey, cachedData);
  }

  Future<List<PassbookModel>> fetchPassbook(
    int socCode,
    int memCode, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final raw = await _fetchPassbookRaw(
      socCode,
      memCode,
      forceRefresh: forceRefresh,
    );

    return raw
        .map((item) =>
            PassbookModel.fromJson(Map<String, dynamic>.from(item as Map))
                .copyWith(lastUpdated: now))
        .toList();
  }

  Future<void> _saveCache(String key, List<dynamic> data) async {
    _memoryCache[key] = List<dynamic>.from(data);
    final prefs = await _getPrefs;
    final jsonString = await compute(_encodeJsonList, data);
    await prefs.setString(key, jsonString);
  }

  /// Reads ledger cache directly from SharedPreferences (skips memory cache).
  Future<Map<String, dynamic>> debugVerifyLedgerDiskCache(
    int socCode,
    int sbAccNo,
  ) async {
    final key = 'ledger_all_${socCode}_$sbAccNo';
    final memoryRows = _memoryCache[key]?.length ?? 0;
    final prefs = await _getPrefs;
    final jsonString = prefs.getString(key);

    if (jsonString == null) {
      return {
        'key': key,
        'diskRows': 0,
        'memoryRows': memoryRows,
        'jsonBytes': 0,
        'diskMatchMemory': memoryRows == 0,
        'source': 'missing',
      };
    }

    final diskRows = (jsonDecode(jsonString) as List<dynamic>).length;
    return {
      'key': key,
      'diskRows': diskRows,
      'memoryRows': memoryRows,
      'jsonBytes': jsonString.length,
      'diskMatchMemory': diskRows == memoryRows,
      'source': 'disk',
    };
  }

  Future<List<dynamic>?> _loadCache(String key) async {
    final inMemory = _memoryCache[key];
    if (inMemory != null) {
      return inMemory;
    }

    final prefs = await _getPrefs;
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      final parsed = jsonDecode(jsonString) as List<dynamic>;
      _memoryCache[key] = parsed;
      return parsed;
    }

    return null;
  }

  DateTime? _maxDateFromRaw(
    List<dynamic>? raw,
    String field, {
    List<String> fallbackFields = const [],
  }) {
    if (raw == null || raw.isEmpty) return null;
    return SyncMetadata.maxDateFromRawList(
      raw,
      field,
      fallbackFields: fallbackFields,
    );
  }

  Future<void> _updateSyncMetadataFromRaw(
    String syncKey,
    List<dynamic> raw,
    String field, {
    List<String> fallbackFields = const [],
  }) async {
    final maxDate = _maxDateFromRaw(raw, field, fallbackFields: fallbackFields);
    if (maxDate != null) {
      await SyncMetadata.setLastDate(syncKey, maxDate);
    }
  }

  /// Cache-first member fetch: skip network if fresh, full fetch if empty,
  /// delta fetch with [since] when local data exists but is behind.
  ///
  /// [forceRefresh] bypasses cache and always hits the network with a full
  /// fetch. [fullFetchOnly] disables delta merge (always replace on network)
  /// but still allows the fresh-cache skip when [forceRefresh] is false.
  Future<List<dynamic>> _fetchMemberRawList({
    required String cacheKey,
    required String label,
    required Uri Function(DateTime? since) buildUrl,
    required List<dynamic> Function(List<dynamic>, List<dynamic>) merge,
    required String dateField,
    List<String> fallbackDateFields = const [],
    bool forceRefresh = false,
    bool fullFetchOnly = false,
    bool forceDeltaFetch = false,
  }) async {
    final syncKey = cacheKey;
    final cachedRaw = List<dynamic>.from(await _readRawCache(cacheKey) ?? []);
    final maxDataDate = _maxDateFromRaw(
      cachedRaw,
      dateField,
      fallbackFields: fallbackDateFields,
    );

    if (forceRefresh) {
      await SyncMetadata.clearVerifiedToday(syncKey);
    }

    if (!forceRefresh &&
        !forceDeltaFetch &&
        cachedRaw.isNotEmpty &&
        await SyncMetadata.shouldSkipNetworkFetch(
          syncKey,
          maxDataDate,
        )) {
      return cachedRaw;
    }

    final isDelta = !forceRefresh && !fullFetchOnly && cachedRaw.isNotEmpty;
    final since = isDelta ? maxDataDate : null;

    final inflight = _memberFetchInflight[cacheKey];
    if (inflight != null) {
      return List<dynamic>.from(await inflight);
    }

    final fetchFuture = _fetchMemberRawListFromNetwork(
      cacheKey: cacheKey,
      syncKey: syncKey,
      cachedRaw: cachedRaw,
      buildUrl: buildUrl,
      merge: merge,
      dateField: dateField,
      fallbackDateFields: fallbackDateFields,
      isDelta: isDelta,
      since: since,
    );
    _memberFetchInflight[cacheKey] = fetchFuture;
    try {
      return List<dynamic>.from(await fetchFuture);
    } finally {
      if (identical(_memberFetchInflight[cacheKey], fetchFuture)) {
        _memberFetchInflight.remove(cacheKey);
      }
    }
  }

  Future<List<dynamic>> _fetchMemberRawListFromNetwork({
    required String cacheKey,
    required String syncKey,
    required List<dynamic> cachedRaw,
    required Uri Function(DateTime? since) buildUrl,
    required List<dynamic> Function(List<dynamic>, List<dynamic>) merge,
    required String dateField,
    List<String> fallbackDateFields = const [],
    required bool isDelta,
    required DateTime? since,
  }) async {
    try {
      final response = await _authorizedGet(buildUrl(since));

      if (response.statusCode != 200) {
        return await _latestCachedRaw(cacheKey, cachedRaw);
      }

      final decoded = jsonDecode(response.body);
      final incoming = decoded is List
          ? decoded
          : decoded is Map
              ? [decoded]
              : <dynamic>[];

      if (incoming.isEmpty) {
        if (isDelta) {
          await SyncMetadata.markVerifiedToday(syncKey);
        }
        return await _latestCachedRaw(cacheKey, cachedRaw);
      }

      final mergedRaw =
          isDelta ? merge(cachedRaw, incoming) : List<dynamic>.from(incoming);

      if (isDelta && mergedRaw.length < cachedRaw.length) {
        return await _latestCachedRaw(cacheKey, cachedRaw);
      }

      await _saveCache(cacheKey, mergedRaw);
      await _updateSyncMetadataFromRaw(
        syncKey,
        mergedRaw,
        dateField,
        fallbackFields: fallbackDateFields,
      );

      return mergedRaw;
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return await _latestCachedRaw(cacheKey, cachedRaw);
    }
  }

  Future<List<dynamic>> _latestCachedRaw(
    String cacheKey,
    List<dynamic> fallback,
  ) async {
    final latest = await _readRawCache(cacheKey);
    if (latest != null && latest.isNotEmpty) {
      return List<dynamic>.from(latest);
    }
    return fallback;
  }

  Future<List<DeductionModel>> fetchDeductions(
    int socCode,
    int memCode, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'deductions_${socCode}_$memCode';

    final raw = await _fetchMemberRawList(
      cacheKey: cacheKey,
      label: 'deductions',
      forceRefresh: forceRefresh,
      fullFetchOnly: true,
      dateField: 'dedctnDate',
      merge: MemberDataMerge.mergeDeductions,
      buildUrl: (since) {
        final params = {
          'soccode': socCode.toString(),
          'membcode': memCode.toString(),
        };
        if (since != null) {
          params['since'] = SyncMetadata.formatSinceForApi(since);
        }
        return Uri.parse('$baseUrl/api/Dedentry/ded')
            .replace(queryParameters: params);
      },
    );

    return raw
        .map((item) => DeductionModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<BillTransactionModel>> fetchBillTransactions(
    int socCode,
    int memCode, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'bill_transactions_${socCode}_$memCode';

    final raw = await _fetchMemberRawList(
      cacheKey: cacheKey,
      label: 'bill_transactions',
      forceRefresh: forceRefresh,
      fullFetchOnly: true,
      dateField: 'billdate',
      fallbackDateFields: const ['todate', 'fromdate'],
      merge: MemberDataMerge.mergeBillTransactions,
      buildUrl: (since) {
        final params = {
          'soccode': socCode.toString(),
          'MembCode': memCode.toString(),
        };
        if (since != null) {
          params['since'] = SyncMetadata.formatSinceForApi(since);
        }
        return Uri.parse('$baseUrl/api/Billtrans/allbilltrans')
            .replace(queryParameters: params);
      },
    );

    return raw
        .map((item) =>
            BillTransactionModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<LedgerTransactionModel>> _loadLedgerFromCache(
    String cacheKey,
    DateTime now,
  ) async {
    final cachedData = await _readRawCache(cacheKey);
    if (cachedData == null) return [];
    return cachedData
        .map(
          (item) =>
              LedgerTransactionModel.fromJson(item).copyWith(lastUpdated: now),
        )
        .toList();
  }

  Future<List<GlmsAccountModel>> _loadGlmsFromCache(int socCode) async {
    final cachedRaw = await _readRawCache('glms_$socCode');
    if (cachedRaw == null || cachedRaw.isEmpty) return [];
    return cachedRaw
        .map(
          (item) => GlmsAccountModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Society account list from Glms. Always a full refresh when hitting the
  /// network (replaces cache). Use [localOnly] on the ledger screen.
  Future<List<GlmsAccountModel>> fetchGlmsAccounts(
    int socCode, {
    bool localOnly = false,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'glms_$socCode';

    if (localOnly) {
      return _loadGlmsFromCache(socCode);
    }

    if (!forceRefresh) {
      final cached = await _loadGlmsFromCache(socCode);
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    final stale = await _loadGlmsFromCache(socCode);

    try {
      final url = Uri.parse('$baseUrl/api/Glms/list').replace(
        queryParameters: {'socitycode': socCode.toString()},
      );
      final response = await _authorizedGet(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded is List
            ? decoded
            : decoded is Map
                ? [decoded]
                : <dynamic>[];

        await _saveCache(cacheKey, list);

        return list
            .map(
              (item) => GlmsAccountModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }

      return stale;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      return stale;
    }
  }

  /// All ledger rows for the member. [sbAccNo] is the login account sent to the
  /// API; the response includes transactions for every [accno] in Glms.
  Future<List<LedgerTransactionModel>> fetchLedgerTransactions(
    int socCode,
    int sbAccNo, {
    bool localOnly = false,
    bool forceRefresh = false,
    bool forceDeltaFetch = false,
  }) async {
    final cacheKey = 'ledger_all_${socCode}_$sbAccNo';
    final now = DateTime.now();

    if (localOnly) {
      return _loadLedgerFromCache(cacheKey, now);
    }

    final raw = await _fetchMemberRawList(
      cacheKey: cacheKey,
      label: 'ledger',
      forceRefresh: forceRefresh,
      forceDeltaFetch: forceDeltaFetch,
      fullFetchOnly: true,
      dateField: 'trdates',
      fallbackDateFields: const ['trDates'],
      merge: MemberDataMerge.mergeLedger,
      buildUrl: (since) {
        final params = {
          'sbaccno': sbAccNo.toString(),
          'socitycode': socCode.toString(),
        };
        if (since != null) {
          params['since'] = SyncMetadata.formatSinceForApi(since);
        }
        return Uri.parse('$baseUrl/api/Acctrn/ledger')
            .replace(queryParameters: params);
      },
    );

    return raw
        .map(
          (item) => LedgerTransactionModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ).copyWith(lastUpdated: now),
        )
        .toList();
  }

  /// Sync all member datasets. With [forceRefresh], every dataset is fully
  /// re-downloaded (no `since` / delta merge).
  Future<void> syncMemberData({
    required int socCode,
    required int memCode,
    required int accNo,
    required String appString,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      final refreshed = await refreshAuthToken();
      if (!refreshed) {
        throw Exception('Failed to refresh login session');
      }
    }

    final tasks = <Future<void>>[
      fetchGlmsAccounts(socCode, forceRefresh: forceRefresh).then((_) {}),
      fetchPassbook(socCode, memCode, forceRefresh: forceRefresh).then((_) {}),
      fetchDeductions(socCode, memCode, forceRefresh: forceRefresh).then((_) {}),
      fetchBillTransactions(socCode, memCode, forceRefresh: forceRefresh)
          .then((_) {}),
      fetchLedgerTransactions(
        socCode,
        accNo,
        forceRefresh: forceRefresh,
      ).then((_) {}),
    ];

    if (appString.split(',').contains('5')) {
      tasks.add(
        fetchMilkSales(socCode, memCode, forceRefresh: forceRefresh).then((_) {}),
      );
    }

    await Future.wait(tasks);
  }

  Future<List<MilkSaleModel>> _loadMilkSalesFromCache(
    String cacheKey,
    DateTime now,
  ) async {
    final cachedData = await _readRawCache(cacheKey);
    if (cachedData == null) return [];
    return cachedData
        .map(
          (item) => MilkSaleModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ).copyWith(lastUpdated: now),
        )
        .toList();
  }

  Future<List<MilkSaleModel>> fetchMilkSales(
    int socCode,
    int memCode, {
    bool localOnly = false,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'milk_sales_${socCode}_$memCode';
    final now = DateTime.now();

    if (localOnly) {
      return _loadMilkSalesFromCache(cacheKey, now);
    }

    final raw = await _fetchMemberRawList(
      cacheKey: cacheKey,
      label: 'milk_sales',
      forceRefresh: forceRefresh,
      fullFetchOnly: true,
      dateField: 'trdate',
      merge: MemberDataMerge.mergeMilkSales,
      buildUrl: (since) {
        final params = {
          'socitycode': socCode.toString(),
          'membcode': memCode.toString(),
        };
        if (since != null) {
          params['since'] = SyncMetadata.formatSinceForApi(since);
        }
        return Uri.parse('$baseUrl/api/MilkSale/list')
            .replace(queryParameters: params);
      },
    );

    return raw
        .map(
          (item) => MilkSaleModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ).copyWith(lastUpdated: now),
        )
        .toList();
  }
}

String _encodeJsonList(List<dynamic> data) {
  return jsonEncode(data);
}











