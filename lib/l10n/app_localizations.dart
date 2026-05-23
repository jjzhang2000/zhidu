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

  /// AI Configuration page title
  ///
  /// In en, this message translates to:
  /// **'AI Configuration'**
  String get aiConfigTitle;

  /// No description provided for @aiConfigScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Configuration'**
  String get aiConfigScreenTitle;

  /// No description provided for @readThinThick.
  ///
  /// In en, this message translates to:
  /// **'Read Thin First, Then Thick'**
  String get readThinThick;

  /// Appearance Settings title
  ///
  /// In en, this message translates to:
  /// **'Appearance Settings'**
  String get appearanceSettingTitle;

  /// Theme Settings title
  ///
  /// In en, this message translates to:
  /// **'Theme Settings'**
  String get themeSettingTitle;

  /// No description provided for @themeSettingsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Settings'**
  String get themeSettingsScreenTitle;

  /// Language Settings title
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettingTitle;

  /// No description provided for @languageSettingsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettingsScreenTitle;

  /// About title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @aiLanguageFollowBook.
  ///
  /// In en, this message translates to:
  /// **'Follow Book'**
  String get aiLanguageFollowBook;

  /// No description provided for @aiLanguageFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get aiLanguageFollowSystem;

  /// No description provided for @aiLanguageManualSelect.
  ///
  /// In en, this message translates to:
  /// **'Manual Select'**
  String get aiLanguageManualSelect;

  /// No description provided for @uiLanguageFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get uiLanguageFollowSystem;

  /// No description provided for @uiLanguageManualSelect.
  ///
  /// In en, this message translates to:
  /// **'Manual Select'**
  String get uiLanguageManualSelect;

  /// No description provided for @selectAiOutputLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select AI Output Language'**
  String get selectAiOutputLanguage;

  /// No description provided for @selectUiLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select UI Language'**
  String get selectUiLanguage;

  /// No description provided for @aiOutputLanguage.
  ///
  /// In en, this message translates to:
  /// **'AI Output Language'**
  String get aiOutputLanguage;

  /// No description provided for @uiDisplayLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface Language'**
  String get uiDisplayLanguage;

  /// No description provided for @aiLanguageSetting.
  ///
  /// In en, this message translates to:
  /// **'AI Language Setting'**
  String get aiLanguageSetting;

  /// No description provided for @uiLanguageSetting.
  ///
  /// In en, this message translates to:
  /// **'Interface Language Setting'**
  String get uiLanguageSetting;

  /// No description provided for @aiLanguageControl.
  ///
  /// In en, this message translates to:
  /// **'Controls the language of AI-generated content'**
  String get aiLanguageControl;

  /// No description provided for @uiLanguageControl.
  ///
  /// In en, this message translates to:
  /// **'Controls the display language of the app interface'**
  String get uiLanguageControl;

  /// No description provided for @aiLayeredReader.
  ///
  /// In en, this message translates to:
  /// **'AI Layered Reader'**
  String get aiLayeredReader;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @bookshelfEmpty.
  ///
  /// In en, this message translates to:
  /// **'Bookshelf is empty'**
  String get bookshelfEmpty;

  /// No description provided for @noRelatedBooks.
  ///
  /// In en, this message translates to:
  /// **'No related books found'**
  String get noRelatedBooks;

  /// No description provided for @tryOtherKeywords.
  ///
  /// In en, this message translates to:
  /// **'Please try other keywords'**
  String get tryOtherKeywords;

  /// No description provided for @clickToAddBooks.
  ///
  /// In en, this message translates to:
  /// **'Click button at bottom right to add books'**
  String get clickToAddBooks;

  /// No description provided for @confirmRemoval.
  ///
  /// In en, this message translates to:
  /// **'Confirm removal'**
  String get confirmRemoval;

  /// No description provided for @removeConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove《{bookTitle}》?'**
  String removeConfirmation(String bookTitle);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @zhipuProvider.
  ///
  /// In en, this message translates to:
  /// **'Zhipu'**
  String get zhipuProvider;

  /// No description provided for @qwenProvider.
  ///
  /// In en, this message translates to:
  /// **'Qwen'**
  String get qwenProvider;

  /// No description provided for @deepseekProvider.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek'**
  String get deepseekProvider;

  /// No description provided for @minimaxProvider.
  ///
  /// In en, this message translates to:
  /// **'MiniMax'**
  String get minimaxProvider;

  /// No description provided for @ollamaProvider.
  ///
  /// In en, this message translates to:
  /// **'Ollama (Local)'**
  String get ollamaProvider;

  /// No description provided for @lmstudioProvider.
  ///
  /// In en, this message translates to:
  /// **'LM Studio (Local)'**
  String get lmstudioProvider;

  /// No description provided for @chineseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get chineseLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @japaneseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japaneseLanguage;

  /// No description provided for @notConfiguredClickToSet.
  ///
  /// In en, this message translates to:
  /// **'Not configured (click to set)'**
  String get notConfiguredClickToSet;

  /// No description provided for @addedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Added: {bookTitle}'**
  String addedSuccessfully(String bookTitle);

  /// No description provided for @removedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Removed《{bookTitle}》'**
  String removedSuccessfully(String bookTitle);

  /// No description provided for @themeModeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically follow system theme settings'**
  String get themeModeSystemSubtitle;

  /// No description provided for @themeModeLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get themeModeLightSubtitle;

  /// No description provided for @themeModeDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get themeModeDarkSubtitle;

  /// No description provided for @aiLanguageModeBookSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically detect language from book content'**
  String get aiLanguageModeBookSubtitle;

  /// No description provided for @aiLanguageModeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use system language settings'**
  String get aiLanguageModeSystemSubtitle;

  /// No description provided for @aiLanguageModeManualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manually specify AI output language'**
  String get aiLanguageModeManualSubtitle;

  /// No description provided for @uiLanguageModeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use system language settings'**
  String get uiLanguageModeSystemSubtitle;

  /// No description provided for @uiLanguageModeManualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manually specify interface display language'**
  String get uiLanguageModeManualSubtitle;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testing;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @aiServiceSettings.
  ///
  /// In en, this message translates to:
  /// **'AI Service Settings'**
  String get aiServiceSettings;

  /// No description provided for @importBook.
  ///
  /// In en, this message translates to:
  /// **'Import Book'**
  String get importBook;

  /// No description provided for @aiProvider.
  ///
  /// In en, this message translates to:
  /// **'AI Provider'**
  String get aiProvider;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @baseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// Prompt - Chapters label
  ///
  /// In en, this message translates to:
  /// **'Chapters: '**
  String get promptBookChaptersLabel;

  /// Prompt - Book Summary template
  ///
  /// In en, this message translates to:
  /// **'{title}|{author}|{chapterSummaries}|{chaptersLine}'**
  String promptBookSummary(String title, String author, String chapterSummaries, String chaptersLine);

  /// Prompt - Preface Summary template
  ///
  /// In en, this message translates to:
  /// **'{title}|{author}|{prefaceContent}|{chaptersLine}'**
  String promptPrefaceSummary(String title, String author, String prefaceContent, String chaptersLine);

  /// Prompt - Chapter Summary template
  ///
  /// In en, this message translates to:
  /// **'{chapterTitle}|{content}'**
  String promptChapterSummary(String chapterTitle, String content);

  /// Prompt - HTML Translation template
  ///
  /// In en, this message translates to:
  /// **'{content}|{chapterTitle}'**
  String promptTranslateHtml(String content, String chapterTitle);
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
