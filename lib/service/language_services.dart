import 'package:flutter/material.dart';

class LanguageService extends ChangeNotifier {
  // Default to English if no user is logged in
  Locale _appLocale = const Locale('en');

  Locale get appLocale => _appLocale;

  /// Changes the app's locale based on a new Locale object.
  void changeLocale(Locale newLocale) {
    if (_appLocale == newLocale) return; // No change needed

    _appLocale = newLocale;
    notifyListeners();
  }

  /// A convenient helper to change the locale directly from an API langCode.
  void changeLocaleFromLangCode(int langCode) {
    Locale newLocale;
    switch (langCode) {
      case 2: // Marathi
      case 4: // Marathi + Eng Numbers
        newLocale = const Locale('mr');
        break;
      case 3: // Kannada
        newLocale = const Locale('kn');
        break;
      default: // langCode 1 or any other case is English
        newLocale = const Locale('en');
        break;
    }
    changeLocale(newLocale);
  }
}
