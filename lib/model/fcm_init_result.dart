import 'package:passbook/utils/user_facing_error.dart';

/// Result of Firebase Cloud Messaging initialization.
class FcmInitResult {
  final bool isFullySuccessful;
  final List<UserFacingError> warnings;

  const FcmInitResult({
    required this.isFullySuccessful,
    this.warnings = const [],
  });

  UserFacingError? get primaryWarning =>
      warnings.isNotEmpty ? warnings.first : null;
}
