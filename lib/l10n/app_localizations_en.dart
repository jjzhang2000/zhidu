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

  @override
  String get promptBookTitleLabel => 'Title: ';

  @override
  String get promptBookAuthorLabel => 'Author: ';

  @override
  String get promptBookChaptersLabel => 'Chapters: ';

  @override
  String promptBookSummary(Object title, Object author, Object chapterSummaries, Object chaptersLine) {
    return '''Please respond in English.

Please generate a complete book summary based on the following chapter summaries, output in Markdown format.

Book information:
- Title: $title
- Author: $author
$chaptersLine

Chapter summaries:
$chapterSummaries

Requirements:
1. **Length: 400-600 words** (approximately 800-900 Chinese characters) - this is strict
   - Do NOT exceed 700 words
   - Do NOT write less than 300 words
2. Output in sections using Markdown headers (##) and paragraphs for easy reading
3. Synthesize chapter content to distill the book's core ideas and knowledge system
4. Must include the target audience or technical requirements (e.g., required background knowledge, prerequisites)
5. Output in Markdown format, can include headers, lists, bold text, etc.
6. Structure your response as:
   - `## Content Summary` - Overview of the book's content
   - `## Core Themes` - Main themes and key ideas, described in paragraphs
   - `## Key Points` - 3-5 bullet points of the most important concepts
   - `## Target Audience` - Who should read this book and what prerequisites are needed

**IMPORTANT**: DO NOT output placeholder text like "(Book content overview)" or "(Core themes)". Generate actual summary content based on the chapter summaries.
''';
  }

  @override
  String promptPrefaceSummary(Object title, Object author, Object prefaceContent, Object chaptersLine) {
    return '''Please respond in English.

Please generate a content introduction for the book based on the following preface/foreword content, output in Markdown format.

Book information:
- Title: $title
- Author: $author
$chaptersLine

Preface/Foreword content:
$prefaceContent

Requirements:
1. **Length: 400-600 words** (approximately 800-900 Chinese characters) - this is strict
   - Do NOT exceed 700 words
   - Do NOT write less than 300 words
2. Output in sections using Markdown headers (##) and paragraphs for easy reading
3. Distill the book's theme and core content based on the preface/foreword
4. Must include the target audience or technical requirements (e.g., required background knowledge, prerequisites)
5. Output in Markdown format, can include headers, lists, bold text, etc.
6. Structure your response as:
   - `## Content Summary` - Overview of the book's content
   - `## Core Themes` - Main themes and key ideas, described in paragraphs
   - `## Target Audience` - Who should read this book and what prerequisites are needed

**IMPORTANT**: DO NOT output placeholder text like "(Content overview)" or "(Core content description)". Generate actual summary content based on the preface.
''';
  }

  @override
  String promptChapterSummary(Object chapterTitle, Object content) {
    return '''Please respond in English.

Please analyze the following book chapter content comprehensively, **first extract the real chapter title**, then generate a summary.

${chapterTitle != '' ? 'Original chapter identifier: $chapterTitle (may not be accurate, please judge the real title based on the content)\n' : ''}Chapter content:
$content

Requirements:
1. **The first line must output the real chapter title**, format: `## [Real Title]`
   - **Must preserve chapter numbering** (e.g., "Chapter X", "Part X", "X." etc.)
   - Title format examples: "## Chapter 1: Data Structures and Algorithms", "## Chapter 1: Introduction", "## 1. Basic Concepts"
   - If the original identifier contains numbering, preserve the numbering and extract the full title
   - If there is no obvious title in the content, distill a summary title based on the content (still needs to include numbering)
2. After the title line, leave a blank line, then output the summary text
3. **Summary length: 200-300 words** (approximately 400-600 Chinese characters) - this is strict
   - Do NOT exceed 350 words
   - Do NOT write less than 150 words
   - Focus on key points, be concise
4. Summary text should use Markdown headers (##) and paragraphs for easy reading
5. Use accessible language, maintain objectivity and neutrality
6. Structure your response as:
   - Start with `## [title]` (only show the title, not "Chapter Title:" prefix)
   - Then `## Core Content` section with main points
   - Then `## Key Points` with 3-5 bullet points
   - End with `## Summary` section

**IMPORTANT**: DO NOT output placeholder text like "(Main content overview)" or "(Chapter summary)". Generate actual summary content based on the chapter.
''';
  }

  @override
  String promptTranslateHtml(Object content, Object chapterTitle) {
    return '''Please respond in English.

Please translate the following HTML content to English.

${chapterTitle != '' ? 'Chapter title: $chapterTitle\n' : ''}HTML source:
$content

Translation Rules
1. ALL text must be translated to English, regardless of the source language
2. Strictly preserve ALL HTML tags: tag names, attributes, nesting, and order must remain completely unchanged
3. Only translate the text content inside tags, do not translate tag names, attribute values, URLs, or code
4. Technical terms can remain in original
5. Code blocks (content inside \`<code>\` or \`<pre>\` tags) should NOT be translated at all, and do NOT perform any escape processing
6. For content in \`<code>\` and \`<pre>\`, output exactly as-is, do NOT add or remove any backslashes
7. The input may contain placeholders \`%%ZHIDU_CODE_BLOCK_N%%\` (where N is a number), these are markers for code blocks - keep them as-is
8. Do NOT add any explanations, notes, or extra content
9. Output ONLY the translated HTML
''';
  }
}

