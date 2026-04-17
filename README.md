# 智读 - AI分层阅读器

<p align="center">
  <img src="assets/icons/app_icon.png" alt="智读 Logo" width="120" height="120">
</p>

<p align="center">
  <strong>先读薄，再读厚，沉淀知识资产</strong>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#技术栈">技术栈</a> •
  <a href="#安装说明">安装说明</a> •
  <a href="#使用指南">使用指南</a> •
  <a href="#项目结构">项目结构</a> •
  <a href="#配置说明">配置说明</a>
</p>

---

## 📖 项目介绍

智读是一款基于Flutter开发的跨平台AI智能阅读器，主打"分层阅读"和"知识蒸馏"功能。通过AI分层解析，帮助用户实现"先读薄，再读厚"的阅读体验，最终将书籍精华沉淀为可复习的个人知识资产。

### 核心理念

- **先读薄**：通过AI生成全书概览和章节摘要，快速掌握核心观点
- **再读厚**：随时跳转到原文深入阅读，理解详细内容
- **知识沉淀**：将阅读精华保存为Markdown格式导出

---

## ✨ 功能特性

### 智能导入与解析
- 📚 支持 EPUB 和 PDF 格式书籍导入
- 🎯 采用"精准打击"策略，避免全量解析
- 📑 智能识别章节结构和目录
- 🖼️ 自动提取封面图片

### AI分层阅读引擎
- 🧠 **全书概览**：
  - 有前言/序言：直接从前言生成全书摘要
  - 无前言/序言：等待所有章节摘要完成后生成全书摘要
- 📝 **章节精炼**：逐章生成AI摘要，提取核心观点
- 📄 **Markdown输出**：所有摘要以Markdown格式显示和导出

### 用户交互
- 🚀 **逃逸机制**：随时跳过AI分析，直接阅读原文
- ⚡ **智能预加载**：后台静默预加载下一章内容
- 🎨 **主题切换**：支持亮色/暗色/跟随系统主题
- 🔍 **章节导航**：仅在第一级目录间遍历，避免子章节干扰
- 📖 **PDF阅读器**：支持PDF分页阅读，智能跳过封面页

### 高级设置管理
- ⚙️ **统一设置中心**：AI、主题、存储、语言设置集中管理
- 🌐 **AI语言控制**：支持多语言AI输出设置
- 💾 **存储路径自定义**：可指定数据存储位置
- 🔄 **设置导入导出**：支持设置备份与恢复

---

## 🛠 技术栈

| 类别 | 技术/库 |
|------|---------|
| **前端框架** | Flutter (Dart) |
| **状态管理** | StatefulWidget + Service单例模式 + ValueNotifier响应式更新 |
| **EPUB处理** | epub_plus, archive, xml |
| **PDF处理** | pdf (pdfium), sync_pdf_renderer |
| **文件处理** | file_picker, path_provider, path |
| **AI服务** | 大语言模型API（智谱/通义千问） |
| **本地存储** | 文件存储（JSON + Markdown） |
| **UI组件** | flutter_html（HTML渲染） |
| **数据解析** | markdown |
| **设置管理** | ValueNotifier（响应式设置更新） |

---

## 📦 安装说明

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Windows（主要开发）、Android、iOS、macOS、Linux
- Web限制：Web平台仅支持演示，无法导入本地文件（浏览器沙箱限制）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone <repository-url>
   cd zhidu
   ```

2. **配置AI服务**
   - 在设置页面配置AI服务（推荐方式）
   - 或在项目根目录创建 `ai_config.json` 文件（旧版兼容）
   - 参考 `AGENTS.md` 中的配置格式

3. **安装依赖**
   ```bash
   flutter pub get
   ```

4. **运行应用**
   ```bash
   # 开发模式
   flutter run

   # 生产模式
   flutter run --release
   ```

### 构建发布版本

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web（功能受限）
flutter build web --release
```

---

## 🚀 使用指南

### 1. 添加书籍
- 点击首页右下角的"+"按钮
- 选择 EPUB 或 PDF 格式的书籍文件
- 等待文件解析完成

### 2. 阅读书籍
- 在书架页面点击书籍封面
- 查看AI生成的全书概览（Markdown格式）
- 点击章节进入阅读模式

### 3. 查看AI摘要
- 在章节页面查看AI生成的章节摘要（Markdown格式）
- 点击"阅读原文"按钮跳转到原文
- 使用底部 `<` 和 `>` 按钮在第一级章节间导航

### 4. 配置应用设置
- 点击底部导航栏的"设置"按钮
- 配置AI服务（提供商、API Key、模型等）
- 设置主题偏好（亮色/暗色/跟随系统）
- 配置语言设置（AI输出语言等）
- 管理存储路径

### 5. 导出摘要
- 全书摘要和章节摘要自动保存为Markdown文件
- 支持导出为Markdown格式文件
- 文件保存在指定存储目录

---

## ⚙️ 配置说明

### AI服务配置
- **提供商**：支持智谱AI（zhipu）和通义千问（qwen）
- **API Key**：从对应服务商获取的有效API密钥
- **模型**：支持多种大语言模型（如glm-4-flash, qwen-plus等）
- **Base URL**：API服务地址

### 主题设置
- **亮色主题**：白天使用，护眼舒适
- **暗色主题**：夜间使用，减少眼部疲劳
- **跟随系统**：自动根据系统设置切换主题

### 语言设置
- **AI输出语言**：控制AI生成内容的语言
- **语言模式**：自动检测或手动指定AI输出语言

### 存储设置
- **自定义路径**：可指定应用数据存储位置
- **数据管理**：书籍、摘要等数据的存储位置

---

## 📁 项目结构

