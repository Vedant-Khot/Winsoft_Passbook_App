import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kn'),
    Locale('mr'),
  ];

  /// No description provided for @milkRecords.
  ///
  /// In en, this message translates to:
  /// **'Milk Records'**
  String get milkRecords;

  /// No description provided for @milkRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily milk collection'**
  String get milkRecordsSubtitle;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Milk Bill'**
  String get reports;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed analysis'**
  String get reportsSubtitle;

  /// No description provided for @ledger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledger;

  /// No description provided for @ledgerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account history'**
  String get ledgerSubtitle;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @myProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get myProfileSubtitle;

  /// No description provided for @refreshAllData.
  ///
  /// In en, this message translates to:
  /// **'Refresh All Data'**
  String get refreshAllData;

  /// No description provided for @refreshAllDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download full passbook, bills, deductions, and ledger'**
  String get refreshAllDataSubtitle;

  /// No description provided for @refreshAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'All data reloaded successfully'**
  String get refreshAllSuccess;

  /// No description provided for @refreshAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Reload failed'**
  String get refreshAllFailed;

  /// No description provided for @refreshAllLoading.
  ///
  /// In en, this message translates to:
  /// **'Refreshing all data...'**
  String get refreshAllLoading;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of account'**
  String get logoutSubtitle;

  /// No description provided for @savedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Saved Accounts'**
  String get savedAccounts;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @addAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with another dairy account'**
  String get addAccountSubtitle;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get switchAccount;

  /// No description provided for @activeAccount.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeAccount;

  /// No description provided for @accountAdded.
  ///
  /// In en, this message translates to:
  /// **'Account added successfully'**
  String get accountAdded;

  /// No description provided for @accountSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched account'**
  String get accountSwitched;

  /// No description provided for @accountRemoved.
  ///
  /// In en, this message translates to:
  /// **'Account removed'**
  String get accountRemoved;

  /// No description provided for @removeAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove Account'**
  String get removeAccount;

  /// No description provided for @removeAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this account from this device?'**
  String get removeAccountConfirm;

  /// No description provided for @logoutAllAccounts.
  ///
  /// In en, this message translates to:
  /// **'Logout All Accounts'**
  String get logoutAllAccounts;

  /// No description provided for @logoutAllAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all saved accounts from this device'**
  String get logoutAllAccountsSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @marathi.
  ///
  /// In en, this message translates to:
  /// **'Marathi'**
  String get marathi;

  /// No description provided for @kannada.
  ///
  /// In en, this message translates to:
  /// **'Kannada'**
  String get kannada;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Milk Passbook Login'**
  String get loginTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get welcomeBack;

  /// No description provided for @dairyCode.
  ///
  /// In en, this message translates to:
  /// **'Dairy Code'**
  String get dairyCode;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @passbookTitle.
  ///
  /// In en, this message translates to:
  /// **'Passbook'**
  String get passbookTitle;

  /// No description provided for @searchRecords.
  ///
  /// In en, this message translates to:
  /// **'Search Records'**
  String get searchRecords;

  /// No description provided for @noEntriesFound.
  ///
  /// In en, this message translates to:
  /// **'No entries found.'**
  String get noEntriesFound;

  /// No description provided for @passbook_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get passbook_date;

  /// No description provided for @passbook_session.
  ///
  /// In en, this message translates to:
  /// **'M/E'**
  String get passbook_session;

  /// No description provided for @passbook_liters.
  ///
  /// In en, this message translates to:
  /// **'Liters'**
  String get passbook_liters;

  /// No description provided for @passbook_fat.
  ///
  /// In en, this message translates to:
  /// **'FAT'**
  String get passbook_fat;

  /// No description provided for @passbook_rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get passbook_rate;

  /// No description provided for @passbook_amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get passbook_amount;

  /// No description provided for @passbook_snf.
  ///
  /// In en, this message translates to:
  /// **'SNF'**
  String get passbook_snf;

  /// No description provided for @animal_cow.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get animal_cow;

  /// No description provided for @animal_buffalo.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get animal_buffalo;

  /// No description provided for @ledger_openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening Balance'**
  String get ledger_openingBalance;

  /// No description provided for @report_morningCollection.
  ///
  /// In en, this message translates to:
  /// **'Morning '**
  String get report_morningCollection;

  /// No description provided for @report_eveningCollection.
  ///
  /// In en, this message translates to:
  /// **'Evening '**
  String get report_eveningCollection;

  /// No description provided for @report_deductions.
  ///
  /// In en, this message translates to:
  /// **'Deductions'**
  String get report_deductions;

  /// No description provided for @report_summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get report_summary;

  /// No description provided for @report_selectPeriod.
  ///
  /// In en, this message translates to:
  /// **'Select Bill Period'**
  String get report_selectPeriod;

  /// No description provided for @summary_totalMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk:'**
  String get summary_totalMilk;

  /// No description provided for @summary_totalMilkAmount.
  ///
  /// In en, this message translates to:
  /// **'Amt:'**
  String get summary_totalMilkAmount;

  /// No description provided for @summary_totalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings:'**
  String get summary_totalEarnings;

  /// No description provided for @summary_netAmount.
  ///
  /// In en, this message translates to:
  /// **'Net Amount:'**
  String get summary_netAmount;

  /// No description provided for @summary_fromPassbook.
  ///
  /// In en, this message translates to:
  /// **'Passbook'**
  String get summary_fromPassbook;

  /// No description provided for @summary_fromBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get summary_fromBill;

  /// No description provided for @report_deductionName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get report_deductionName;

  /// No description provided for @report_earning.
  ///
  /// In en, this message translates to:
  /// **'Earning '**
  String get report_earning;

  /// No description provided for @report_deduction.
  ///
  /// In en, this message translates to:
  /// **'Deduction '**
  String get report_deduction;

  /// No description provided for @report_billMismatch.
  ///
  /// In en, this message translates to:
  /// **'There is a mismatch in the bill. Passbook totals do not match the bill summary.'**
  String get report_billMismatch;

  /// No description provided for @ledger_title.
  ///
  /// In en, this message translates to:
  /// **'Financial Ledger'**
  String get ledger_title;

  /// No description provided for @ledger_selectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select Account'**
  String get ledger_selectAccount;

  /// No description provided for @ledger_loadingAccounts.
  ///
  /// In en, this message translates to:
  /// **'Loading accounts...'**
  String get ledger_loadingAccounts;

  /// No description provided for @ledger_noAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts found.'**
  String get ledger_noAccounts;

  /// No description provided for @ledger_transactionsFor.
  ///
  /// In en, this message translates to:
  /// **'Transactions for'**
  String get ledger_transactionsFor;

  /// No description provided for @ledger_noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions found for this account.'**
  String get ledger_noTransactions;

  /// No description provided for @ledger_col_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get ledger_col_date;

  /// No description provided for @ledger_col_particulars.
  ///
  /// In en, this message translates to:
  /// **'Particulars'**
  String get ledger_col_particulars;

  /// No description provided for @ledger_col_debit.
  ///
  /// In en, this message translates to:
  /// **'Dr'**
  String get ledger_col_debit;

  /// No description provided for @passbook_amount_me.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get passbook_amount_me;

  /// No description provided for @ledger_col_debit_sum.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get ledger_col_debit_sum;

  /// No description provided for @ledger_col_credit_sum.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get ledger_col_credit_sum;

  /// No description provided for @ledger_col_credit.
  ///
  /// In en, this message translates to:
  /// **'Cr'**
  String get ledger_col_credit;

  /// No description provided for @ledger_col_balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get ledger_col_balance;

  /// No description provided for @profile_title.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profile_title;

  /// No description provided for @profile_memberId.
  ///
  /// In en, this message translates to:
  /// **'Member ID'**
  String get profile_memberId;

  /// No description provided for @profile_personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get profile_personalInfo;

  /// No description provided for @profile_memberCode.
  ///
  /// In en, this message translates to:
  /// **'Member Code'**
  String get profile_memberCode;

  /// No description provided for @profile_mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get profile_mobileNumber;

  /// No description provided for @profile_societyInfo.
  ///
  /// In en, this message translates to:
  /// **'Society Information'**
  String get profile_societyInfo;

  /// No description provided for @profile_societyName.
  ///
  /// In en, this message translates to:
  /// **'Society Name'**
  String get profile_societyName;

  /// No description provided for @profile_societyCode.
  ///
  /// In en, this message translates to:
  /// **'Society Code'**
  String get profile_societyCode;

  /// No description provided for @profile_accountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get profile_accountDetails;

  /// No description provided for @profile_tokenExpires.
  ///
  /// In en, this message translates to:
  /// **'Token Expires On'**
  String get profile_tokenExpires;

  /// No description provided for @profile_billType.
  ///
  /// In en, this message translates to:
  /// **'Bill Type'**
  String get profile_billType;

  /// No description provided for @profile_notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not Provided'**
  String get profile_notProvided;

  /// No description provided for @passbook_cobf.
  ///
  /// In en, this message translates to:
  /// **'C/B'**
  String get passbook_cobf;

  /// No description provided for @cow.
  ///
  /// In en, this message translates to:
  /// **'Cow'**
  String get cow;

  /// No description provided for @buffalo.
  ///
  /// In en, this message translates to:
  /// **'Buffalo'**
  String get buffalo;

  /// No description provided for @milk_sale.
  ///
  /// In en, this message translates to:
  /// **'Milk Sale'**
  String get milk_sale;

  /// No description provided for @milk_sale_details.
  ///
  /// In en, this message translates to:
  /// **'Milk Sale Reports'**
  String get milk_sale_details;

  /// No description provided for @milk_sale_total_milk_amount.
  ///
  /// In en, this message translates to:
  /// **'Total Milk Amount'**
  String get milk_sale_total_milk_amount;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @milk_slips.
  ///
  /// In en, this message translates to:
  /// **'Milk Slips'**
  String get milk_slips;

  /// No description provided for @milkSlipsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View milk slips by session'**
  String get milkSlipsSubtitle;

  /// No description provided for @milk_passbook.
  ///
  /// In en, this message translates to:
  /// **'Milk Passbook'**
  String get milk_passbook;

  /// No description provided for @milkPassbookSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your detailed milk passbook'**
  String get milkPassbookSubtitle;

  /// No description provided for @passbook_type.
  ///
  /// In en, this message translates to:
  /// **'C/B'**
  String get passbook_type;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Summary & Statistics'**
  String get dashboardSubtitle;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @switchToLight.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch to Light'**
  String get switchToLight;

  /// No description provided for @switchToDark.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch to Dark'**
  String get switchToDark;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @yearlyMilk.
  ///
  /// In en, this message translates to:
  /// **'Yearly Milk'**
  String get yearlyMilk;

  /// No description provided for @yearlyAmount.
  ///
  /// In en, this message translates to:
  /// **'Yearly Amount'**
  String get yearlyAmount;

  /// No description provided for @dashboardTotalMilk.
  ///
  /// In en, this message translates to:
  /// **'Total Milk'**
  String get dashboardTotalMilk;

  /// No description provided for @dashboardTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get dashboardTotalAmount;

  /// No description provided for @dashboardAverageFat.
  ///
  /// In en, this message translates to:
  /// **'Average FAT'**
  String get dashboardAverageFat;

  /// No description provided for @dashboardAvgRate.
  ///
  /// In en, this message translates to:
  /// **'Avg Rate'**
  String get dashboardAvgRate;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kn', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kn':
      return AppLocalizationsKn();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
