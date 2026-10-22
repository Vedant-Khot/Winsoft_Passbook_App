class DeductionModel {
  final DateTime? dedctnDate;
  final int? dedentrytrno;
  final int? dedctnTrno;
  final String? dedName;
  final int? dedcode;
  final int? membCode;
  final double? dedctnAmt1;
  final double? actdedAmt;
  final String? cobf;
  final int? trntype;
  final int? mbillno;
  final int? billno;
  final int? socCode;
  final int? dedearn;

  DeductionModel({
    this.dedctnDate,
    this.dedentrytrno,
    this.dedctnTrno,
    this.dedName,
    this.dedcode,
    this.membCode,
    this.dedctnAmt1,
    this.actdedAmt,
    this.cobf,
    this.trntype,
    this.mbillno,
    this.billno,
    this.socCode,
    this.dedearn,
  });
  // In DeductionModel
  DeductionModel.empty()
    : this(dedctnDate: DateTime(0), dedName: '', dedctnAmt1: 0, billno: 0);
  factory DeductionModel.fromJson(Map<String, dynamic> json) {
    return DeductionModel(
      // Corrected to camelCase keys
      dedctnDate: json['dedctnDate'] != null
          ? DateTime.tryParse(json['dedctnDate'])
          : null,
      dedentrytrno: json['dedentrytrno'],
      dedctnTrno: json['dedctnTrno'],
      dedName: json['dedName'],
      dedcode: json['dedcode'],
      membCode: json['membCode'],
      dedctnAmt1: (json['dedctnAmt1'] as num?)?.toDouble(),
      actdedAmt: (json['actdedAmt'] as num?)?.toDouble(),
      cobf: json['cobf'],
      trntype: json['trntype'],
      mbillno: json['mbillno'],
      billno: json['billno'],
      socCode: json['socCode'],
      dedearn: json['dedearn'],
    );
  }
}
