import 'package:firebase_core/firebase_core.dart';
import 'package:passbook/model/mem_info_model.dart';
import 'package:passbook/utils/user_facing_error.dart';

UserFacingError mapLoginResponse(LoginResponse response) {
  if (response.isNetworkError) {
    return const UserFacingError(
      title: 'No Internet Connection',
      message: 'Unable to reach the server. Please check your connection and try again.',
      guidance:
          '• Turn on mobile data or Wi‑Fi\n'
          '• Move to an area with better signal\n'
          '• Disable VPN if you are using one\n'
          '• Try again in a few moments',
    );
  }

  final message = response.message.toLowerCase();

  if (message.contains('incorrect dairy code') ||
      message.contains('please check dairy code')) {
    return const UserFacingError(
      title: 'Invalid Dairy Code',
      message: 'The dairy code you entered was not found.',
      guidance:
          '• Double-check the dairy code with your society office\n'
          '• Make sure there are no extra spaces\n'
          '• Contact support if you are unsure of your code',
    );
  }

  if (message.contains('incorrect phone') ||
      message.contains('phone number')) {
    return const UserFacingError(
      title: 'Phone Number Not Registered',
      message: 'This phone number is not registered for the given dairy code.',
      guidance:
          '• Verify the 10-digit mobile number registered with your dairy\n'
          '• Confirm the dairy code matches your society\n'
          '• Contact your dairy office to update your registered number',
    );
  }

  if (message.contains('no token')) {
    return const UserFacingError(
      title: 'Login Incomplete',
      message: 'Your account was found but the server did not provide a session token.',
      guidance:
          '• Wait a moment and try signing in again\n'
          '• If the problem continues, contact your dairy support team',
    );
  }

  if (message.contains('status code 5')) {
    return UserFacingError(
      title: 'Server Unavailable',
      message: response.message,
      guidance:
          'The server is temporarily unavailable.\n\n'
          '• Try again in a few minutes\n'
          '• Contact support if this keeps happening',
    );
  }

  if (message.contains('status code 4')) {
    return UserFacingError(
      title: 'Request Failed',
      message: response.message,
      guidance: 'Please verify your dairy code and phone number, then try again.',
    );
  }

  return UserFacingError(
    title: 'Sign In Failed',
    message: response.message.isNotEmpty
        ? response.message
        : 'Unable to sign in. Please try again.',
    guidance: 'Check your details and try again. Contact support if the issue persists.',
  );
}

UserFacingError mapFcmError(Object error) {
  final text = error.toString().toLowerCase();

  if (error is FirebaseException) {
    return _mapFcmErrorText(error.code, error.message ?? text);
  }

  return _mapFcmErrorText('', text);
}

