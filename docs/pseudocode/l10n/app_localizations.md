# l10n/app_localizations.dart 伪代码说明

## 文件概述
国际化本地化基类定义，提供多语言文本访问接口。

---

## 抽象类：AppLocalizations

**功能**：定义所有本地化字符串的接口

### 属性
```
localeName: String  // 标准化的语言环境名称
```

---

### 方法：of() (静态方法)

**功能**：从 BuildContext 获取 AppLocalizations 实例

**伪代码**：
```
STATIC METHOD of(BuildContext context) -> AppLocalizations?:
    RETURN Localizations.of<AppLocalizations>(context, AppLocalizations)
END METHOD
```

---

### 属性：delegate (静态常量)

**功能**：本地化代理，用于加载和支撑本地化资源

```
CONST delegate = _AppLocalizationsDelegate()
```

---

### 属性：localizationsDelegates (静态常量)

**功能**：返回所有本地化代理列表

**伪代码**：
```
CONST localizationsDelegates = [
    delegate,                              // AppLocalizations 代理
    GlobalMaterialLocalizations.delegate,  // Material 组件本地化
    GlobalCupertinoLocalizations.delegate, // Cupertino 组件本地化
    GlobalWidgetsLocalizations.delegate    // Widgets 本地化
]
```

---

### 属性：supportedLocales (静态常量)

**功能**：支持的语言环境列表

```
CONST supportedLocales = [
    Locale('en'),  // 英语
    Locale('ja'),  // 日语
    Locale('zh')   // 中文
]
```

---

### 抽象 Getter 方法

**功能**：定义所有可本地化的字符串

**字符串资源分类**：

#### 应用基础
```
appTitle: String                    // 应用标题
readThinThick: String               // "先读薄，再读厚"理念
aiLayeredReader: String             // "AI 分层阅读器"
version: String                     // 版本号
```

#### 导航和标签
```
homeTabBookshelf: String            // 首页 - 书架
homeTabDiscovery: String            // 首页 - 发现
homeTabProfile: String              // 首页 - 我的
bookShelf: String                   // 书架
discovery: String                   // 发现
myProfile: String                   // 我的
```

#### 设置相关
```
settingsTitle: String               // 设置
aiConfigTitle: String               // AI 配置
aiConfigSubtitle: String            // AI 配置副标题
appearanceSettingTitle: String      // 外观设置
themeSettingTitle: String           // 主题设置
languageSettingTitle: String        // 语言设置
dataExportTitle: String             // 数据导出
dataManagementTitle: String         // 数据管理
backupRestoreTitle: String          // 备份与恢复
dataStatisticsTitle: String         // 数据统计
```

#### AI 配置
```
aiProvider: String                  // AI 提供商
apiKey: String                      // API 密钥
model: String                       // 模型
baseUrl: String                     // Base URL
testConnection: String              // 测试连接
zhipuProvider: String               // 智谱
qwenProvider: String                // 通义千问
ollamaProvider: String              // Ollama (本地)
```

#### 语言选项
```
chineseLanguage: String             // 简体中文
englishLanguage: String             // 英语
japaneseLanguage: String            // 日语
aiLanguageFollowBook: String        // 跟随书籍
aiLanguageFollowSystem: String      // 跟随系统
aiLanguageManualSelect: String      // 手动选择
uiLanguageFollowSystem: String      // 跟随系统 (UI)
uiLanguageManualSelect: String      // 手动选择 (UI)
```

#### 通用操作
```
save: String                        // 保存
cancel: String                      // 取消
confirm: String                     // 确认
ok: String                          // 确定
back: String                        // 返回
remove: String                      // 移除
search: String                      // 搜索
importBook: String                  // 导入书籍
retry: String                       // 重试
loading: String                     // 加载中...
testing: String                     // 测试中...
saving: String                      // 保存中...
```