```
zhidu/
├── lib/
│   ├── main.dart                 # 应用入口，初始化所有Service
│   ├── models/                   # 数据模型
│   │   ├── app_settings.dart    # 应用设置模型（AI、主题、语言、存储）
│   │   ├── book.dart            # 书籍模型
│   │   ├── book_metadata.dart   # 书籍元数据
│   │   ├── chapter.dart         # 章节模型
│   │   ├── chapter_content.dart # 章节内容
│   │   ├── chapter_location.dart # 章节位置
│   │   └── chapter_summary.dart # 章节摘要
│   ├── screens/                  # UI页面
│   │   ├── home_screen.dart     # 首页（书架/发现/我的）
│   │   ├── book_detail_screen.dart # 书籍详情（全书概览）
│   │   ├── summary_screen.dart  # 章节摘要页
│   │   ├── pdf_reader_screen.dart # PDF阅读器
│   │   ├── ai_config_screen.dart # AI配置页面
│   │   ├── settings_screen.dart # 设置主页面
│   │   ├── theme_settings_screen.dart # 主题设置页面
│   │   ├── language_settings_screen.dart # 语言设置页面
│   │   └── storage_settings_screen.dart # 存储设置页面
│   ├── services/                 # 业务服务层（单例模式）
│   │   ├── book_service.dart    # 书籍管理（导入、解析）
│   │   ├── epub_service.dart    # EPUB文件解析
│   │   ├── pdf_service.dart     # PDF文件解析
│   │   ├── ai_service.dart      # AI服务（智谱/通义千问API）
│   │   ├── ai_prompts.dart      # AI提示词模板
│   │   ├── summary_service.dart # 摘要生成与管理
│   │   ├── export_service.dart  # Markdown导出
│   │   ├── storage_config.dart  # 存储路径配置
│   │   ├── file_storage_service.dart # 文件存储服务
│   │   ├── settings_service.dart # 设置管理服务（AI、主题、语言、存储）
│   │   └── log_service.dart     # 日志服务
│   │   └── parsers/             # 格式解析器
│   │       ├── book_format_parser.dart # 解析器接口
│   │       ├── epub_parser.dart # EPUB解析器
│   │       ├── pdf_parser.dart  # PDF解析器
│   │       └── format_registry.dart # 格式注册表
│   └── utils/
│       └── app_theme.dart       # 主题配置
├── docs/                        # 项目文档
│   ├── code-review/             # 代码审查报告
│   └── superpowers/             # 开发辅助文档
├── assets/                      # 资源文件
│   ├── icons/                  # 应用图标
│   └── images/                 # 图片资源
├── pubspec.yaml                # 项目配置
├── analysis_options.yaml       # 代码分析配置
├── AGENTS.md                   # 开发指南（供AI助手参考）
├── README.md                   # 项目说明
├── Requirement.md              # 需求文档
├── Technical_Plan.md           # 技术方案
└── LOGGING.md                  # 日志系统说明
```

---

## 💾 存储架构

### 目录结构

```
Documents/zhidu/
├── settings.json               # 应用设置文件（AI、主题、语言、存储设置）
├── books_index.json           # 书籍索引文件
└── books/
    └── {bookId}/              # 每本书独立目录
        ├── metadata.json      # 书籍元数据
        ├── summary.md         # 书籍摘要
        ├── chapter-001.md     # 章节摘要（按章节编号）
        ├── chapter-002.md
        └── cover.jpg/png      # 封面图片
```

### 存储路径

- **Windows**: `C:\Users\{username}\Documents\zhidu\`
- **macOS**: `/Users/{username}/Documents/zhidu/`
- **Android**: `/storage/emulated/0/Documents/zhidu/` 或应用私有目录
- **iOS**: `/var/mobile/Containers/Data/Application/{uuid}/Documents/zhidu/`

---

## 🗺 开发计划

### 第一阶段：MVP版本（已完成）
- [x] 项目框架搭建
- [x] EPUB导入与解析
- [x] AI分层摘要生成（全书+章节）
- [x] 原文阅读器实现
- [x] 文件存储实现（从SQLite迁移）

### 第二阶段：功能优化（已完成）
- [x] PDF格式支持
- [x] 存储架构优化（文件存储替代SQLite）
- [x] 代码审查和清理
- [x] 格式解析器架构（注册表模式）
- [x] 设置管理重构（AI、主题、语言、存储设置统一管理）

### 第三阶段：体验增强（待开发）
- [ ] 复习卡片功能
- [ ] 云同步备份
- [ ] 用户自定义提示词
- [ ] 性能优化
- [ ] 多语言界面支持

---

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

---

## 📄 许可证

本项目采用 **GNU Affero General Public License v3 (AGPLv3)** 开源协议。

### 开源使用
- ✅ 个人学习、研究、非商业项目：免费使用
- ✅ 修改和分发：必须保持开源并使用相同协议
- ✅ 网络服务：必须向用户提供源代码

### 商业许可
如果您需要在商业产品中使用本软件且不公开源代码，请联系获取商业授权：
- 商业使用权（无需公开源代码）
- 技术支持服务
- 定制开发服务

联系方式：[GitHub 项目页面](https://github.com/jjzhang2000/zhidu)

详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- [Flutter](https://flutter.dev/) - 跨平台UI框架
- [epub_plus](https://pub.dev/packages/epub_plus) - EPUB解析库
- [flutter_html](https://pub.dev/packages/flutter_html) - HTML渲染
- [智谱AI](https://zhipuai.cn/) - 大语言模型API
- [通义千问](https://qwen.ai/) - 大语言模型API
- [http](https://pub.dev/packages/http) - HTTP客户端
- [path_provider](https://pub.dev/packages/path_provider) - 路径管理

---

<p align="center">
  Made with ❤️ by 智读团队
</p>