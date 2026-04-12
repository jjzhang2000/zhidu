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
  <a href="#项目结构">项目结构</a>
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
- 📚 支持EPUB格式书籍导入（PDF支持待开发）
- 🎯 采用"精准打击"策略，避免全量解析
- 📑 智能识别章节结构和目录

### AI分层阅读引擎
- 🧠 **全书概览**：
  - 有前言/序言：直接从前言生成全书摘要
  - 无前言/序言：等待所有章节摘要完成后生成全书摘要
- 📝 **章节精炼**：逐章生成AI摘要，提取核心观点
- 📄 **Markdown输出**：所有摘要以Markdown格式显示和导出

### 用户交互
- 🚀 **逃逸机制**：随时跳过AI分析，直接阅读原文
- ⚡ **智能预加载**：后台静默预加载下一章内容
- 🎨 **主题切换**：支持亮色/暗色主题
- 🔍 **章节导航**：仅在第一级目录间遍历，避免子章节干扰

---

## 🛠 技术栈

| 类别 | 技术/库 |
|------|---------|
| **前端框架** | Flutter (Dart) |
| **状态管理** | StatefulWidget + Service单例模式 |
| **EPUB处理** | epub_plus |
| **文件处理** | file_picker, path_provider, archive, xml, image |
| **AI服务** | 大语言模型API（智谱/通义千问） |
| **本地存储** | SQLite数据库（drift ORM） |
| **UI组件** | flutter_html（HTML渲染） |
| **数据解析** | markdown |

---

## 📦 安装说明

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Windows（主要开发）、Android、iOS、macOS、Linux
- Web限制：Web平台仅支持演示，无法导入本地EPUB文件（浏览器沙箱限制）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone <repository-url>
   cd zhidu
   ```

2. **配置AI服务**
   - 在项目根目录创建 `ai_config.json` 文件
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
- 选择EPUB格式的书籍文件
- 等待文件解析完成

### 2. 阅读书籍
- 在书架页面点击书籍封面
- 查看AI生成的全书概览（Markdown格式）
- 点击章节进入阅读模式

### 3. 查看AI摘要
- 在章节页面查看AI生成的章节摘要（Markdown格式）
- 点击"阅读原文"按钮跳转到原文
- 使用底部 `<` 和 `>` 按钮在第一级章节间导航

### 4. 导出摘要
- 全书摘要和章节摘要自动保存到SQLite数据库
- 支持导出为Markdown格式文件
- 文件保存在应用专用目录

---

## 📁 项目结构

```
zhidu/
├── lib/
│   ├── main.dart                 # 应用入口，初始化所有Service
│   ├── data/                     # 数据层
│   │   └── database/             # 数据库定义
│   │       ├── database.dart     # drift数据库配置和表定义
│   │       └── database.g.dart   # 生成的数据库代码
│   ├── models/                   # 数据模型
│   │   ├── book.dart            # 书籍模型
│   │   ├── book_summary.dart    # 书籍摘要（全书概览）
│   │   ├── chapter_summary.dart # 章节摘要
│   │   └── section_summary.dart # 小节摘要
│   ├── screens/                  # UI页面
│   │   ├── home_screen.dart     # 首页（书架/发现/我的）
│   │   ├── book_detail_screen.dart      # 书籍详情（全书概览）
│   │   ├── summary_screen.dart          # 章节摘要页
│   │   └── settings_screen.dart         # 设置
│   ├── services/                 # 业务服务层（单例模式）
│   │   ├── book_service.dart    # 书籍管理（导入、解析）
│   │   ├── epub_service.dart    # EPUB文件解析（核心）
│   │   ├── ai_service.dart      # AI服务（智谱/通义千问API）
│   │   ├── summary_service.dart # 摘要生成与管理
│   │   ├── export_service.dart  # Markdown导出
│   │   └── log_service.dart     # 日志服务
│   └── utils/
│       └── app_theme.dart       # 主题配置
├── assets/                      # 资源文件
│   ├── icons/                  # 应用图标
│   └── images/                 # 图片资源
├── pubspec.yaml                # 项目配置
├── analysis_options.yaml       # 代码分析配置
└── README.md                  # 项目说明
```

---

## 🗺 开发计划

### 第一阶段：MVP版本（已完成）
- [x] 项目框架搭建
- [x] EPUB导入与解析
- [x] AI分层摘要生成（全书+章节）
- [x] 原文阅读器实现
- [x] SQLite数据库存储

### 第二阶段：功能优化
- [ ] PDF格式支持
- [ ] 复习卡片功能
- [ ] 云同步备份
- [ ] 用户自定义提示词

### 第三阶段：体验增强
- [ ] 性能优化
- [ ] 多语言支持
- [ ] 用户测试与反馈优化

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

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- [Flutter](https://flutter.dev/) - 跨平台UI框架
- [epub_plus](https://pub.dev/packages/epub_plus) - EPUB解析库
- [drift](https://pub.dev/packages/drift) - SQLite ORM
- [flutter_html](https://pub.dev/packages/flutter_html) - HTML渲染
- [智谱AI](https://zhipuai.cn/) - 大语言模型API
- [通义千问](https://qwen.ai/) - 大语言模型API

---

<p align="center">
  Made with ❤️ by 智读团队
</p>