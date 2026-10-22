import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:passbook/model/announcement_model.dart';
import 'package:passbook/model/fcm_init_result.dart';
import 'package:passbook/service/api_service.dart';
import 'package:passbook/utils/error_mappers.dart';
import 'package:passbook/utils/user_facing_error.dart';

// This function MUST be a top-level function (not inside a class)
// to be accessible when the app is terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other services in the background, like local notifications,
  // you must initialize them here.
  await Firebase.initializeApp();

  debugPrint("Handling a background message: ${message.messageId}");

  // Process data update actions in the background
  await _processBackgroundDataUpdate(message);

  // To show a notification when the app is in the background or terminated,
  // you can call the showLocalNotification logic here as well.
  if (message.notification != null) {
    final localNotifications = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await localNotifications.initialize(settings);

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    await localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: message.data['route'],
    );
  }
}

/// Helper function to perform silent background caches update on demand
Future<void> _processBackgroundDataUpdate(RemoteMessage message) async {
  try {
    final apiService = ApiService();
    await apiService.init();
    final user = apiService.currentUser;
    if (user == null) {
      debugPrint("CustomFirebaseApi: No user is logged in. Skipping background sync.");
      return;
    }

    // Check if the message contains announcement data
    if (message.data.containsKey('announcementId') ||
        message.data.containsKey('societyMessageTitle')) {
      try {
        final announcement = AnnouncementModel.fromJson(message.data);
        // Only save it if it is meant for this society (or global)
        if (announcement.socCode == 0 || announcement.socCode == user.socCode) {
          await apiService.saveAnnouncementToCache(
            user.socCode,
            user.membCode,
            announcement,
          );
          debugPrint("CustomFirebaseApi: Saved new announcement from push notification: ${announcement.societyMessageHead}");
        }
      } catch (e) {
        debugPrint("CustomFirebaseApi: Error parsing announcement from data payload: $e");
      }
    }

    final action = message.data['action'];
    if (action == null) return;

    debugPrint("CustomFirebaseApi: Processing background data update action: $action");

    switch (action) {
      case 'refresh_passbook':
        await apiService.fetchPassbook(user.socCode, user.membCode, forceRefresh: true);
        debugPrint("CustomFirebaseApi: Background sync complete for passbook.");
        break;
      case 'refresh_ledger':
        await apiService.fetchLedgerTransactions(user.socCode, user.accno, forceRefresh: true);
        debugPrint("CustomFirebaseApi: Background sync complete for ledger.");
        break;
      case 'refresh_deductions':
        await apiService.fetchDeductions(user.socCode, user.membCode, forceRefresh: true);
        debugPrint("CustomFirebaseApi: Background sync complete for deductions.");
        break;
      case 'refresh_bills':
        await apiService.fetchBillTransactions(user.socCode, user.membCode, forceRefresh: true);
        debugPrint("CustomFirebaseApi: Background sync complete for bill transactions.");
        break;
      case 'refresh_milk_sales':
        await apiService.fetchMilkSales(user.socCode, user.membCode, forceRefresh: true);
        debugPrint("CustomFirebaseApi: Background sync complete for milk sales.");
        break;
      case 'refresh_announcements':
        await apiService.fetchAnnouncements(user.socCode, user.membCode, forceRefresh: true);
        debugPrint("CustomFirebaseApi: Background sync complete for announcements.");
        break;
      case 'delete_announcement':
        final id = message.data['announcementId'];
        if (id != null) {
          await apiService.deleteAnnouncementFromCache(user.socCode, user.membCode, id);
          debugPrint("CustomFirebaseApi: Remote deletion of announcement ID: $id completed.");
        }
        break;
      case 'refresh_all':
        await apiService.syncMemberData(
          socCode: user.socCode,
          memCode: user.membCode,
          accNo: user.accno,
          appString: user.appString,
          forceRefresh: true,
        );
        await apiService.fetchAnnouncements(
          user.socCode,
          user.membCode,
          forceRefresh: true,
        );
        debugPrint("CustomFirebaseApi: Background sync complete for all data.");
        break;
      default:
        debugPrint("CustomFirebaseApi: Unknown action: $action");
        break;
    }
  } catch (e) {
    debugPrint("CustomFirebaseApi: Error in background data update: $e");
  }
}

class CustomFirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initializes the local notifications plugin with the CORRECT icon.
  Future<void> initLocalNotifications() async {
    // --- THIS IS THE PRIMARY FIX ---
    // Use the exact name of your simple, white-and-transparent icon
    // from the `android/app/src/main/res/drawable` folder.
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // ----------------------------

    const settings = InitializationSettings(android: android);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (payload) {
        debugPrint('Notification tapped with payload: ${payload.payload}');
        // TODO: Handle navigation based on the payload
      },
    );

    // Create a notification channel for Android (important for Android 8.0+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
            importance: Importance.max,
          ),
        );
  }

  /// Shows a local notification when the app is in the foreground.
  Future<void> showLocalNotification(RemoteMessage message) async {
    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: message.data['route'],
    );
  }

  /// Initializes notification services and registers the device token.
  /// Failures are returned as warnings — they must not block login.
  Future<FcmInitResult> initNotifications(
    String token,
    int socCode,
    int memCode,
  ) async {
    final warnings = <UserFacingError>[];

    try {
      await _firebaseMessaging.requestPermission();
    } catch (e) {
      debugPrint("CustomFirebaseApi: Notification permission request failed: $e");
      warnings.add(mapFcmError(e));
      return FcmInitResult(isFullySuccessful: false, warnings: warnings);
    }

    String? fcmToken;
    try {
      fcmToken = await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint("CustomFirebaseApi: Failed to get FCM token: $e");
      warnings.add(mapFcmError(e));
      return FcmInitResult(isFullySuccessful: false, warnings: warnings);
    }

    if (fcmToken == null || fcmToken.isEmpty) {
      debugPrint("CustomFirebaseApi: FCM token was null or empty.");
      warnings.add(mapFcmError('FCM token is null'));
      return FcmInitResult(isFullySuccessful: false, warnings: warnings);
    }

    debugPrint("FCM Token: $fcmToken");

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidId = androidInfo.id;

      final registered = await ApiService().postFcmToken(
        token,
        fcmToken,
        androidId,
        socCode,
        memCode,
      );

      if (!registered) {
        debugPrint("CustomFirebaseApi: Failed to post FCM token to server.");
        warnings.add(mapFcmTokenPostFailure());
      }
    } catch (e) {
      debugPrint("CustomFirebaseApi: Error posting FCM token: $e");
      warnings.add(mapFcmTokenPostFailure());
    }

    try {
      await _firebaseMessaging.subscribeToTopic('announcements_$socCode');
      await _firebaseMessaging.subscribeToTopic('announcements_global');
      debugPrint(
        "Successfully subscribed to 'announcements_$socCode' and 'announcements_global' topics.",
      );
    } catch (e) {
      debugPrint("CustomFirebaseApi: Failed to subscribe to topics: $e");
      warnings.add(mapFcmTopicSubscriptionFailure());
    }

    try {
      await initializeListenersOnly();
    } catch (e) {
      debugPrint("CustomFirebaseApi: Failed to initialize listeners: $e");
      warnings.add(mapFcmError(e));
      return FcmInitResult(isFullySuccessful: false, warnings: warnings);
    }

    return FcmInitResult(
      isFullySuccessful: warnings.isEmpty,
      warnings: warnings,
    );
  }

  /// Initializes only the message listeners.
  Future<void> initializeListenersOnly() async {
    await initLocalNotifications();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      _processBackgroundDataUpdate(message);
      if (message.notification != null) {
        showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      _processBackgroundDataUpdate(message);
      // TODO: Handle navigation here based on message.data
    });
  }
}

