import 'package:intl/intl.dart'; // <-- IMPORTANT: Add this import

class BillTransactionModel {
  final int? billno;
  final DateTime? fromdate;
  final DateTime? todate;
  final DateTime? billdate;
  final String? cobf;
  final double liters;
  final double amount;
  final double totearn;
  final double totded;
  final double netamt;
  final double bliters;
  final double bamount;
  final double cliters;
  final double camount;

  BillTransactionModel({
    this.billno,
    this.fromdate,
    this.todate,
    this.billdate,
    this.cobf,
    required this.liters,
    required this.amount,
    required this.totearn,
    required this.totded,
    required this.netamt,
    required this.bliters,
    required this.bamount,
    required this.cliters,
    required this.camount,
  });

  // --- NEW, MORE ROBUST fromJson FACTORY ---
  factory BillTransactionModel.fromJson(Map<String, dynamic> json) {
    /// A flexible date parser that tries multiple formats.
    DateTime? _parseDateFlexible(String? dateString) {
      if (dateString == null || dateString.isEmpty) {
        return null;
      }

      // 1. First, try the standard ISO 8601 parser. It's fast and handles many common cases.
      // It can parse formats like '2025-04-11T10:00:00Z'
      final isoDate = DateTime.tryParse(dateString);
      if (isoDate != null) {
        return isoDate;
      }

      // 2. If ISO fails, try our list of custom formats.
      // Add any other formats your API might send to this list.
      final customFormats = [
        DateFormat('dd/MM/yyyy'), // For strings like '11/04/2025'
        DateFormat('yyyy-MM-dd'), // For strings like '2025-04-11'
      ];

      for (var format in customFormats) {
        try {
          // If parsing succeeds, return the date immediately.
          return format.parse(dateString);
        } on FormatException {
          // If it fails, do nothing and let the loop try the next format.
          continue;
        }
      }

      // 3. If all attempts fail, return null.
      return null;
    }

    return BillTransactionModel(
      billno: json['billno'],

      // Use our new flexible helper for all date fields
      fromdate: _parseDateFlexible(json['fromdate']),
      todate: _parseDateFlexible(json['todate']),
      billdate: _parseDateFlexible(json['billdate']),

      cobf: json['cobf'],
      liters: (json['liters'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      totearn: (json['totearn'] as num?)?.toDouble() ?? 0.0,
      totded: (json['totded'] as num?)?.toDouble() ?? 0.0,
      netamt: (json['netamt'] as num?)?.toDouble() ?? 0.0,
      bliters: (json['bliters'] as num?)?.toDouble() ?? 0.0,
      bamount: (json['bamount'] as num?)?.toDouble() ?? 0.0,
      cliters: (json['cliters'] as num?)?.toDouble() ?? 0.0,
      camount: (json['camount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
