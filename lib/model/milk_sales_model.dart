import 'package:passbook/model/data_parser.dart';

// import 'date_parser.dart';

class MilkSaleModel {
  final DateTime trDate;
  final int me;
  final String? cobf;
  final double liters;
  final double fat;
  final double rate;
  final double tot;
  final double paid;
  final DateTime? lastUpdated;

  MilkSaleModel({
    required this.trDate,
    required this.me,
    this.cobf,
    required this.liters,
    required this.fat,
    required this.rate,
    required this.tot,
    required this.paid,
    this.lastUpdated,
  });

  factory MilkSaleModel.fromJson(Map<String, dynamic> json) {
    return MilkSaleModel(
      trDate: parseDateFlexible(json['trdate']) ?? DateTime(1970),
      me: json['me'] ?? 0,
      cobf: json['cobf'],
      liters: (json['liters'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      tot: (json['tot'] as num?)?.toDouble() ?? 0.0,
      paid: (json['paid'] as num?)?.toDouble() ?? 0.0,
    );
  }

  MilkSaleModel copyWith({DateTime? lastUpdated}) {
    return MilkSaleModel(
      trDate: trDate,
      me: me,
      cobf: cobf,
      liters: liters,
      fat: fat,
      rate: rate,
      tot: tot,
      paid: paid,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
