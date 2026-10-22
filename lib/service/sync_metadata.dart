import 'package:passbook/model/data_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks per-dataset last dates and skip logic for member-wise sync.
class SyncMetadata {
  SyncMetadata._();

  /// How recent local [maxDataDate] must be to skip a network call.
  static const int freshnessDays = 2;

  static const _lastDatePrefix = 'sync_last_date_';
  static const _verifiedPrefix = 'sync_verified_';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dayKey(DateTime value) {
    final d = _dateOnly(value);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<void> setLastDate(String datasetKey, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_lastDatePrefix$datasetKey',
      _dateOnly(date).toIso8601String(),
    );
  }

  static Future<bool> wasVerifiedToday(String datasetKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_verifiedPrefix$datasetKey') == _dayKey(DateTime.now());
  }

  static Future<void> markVerifiedToday(String datasetKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_verifiedPrefix$datasetKey', _dayKey(DateTime.now()));
  }

  static bool isDataFresh(DateTime? maxDataDate, {int? freshnessDays}) {
    if (maxDataDate == null) return false;
    final days = freshnessDays ?? SyncMetadata.freshnessDays;
    final cutoff = _dateOnly(DateTime.now().subtract(Duration(days: days)));
    return !_dateOnly(maxDataDate).isBefore(cutoff);
  }

  /// Returns true when the app should use cache only (no API call).
  static Future<bool> shouldSkipNetworkFetch(
    String datasetKey,
    DateTime? maxDataDate, {
    bool forceCheck = false,
  }) async {
    if (forceCheck) return false;
    if (maxDataDate == null) return false;
    if (isDataFresh(maxDataDate)) return true;
    if (await wasVerifiedToday(datasetKey)) return true;
    return false;
  }

  static Future<void> clearVerifiedToday(String datasetKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_verifiedPrefix$datasetKey');
  }

  static String formatSinceForApi(DateTime date) => _dayKey(date);

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_lastDatePrefix) || key.startsWith(_verifiedPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  static DateTime? maxDateFromRawList(
    List<dynamic> items,
    String field, {
    List<String> fallbackFields = const [],
  }) {
    DateTime? max;
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      DateTime? parsed = parseDateFlexible(map[field]);
      for (final fallback in fallbackFields) {
        parsed ??= parseDateFlexible(map[fallback]);
      }
      if (parsed != null && (max == null || parsed.isAfter(max))) {
        max = parsed;
      }
    }
    return max;
  }
}

/// Merge helpers for delta sync responses into existing cached JSON rows.
class MemberDataMerge {
  MemberDataMerge._();

  static String _field(Map<String, dynamic> item, String key) =>
      item[key]?.toString() ?? '';

  /// Prefer server-assigned row ids; fall back to a richer composite key.
  static String mergeKey(
    Map<String, dynamic> item, {
    required List<String> idFields,
    required String Function(Map<String, dynamic> item) fallback,
  }) {
    for (final field in idFields) {
      final value = item[field];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text == '0') continue;
      return '$field:$text';
    }
    return fallback(item);
  }

  static List<dynamic> mergeRawByKey(
    List<dynamic> existing,
    List<dynamic> incoming,
    String Function(Map<String, dynamic> item) keyBuilder,
  ) {
    final merged = <String, dynamic>{};

    void addItem(dynamic raw) {
      if (raw is! Map) return;
      final map = Map<String, dynamic>.from(raw);
      merged[keyBuilder(map)] = map;
    }

    for (final item in existing) {
      addItem(item);
    }
    for (final item in incoming) {
      addItem(item);
    }

    return merged.values.toList();
  }

  static String passbookMergeKey(Map<String, dynamic> row) => mergeKey(
        row,
        idFields: const ['mltrno', 'milksrno', 'lineno'],
        fallback: (item) =>
            '${_field(item, 'trndate')}_${_field(item, 'me')}_${_field(item, 'cobf')}_'
            '${_field(item, 'membCode')}_${_field(item, 'liters')}_${_field(item, 'fat')}_'
            '${_field(item, 'rate')}_${_field(item, 'degree')}_${_field(item, 'amount')}',
      );

  static List<dynamic> mergePassbook(List<dynamic> existing, List<dynamic> incoming) {
    return mergeRawByKey(
      existing,
      incoming,
      passbookMergeKey,
    );
  }

  static List<dynamic> mergeDeductions(List<dynamic> existing, List<dynamic> incoming) {
    return mergeRawByKey(
      existing,
      incoming,
      (item) => mergeKey(
        item,
        idFields: const ['dedentrytrno', 'dedctnTrno'],
        fallback: (row) =>
            '${_field(row, 'billno')}_${_field(row, 'dedcode')}_${_field(row, 'dedctnDate')}_'
            '${_field(row, 'membCode')}_${_field(row, 'actdedAmt')}_${_field(row, 'dedctnAmt1')}',
      ),
    );
  }

  static List<dynamic> mergeBillTransactions(
    List<dynamic> existing,
    List<dynamic> incoming,
  ) {
    return mergeRawByKey(
      existing,
      incoming,
      (item) => mergeKey(
        item,
        idFields: const ['billtrno'],
        fallback: (row) =>
            '${_field(row, 'billno')}_${_field(row, 'mbillno')}_${_field(row, 'cobf')}_'
            '${_field(row, 'billdate')}_${_field(row, 'membcode')}',
      ),
    );
  }

  static List<dynamic> mergeLedger(List<dynamic> existing, List<dynamic> incoming) {
    return mergeRawByKey(
      existing,
      incoming,
      (item) => mergeKey(
        item,
        idFields: const ['trno', 'autotrno'],
        fallback: (row) =>
            '${_field(row, 'accno')}_${_field(row, 'trdates')}_${_field(row, 'trDates')}_'
            '${_field(row, 'part')}_${_field(row, 'amt')}_${_field(row, 'crdb')}_'
            '${_field(row, 'opInd')}_${_field(row, 'docno')}_${_field(row, 'voucherNo')}_'
            '${_field(row, 'trntype')}',
      ),
    );
  }

  static List<dynamic> mergeMilkSales(List<dynamic> existing, List<dynamic> incoming) {
    return mergeRawByKey(
      existing,
      incoming,
      (item) => mergeKey(
        item,
        idFields: const ['milksaleno'],
        fallback: (row) =>
            '${_field(row, 'trdate')}_${_field(row, 'me')}_${_field(row, 'cobf')}_'
            '${_field(row, 'tot')}_${_field(row, 'paid')}_${_field(row, 'liters')}',
      ),
    );
  }
}
