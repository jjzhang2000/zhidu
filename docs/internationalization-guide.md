# 智读 - 国际化实现指南

## 概述

智读应用现在支持多语言界面，包括简体中文、英语和日语。本文档详细介绍国际化功能的实现方式、技术架构和使用方法。

## 技术架构

### 1. 国际化框架
- **基础框架**: Flutter官方国际化方案
- **依赖库**: flutter_localizations、intl
- **资源格式**: ARB (Application Resource Bundle)

### 2. 文件结构
```
lib/
└── l10n/                           # 国际化资源目录
    ├── app_zh.arb                 # 中文资源文件
    ├── app_en.arb                 # 英文资源文件  
    ├── app_ja.arb                 # 日文资源文件
    ├── app_localizations.dart     # 自动生成的本地化代码
    ├── app_localizations_zh.dart  # 中文本地化实现
    ├── app_localizations_en.dart  # 英文本地化实现
    └── app_localizations_ja.dart  # 日文本地化实现
```

### 3. 生成配置
在`pubspec.yaml`中配置：
```yaml
flutter_intl:
  enabled: true
  arb_dir: lib/l10n
  template_arb_file: app_zh.arb
  output_dir: lib/l10n
```

## 实现细节

### 1. 页面国际化改造

#### AI设置页面 (ai_config_screen.dart)
- 页面标题国际化
- 提供商选项名称国际化
- 按钮文本国际化（"测试连接"、"保存"等）
- 标签文本国际化（"AI提供商"、"API Key"、"模型"、"Base URL"等）

#### 主题设置页面 (theme_settings_screen.dart)
- 页面标题国际化
- 主题选项标题国际化（"跟随系统"、"亮色模式"、"暗色模式"）
- 主题选项说明文字国际化

#### 语言设置页面 (language_settings_screen.dart)
- 页面标题国际化
- AI语言和界面语言选项国际化
- 选项说明文字国际化
- 语言选择国际化

### 2. 代码实现模式

#### 导入国际化支持
```dart
import 'package:zhidu/l10n/app_localizations.dart';
```

#### 在build方法中获取localizations实例
```dart
@override
Widget build(BuildContext context) {
  final localizations = AppLocalizations.of(context)!;
  // 使用localizations访问翻译文本
}
```

#### 动态文本处理
```dart
// 对于需要参数化的文本
Text(localizations.addedSuccessfully(book.title))

// 对于可选文本（防止崩溃）
Text(localizations.chineseLanguage ?? '简体中文')
```

### 3. 国际化键值对

#### 常用键命名规范
- 页面标题: `{pageName}ScreenTitle` (如: `aiConfigScreenTitle`)
- 按钮文本: `{actionName}` (如: `save`, `testConnection`)
- 状态文本: `{actionName}{state}Text` (如: `testing`, `saving`)
- 选项标题: `{category}{option}Title` (如: `themeModeSystem`)
- 说明文字: `{category}{option}Subtitle` (如: `themeModeSystemSubtitle`)

## 使用指南

### 1. 添加新的国际化文本

1. 在所有语言的ARB文件中添加对应的键值对
2. 运行 `flutter gen-l10n` 生成新的国际化代码
3. 在代码中使用 `localizations.{keyName}` 访问文本

### 2. 支持新语言

1. 创建新的ARB文件 (如: `app_fr.arb` for French)
2. 添加对应的翻译键值对
3. 运行 `flutter gen-l10n`
4. 在语言设置页面添加新语言选项

### 3. 文本参数化

对于需要动态内容的文本，使用参数化消息：
```dart
// ARB文件中
"addedSuccessfully": "Added: {bookTitle}"

// 代码中使用
localizations.addedSuccessfully(book.title)
```

## 已支持的国际化内容

### AI设置相关
- 页面标题: AI配置
- 提供商名称: 智谱、通义千问、Ollama（本地）
- 按钮文本: 测试连接、保存、测试中...、保存中...
- 标签文本: AI提供商、API Key、模型、Base URL

### 主题设置相关
- 页面标题: 主题设置
- 选项标题: 跟随系统、亮色模式、暗色模式
- 说明文字: 自动跟随系统主题设置、始终使用浅色主题、始终使用深色主题

### 语言设置相关
- 页面标题: 语言设置
- AI语言选项: 跟随书籍、跟随系统、用户自选
- 界面语言选项: 跟随系统、用户自选
- 语言选项: 简体中文、English、日本語

### 通用文本
- 通用按钮: 取消、移除、确认移除等
- 通用提示: 未配置（点击设置）等
- 成功/错误消息: 已添加、已移除等

## 最佳实践

### 1. 文本长度适配
- 考虑不同语言文本长度差异
- 使用Flexible或Expanded组件处理长文本
- 测试各种语言环境下的UI布局

### 2. 上下文清晰
- 为相似含义的文本使用不同的键
- 添加适当的注释说明文本用途
- 保持键名语义清晰

### 3. 错误处理
- 为避免运行时错误，使用空值合并运算符
- 在非build方法中安全地获取localizations实例

## 维护建议

1. 每次添加新界面元素时考虑国际化需求
2. 定期检查硬编码文本并替换为国际化文本
3. 邀请母语使用者验证翻译准确性
4. 关注不同语言环境下的UI表现