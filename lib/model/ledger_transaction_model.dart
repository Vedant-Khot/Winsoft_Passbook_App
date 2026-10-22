// import 'date_parser.dart';

import 'package:passbook/model/data_parser.dart';

class LedgerTransactionModel {
  final int accno;
  final DateTime? trDates;
  final String? part;
  final String? crdb;
  final double amt;
  final int opInd;
  final DateTime? lastUpdated;

  LedgerTransactionModel({
    required this.accno,
    this.trDates,
    this.part,
    this.crdb,
    required this.amt,
    required this.opInd,
    this.lastUpdated,
  });

  factory LedgerTransactionModel.fromJson(Map<String, dynamic> json) {
    return LedgerTransactionModel(
      accno: json['accno'] is int
          ? json['accno'] as int
          : int.tryParse(json['accno']?.toString() ?? '') ?? 0,
      trDates: parseDateFlexible(json['trdates']),
      part: json['part'],
      crdb: json['crdb'],
      amt: (json['amt'] as num?)?.toDouble() ?? 0.0,
      opInd: json['opInd'] ?? 0,
    );
  }

  LedgerTransactionModel copyWith({DateTime? lastUpdated}) {
    return LedgerTransactionModel(
      accno: accno,
      trDates: trDates,
      part: part,
      crdb: crdb,
      amt: amt,
      opInd: opInd,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
// At the top of lib/screens/ledger_screen.dart

/// A helper class to hold the calculated totals for the ledger.
class LedgerSummary {
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;

  LedgerSummary({
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
  });
}
