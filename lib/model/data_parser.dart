import 'package:intl/intl.dart';

/// A flexible date parser that tries multiple formats to prevent crashes.
///
/// It attempts to parse a date string in the following order:
/// 1. Standard ISO 8601 format (e.g., "2025-09-05T20:00:18.322Z" or "2025-04-11").
/// 2. Custom 'dd/MM/yyyy' format (e.g., "26/05/2025").
///
/// If all formats fail, it prints a warning and returns null.
///
/// [dateString] The string to be parsed into a DateTime.
/// Returns a [DateTime] object if successful, otherwise returns `null`.
DateTime? parseDateFlexible(String? dateString) {
  // 1. Immediately return null if the input string is null or empty.
  if (dateString == null || dateString.isEmpty) {
    return null;
  }

  // 2. First, try the standard, built-in parser. It's very fast and
  // handles all ISO 8601 formats (like the one in your MemInfoModel sample).
  final isoDate = DateTime.tryParse(dateString);
  if (isoDate != null) {
    return isoDate;
  }

  // 3. If the standard parser fails, try a list of custom formats.
  //    Add any other formats your API might send to this list.
  final customFormats = [
    DateFormat('dd/MM/yyyy'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('MM-dd-yyyy'), // For strings like '26/05/2025'
    // You could add more here, like DateFormat('MM-dd-yyyy') if needed.
  ];

  for (var format in customFormats) {
    try {
      // If parsing succeeds with one of the custom formats, return the date.
      return format.parse(dateString);
    } on FormatException {
      // If it fails, this is expected. We just 'continue' to the next format.
      continue;
    }
  }

  // 4. All formats failed.
  return null;
}

String formatLanguageAwareDate(DateTime date, int langCode) {
  // Use a period as a separator for custom font languages
  // to avoid the jarring English hyphen.
  if (langCode == 2 || langCode == 3 || langCode == 4) {
    // Marathi or Kannada
    return DateFormat('dd.MM.yyyy').format(date);
  }

  // Default to using a hyphen for English.
  return DateFormat('dd-MM-yyyy').format(date);
}

/// A shorter version for the custom table.
String formatLanguageAwareDateShort(DateTime date, int langCode) {
  if (langCode == 2 || langCode == 3 || langCode == 4) {
    return DateFormat('dd.MM.yy').format(date);
  }
  return DateFormat('dd-MM-yy').format(date);
}

/// A version of date formatter that does not include the year (e.g. "26-05" or "26.05").
String formatLanguageAwareDateNoYear(DateTime date, int langCode) {
  if (langCode == 2 || langCode == 3 || langCode == 4) {
    return DateFormat('dd.MM').format(date);
  }
  return DateFormat('dd-MM').format(date);
}