#### 状态消息
```
noBooks: String                     // 无书籍
noSummaries: String                 // 无摘要
generatingSummary: String           // 生成摘要中...
error: String                       // 错误
success: String                     // 成功
failed: String                      // 失败
addedSuccessfully(bookTitle): String    // 添加成功
removedSuccessfully(bookTitle): String  // 移除成功
```

#### 书籍相关
```
bookDetailTitle(bookTitle): String  // 书籍详情标题
summaryScreenTitle(bookTitle): String   // 摘要页面标题
pdfReaderTitle(bookTitle): String   // PDF 阅读器标题
removeConfirmation(bookTitle): String   // 移除确认
confirmRemoval: String              // 确认移除
```

#### 空状态提示
```
bookshelfEmpty: String              // 书架为空
noRelatedBooks: String              // 无相关书籍
tryOtherKeywords: String            // 尝试其他关键词
clickToAddBooks: String             // 点击添加书籍
checkSummariesData: String          // 检查摘要数据
```

#### 数据统计
```
booksCount: String                  // 书籍数量
summariesCount: String              // 摘要数量
exportBookSummaries: String         // 导出书籍摘要
exportBookSummariesDesc: String     // 导出描述
```

#### 设置状态
```
aiConfigStatus: String              // AI 配置状态
themeConfigStatus: String           // 主题配置状态
languageConfigStatus: String        // 语言配置状态
notConfiguredClickToSet: String     // 未配置 (点击设置)
```

#### 主题模式
```
themeModeSystem: String             // 系统
themeModeLight: String              // 浅色
themeModeDark: String               // 深色
themeModeSystemSubtitle: String     // 跟随系统
themeModeLightSubtitle: String      // 始终使用浅色
themeModeDarkSubtitle: String       // 始终使用深色
```

#### 语言设置
```
aiLanguageSetting: String           // AI 语言设置
uiLanguageSetting: String           // 界面语言设置
aiOutputLanguage: String            // AI 输出语言
uiDisplayLanguage: String           // 界面语言
selectAiOutputLanguage: String      // 选择 AI 输出语言
selectUiLanguage: String            // 选择界面语言
aiLanguageControl: String           // AI 语言控制说明
uiLanguageControl: String           // UI 语言控制说明
aiLanguageModeBookSubtitle: String  // 跟随书籍说明
aiLanguageModeSystemSubtitle: String // 跟随系统说明
aiLanguageModeManualSubtitle: String // 手动选择说明
uiLanguageModeSystemSubtitle: String // UI 跟随系统说明
uiLanguageModeManualSubtitle: String // UI 手动选择说明
```

#### 屏幕标题
```
aiConfigScreenTitle: String              // AI 配置页面
themeSettingsScreenTitle: String         // 主题设置页面
languageSettingsScreenTitle: String      // 语言设置页面
settingsScreenTitle: String              // 设置页面
storageSettingsScreenTitle: String       // 存储设置页面
backupSettingsScreenTitle: String        // 备份设置页面
```

#### 备份相关
```
backupSettings: String            // 备份设置
backupData: String                // 备份数据
restoreData: String               // 恢复数据
```

---

### 参数化方法

**功能**：支持动态参数的本地化字符串

#### chapterTitle()
```
METHOD chapterTitle(chapterIndex, chapterTitle) -> String:
    // 中文： "第{chapterIndex}章：{chapterTitle}"
    // 英文： "Chapter {chapterIndex}: {chapterTitle}"
    // 日文： "第{chapterIndex}章：{chapterTitle}"
END METHOD
```

#### bookDetailTitle()
```
METHOD bookDetailTitle(bookTitle) -> String:
    // 中文： "{bookTitle} - 书籍详情"
    // 英文： "{bookTitle} - Book Details"
    // 日文： "{bookTitle} - 書籍詳細"
END METHOD
```

#### summaryScreenTitle()
```
METHOD summaryScreenTitle(bookTitle) -> String:
    // 中文： "{bookTitle} - 摘要"
    // 英文： "{bookTitle} - Summary"
    // 日文： "{bookTitle} - 要約"
END METHOD
```

