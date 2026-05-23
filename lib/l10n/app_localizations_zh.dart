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
  String get aiConfigTitle => 'AI配置';

  @override
  String get aiConfigScreenTitle => 'AI配置页面标题';

  @override
  String get readThinThick => '先读薄，再读厚';

  @override
  String get appearanceSettingTitle => '外观设置';

  @override
  String get themeSettingTitle => '主题设置';

  @override
  String get themeSettingsScreenTitle => '主题设置页面标题';

  @override
  String get languageSettingTitle => '语言设置';

  @override
  String get languageSettingsScreenTitle => '语言设置页面标题';

  @override
  String get aboutTitle => '关于';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get aiLanguageFollowBook => '跟随书籍';

  @override
  String get aiLanguageFollowSystem => '跟随系统';

  @override
  String get aiLanguageManualSelect => '用户自选';

  @override
  String get uiLanguageFollowSystem => '跟随系统';

  @override
  String get uiLanguageManualSelect => '用户自选';

  @override
  String get selectAiOutputLanguage => '选择AI输出语言';

  @override
  String get selectUiLanguage => '选择界面语言';

  @override
  String get aiOutputLanguage => 'AI输出语言';

  @override
  String get uiDisplayLanguage => '界面语言';

  @override
  String get aiLanguageSetting => 'AI语言设置';

  @override
  String get uiLanguageSetting => '界面语言设置';

  @override
  String get aiLanguageControl => '控制AI生成内容的语言';

  @override
  String get uiLanguageControl => '控制应用界面的显示语言';

  @override
  String get aiLayeredReader => 'AI 分层阅读器';

  @override
  String get search => '搜索';

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
  String get aiLanguageModeBookSubtitle => '根据书籍内容语言自动判断';

  @override
  String get aiLanguageModeSystemSubtitle => '使用系统语言设置';

  @override
  String get aiLanguageModeManualSubtitle => '手动指定 AI 输出语言';

  @override
  String get uiLanguageModeSystemSubtitle => '使用系统语言设置';

  @override
  String get uiLanguageModeManualSubtitle => '手动指定界面显示语言';

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
  String promptPrefaceSummary(String title, String author, String prefaceContent, String chaptersLine) {
    return '$title|$author|$prefaceContent|$chaptersLine';
  }

  @override
  String promptChapterSummary(String chapterTitle, String content) {
    return '$chapterTitle|$content';
  }

  @override
  String promptTranslateHtml(String content, String chapterTitle) {
    return '$content|$chapterTitle';
  }
}
