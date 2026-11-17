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
  String get settingsTitle => '設定';

  @override
  String get aiConfigTitle => 'AI構成';

  @override
  String get aiConfigScreenTitle => 'AI構成';

  @override
  String get readThinThick => '最初に薄く読んでから厚くする';

  @override
  String get appearanceSettingTitle => '外観設定';

  @override
  String get themeSettingTitle => 'テーマ設定';

  @override
  String get themeSettingsScreenTitle => 'テーマ設定';

  @override
  String get languageSettingTitle => '言語設定';

  @override
  String get languageSettingsScreenTitle => '言語設定';

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
  String get uiDisplayLanguage => 'インターフェース言語';

  @override
  String get aiLanguageSetting => 'AI言語設定';

  @override
  String get uiLanguageSetting => 'インターフェース言語設定';

  @override
  String get aiLanguageControl => 'AI生成コンテンツの言語を制御';

  @override
  String get uiLanguageControl => 'アプリインターフェースの表示言語を制御';

  @override
  String get aiLayeredReader => 'AI層別リーダー';

  @override
  String get search => 'タイトル/著者を検索';

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
  String removeConfirmation(String bookTitle) {
    return '本当に「$bookTitle」を本棚から削除しますか？';
  }

  @override
  String get cancel => 'キャンセル';

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
  String addedSuccessfully(String bookTitle) {
    return '追加済み: $bookTitle';
  }

  @override
  String removedSuccessfully(String bookTitle) {
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
  String get failed => '失敗';

  @override
  String get version => 'バージョン';

  @override
  String get aiServiceSettings => 'AIサービス設定';

  @override
  String get importBook => '書籍をインポート';

  @override
  String get aiProvider => 'AIプロバイダー';

  @override
  String get apiKey => 'APIキー';

  @override
  String get model => 'モデル';

  @override
  String get baseUrl => 'ベースURL';

  @override
  String get promptBookChaptersLabel => '章数：';

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
  String get librarySettingsTitle => '書庫設定';

  @override
  String get calibreLibraryLocation => 'Calibre ライブラリの場所：';

  @override
  String get noLibraries => '未設定';

  @override
  String get browse => '参照';

  @override
  String get refresh => '更新';

  @override
  String get clearBookshelf => '本棚を空にする';

  @override
  String get clearBookshelfConfirmation => '本棚のすべての書籍を削除しますか？この操作は取り消せません。';

  @override
  String get clearBookshelfDone => '本棚を空にしました';
}
