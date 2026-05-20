// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '智読';

  @override
  String get homeTabBookshelf => '本棚';

  @override
  String get homeTabProfile => 'マイページ';

  @override
  String get settingsTitle => '設定';

  @override
  String get aiConfigTitle => 'AI構成';

  @override
  String get aiConfigSubtitle => 'AIサービスプロバイダーとパラメータの構成';

  @override
  String get readThinThick => '最初に薄く読んでから厚くする';

  @override
  String get appearanceSettingTitle => '外観設定';

  @override
  String get themeSettingTitle => 'テーマ設定';

  @override
  String get languageSettingTitle => '言語設定';

  @override
  String get dataExportTitle => 'データエクスポート';

  @override
  String get aiProvider => 'AIプロバイダー';

  @override
  String get apiKey => 'APIキー';

  @override
  String get model => 'モデル';

  @override
  String get baseUrl => 'ベースURL';

  @override
  String get testConnection => '接続テスト';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get ok => 'OK';

  @override
  String get back => '戻る';

  @override
  String chapterTitle(Object chapterIndex, Object chapterTitle) {
    return '第$chapterIndex章 $chapterTitle';
  }

  @override
  String bookDetailTitle(Object bookTitle) {
    return '$bookTitle - 書籍詳細';
  }

  @override
  String summaryScreenTitle(Object bookTitle) {
    return '$bookTitle - 要約';
  }

  @override
  String pdfReaderTitle(Object bookTitle) {
    return '$bookTitle - PDFリーダー';
  }

  @override
  String get aiConfigScreenTitle => 'AI構成';

  @override
  String get themeSettingsScreenTitle => 'テーマ設定';

  @override
  String get languageSettingsScreenTitle => '言語設定';

  @override
  String get settingsScreenTitle => '設定';

  @override
  String get storageSettingsScreenTitle => 'ストレージ設定';

  @override
  String get backupSettingsScreenTitle => 'バックアップ設定';

  @override
  String get noBooks => '書籍がありません';

  @override
  String get importBook => '書籍をインポート';

  @override
  String get importBookDesc => 'EPUBおよびPDF形式をサポート';

  @override
  String get noSummaries => '要約がありません';

  @override
  String get checkSummariesData => 'サマリーデータがあるか確認してください';

  @override
  String get generatingSummary => '要約を生成中...';

  @override
  String get retry => '再試行';

  @override
  String get error => 'エラー';

  @override
  String get success => '成功';

  @override
  String get failed => '失敗';

  @override
  String get loading => '読み込み中...';

  @override
  String get bookShelf => '本棚';

  @override
  String get myProfile => 'マイページ';

  @override
  String get version => 'バージョン';

  @override
  String get aiLayeredReader => 'AI層別リーダー';

  @override
  String get search => '検索';

  @override
  String get bookshelfEmpty => '本棚は空です';

  @override
  String get noRelatedBooks => '関連する書籍が見つかりません';

  @override
  String get tryOtherKeywords => '他のキーワードを試してください';

  @override
  String get clickToAddBooks => '右下のボタンをクリックして書籍を追加';

  @override
  String get confirmRemoval => '削除の確認';

  @override
  String removeConfirmation(Object bookTitle) {
    return '本当に「$bookTitle」を本棚から削除しますか？';
  }

  @override
  String get remove => '削除';

  @override
  String get zhipuProvider => '智譜';

  @override
  String get qwenProvider => '通義千問';

  @override
  String get deepseekProvider => 'DeepSeek';

  @override
  String get minimaxProvider => 'MiniMax';

  @override
  String get ollamaProvider => 'Ollama（ローカル）';

  @override
  String get lmstudioProvider => 'LM Studio（ローカル）';

  @override
  String get chineseLanguage => '簡体中国語';

  @override
  String get englishLanguage => '英語';

  @override
  String get japaneseLanguage => '日本語';

  @override
  String get notConfiguredClickToSet => '未設定（クリックして設定）';

  @override
  String addedSuccessfully(Object bookTitle) {
    return '追加済み: $bookTitle';
  }

  @override
  String removedSuccessfully(Object bookTitle) {
    return '削除済み《$bookTitle》';
  }

  @override
  String get themeModeSystemSubtitle => 'システムのテーマ設定に自動的に従う';

  @override
  String get themeModeLightSubtitle => '常にライトテーマを使用';

  @override
  String get themeModeDarkSubtitle => '常にダークテーマを使用';

  @override
  String get aiLanguageModeBookSubtitle => '書籍の内容から言語を自動検出';

  @override
  String get aiLanguageModeSystemSubtitle => 'システム言語設定を使用';

  @override
  String get aiLanguageModeManualSubtitle => 'AI出力言語を手動で指定';

  @override
  String get uiLanguageModeSystemSubtitle => 'システム言語設定を使用';

  @override
  String get uiLanguageModeManualSubtitle => 'インターフェース表示言語を手動で指定';

  @override
  String get testing => 'テスト中...';

  @override
  String get saving => '保存中...';

  @override
  String get booksCount => '書籍数';

  @override
  String get summariesCount => '要約数';

  @override
  String get exportBookSummaries => '書籍要約をエクスポート';

  @override
  String get exportBookSummariesDesc => 'すべての書籍要約をMarkdownファイルにエクスポート';

  @override
  String get aiServiceSettings => 'AIサービス設定';

  @override
  String get aboutTitle => 'アプリについて';

  @override
  String get themeModeSystem => 'システム';

  @override
  String get themeModeLight => 'ライト';

  @override
  String get themeModeDark => 'ダーク';

  @override
  String get aiLanguageFollowBook => '書籍に従う';

  @override
  String get aiLanguageFollowSystem => 'システムに従う';

  @override
  String get aiLanguageManualSelect => 'ユーザー選択';

  @override
  String get uiLanguageFollowSystem => 'システムに従う';

  @override
  String get uiLanguageManualSelect => 'ユーザー選択';

  @override
  String get selectAiOutputLanguage => 'AI出力言語の選択';

  @override
  String get selectUiLanguage => 'UI言語の選択';

  @override
  String get aiOutputLanguage => 'AI出力言語';

  @override
  String get uiDisplayLanguage => 'インターフース言語';

  @override
  String get aiLanguageSetting => 'AI言語設定';

  @override
  String get uiLanguageSetting => 'インターフェース言語設定';

  @override
  String get aiLanguageControl => 'AI生成コンテンツの言語を制御';

  @override
  String get uiLanguageControl => 'アプリインターフェースの表示言語を制御';

  @override
  String get aiConfigStatus => 'AI構成ステータス';

  @override
  String get themeConfigStatus => 'テーマ構成ステータス';

  @override
  String get languageConfigStatus => '言語構成ステータス';

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
  String get promptBookTitleLabel => '書名：';

  @override
  String get promptBookAuthorLabel => '著者：';

  @override
  String get promptBookChaptersLabel => '章数：';

  @override
  String promptBookSummary(Object title, Object author, Object chapterSummaries, Object chaptersLine) {
    return '''以下の各章の要約に基づいて、書籍全体の完全な要約を生成し、Markdown形式で出力してください。

書籍情報：
- 書名：$title
- 著者：$author
$chaptersLine

各章の要約：
$chapterSummaries

要件：
1. **長さ：400-600文字**（約200-300英単語）- これは厳格な要件です
   - 700文字を超えないこと
   - 300文字を下回らないこと
2. Markdownの見出し（##）と段落を使用してセクション分けし、読みやすくすること
3. 各章の内容を統合し、書籍の核心的な考え方と知識体系を抽出すること
4. 本書の対象読者や技術的要件（必要な基礎知識、前提スキルなど）を必ず含めること
5. Markdown形式で出力し、見出し、リスト、太字などの書式を使用可能
6. 出力構造：
   - `## 内容概要` - 書籍内容の概要
   - `## 核心テーマ` - 書籍の核心テーマ、段落で説明
   - `## 重要ポイント` - 最も重要な3-5の概念ポイント
   - `## 対象読者` - 誰がこの本を読むべきか、必要な前提知識

**重要**：プレースホルダーテキスト（「（書籍内容の概要）」や「（核心テーマ）」など）を出力しないでください。章の要約に基づいて実際の要約内容を生成してください。
''';
  }

  @override
  String promptPrefaceSummary(Object title, Object author, Object prefaceContent, Object chaptersLine) {
    return '''以下の前書き/序文の内容に基づいて、書籍の内容紹介を生成し、Markdown形式で出力してください。

書籍情報：
- 書名：$title
- 著者：$author
$chaptersLine

前書き/序文の内容：
$prefaceContent

要件：
1. **長さ：400-600文字**（約200-300英単語）- これは厳格な要件です
   - 700文字を超えないこと
   - 300文字を下回らないこと
2. Markdownの見出し（##）と段落を使用してセクション分けし、読みやすくすること
3. 前書き/序文の内容に基づいて書籍のテーマと核心内容を抽出すること
4. 本書の対象読者や技術的要件（必要な基礎知識、前提スキルなど）を必ず含めること
5. Markdown形式で出力し、見出し、リスト、太字などの書式を使用可能
6. 出力構造：
   - `## 内容概要` - 書籍内容の概要
   - `## 核心テーマ` - 主要テーマと重要な考え方、段落で説明
   - `## 対象読者` - 誰がこの本を読むべきか、必要な前提知識

**重要**：プレースホルダーテキスト（「（内容概要）」や「（核心内容の説明）」など）を出力しないでください。前書きに基づいて実際の要約内容を生成してください。
''';
  }

  @override
  String promptChapterSummary(Object chapterTitle, Object content) {
    return '''以下の書籍の章の内容を包括的に分析し、**まず章の実際のタイトルを抽出**してから、要約を生成してください。

${chapterTitle != '' ? '元の章の識別子：$chapterTitle（正確でない可能性があります。内容に基づいて実際のタイトルを判断してください）\n' : ''}章の内容：
$content

要件：
1. **最初の行に章の実際のタイトルを出力**、形式：`## [実際のタイトル]`
   - **章番号を必ず保持**（例：「第X章」、「Chapter X」、「X.」など）
   - タイトル形式の例：「## 第1章 データ構造とアルゴリズムの基礎」、「## Chapter 1: Introduction」、「## 1. 基本概念」
   - 元の識別子に番号が含まれている場合は、番号を保持して完全なタイトルを抽出
   - 内容に明確なタイトルがない場合は、内容に基づいて要約タイトルを作成（番号を含めること）
2. タイトル行の後に1行空けて、要約本文を出力
3. **要約の長さ：200-300文字**（約100-150英単語）- これは厳格な要件です
   - 350文字を超えないこと
   - 150文字を下回らないこと
   - 要点に焦点を当て、簡潔にすること
4. 要約本文はMarkdownの見出し（##）と段落を使用して読みやすくすること
5. わかりやすい言葉を使用し、客観的かつ中立的であること
6. 出力構造：
   - `## [タイトル]` で開始（タイトルのみを表示し、「章タイトル：」のような接頭辞は付けない）
   - 次に `## 核心内容` セクション、主要なポイントを含む
   - 次に `## 重要ポイント`、3-5のポイント
   - 最後に `## まとめ` セクション

**重要**：プレースホルダーテキスト（「（主要内容の概要）」や「（章のまとめ）」など）を出力しないでください。章の内容に基づいて実際の要約内容を生成してください。
''';
  }

}
