class GlmsAccountModel {
  final int accno;
  final String accName;

  const GlmsAccountModel({
    required this.accno,
    required this.accName,
  });

  factory GlmsAccountModel.fromJson(Map<String, dynamic> json) {
    return GlmsAccountModel(
      accno: json['accno'] is int
          ? json['accno'] as int
          : int.tryParse(json['accno']?.toString() ?? '') ?? 0,
      accName: json['accName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'accno': accno,
        'accName': accName,
      };
}
