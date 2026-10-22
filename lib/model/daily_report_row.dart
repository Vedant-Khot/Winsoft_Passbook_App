// In passbook/model/daily_report_row.dart

import 'package:passbook/model/passbook_model.dart';

class DailyMilkRecord {
  final DateTime date;

  // Used to store the initial, raw data from the API
  final List<PassbookModel> morningEntries;
  final List<PassbookModel> eveningEntries;

  // Used to store the final, aggregated data for display in the UI
  final PassbookModel? morningEntry;
  final PassbookModel? eveningEntry;

  DailyMilkRecord({
    required this.date,
    // These parameters are for the lists
    List<PassbookModel>? morningEntries,
    List<PassbookModel>? eveningEntries,
    // These parameters are for the single aggregated entries
    this.morningEntry,
    this.eveningEntry,
  }) : morningEntries = morningEntries ?? [],
       eveningEntries = eveningEntries ?? [];
}
