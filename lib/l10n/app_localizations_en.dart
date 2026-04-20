// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZhiDu';

  @override
  String get homeTabBookshelf => 'Bookshelf';

  @override
  String get homeTabDiscovery => 'Discovery';

  @override
  String get homeTabProfile => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get aiConfigTitle => 'AI Configuration';

  @override
  String get aiConfigSubtitle => 'Configure AI service provider and parameters';

  @override
  String get readThinThick => 'Read Thin First, Then Thick';

  @override
  String get appearanceSettingTitle => 'Appearance Settings';

  @override
  String get themeSettingTitle => 'Theme Settings';

  @override
  String get languageSettingTitle => 'Language Settings';

  @override
  String get dataExportTitle => 'Data Export';

  @override
  String get aiProvider => 'AI Provider';

  @override
  String get apiKey => 'API Key';

  @override
  String get model => 'Model';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get ok => 'OK';

  @override
  String get back => 'Back';

  @override
  String chapterTitle(Object chapterIndex, Object chapterTitle) {
    return 'Chapter $chapterIndex: $chapterTitle';
  }

  @override
  String bookDetailTitle(Object bookTitle) {
    return '$bookTitle - Book Details';
  }

  @override
  String summaryScreenTitle(Object bookTitle) {
    return '$bookTitle - Summary';
  }

  @override
  String pdfReaderTitle(Object bookTitle) {
    return '$bookTitle - PDF Reader';
  }

  @override
  String get aiConfigScreenTitle => 'AI Configuration';

  @override
  String get themeSettingsScreenTitle => 'Theme Settings';

  @override
  String get languageSettingsScreenTitle => 'Language Settings';

  @override
  String get settingsScreenTitle => 'Settings';

  @override
  String get storageSettingsScreenTitle => 'Storage Settings';

  @override
  String get backupSettingsScreenTitle => 'Backup Settings';

  @override
  String get noBooks => 'No Books';

  @override
  String get importBook => 'Import Book';

  @override
  String get importBookDesc => 'Supports EPUB and PDF formats';

  @override
  String get noSummaries => 'No Summaries';

  @override
  String get checkSummariesData => 'Please check if there are summary data';

  @override
  String get generatingSummary => 'Generating Summary...';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get failed => 'Failed';

  @override
  String get loading => 'Loading...';

  @override
  String get bookShelf => 'Bookshelf';

  @override
  String get discovery => 'Discovery';

  @override
  String get myProfile => 'Profile';

  @override
  String get version => 'Version';

  @override
  String get aiLayeredReader => 'AI Layered Reader';

  @override
  String get search => 'Search';

  @override
  String get bookshelfEmpty => 'Bookshelf is empty';

  @override
  String get noRelatedBooks => 'No related books found';

  @override
  String get tryOtherKeywords => 'Please try other keywords';

  @override
  String get clickToAddBooks => 'Click button at bottom right to add books';

  @override
  String get confirmRemoval => 'Confirm removal';

  @override
  String removeConfirmation(Object bookTitle) {
    return 'Are you sure you want to remove《$bookTitle》?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get zhipuProvider => 'Zhipu';

  @override
  String get qwenProvider => 'Qwen';

  @override
  String get ollamaProvider => 'Ollama (Local)';

  @override
  String get chineseLanguage => 'Simplified Chinese';

  @override
  String get englishLanguage => 'English';

  @override
  String get japaneseLanguage => 'Japanese';

  @override
  String get notConfiguredClickToSet => 'Not configured (click to set)';

  @override
  String addedSuccessfully(Object bookTitle) {
    return 'Added: $bookTitle';
  }

  @override
  String removedSuccessfully(Object bookTitle) {
    return 'Removed《$bookTitle》';
  }

  @override
  String get themeModeSystemSubtitle => 'Automatically follow system theme settings';

  @override
  String get themeModeLightSubtitle => 'Always use light theme';

  @override
  String get themeModeDarkSubtitle => 'Always use dark theme';

  @override
  String get aiLanguageModeBookSubtitle => 'Automatically detect language from book content';

  @override
  String get aiLanguageModeSystemSubtitle => 'Use system language settings';

  @override
  String get aiLanguageModeManualSubtitle => 'Manually specify AI output language';

  @override
  String get uiLanguageModeSystemSubtitle => 'Use system language settings';

  @override
  String get uiLanguageModeManualSubtitle => 'Manually specify interface display language';

  @override
  String get testing => 'Testing...';

  @override
  String get saving => 'Saving...';

  @override
  String get booksCount => 'Books Count';

  @override
  String get summariesCount => 'Summaries Count';

  @override
  String get exportBookSummaries => 'Export Book Summaries';

  @override
  String get exportBookSummariesDesc => 'Export all book summaries to Markdown files';

  @override
  String get aiServiceSettings => 'AI Service Settings';

  @override
  String get aboutTitle => 'About';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get aiLanguageFollowBook => 'Follow Book';

  @override
  String get aiLanguageFollowSystem => 'Follow System';

  @override
  String get aiLanguageManualSelect => 'Manual Select';

  @override
  String get uiLanguageFollowSystem => 'Follow System';

  @override
  String get uiLanguageManualSelect => 'Manual Select';

  @override
  String get selectAiOutputLanguage => 'Select AI Output Language';

  @override
  String get selectUiLanguage => 'Select UI Language';

  @override
  String get aiOutputLanguage => 'AI Output Language';

  @override
  String get uiDisplayLanguage => 'Interface Language';

  @override
  String get aiLanguageSetting => 'AI Language Setting';

  @override
  String get uiLanguageSetting => 'Interface Language Setting';

  @override
  String get aiLanguageControl => 'Controls the language of AI-generated content';

  @override
  String get uiLanguageControl => 'Controls the display language of the app interface';

  @override
  String get aiConfigStatus => 'AI Configuration Status';

  @override
  String get themeConfigStatus => 'Theme Configuration Status';

  @override
  String get languageConfigStatus => 'Language Configuration Status';

  @override
  String get dataManagementTitle => 'Data Management';

  @override
  String get backupRestoreTitle => 'Backup & Restore';

  @override
  String get dataStatisticsTitle => 'Data Statistics';

  @override
  String get backupSettings => 'Backup Settings';

  @override
  String get backupData => 'Backup Data';

  @override
  String get restoreData => 'Restore Data';
}
