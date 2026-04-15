# 设置页面功能设计文档

## 概述

本设计文档描述了智读应用设置页面的四个核心功能的设计方案：AI配置、主题设置、备份恢复、语言设置。采用SettingsService分离方案，实现统一的配置管理和全局监听。

## 设计目标

- 提供完整的设置管理功能，让用户能够自定义应用行为
- 统一配置存储，便于维护和扩展
- 支持配置变更时全局响应（如主题切换立即生效）
- 保持架构清晰，易于后续维护

## 实现优先级

按以下顺序实现：
1. AI配置功能
2. 主题设置功能
3. 备份恢复功能
4. 语言设置功能

## 架构设计

### 新增文件结构

```
lib/
├── services/
│   ├── settings_service.dart        # 设置服务（单例）- 管理所有配置项
│   └── storage_path_service.dart    # 存储路径服务（单例）- 管理备份目录和书籍存放目录
├── screens/
│   ├── settings_screen.dart         # 设置页面（重构）- 主入口，列出所有设置分组
│   ├── ai_config_screen.dart        # AI配置页面 - 表单填写API Key、选择模型
│   ├── theme_settings_screen.dart   # 主题设置页面 - 三选项切换
│   ├── backup_settings_screen.dart  # 备份设置页面 - 设置备份目录、执行备份恢复、自动备份
│   ├── storage_settings_screen.dart # 存储路径设置页面 - 设置书籍存放目录
│   └── language_settings_screen.dart # 语言设置页面 - AI输出语言选择
└── models/
    └── app_settings.dart            # 应用设置数据模型
```

### 配置存储

- 配置文件路径：`Documents/zhidu/settings.json`
- 原配置文件：`ai_config.json`废弃，配置迁移到settings.json

### 配置文件结构

```json
{
  "ai": {
    "provider": "qwen",
    "apiKey": "sk-xxx",
    "model": "qwen-plus",
    "baseUrl": "https://dashscope.aliyuncs.com/compatible-mode/v1"
  },
  "theme": {
    "mode": "system"
  },
  "storage": {
    "booksDirectory": "Documents/zhidu/books",
    "backupDirectory": "Documents/zhidu/backups",
    "autoBackup": {
      "enabled": true,
      "interval": "daily"
    },
    "lastBackupTime": "2026-04-15T10:00:00"
  },
  "language": {
    "aiOutputLanguage": "auto_book",
    "manualLanguage": "zh"
  }
}
```

## 功能详细设计

### 1. AI配置功能

#### 目标

让用户在应用内直接配置AI服务，无需手动编辑配置文件。

#### 配置项

- 提供商：下拉菜单（智谱、通义千问）
- API Key：文本输入框（密码类型，可点击显示）
- 模型：下拉菜单（根据提供商动态切换可选模型）
- Base URL：文本输入框（默认值自动填充）

#### 页面功能

- **AiConfigScreen**：
  - 显示当前配置状态（已配置/未配置）
  - 提供表单填写各项配置
  - "测试连接"按钮：验证API Key和连接是否有效
  - "保存"按钮：保存配置并触发AIService重新初始化

#### AIService修改

- `init()`方法改为从SettingsService读取配置
- 新增`reloadConfig()`方法：重新加载配置并初始化
- SettingsService提供`aiConfigNotifier`，配置变更时通知AIService重新加载

#### 提供商模型映射

- 智谱（zhipu）：
  - 模型选项：glm-4-flash、glm-4、glm-4-plus
  - Base URL默认值：https://open.bigmodel.cn/api/paas/v4
  
- 通义千问（qwen）：
  - 模型选项：qwen-turbo、qwen-plus、qwen-max
  - Base URL默认值：https://dashscope.aliyuncs.com/compatible-mode/v1

### 2. 主题设置功能

#### 目标

让用户能够自定义应用的视觉主题，提升阅读体验。

#### 配置项

- 主题模式：三选项（跟随系统、亮色、暗色）

#### 页面功能

- **ThemeSettingsScreen**：
  - 显示当前主题状态
  - 提供三个单选按钮选项
  - 选中后立即生效

#### 实现机制

- SettingsService提供`themeModeNotifier`（ValueNotifier<ThemeMode>）
- ZhiduApp改为StatefulWidget，监听`themeModeNotifier`
- 使用`ValueListenableBuilder`动态更新MaterialApp的themeMode属性

#### AppTheme复用

- 现有的`AppTheme.lightTheme`和`AppTheme.darkTheme`无需修改
- 主题切换只是改变MaterialApp的themeMode属性

### 3. 备份恢复功能

#### 目标

重新设计备份恢复功能，支持完整的配置备份和自动备份。

#### StoragePathService职责

- 管理备份目录路径（用户可选）
- 管理书籍存放目录路径（用户可选）
- 默认路径：`Documents/zhidu/`
- 提供目录选择对话框（使用FilePicker）

#### 配置项

- 书籍存放目录：用户可自定义
- 备份目录：用户可自定义
- 自动备份开关：启用/禁用
- 自动备份频率：每天/每周
- 上次备份时间：记录以便判断是否需要备份

#### 页面功能

- **StorageSettingsScreen**：
  - 书籍存放目录设置
  - 显示当前路径
  - 点击打开目录选择对话框
  
