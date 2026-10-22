import 'package:flutter/material.dart';

// import 'package.flutter/material.dart';

class DynamicText extends StatelessWidget {
  final String text;
  final int langCode;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  // Static regex — instantiated once for the entire app lifetime (not per rebuild)
  static final _numericRegex = RegExp(r'^[0-9.]+$');

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
    String? fontFamily;
    double fontSizeMultiplier = 1.0;
    TextStyle customFontStyle = const TextStyle();

    // Fast path: English text with no Shivaji characters needs no custom font
    if (langCode == 1 && !_shivajiPatternRegex.hasMatch(text)) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    switch (langCode) {
      case 2: // Marathi
      case 4: // Marathi + English Numbers
        // can we check if it is number or text? If number, use Shree font else shivaji
        final input = text.trim();

        // Regex: only digits and dots allowed
        final isNumericOrDate = _numericRegex.hasMatch(input);

        if (forceKiran || isNumericOrDate) {
          fontFamily = 'Kiran';
          fontSizeMultiplier = 1.45;
          customFontStyle = const TextStyle(fontWeight: FontWeight.bold);
        } else {
          fontFamily = 'Shivaji';
          fontSizeMultiplier = 1.3;
          customFontStyle = const TextStyle(fontWeight: FontWeight.bold);
        }

        // fontFamily = 'Shree';
        // Increase the size a bit more and make it bold by default.
        // fontSizeMultiplier = 1.45;
        // customFontStyle = const TextStyle(fontWeight: FontWeight.bold);
        break;
      case 3: // Kannada
        fontFamily = 'Baraha';
        fontSizeMultiplier = 1.15;
        // You could make Baraha bold too if needed:
        // customFontStyle = const TextStyle(fontWeight: FontWeight.bold);
        break;
      default: // langCode 1 (English)
        fontFamily = null;
        break;
    }

    // --- END OF NEW LOGIC ---

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final finalFontSize = (baseStyle.fontSize ?? 14.0) * fontSizeMultiplier;

    // Create the final text style.
    // 1. Start with the base style.
    // 2. Merge our custom font style (which adds boldness for Shivaji).
    // 3. Apply the final font family and adjusted font size.
    final finalStyle = baseStyle
        .merge(customFontStyle)
        .copyWith(fontFamily: fontFamily, fontSize: finalFontSize);

    return Text(
      text,
      style: finalStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
