// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '智读';

  @override
  String get settingsTitle => '设置';

  @override
  String get aiConfigTitle => 'AI';

  @override
  String get aiConfigScreenTitle => 'AI配置页面标题';

  @override
  String get readThinThick => '先读薄，再读厚';

  @override
  String get themeSettingTitle => '主题';

  @override
  String get languageSettingTitle => '语言';

  @override
  String get aboutTitle => '关于';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get languageModeFollowSystem => '跟随系统';

  @override
  String get languageModeManualSelect => '用户自选';

  @override
  String get languageModeSystemSubtitle => 'AI摘要、翻译与界面统一跟随系统语言';

  @override
  String get languageModeManualSubtitle => '手动指定统一的AI与界面语言';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get aiLayeredReader => 'AI 分层阅读器';

  @override
  String get search => '搜索书名/作者';

  @override
  String get sortBy => '排序';

  @override
  String get sortLastRead => '最近阅读时间';

  @override
  String get sortAddedAsc => '加入时间-递增';

  @override
  String get sortAddedDesc => '加入时间-递减';

  @override
  String get sortTitleAsc => '书名-递增';

  @override
  String get sortTitleDesc => '书名-递减';

  @override
  String get sortAuthorAsc => '作者-递增';

  @override
  String get sortAuthorDesc => '作者-递减';

  @override
  String get bookshelfEmpty => '书架空空如也';

  @override
  String get noRelatedBooks => '未找到相关书籍';

  @override
  String get tryOtherKeywords => '请尝试其他关键词';

  @override
  String get clickToAddBooks => '点击右下角按钮添加书籍';

  @override
  String get confirmRemoval => '确认移除';

  @override
  String removeConfirmation(String bookTitle) {
    return '确定要从书架移除《$bookTitle》吗？';
  }

  @override
  String get cancel => '取消';

  @override
  String get remove => '移除';

  @override
  String get zhipuProvider => '智谱';

  @override
  String get qwenProvider => '通义千问';

  @override
  String get deepseekProvider => 'DeepSeek';

  @override
  String get minimaxProvider => 'MiniMax';

  @override
  String get ollamaProvider => 'Ollama（本地）';

  @override
  String get lmstudioProvider => 'LM Studio（本地）';

  @override
  String get chineseLanguage => '简体中文';

  @override
  String get englishLanguage => 'English';

  @override
  String get japaneseLanguage => '日本語';

  @override
  String get notConfiguredClickToSet => '未配置（点击设置）';

  @override
  String addedSuccessfully(String bookTitle) {
    return '已添加: $bookTitle';
  }

  @override
  String removedSuccessfully(String bookTitle) {
    return '已移除《$bookTitle》';
  }

  @override
  String get themeModeSystemSubtitle => '自动跟随系统主题设置';

  @override
  String get themeModeLightSubtitle => '始终使用浅色主题';

  @override
  String get themeModeDarkSubtitle => '始终使用深色主题';

  @override
  String get testing => '测试中...';

  @override
  String get saving => '保存中...';

  @override
  String get failed => '失败';

  @override
  String get version => '版本';

  @override
  String get aiServiceSettings => 'AI 服务设置';

  @override
  String get importBook => '导入书籍';

  @override
  String get aiProvider => 'AI提供商';

  @override
  String get apiKey => 'API Key';

  @override
  String get model => '模型';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get promptBookChaptersLabel => '章节数：';

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
  String get librarySettingsTitle => '书库';

  @override
  String get calibreLibraryLocation => 'Calibre书库位置：';

  @override
  String get noLibraries => '未设置';

  @override
  String get browse => '浏览';

  @override
  String get refresh => '刷新';

  @override
  String get clearBookshelf => '清空书架';

  @override
  String get clearBookshelfConfirmation => '确定要清空书架中的所有书籍吗？此操作不可恢复。';

  @override
  String get clearBookshelfDone => '书架已清空';
}
