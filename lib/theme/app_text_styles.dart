import 'package:flutter/material.dart';

/// Bundled Poppins styles — no runtime network fetch.
abstract final class AppTextStyles {
  static const String fontFamily = 'Poppins';

  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextTheme poppinsTextTheme(TextTheme base) {
    return base.apply(fontFamily: fontFamily);
  }
}
