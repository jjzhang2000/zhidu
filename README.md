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
- **知识沉淀**：将阅读精华保存为Markdown格式的复习卡片

---

## ✨ 功能特性

### 智能导入与解析
- 📚 支持PDF和EPUB格式书籍导入
- 🎯 采用"精准打击"策略，避免全量解析
- 📑 智能识别章节结构和目录

### AI分层阅读引擎
- 🧠 **全书概览**：自动分析前言、序言、后记，生成双轨制摘要
- 📝 **章节精炼**：逐章生成AI摘要，提取核心观点
- 🎭 **双轨制输出**：
  - 客观摘要：忠实原文，提取核心观点、逻辑脉络
  - AI观点：提供主观评价、价值评估、阅读建议

### 复习模式
- 🎴 **闪卡视图**：核心观点+关键论据的卡片式复习
- 👆 **交互操作**：左右滑动切换，点击翻转查看
- 📊 **进度追踪**：实时显示复习进度

### 用户交互
- 🚀 **逃逸机制**：随时跳过AI分析，直接阅读原文
- ⚡ **智能预加载**：后台静默预加载下一章内容
- 🎨 **主题切换**：支持亮色/暗色主题

---

## 🛠 技术栈

| 类别 | 技术/库 |
|------|---------|
| **前端框架** | Flutter (Dart) |
| **状态管理** | flutter_riverpod |
| **PDF处理** | pdfx |
| **EPUB处理** | epubx |
| **文件处理** | file_picker, path_provider, archive |
| **AI服务** | 大语言模型API |
| **本地存储** | shared_preferences |
| **UI组件** | flip_card, flutter_card_swiper |
| **数据解析** | yaml, markdown |

---

## 📦 安装说明

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK / Xcode（用于移动端构建）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone <repository-url>
   cd 智读
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行应用**
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

# Web
flutter build web --release
```

---

## 🚀 使用指南

### 1. 添加书籍
- 点击首页右下角的"+"按钮
- 选择PDF或EPUB格式的书籍文件
- 等待文件解析完成

### 2. 阅读书籍
- 在书架页面点击书籍封面
- 查看AI生成的全书概览
- 点击"开始阅读"进入阅读模式

### 3. 查看AI摘要
- 在阅读页面查看章节AI摘要
- 切换"客观摘要"和"AI观点"标签
- 点击"阅读原文"按钮跳转到原文

### 4. 复习模式
- 阅读完章节后，点击"复习模式"
- 使用闪卡复习核心观点和关键论据
- 左右滑动切换卡片，点击翻转查看

### 5. 导出复习资料
- 复习概要以Markdown格式自动保存
- 文件保存在应用目录的`/Summaries/`文件夹
- 支持通过系统云同步功能备份

---

## 📁 项目结构

```
zhidu/
├── android/                 # Android平台配置
├── ios/                     # iOS平台配置
├── lib/
│   ├── main.dart           # 应用入口
│   ├── models/             # 数据模型
│   │   ├── book.dart       # 书籍模型
│   │   ├── chapter_summary.dart  # 章节摘要
│   │   └── book_summary.dart     # 书籍摘要
│   ├── screens/            # 页面
│   │   └── home_screen.dart      # 首页（书架/发现/我的）
│   ├── services/           # 服务层
│   │   └── storage_service.dart  # 存储服务
│   ├── utils/              # 工具类
│   │   └── app_theme.dart        # 主题配置
│   └── widgets/            # 自定义组件
├── assets/                 # 资源文件
│   ├── images/            # 图片
│   ├── icons/             # 图标
│   └── fonts/             # 字体
├── pubspec.yaml           # 项目配置
├── analysis_options.yaml  # 代码分析配置
└── README.md             # 项目说明
```

---

## 🗺 开发计划

### 第一阶段：MVP版本（1-2个月）
- [x] 项目框架搭建
- [ ] PDF/EPUB导入与解析
- [ ] AI双轨制摘要生成
- [ ] 原文阅读器实现
- [ ] 闪卡复习模式基础UI

### 第二阶段：功能优化（1个月）
- [ ] 后台静默预加载
- [ ] 无前言时的兜底分析逻辑
- [ ] PDF章节识别准确率优化

### 第三阶段：体验增强（1个月）
- [ ] 闪卡导出功能
- [ ] 文件系统备份与恢复
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
- [epubx](https://pub.dev/packages/epubx) - EPUB解析库
- [pdfx](https://pub.dev/packages/pdfx) - PDF处理库
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) - 状态管理

---

<p align="center">
  Made with ❤️ by 智读团队
</p>