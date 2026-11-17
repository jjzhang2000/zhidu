import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh')
  ];

  /// App title
  ///
  /// In en, this message translates to:
  /// **'ZhiDu'**
  String get appTitle;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// AI config section title
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiConfigTitle;

  /// AI config page title
  ///
  /// In en, this message translates to:
  /// **'AI Configuration'**
  String get aiConfigScreenTitle;

  /// App subtitle
  ///
  /// In en, this message translates to:
  /// **'Read Thin First, Then Thick'**
  String get readThinThick;

  /// Theme settings section title
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSettingTitle;

  /// Language settings section title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingTitle;

  /// About title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// Theme mode - system
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeSystem;

  /// Theme mode - light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// Theme mode - dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// Language mode - follow system
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get languageModeFollowSystem;

  /// Language mode - manual select
  ///
  /// In en, this message translates to:
  /// **'Manual Select'**
  String get languageModeManualSelect;

  /// Language mode - follow system description
  ///
  /// In en, this message translates to:
  /// **'Follow system language for AI summaries, translations and interface'**
  String get languageModeSystemSubtitle;

  /// Language mode - manual select description
  ///
  /// In en, this message translates to:
  /// **'Manually specify a unified AI and interface language'**
  String get languageModeManualSubtitle;

  /// Unified language picker title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// App name description
  ///
  /// In en, this message translates to:
  /// **'AI Layered Reader'**
  String get aiLayeredReader;

  /// Search hint
  ///
  /// In en, this message translates to:
  /// **'Search title/author'**
  String get search;

  /// Empty bookshelf hint
  ///
  /// In en, this message translates to:
  /// **'Bookshelf is empty'**
  String get bookshelfEmpty;

  /// No search results hint
  ///
  /// In en, this message translates to:
  /// **'No related books found'**
  String get noRelatedBooks;

  /// No search results suggestion
  ///
  /// In en, this message translates to:
  /// **'Please try other keywords'**
  String get tryOtherKeywords;

  /// Add book guidance
  ///
  /// In en, this message translates to:
  /// **'Click button at bottom right to add books'**
  String get clickToAddBooks;

  /// Removal confirm dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm removal'**
  String get confirmRemoval;

  /// Removal confirm dialog message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove《{bookTitle}》?'**
  String removeConfirmation(String bookTitle);

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Remove button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// AI provider - Zhipu
  ///
  /// In en, this message translates to:
  /// **'Zhipu'**
  String get zhipuProvider;

  /// AI provider - Qwen
  ///
  /// In en, this message translates to:
  /// **'Qwen'**
  String get qwenProvider;

  /// AI provider - DeepSeek
  ///
  /// In en, this message translates to:
  /// **'DeepSeek'**
  String get deepseekProvider;

  /// AI provider - MiniMax
  ///
  /// In en, this message translates to:
  /// **'MiniMax'**
  String get minimaxProvider;

  /// AI provider - Ollama local
  ///
  /// In en, this message translates to:
  /// **'Ollama (Local)'**
  String get ollamaProvider;

  /// AI provider - LM Studio local
  ///
  /// In en, this message translates to:
  /// **'LM Studio (Local)'**
  String get lmstudioProvider;

  /// Language option - Chinese
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get chineseLanguage;

  /// Language option - English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// Language option - Japanese
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japaneseLanguage;

  /// AI not configured hint
  ///
  /// In en, this message translates to:
  /// **'Not configured (click to set)'**
  String get notConfiguredClickToSet;

  /// Book added success message
  ///
  /// In en, this message translates to:
  /// **'Added: {bookTitle}'**
  String addedSuccessfully(String bookTitle);

  /// Book removed success message
  ///
  /// In en, this message translates to:
  /// **'Removed《{bookTitle}》'**
  String removedSuccessfully(String bookTitle);

  /// Theme mode - system description
  ///
  /// In en, this message translates to:
  /// **'Automatically follow system theme settings'**
  String get themeModeSystemSubtitle;

  /// Theme mode - light description
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get themeModeLightSubtitle;

  /// Theme mode - dark description
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get themeModeDarkSubtitle;

  /// Connection testing status
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testing;

  /// Saving status
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// Operation failed message
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// Version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// AI service settings section title
  ///
  /// In en, this message translates to:
  /// **'AI Service Settings'**
  String get aiServiceSettings;

  /// Import book button
  ///
  /// In en, this message translates to:
  /// **'Import Book'**
  String get importBook;

  /// AI provider label
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get aiProvider;

  /// API key label
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// Model label
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// Base URL label
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// Prompt - chapters label
  ///
  /// In en, this message translates to:
  /// **'Chapters: '**
  String get promptBookChaptersLabel;

  /// Prompt - book summary template
  ///
  /// In en, this message translates to:
  /// **'{title}|{author}|{chapterSummaries}|{chaptersLine}'**
  String promptBookSummary(String title, String author, String chapterSummaries, String chaptersLine);

  /// Prompt - chapter summary template
  ///
  /// In en, this message translates to:
  /// **'{chapterTitle}|{content}'**
  String promptChapterSummary(String chapterTitle, String content);

  /// Prompt - HTML translation template
  ///
  /// In en, this message translates to:
  /// **'{content}|{chapterTitle}'**
  String promptTranslateHtml(String content, String chapterTitle);

  /// Library settings section title
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get librarySettingsTitle;

  /// Calibre library location label
  ///
  /// In en, this message translates to:
  /// **'Calibre library location:'**
  String get calibreLibraryLocation;

  /// Library path not set placeholder
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get noLibraries;

  /// Browse folder button
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// Refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Clear bookshelf button and dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear Bookshelf'**
  String get clearBookshelf;

  /// Clear bookshelf confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all books? This cannot be undone.'**
  String get clearBookshelfConfirmation;

  /// Bookshelf cleared hint
  ///
  /// In en, this message translates to:
  /// **'Bookshelf cleared'**
  String get clearBookshelfDone;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
