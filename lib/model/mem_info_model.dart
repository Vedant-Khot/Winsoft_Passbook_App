import 'dart:convert';

import 'package:passbook/model/data_parser.dart';
// import 'date_parser.dart';

class MemInfoModel {
  final int socCode;
  final int membCode;
  final int accno;
  final String? memName;
  final int langCode;
  final int cobfType;
  final String? socName;
  final int billtype;
  final String? authtoken;
  final DateTime expireDate;
  final String? mobNo;
  final int? rptType;
  final int? dairyType;
  final String appString;

  MemInfoModel({
    required this.socCode,
    required this.membCode,
    required this.accno,
    this.memName,
    required this.langCode,
    required this.cobfType,
    this.socName,
    required this.billtype,
    this.authtoken,
    required this.expireDate,
    this.mobNo,
    this.rptType,
    this.dairyType,
    required this.appString,
  });

  factory MemInfoModel.fromJson(Map<String, dynamic> json) {
    return MemInfoModel(
      socCode: json['socCode'] ?? 0,
      membCode: json['membCode'] ?? 0,
      accno: json['accno'] ?? json['accNo'] ?? json['membCode'] ?? 0,
      memName: json['memName'],
      langCode: json['langCode'] ?? 0,
      cobfType: json['cobfType'] ?? 0,
      socName: json['socName'],
      billtype: json['billtype'] ?? 0,
      authtoken: json['authtoken'],
      expireDate: parseDateFlexible(json['expireDate']) ?? DateTime.now(),
      mobNo: json['mobNo'],
      rptType: json['rptType'] ?? json['rptype'],
      dairyType: json['dairyType'],
      appString: json['appString'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'socCode': socCode,
      'membCode': membCode,
      'accno': accno,
      'memName': memName,
      'langCode': langCode,
      'cobfType': cobfType,
      'socName': socName,
      'billtype': billtype,
      'authtoken': authtoken,
      'expireDate': expireDate.toIso8601String(),
      'mobNo': mobNo,
      'rptType': rptType,
      'dairyType': dairyType,
      'appString': appString,
    };
  }

  factory MemInfoModel.fromJsonString(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return MemInfoModel.fromJson(data);
  }

  MemInfoModel copyWith({
    int? socCode,
    int? membCode,
    int? accno,
    String? memName,
    int? langCode,
    int? cobfType,
    String? socName,
    int? billtype,
    String? authtoken,
    DateTime? expireDate,
    String? mobNo,
    int? rptType,
    int? dairyType,
    String? appString,
  }) {
    return MemInfoModel(
      socCode: socCode ?? this.socCode,
      membCode: membCode ?? this.membCode,
      accno: accno ?? this.accno,
      memName: memName ?? this.memName,
      langCode: langCode ?? this.langCode,
      cobfType: cobfType ?? this.cobfType,
      socName: socName ?? this.socName,
      billtype: billtype ?? this.billtype,
      authtoken: authtoken ?? this.authtoken,
      expireDate: expireDate ?? this.expireDate,
      mobNo: mobNo ?? this.mobNo,
      rptType: rptType ?? this.rptType,
      dairyType: dairyType ?? this.dairyType,
      appString: appString ?? this.appString,
    );
  }
}

class LoginResponse {
  final bool success;
  final String message;
  final MemInfoModel? data;
  final bool isNetworkError;

  LoginResponse({
    required this.success,
    required this.message,
    this.data,
    this.isNetworkError = false,
  });
}
