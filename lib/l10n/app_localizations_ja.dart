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
  String get homeTabDiscovery => '発見';

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
  String get discovery => '発見';

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
  String get ollamaProvider => 'Ollama（ローカル）';

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
}
