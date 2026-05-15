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
  String get homeTabBookshelf => '书架';

  @override
  String get homeTabProfile => '我的';

  @override
  String get settingsTitle => '设置';

  @override
  String get aiConfigTitle => 'AI配置';

  @override
  String get aiConfigSubtitle => '配置AI服务提供商及参数';

  @override
  String get readThinThick => '先读薄，再读厚';

  @override
  String get appearanceSettingTitle => '外观设置';

  @override
  String get themeSettingTitle => '主题设置';

  @override
  String get languageSettingTitle => '语言设置';

  @override
  String get dataExportTitle => '数据导出';

  @override
  String get aiProvider => 'AI Provider';

  @override
  String get apiKey => 'API Key';

  @override
  String get model => 'Model';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get testConnection => '测试连接';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

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
  String get aiConfigScreenTitle => 'AI配置';

  @override
  String get themeSettingsScreenTitle => '主题设置';

  @override
  String get languageSettingsScreenTitle => '语言设置';

  @override
  String get settingsScreenTitle => '设置';

  @override
  String get storageSettingsScreenTitle => '存储设置';

  @override
  String get backupSettingsScreenTitle => '备份设置';

  @override
  String get noBooks => '暂无书籍';

  @override
  String get importBook => '导入书籍';

  @override
  String get importBookDesc => '支持EPUB和PDF格式';

  @override
  String get noSummaries => '暂无摘要';

  @override
  String get checkSummariesData => 'Please check if there are summary data';

  @override
  String get generatingSummary => '正在生成摘要...';

  @override
  String get retry => '重试';

  @override
  String get error => '错误';

  @override
  String get success => '成功';

  @override
  String get failed => '失败';

  @override
  String get loading => '加载中...';

  @override
  String get bookShelf => '书架';

  @override
  String get myProfile => '我的';

  @override
  String get version => '版本';

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
  String removeConfirmation(Object bookTitle) {
    return '确定要从书架移除《$bookTitle》吗？';
  }

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
  String addedSuccessfully(Object bookTitle) {
    return '已添加: $bookTitle';
  }

  @override
  String removedSuccessfully(Object bookTitle) {
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
  String get booksCount => '书籍数量';

  @override
  String get summariesCount => '摘要数量';

  @override
  String get exportBookSummaries => '导出书籍摘要';

  @override
  String get exportBookSummariesDesc => '将所有书籍摘要导出为 Markdown 文件';

  @override
  String get aiServiceSettings => 'AI 服务设置';

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
  String get aiConfigStatus => 'AI配置状态';

  @override
  String get themeConfigStatus => '主题配置状态';

  @override
  String get languageConfigStatus => '语言配置状态';

  @override
  String get dataManagementTitle => '数据管理';

  @override
  String get backupRestoreTitle => '备份与恢复';

  @override
  String get dataStatisticsTitle => '数据统计';

  @override
  String get backupSettings => '备份设置';

  @override
  String get backupData => '备份数据';

  @override
  String get restoreData => '恢复数据';
}
