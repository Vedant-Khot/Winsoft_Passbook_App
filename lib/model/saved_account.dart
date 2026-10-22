import 'package:passbook/model/mem_info_model.dart';

class SavedAccount {
  final String id;
  final int socCode;
  final int membCode;
  final String? memName;
  final String? socName;
  final String? mobNo;
  final int langCode;

  const SavedAccount({
    required this.id,
    required this.socCode,
    required this.membCode,
    this.memName,
    this.socName,
    this.mobNo,
    required this.langCode,
  });

  factory SavedAccount.fromUser(MemInfoModel user) {
    return SavedAccount(
      id: SavedAccount.idFor(user),
      socCode: user.socCode,
      membCode: user.membCode,
      memName: user.memName,
      socName: user.socName,
      mobNo: user.mobNo,
      langCode: user.langCode,
    );
  }

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      id: json['id'] as String,
      socCode: json['socCode'] as int? ?? 0,
      membCode: json['membCode'] as int? ?? 0,
      memName: json['memName'] as String?,
      socName: json['socName'] as String?,
      mobNo: json['mobNo'] as String?,
      langCode: json['langCode'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'socCode': socCode,
      'membCode': membCode,
      'memName': memName,
      'socName': socName,
      'mobNo': mobNo,
      'langCode': langCode,
    };
  }

  static String idFor(MemInfoModel user) => '${user.socCode}_${user.membCode}';
}
