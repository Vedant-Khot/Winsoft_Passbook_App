import 'package:passbook/model/bill_transaction_model.dart';
import 'package:passbook/model/data_parser.dart';
import 'package:intl/intl.dart';

class BillPeriod {
  final DateTime fromDate;
  final DateTime toDate;
  // We can store the full transaction if we need it later for the summary
  final BillTransactionModel sourceTransaction;

  BillPeriod({
    required this.fromDate,
    required this.toDate,
    required this.sourceTransaction,
  });

  // --- NEW: Language-Aware displayValue ---
  /// Generates the display string for the dropdown based on a langCode.
  String getDisplayValue(int langCode) {
    // We use our existing helper which handles separators and two-digit years.
    final from = formatLanguageAwareDateShort(fromDate, langCode);
    final to = formatLanguageAwareDateShort(toDate, langCode);

    // We can use l10n here if we add a "to" key, but a simple string is also fine.
    // For simplicity, we'll hardcode "to" for now.
    return '$from to $to';
  }

  // We can keep the old getter for any part of the app that doesn't need
  // the language-aware version, or remove it. Let's keep it for now.
  String get displayValue {
    // This is the old, English-only version.
    return '${DateFormat('dd MMM yyyy').format(fromDate)} to ${DateFormat('dd MMM yyyy').format(toDate)}';
  }

  // This is what the user will see in the dropdown menu
  // String get displayValue {
  //   final from = DateFormat('dd MMM yyyy').format(fromDate);
  //   final to = DateFormat('dd MMM yyyy').format(toDate);
  //   return '$from to $to';
  // }

  // We need to override these for the DropdownButton to correctly
  // identify unique items, especially if there are duplicates.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillPeriod &&
          runtimeType == other.runtimeType &&
          fromDate == other.fromDate &&
          toDate == other.toDate;

  @override
  int get hashCode => fromDate.hashCode ^ toDate.hashCode;
}
