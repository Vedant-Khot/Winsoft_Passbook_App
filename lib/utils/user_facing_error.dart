import 'package:flutter/material.dart';

enum MessageSeverity { error, warning, success, info }

/// A user-readable error or notice with optional troubleshooting guidance.
class UserFacingError {
  final String title;
  final String message;
  final String? guidance;
  final MessageSeverity severity;

  const UserFacingError({
    required this.title,
    required this.message,
    this.guidance,
    this.severity = MessageSeverity.error,
  });
}

Color severityColor(MessageSeverity severity, ThemeData theme) {
  switch (severity) {
    case MessageSeverity.error:
      return theme.colorScheme.error;
    case MessageSeverity.warning:
      return Colors.orange.shade700;
    case MessageSeverity.success:
      return Colors.green.shade600;
    case MessageSeverity.info:
      return theme.colorScheme.primary;
  }
}

IconData severityIcon(MessageSeverity severity) {
  switch (severity) {
    case MessageSeverity.error:
      return Icons.error_outline;
    case MessageSeverity.warning:
      return Icons.warning_amber_rounded;
    case MessageSeverity.success:
      return Icons.check_circle_outline;
    case MessageSeverity.info:
      return Icons.info_outline;
  }
}

void showUserMessageSnackBar(BuildContext context, UserFacingError error) {
  final theme = Theme.of(context);
  final color = severityColor(error.severity, theme);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(severityIcon(error.severity), color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(error.message, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: error.guidance != null
          ? const Duration(seconds: 6)
          : const Duration(seconds: 4),
      action: error.guidance != null
          ? SnackBarAction(
              label: 'Help',
              textColor: Colors.white,
              onPressed: () => showUserMessageDialog(context, error),
            )
          : null,
    ),
  );
}

Future<void> showUserMessageDialog(
  BuildContext context,
  UserFacingError error,
) async {
  final theme = Theme.of(context);
  final color = severityColor(error.severity, theme);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(severityIcon(error.severity), color: color, size: 32),
      title: Text(error.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            if (error.guidance != null) ...[
              const SizedBox(height: 16),
              Text(
                'What you can do',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(error.guidance!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showUserMessage(
  BuildContext context,
  UserFacingError error, {
  bool preferDialog = false,
}) {
  if (preferDialog || (error.guidance != null && error.severity == MessageSeverity.error)) {
    showUserMessageDialog(context, error);
  } else {
    showUserMessageSnackBar(context, error);
  }
}
