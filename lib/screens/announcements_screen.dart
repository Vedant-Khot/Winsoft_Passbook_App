import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../model/announcement_model.dart';

class AnnouncementsScreen extends StatelessWidget {
  final List<AnnouncementModel> announcements;

  const AnnouncementsScreen({super.key, required this.announcements});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final poppinsStyle = AppTextStyles.poppins();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Announcements",
          style: poppinsStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final announcement = announcements[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.15),
                    colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.campaign,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (announcement.societyMessageHead != null &&
                            announcement.societyMessageHead!.trim().isNotEmpty)
                          Text(
                            announcement.societyMessageHead!,
                            style: poppinsStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        if (announcement.societyMessageTitle != null &&
                            announcement.societyMessageTitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            announcement.societyMessageTitle!,
                            style: poppinsStyle.copyWith(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (announcement.endDate != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            "Valid until: ${announcement.endDate!.day}/${announcement.endDate!.month}/${announcement.endDate!.year}",
                            style: poppinsStyle.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