#### pdfReaderTitle()
```
METHOD pdfReaderTitle(bookTitle) -> String:
    // 中文： "{bookTitle} - PDF 阅读器"
    // 英文： "{bookTitle} - PDF Reader"
    // 日文： "{bookTitle} - PDF リーダー"
END METHOD
```

#### removeConfirmation()
```
METHOD removeConfirmation(bookTitle) -> String:
    // 中文： "您确定要移除《{bookTitle}》吗？"
    // 英文： "Are you sure you want to remove《{bookTitle}》?"
    // 日文： "《{bookTitle}》を削除してもよろしいですか？"
END METHOD
```

#### addedSuccessfully()
```
METHOD addedSuccessfully(bookTitle) -> String:
    // 中文： "已添加：{bookTitle}"
    // 英文： "Added: {bookTitle}"
    // 日文： "追加済み：{bookTitle}"
END METHOD
```

#### removedSuccessfully()
```
METHOD removedSuccessfully(bookTitle) -> String:
    // 中文： "已移除《{bookTitle}》"
    // 英文： "Removed《{bookTitle}》"
    // 日文： "《{bookTitle}》を削除しました"
END METHOD
```

---

## 类：_AppLocalizationsDelegate

**功能**：本地化代理实现，负责加载特定语言的资源

### 方法：load()

**功能**：加载指定语言的本地化资源

**伪代码**：
```
METHOD load(Locale locale) ASYNC -> AppLocalizations:
    // 1. 根据语言环境查找对应的实现
    localizations = CALL lookupAppLocalizations(locale)
    
    // 2. 包装为 SynchronousFuture 返回
    RETURN SynchronousFuture<AppLocalizations>(localizations)
END METHOD
```

---

### 方法：isSupported()

**功能**：检查语言环境是否支持

**伪代码**：
```
METHOD isSupported(Locale locale) -> Boolean:
    RETURN ['en', 'ja', 'zh'].contains(locale.languageCode)
END METHOD
```

---

### 方法：shouldReload()

**功能**：判断是否需要重新加载

**伪代码**：
```
METHOD shouldReload(_AppLocalizationsDelegate old) -> Boolean:
    RETURN false  // 不需要重新加载
END METHOD
```

---

## 函数：lookupAppLocalizations()

**功能**：根据语言环境查找对应的本地化实现

**伪代码**：
```
FUNCTION lookupAppLocalizations(Locale locale) -> AppLocalizations:
    // 1. 根据语言代码查找实现
    SWITCH locale.languageCode:
        CASE 'en':
            RETURN AppLocalizationsEn()  // 英文实现
        CASE 'ja':
            RETURN AppLocalizationsJa()  // 日文实现
        CASE 'zh':
            RETURN AppLocalizationsZh()  // 中文实现
        DEFAULT:
            // 2. 不支持的语言，抛出错误
            THROW FlutterError(
                'AppLocalizations.delegate failed to load unsupported locale'
            )
    END SWITCH
END FUNCTION
```

---

## 使用示例

```dart
// 在 Widget 中使用
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        // 简单字符串
        Text(localizations.appTitle),
        
        // 带参数的字符串
        Text(localizations.chapterTitle(1, '引言')),
        
        // 条件显示
        if (localizations.localeName == 'zh')
          Text('中文界面')
        else
          Text('其他语言'),
      ],
    );
  }
}

// 在 MaterialApp 中配置
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: Locale('zh', 'CN'),  // 设置当前语言
  home: HomeScreen()
)
```

---

## 扩展新语言

1. 创建新的 ARB 文件：`lib/l10n/app_{locale}.arb`
2. 翻译所有字符串键值
3. 运行 `flutter gen-l10n` 生成代码
4. 在 `lookupAppLocalizations` 中添加新语言分支
5. 在 `supportedLocales` 中添加新语言

---

## 翻译键命名规范

- 使用驼峰命名法 (camelCase)
- 名词短语用于标签和标题
- 动词短语用于操作按钮
- 描述性名称用于说明文本
- 参数化方法使用有意义的参数名
