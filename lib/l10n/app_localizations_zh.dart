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

  @override
  String get promptBookTitleLabel => '书名：';

  @override
  String get promptBookAuthorLabel => '作者：';

  @override
  String get promptBookChaptersLabel => '章节数：';

  @override
  String promptBookSummary(Object title, Object author, Object chapterSummaries, Object chaptersLine) {
    return '''请根据以下各章节摘要，为全书生成一份完整的书籍摘要，使用 Markdown 格式输出。

书籍信息：
- 书名：$title
- 作者：$author
$chaptersLine

各章节摘要：
$chapterSummaries

要求：
1. **长度：400-600 字**（约 200-300 英文单词）- 这是严格要求
   - 不要超过 700 字
   - 不要少于 300 字
2. 按内容分段输出，使用 Markdown 标题（##）和段落组织，便于阅读
3. 综合各章节内容，提炼全书核心观点和知识体系
4. 必须包含本书的适用读者人群或技术要求（如需要的基础知识、前置技能等）
5. 使用 Markdown 格式输出，可以包含标题、列表、粗体等格式
6. 输出结构：
   - `## 内容简介` - 全书内容概览
   - `## 核心主题` - 全书核心主题，用段落描述
   - `## 关键要点` - 最重要的 3-5 个概念要点
   - `## 适合读者` - 谁应该阅读此书以及需要什么前置知识

**重要**：不要输出占位符文本如"（全书内容概述）"或"（核心主题）"。基于章节摘要生成实际的摘要内容。
''';
  }

  @override
  String promptPrefaceSummary(Object title, Object author, Object prefaceContent, Object chaptersLine) {
    return '''请根据以下前言/序言内容，为书籍生成一份内容介绍，使用 Markdown 格式输出。

书籍信息：
- 书名：$title
- 作者：$author
$chaptersLine

前言/序言内容：
$prefaceContent

要求：
1. **长度：400-600 字**（约 200-300 英文单词）- 这是严格要求
   - 不要超过 700 字
   - 不要少于 300 字
2. 按内容分段输出，使用 Markdown 标题（##）和段落组织，便于阅读
3. 基于前言/序言内容提炼书籍主题和核心内容
4. 必须包含本书的适用读者人群或技术要求（如需要的基础知识、前置技能等）
5. 使用 Markdown 格式输出，可以包含标题、列表、粗体等格式
6. 输出结构：
   - `## 内容简介` - 书籍内容概览
   - `## 核心主题` - 主要主题和关键思想，用段落描述
   - `## 适合读者` - 谁应该阅读此书以及需要什么前置知识

**重要**：不要输出占位符文本如"（内容概述）"或"（核心内容描述）"。基于前言生成实际的摘要内容。
''';
  }

  @override
  String promptChapterSummary(Object chapterTitle, Object content) {
    return '''请对以下书籍章节内容进行全面分析，**首先提取章节的真实标题**，然后生成摘要。

${chapterTitle != '' ? '原始章节标识：$chapterTitle（可能不准确，请根据内容判断真实标题）\n' : ''}章节内容：
$content

要求：
1. **第一行必须输出章节的真实标题**，格式为：`## [真实标题]`
   - **必须保留章节编号**（如"第 X 章"、"Chapter X"、"X."等）
   - 标题格式示例："## 第 1 章 数据结构与算法基础"、"## Chapter 1: Introduction"、"## 1. 基础概念"
   - 如果原始标识包含编号，保留编号并提取完整标题
   - 如果内容无明显标题，请根据内容提炼概括性标题（仍需包含编号）
2. 标题行之后空一行，然后输出摘要正文
3. **摘要长度：200-300 字**（约 100-150 英文单词）- 这是严格要求
   - 不要超过 350 字
   - 不要少于 150 字
   - 重点关注要点，保持简洁
4. 摘要正文使用 Markdown 标题（##）和段落组织，便于阅读
5. 使用通俗易懂的语言，保持客观中立
6. 输出结构：
   - 以 `## [标题]` 开始（只显示标题，不显示"章节标题："这类字样）
   - 然后是 `## 核心内容` 部分，包含主要要点
   - 然后是 `## 关键要点`，包含 3-5 个要点
   - 最后是 `## 总结` 部分

**重要**：不要输出占位符文本如"（主要内容概述）"或"（章节总结）"。基于章节内容生成实际的摘要内容。
''';
  }


}

