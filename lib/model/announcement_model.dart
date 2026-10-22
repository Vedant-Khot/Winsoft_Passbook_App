class AnnouncementModel {
  final int announcementId;
  final int socCode;
  final int membCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? societyMessageHead;
  final String? societyMessageTitle;
  final DateTime? systemDate;

  AnnouncementModel({
    required this.announcementId,
    required this.socCode,
    required this.membCode,
    this.startDate,
    this.endDate,
    this.societyMessageHead,
    this.societyMessageTitle,
    this.systemDate,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? 0;
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return AnnouncementModel(
      announcementId: parseId(json['announcementId']),
      socCode: parseId(json['socCode']),
      membCode: parseId(json['membCode']),
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      societyMessageHead: json['societyMessageHead']?.toString(),
      societyMessageTitle: json['societyMessageTitle']?.toString(),
      systemDate: parseDate(json['systemDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'announcementId': announcementId,
      'socCode': socCode,
      'membCode': membCode,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'societyMessageHead': societyMessageHead,
      'societyMessageTitle': societyMessageTitle,
      'systemDate': systemDate?.toIso8601String(),
    };
  }

  /// Checks if the announcement is currently active (today is between startDate and endDate inclusive).
  bool get isActive {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (startDate != null) {
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      if (today.isBefore(start)) return false;
    }

    if (endDate != null) {
      final limit = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (today.isAfter(limit)) return false;
    }

    return true;
  }
}
