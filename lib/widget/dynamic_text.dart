import 'package:flutter/material.dart';

// import 'package.flutter/material.dart';

class DynamicText extends StatelessWidget {
  final String text;
  final int langCode;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  // Fast check: digits, dot, hyphen, slash, colon, space
  static bool _isDigitsAndDots(String s) {
    if (s.isEmpty) return false;
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if ((code < 48 || code > 57) && code != 46 && code != 45 && code != 47 && code != 58 && code != 32) {
        return false;
      }
    }
    return true;
  }

  // Detects characters commonly produced by Marathi Shivaji font typing
  static final _shivajiPatternRegex = RegExp(r'[%^~³´µ¤§¢±²¸¹º»¼½¾¿\u00C0-\u00FF]');

  final bool forceKiran;

  const DynamicText({
    super.key,
    required this.text,
    required this.langCode,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.forceKiran = false,
  });

  @override
  Widget build(BuildContext context) {
    // Fast path: English text with no Shivaji characters needs no custom font
    if (langCode == 1 && (text.isEmpty || !_shivajiPatternRegex.hasMatch(text))) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    String? fontFamily;
    double fontSizeMultiplier = 1.0;
    FontWeight? fontWeight;

    switch (langCode) {
      case 2: // Marathi
      case 4: // Marathi + English Numbers
        final isNumericOrDate = forceKiran || _isDigitsAndDots(text.trim());
        if (isNumericOrDate) {
          fontFamily = 'Kiran';
          fontSizeMultiplier = 1.45;
          fontWeight = FontWeight.bold;
        } else {
          fontFamily = 'Shivaji';
          fontSizeMultiplier = 1.3;
          fontWeight = FontWeight.bold;
        }
        break;
      case 3: // Kannada
        fontFamily = 'Baraha';
        fontSizeMultiplier = 1.15;
        break;
      default: // langCode 1 (English)
        fontFamily = null;
        break;
    }

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final finalFontSize = (baseStyle.fontSize ?? 14.0) * fontSizeMultiplier;

    final finalStyle = baseStyle.copyWith(
      fontFamily: fontFamily,
      fontSize: finalFontSize,
      fontWeight: fontWeight ?? baseStyle.fontWeight,
    );

    return Text(
      text,
      style: finalStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