- **BackupSettingsScreen**：
  - 备份目录设置
  - 显示当前路径和上次备份时间
  - 自动备份开关
  - 备份频率选择（每天、每周）
  - "备份数据"按钮：手动触发备份
  - "恢复数据"按钮：从备份文件恢复

#### 备份内容

- 所有书籍信息（books.json）
- 所有章节摘要（各书籍目录下的summary.md和chapter-*.md）
- 所有配置设置（settings.json）

#### 备份文件

- 手动备份：用户选择保存位置，文件名`zhidu_backup_<timestamp>.json`
- 自动备份：保存到备份目录，固定文件名`auto_backup.json`（只保留最新一份）

#### 自动备份实现

- **触发时机**：应用启动时在main.dart调用`SettingsService.checkAutoBackup()`
- **判断逻辑**：
  - daily：距离上次备份超过24小时则执行备份
  - weekly：距离上次备份超过7天则执行备份
- **执行流程**：
  1. 检查是否启用自动备份
  2. 检查上次备份时间是否超过间隔
  3. 需要备份则静默执行
  4. 备份完成后更新`lastBackupTime`

#### ExportService修改

- 备份内容增加settings.json
- 备份路径使用StoragePathService指定的目录
- 恢复时同时恢复配置并触发Service重新加载
- 新增`backupAllData()`方法：整合备份逻辑

### 4. 语言设置功能

#### 目标

控制AI摘要的输出语言，让用户能够选择摘要使用的语言。

#### 配置项

- AI输出语言模式：三选项
  - 书籍语言（自动判断）
  - 跟随系统
  - 手动选择
- 手动语言代码：仅在手动选择模式下使用

#### 页面功能

- **LanguageSettingsScreen**：
  - AI输出语言选项（三个单选按钮）
  - 语言下拉菜单（仅在手动选择时显示）
  - 支持语言：简体中文、English、日本語

#### AI Prompt修改

- **AiPrompts修改**：
  - 每个Prompt模板增加语言参数
  - 根据语言设置添加相应指令
  
- **语言指令示例**：
  - 书籍语言模式："根据书籍内容的语言，使用相同语言输出摘要"
  - 中文模式："请用中文输出摘要"
  - 英文模式："Please respond in English for the summary"
  - 日文模式："摘要は日本語で出力してください"

#### SettingsService实现

- 提供`aiOutputLanguageNotifier`
- AIService在生成摘要前获取语言设置
- 将语言指令注入Prompt模板

## 现有服务修改

### AIService

- 移除`ai_config.json`读取逻辑
- 新增`reloadConfig()`方法
- init()改为从SettingsService读取配置
- 生成摘要时从SettingsService获取语言设置并注入Prompt

### ExportService

- 备份内容增加settings.json
- 备份路径使用StoragePathService指定的目录
- 恢复时触发SettingsService和AIService重新加载

### BookService

- 书籍存放路径使用StoragePathService指定的目录
- init()时从StoragePathService获取路径

### ZhiduApp（main.dart）

- 改为StatefulWidget
- 监听`themeModeNotifier`动态切换主题
- 启动时调用`SettingsService.checkAutoBackup()`

## 数据流

### 配置加载流程

```
应用启动 → SettingsService.init() → 读取settings.json → 
通知各Service加载配置 → 
（如AIService.reloadConfig()、BookService更新路径等）
```

### 主题切换流程

```
用户选择主题 → SettingsService.updateThemeMode() → 
更新settings.json → 
触发themeModeNotifier → 
ZhiduApp监听到变更 → 
更新MaterialApp.themeMode → 
界面立即切换主题
```

### 自动备份流程

```
应用启动 → main.dart调用checkAutoBackup() → 
检查lastBackupTime → 
超过间隔则执行备份 → 
ExportService.backupAllData() → 
更新lastBackupTime
```

### AI生成摘要流程

```
用户请求生成摘要 → SummaryService调用AIService → 
AIService获取语言设置 → 
注入语言指令到Prompt → 
调用AI API → 
返回对应语言的摘要
```

## 错误处理

### 配置文件不存在

- SettingsService使用默认配置创建settings.json
- 提示用户需要配置AI服务

### AI配置无效

- AiConfigScreen显示"未配置"状态
- 生成摘要前检查配置有效性，无效则提示用户

### 备份失败

- 记录错误日志
- 提示用户备份失败原因
- 不影响应用正常运行

### 恢复失败

- 记录错误日志
- 提示用户恢复失败原因
- 原数据保持不变

### 存储路径无效

- 检查目录是否存在和可写入
- 无效路径则提示用户重新选择

## 测试要点

### AI配置测试

- 测试连接功能验证
- 配置保存和重新加载
- 无效API Key的处理

### 主题切换测试

- 三种主题模式切换
- 配置持久化
- 应用重启后主题保持

### 备份恢复测试

- 完整数据备份和恢复
- 自动备份触发条件
- 路径变更后的行为

### 语言设置测试

- 三种语言模式
- AI输出语言正确性
- 配置持久化

## 后续扩展

- 支持更多AI提供商（如Claude、GPT）
- 支持更多语言选项
- UI国际化（基于当前语言设置）
- 云端备份（Google Drive、iCloud）
- 配置导入导出（便于多设备同步）