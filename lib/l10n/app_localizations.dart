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
/// To configure the locales supported by your app, you'll need to edit this
/// file.
///
/// First, open your project's ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project's Runner folder.
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
  /// Creates an AppLocalizations instance for the given [locale].
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  /// Canonicalized locale name used by intl message lookup.
  final String localeName;

  /// Retrieves the AppLocalizations instance from the given [context].
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// Localizations delegate for loading AppLocalizations.
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
  String get appTitle;

  /// Settings page title
  String get settingsTitle;

  /// AI config section title
  String get aiConfigTitle;

  /// AI config page title
  String get aiConfigScreenTitle;

  /// App subtitle
  String get readThinThick;

  /// Appearance settings title
  String get appearanceSettingTitle;

  /// Theme settings section title
  String get themeSettingTitle;

  /// Theme settings page title
  String get themeSettingsScreenTitle;

  /// Language settings section title
  String get languageSettingTitle;

  /// Language settings page title
  String get languageSettingsScreenTitle;

  /// About title
  String get aboutTitle;

  /// Theme mode - system
  String get themeModeSystem;

  /// Theme mode - light
  String get themeModeLight;

  /// Theme mode - dark
  String get themeModeDark;

  /// AI language mode - follow book
  String get aiLanguageFollowBook;

  /// AI language mode - follow system
  String get aiLanguageFollowSystem;

  /// AI language mode - manual select
  String get aiLanguageManualSelect;

  /// UI language mode - follow system
  String get uiLanguageFollowSystem;

  /// UI language mode - manual select
  String get uiLanguageManualSelect;

  /// AI output language picker title
  String get selectAiOutputLanguage;

  /// UI language picker title
  String get selectUiLanguage;

  /// AI output language label
  String get aiOutputLanguage;

  /// UI display language label
  String get uiDisplayLanguage;

  /// AI language setting section title
  String get aiLanguageSetting;

  /// UI language setting section title
  String get uiLanguageSetting;

  /// AI language setting description
  String get aiLanguageControl;

  /// UI language setting description
  String get uiLanguageControl;

  /// App name description
  String get aiLayeredReader;

  /// Search hint
  String get search;

  /// Empty bookshelf hint
  String get bookshelfEmpty;

  /// No search results hint
  String get noRelatedBooks;

  /// No search results suggestion
  String get tryOtherKeywords;

  /// Add book guidance
  String get clickToAddBooks;

  /// Removal confirm dialog title
  String get confirmRemoval;

  /// Removal confirm dialog message
  String removeConfirmation(String bookTitle);

  /// Cancel button
  String get cancel;

  /// Remove button
  String get remove;

  /// AI provider - Zhipu
  String get zhipuProvider;

  /// AI provider - Qwen
  String get qwenProvider;

  /// AI provider - DeepSeek
  String get deepseekProvider;

  /// AI provider - MiniMax
  String get minimaxProvider;

  /// AI provider - Ollama local
  String get ollamaProvider;

  /// AI provider - LM Studio local
  String get lmstudioProvider;

  /// Language option - Chinese
  String get chineseLanguage;

  /// Language option - English
  String get englishLanguage;

  /// Language option - Japanese
  String get japaneseLanguage;

  /// AI not configured hint
  String get notConfiguredClickToSet;

  /// Book added success message
  String addedSuccessfully(String bookTitle);

  /// Book removed success message
  String removedSuccessfully(String bookTitle);

  /// Theme mode - system description
  String get themeModeSystemSubtitle;

  /// Theme mode - light description
  String get themeModeLightSubtitle;

  /// Theme mode - dark description
  String get themeModeDarkSubtitle;

  /// AI language mode - follow book description
  String get aiLanguageModeBookSubtitle;

  /// AI language mode - follow system description
  String get aiLanguageModeSystemSubtitle;

  /// AI language mode - manual select description
  String get aiLanguageModeManualSubtitle;

  /// UI language mode - follow system description
  String get uiLanguageModeSystemSubtitle;

  /// UI language mode - manual select description
  String get uiLanguageModeManualSubtitle;

  /// Connection testing status
  String get testing;

  /// Saving status
  String get saving;

  /// Operation failed message
  String get failed;

  /// Version label
  String get version;

  /// AI service settings section title
  String get aiServiceSettings;

  /// Import book button
  String get importBook;

  /// AI provider label
  String get aiProvider;

  /// API key label
  String get apiKey;

  /// Model label
  String get model;

  /// Base URL label
  String get baseUrl;

  /// Prompt - chapters label
  String get promptBookChaptersLabel;

  /// Prompt - book summary template
  String promptBookSummary(String title, String author, String chapterSummaries, String chaptersLine);

  /// Prompt - chapter summary template
  String promptChapterSummary(String chapterTitle, String content);

  /// Prompt - HTML translation template
  String promptTranslateHtml(String content, String chapterTitle);
}

/// Delegate for loading AppLocalizations based on locale.
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

/// Returns the AppLocalizations implementation for the given [locale].
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