UserFacingError _mapFcmErrorText(String code, String text) {
  if (text.contains('service_not_available') ||
      text.contains('service not available')) {
    return const UserFacingError(
      title: 'Push Notifications Unavailable',
      message:
          'You signed in successfully, but push notifications could not be set up right now.',
      guidance:
          '• Update Google Play Services from the Play Store\n'
          '• Ensure you have a stable internet connection\n'
          '• Restart your phone and open the app again\n'
          '• If using an emulator, use one with Google Play installed\n\n'
          'You can still use the app — only alerts may not arrive until this is fixed.',
      severity: MessageSeverity.warning,
    );
  }

  if (text.contains('missing_google_play_services') ||
      text.contains('google play services') ||
      text.contains('googleplaynotavailable')) {
    return const UserFacingError(
      title: 'Google Play Services Required',
      message:
          'Push notifications need Google Play Services, which is missing or outdated on this device.',
      guidance:
          '• Install or update Google Play Services from the Play Store\n'
          '• On Huawei or custom ROM devices, push alerts may not be supported\n\n'
          'You can continue using the app without push notifications.',
      severity: MessageSeverity.warning,
    );
  }

  if (text.contains('permission') ||
      text.contains('not authorized') ||
      code == 'permission-blocked') {
    return const UserFacingError(
      title: 'Notification Permission Denied',
      message:
          'You signed in successfully, but notification permission was not granted.',
      guidance:
          '• Open Settings → Apps → Passbook → Notifications\n'
          '• Enable notifications for this app\n'
          '• Reopen the app to register for alerts',
      severity: MessageSeverity.warning,
    );
  }

  if (text.contains('network') ||
      text.contains('socket') ||
      text.contains('failed host lookup') ||
      text.contains('timeout')) {
    return const UserFacingError(
      title: 'Notifications Not Registered',
      message:
          'Could not register for push notifications due to a network issue.',
      guidance:
          '• Check your internet connection\n'
          '• Open the app again when you are back online\n\n'
          'Your login is still valid and the app will work normally.',
      severity: MessageSeverity.warning,
    );
  }

  if (text.contains('token') && text.contains('null')) {
    return const UserFacingError(
      title: 'Notification Token Unavailable',
      message:
          'The device could not obtain a notification token at this time.',
      guidance:
          '• Restart the app\n'
          '• Ensure Google Play Services is up to date\n'
          '• Try again on a physical Android device if you are on an emulator',
      severity: MessageSeverity.warning,
    );
  }

  return UserFacingError(
    title: 'Push Notifications Not Set Up',
    message: 'Signed in successfully, but notification setup encountered a problem.',
    guidance:
        'You can use the app normally. To receive alerts, try:\n'
        '• Closing and reopening the app\n'
        '• Updating Google Play Services\n'
        '• Checking your internet connection\n\n'
        'Technical details: $text',
    severity: MessageSeverity.warning,
  );
}

UserFacingError mapFcmTokenPostFailure() {
  return const UserFacingError(
    title: 'Alerts May Be Delayed',
    message:
        'Push notifications were set up on this device but could not be saved to the server.',
    guidance:
        '• Check your internet connection\n'
        '• Restart the app to retry registration\n\n'
        'You can still use all app features.',
    severity: MessageSeverity.warning,
  );
}

UserFacingError mapFcmTopicSubscriptionFailure() {
  return const UserFacingError(
    title: 'Some Alerts May Be Missing',
    message:
        'General notifications are enabled, but society announcement alerts may not arrive.',
    guidance:
        '• Restart the app when you have a stable connection\n'
        '• Other app features are unaffected',
    severity: MessageSeverity.warning,
  );
}

UserFacingError mapUnexpectedError(Object error) {
  final text = error.toString();

  if (text.toLowerCase().contains('firebase_messaging') ||
      text.toLowerCase().contains('service_not_available')) {
    return mapFcmError(error);
  }

  return UserFacingError(
    title: 'Something Went Wrong',
    message: 'An unexpected error occurred while signing in.',
    guidance:
        '• Check your internet connection\n'
        '• Close and reopen the app\n'
        '• Try again in a few minutes\n\n'
        'If this continues, contact support with this message:\n$text',
  );
}

UserFacingError sessionExpiredMessage() {
  return const UserFacingError(
    title: 'Session Expired',
    message: 'Your previous session is no longer valid. Please sign in again.',
    guidance:
        '• Enter your dairy code and registered phone number\n'
        '• Contact your dairy office if your details have changed',
    severity: MessageSeverity.info,
  );
}

UserFacingError loginSuccessMessage() {
  return const UserFacingError(
    title: 'Welcome Back',
    message: 'You have signed in successfully.',
    severity: MessageSeverity.success,
  );
}

UserFacingError offlineModeMessage() {
  return const UserFacingError(
    title: 'Offline Mode',
    message: 'Could not verify your session online. Showing your last saved data.',
    guidance:
        '• Connect to the internet to refresh your data\n'
        '• Some information may be outdated until you are back online',
    severity: MessageSeverity.info,
  );
}
