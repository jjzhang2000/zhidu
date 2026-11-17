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
  String get settingsTitle => 'Settings';

  @override
  String get aiConfigTitle => 'AI Configuration';

  @override
  String get aiConfigScreenTitle => 'AI Configuration';

  @override
  String get readThinThick => 'Read Thin First, Then Thick';

  @override
  String get appearanceSettingTitle => 'Appearance Settings';

  @override
  String get themeSettingTitle => 'Theme Settings';

  @override
  String get themeSettingsScreenTitle => 'Theme Settings';

  @override
  String get languageSettingTitle => 'Language Settings';

  @override
  String get languageSettingsScreenTitle => 'Language Settings';

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
  String get aiLayeredReader => 'AI Layered Reader';

  @override
  String get search => 'Search title/author';

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
  String removeConfirmation(String bookTitle) {
    return 'Are you sure you want to remove《$bookTitle》?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get zhipuProvider => 'Zhipu';

  @override
  String get qwenProvider => 'Qwen';

  @override
  String get deepseekProvider => 'DeepSeek';

  @override
  String get minimaxProvider => 'MiniMax';

  @override
  String get ollamaProvider => 'Ollama (Local)';

  @override
  String get lmstudioProvider => 'LM Studio (Local)';

  @override
  String get chineseLanguage => 'Simplified Chinese';

  @override
  String get englishLanguage => 'English';

  @override
  String get japaneseLanguage => 'Japanese';

  @override
  String get notConfiguredClickToSet => 'Not configured (click to set)';

  @override
  String addedSuccessfully(String bookTitle) {
    return 'Added: $bookTitle';
  }

  @override
  String removedSuccessfully(String bookTitle) {
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
  String get failed => 'Failed';

  @override
  String get version => 'Version';

  @override
  String get aiServiceSettings => 'AI Service Settings';

  @override
  String get importBook => 'Import Book';

  @override
  String get aiProvider => 'AI Provider';

  @override
  String get apiKey => 'API Key';

  @override
  String get model => 'Model';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get promptBookChaptersLabel => 'Chapters: ';

  @override
  String promptBookSummary(String title, String author, String chapterSummaries, String chaptersLine) {
    return '$title|$author|$chapterSummaries|$chaptersLine';
  }

  @override
  String promptChapterSummary(String chapterTitle, String content) {
    return '$chapterTitle|$content';
  }

  @override
  String promptTranslateHtml(String content, String chapterTitle) {
    return '$content|$chapterTitle';
  }

  @override
  String get librarySettingsTitle => 'Library Settings';

  @override
  String get calibreLibraryLocation => 'Calibre library location:';

  @override
  String get noLibraries => 'Not set';

  @override
  String get browse => 'Browse';

  @override
  String get refresh => 'Refresh';

  @override
  String get clearBookshelf => 'Clear Bookshelf';

  @override
  String get clearBookshelfConfirmation => 'Are you sure you want to clear all books? This cannot be undone.';

  @override
  String get clearBookshelfDone => 'Bookshelf cleared';
}
