import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:passbook/model/data_parser.dart';

/// Builds display rows for the passbook table off the UI thread.
class PassbookRowProcessor {
  static Future<List<Map<String, dynamic>>> process(
    List<Map<String, dynamic>> entries,
    int langCode,
  ) {
    return compute(_processPassbookRows, {
      'entries': entries,
      'langCode': langCode,
    });
  }
}

List<Map<String, dynamic>> _processPassbookRows(Map<String, dynamic> args) {
  final rawEntries = args['entries'] as List<dynamic>;
  final langCode = args['langCode'] as int;

  final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
  for (final item in rawEntries) {
    final entry = Map<String, dynamic>.from(item as Map);
    final parsed = parseDateFlexible(entry['trndate']?.toString());
    if (parsed == null) continue;

    final dateKey = _formatDateShort(parsed, langCode);
    groupedByDate.putIfAbsent(dateKey, () => []).add(entry);
  }

  const summaryConfig = [
    {'me': 1, 'cobf': 'C'},
    {'me': 1, 'cobf': 'B'},
    {'me': 2, 'cobf': 'C'},
    {'me': 2, 'cobf': 'B'},
  ];

  final List<Map<String, dynamic>> processedRows = [];

  for (final dateKey in groupedByDate.keys) {
    final dayEntries = groupedByDate[dateKey]!;
    final parsedDate = parseDateFlexible(dayEntries.first['trndate']?.toString()) ?? DateTime(1970);

    for (final config in summaryConfig) {
      final me = config['me'] as int;
      final cobf = config['cobf'] as String;
      final matches = dayEntries.where((e) {
        return _parseMe(e['me']) == me &&
            (e['cobf']?.toString().trim().toUpperCase() ?? '') == cobf;
      }).toList();

      if (matches.isEmpty) continue;

      double liters = 0.0;
      double amount = 0.0;
      double weightedFat = 0.0;
      double weightedDegree = 0.0;

      for (final e in matches) {
        final l = (e['liters'] as num?)?.toDouble() ?? 0.0;
        final a = (e['amount'] as num?)?.toDouble() ?? 0.0;
        final f = (e['fat'] as num?)?.toDouble() ?? 0.0;
        final d = (e['degree'] as num?)?.toDouble() ?? 0.0;
        liters += l;
        amount += a;
        weightedFat += f * l;
        weightedDegree += d * l;
      }

      processedRows.add({
        'date': parsedDate,
        'dateKey': dateKey,
        'cobfType': cobf,
        'isMorning': me == 1,
        'liters': liters,
        'fat': liters > 0 ? weightedFat / liters : 0.0,
        'degree': liters > 0 ? weightedDegree / liters : 0.0,
        'rate': liters > 0 ? amount / liters : 0.0,
        'amount': amount,
      });
    }
  }

  // Sort deterministically: Date descending, Morning before Evening, Cow before Buffalo
  processedRows.sort((a, b) {
    final DateTime dateA = a['date'] as DateTime;
    final DateTime dateB = b['date'] as DateTime;
    final dateComp = dateB.compareTo(dateA);
    if (dateComp != 0) return dateComp;

    final bool morningA = a['isMorning'] as bool;
    final bool morningB = b['isMorning'] as bool;
    if (morningA != morningB) {
      return morningA ? -1 : 1;
    }

    final String cobfA = a['cobfType'] as String;
    final String cobfB = b['cobfType'] as String;
    return cobfA.compareTo(cobfB);
  });

  return processedRows;
}

int _parseMe(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

String _formatDateShort(DateTime date, int langCode) {
  if (langCode == 2 || langCode == 3 || langCode == 4) {
    return DateFormat('dd.MM.yy').format(date);
  }
  return DateFormat('dd-MM-yy').format(date);
}
