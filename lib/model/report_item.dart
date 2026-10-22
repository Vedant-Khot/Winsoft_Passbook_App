// Import the data models that this file will be "wrapping".
import '../model/bill_transaction_model.dart';
import '../model/deduction_model.dart';
import '../model/passbook_model.dart';

// -----------------------------------------------------------------------------
// This is the "base" or "parent" class. We use an abstract class because
// you never create an instance of a plain "ReportItem". You only create
// instances of its more specific children (like ReportHeaderItem, MilkEntryItem, etc.).
//
// Think of this as defining a "contract": anything that wants to be shown in our
// report list MUST be a type of ReportItem.
// -----------------------------------------------------------------------------
abstract class ReportItem {}

// -----------------------------------------------------------------------------
// A simple class to represent a title or a heading in the list.
// For example: "Morning Collection", "Deductions", "Bill Summary".
// -----------------------------------------------------------------------------
// A class to represent a COLLAPSIBLE heading in the list.
class ReportHeaderItem extends ReportItem {
  final String title;

  // --- ADD THESE NEW PROPERTIES ---
  final double
  totalAmount; // e.g., total earnings for morning, total deductions
  final int itemCount; // e.g., number of morning entries

  ReportHeaderItem({
    required this.title,
    this.totalAmount = 0.0, // Default to 0
    this.itemCount = 0, // Default to 0
  });
}

// -----------------------------------------------------------------------------
// A class that holds a single milk entry from the passbook data.
// It acts as a "wrapper" or "container" for a PassbookModel object.
// -----------------------------------------------------------------------------
class MilkEntryItem extends ReportItem {
  final PassbookModel milkEntry;

  MilkEntryItem(this.milkEntry);
}

// -----------------------------------------------------------------------------
// A class that holds a single deduction entry.
// It acts as a "wrapper" for a DeductionModel object.
// -----------------------------------------------------------------------------
class DeductionItem extends ReportItem {
  final DeductionModel deduction;

  DeductionItem(this.deduction);
}

// -----------------------------------------------------------------------------
// A class that holds the final bill summary information.
// It acts as a "wrapper" for a BillTransactionModel object.
// -----------------------------------------------------------------------------
class BillSummaryItem extends ReportItem {
  final BillTransactionModel summary;

  BillSummaryItem(this.summary);
}

// A class to hold our dynamically calculated summary totals.
class CalculatedSummaryItem extends ReportItem {
  final double totalLiters;
  final double totalLitersAmount;
  final double totalEarnings;
  final double totalDeductions;
  final double netAmount;

  CalculatedSummaryItem({
    required this.totalLiters,
    required this.totalLitersAmount,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netAmount,
  });
}
