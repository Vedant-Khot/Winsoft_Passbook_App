// lib/models/passbook_model.dart
// import 'date_parser.dart';

import 'package:passbook/model/data_parser.dart';

class PassbookModel {
  final String? cobf;
  final double fat;
  final double rate;
  final double liters;
  final double amount;
  final int me;
  final double degree;
  final DateTime trndate;
  final DateTime? lastUpdated;

  PassbookModel({
    this.cobf,
    required this.fat,
    required this.rate,
    required this.liters,
    required this.amount,
    required this.me,
    required this.degree,
    required this.trndate,
    this.lastUpdated,
  });

  factory PassbookModel.fromJson(Map<String, dynamic> json) {
    return PassbookModel(
      trndate: parseDateFlexible(json['trndate']) ?? DateTime(1970),
      cobf: json['cobf'],
      me: json['me'] ?? 0,
      liters: (json['liters'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      degree: (json['degree'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
  // In PassbookModel
  PassbookModel.empty()
    : this(
        trndate: DateTime(0),
        me: 0,
        liters: 0,
        fat: 0,
        rate: 0,
        amount: 0,
        degree: 0,
        cobf: '',
      );
  PassbookModel copyWith({DateTime? lastUpdated}) {
    return PassbookModel(
      cobf: cobf,
      fat: fat,
      rate: rate,
      liters: liters,
      amount: amount,
      me: me,
      degree: degree,
      trndate: trndate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trndate': trndate.toIso8601String(),
      'cobf': cobf,
      'me': me,
      'liters': liters,
      'fat': fat,
      'degree': degree,
      'rate': rate,
      'amount': amount,
    };
  }
}
