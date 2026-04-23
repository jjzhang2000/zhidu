# Calibre OPF 元数据集成文档

## 概述

此功能实现了对 Calibre 书籍库的轻量级支持，允许智读 (Zhidu) 在导入书籍时自动读取同目录下的 `metadata.opf` 文件，以获取更准确的书籍元数据信息。此功能遵循轻量级、单向、仅限必需、适当格式容错的设计原则。

## 设计原则

1. **轻量级**: 最小化代码改动，不引入复杂依赖
2. **单向**: 仅从 Calibre 库读取，不涉及写入
3. **必需优先**: 只处理核心元数据（标题、作者、封面、语言）
4. **容错**: OPF 读取失败不影响现有功能

## 实现架构

### 1. OPF 元数据模型

- **文件**: `lib/models/opf_metadata.dart`
- **功能**: 定义从 OPF 文件解析出的元数据结构

### 2. OPF 读取服务

- **文件**: `lib/services/opf_reader_service.dart`
- **功能**: 解析 OPF 文件并提取元数据信息
- **关键方法**:
  - `readFromOpfFile(String opfPath)`: 从指定路径读取 OPF 文件
  - `readFromSameDirectory(String bookFilePath)`: 从书籍文件同目录查找并读取 `metadata.opf`

### 3. BookService 集成

- **修改文件**: `lib/services/book_service.dart`
- **集成点**: `importBookFromPath()` 方法
- **逻辑**:
  1. 首先尝试读取同目录下的 `metadata.opf` 文件
  2. 如果存在，优先使用 OPF 中的元数据
  3. 如果不存在或解析失败，回退到原有解析逻辑

## OPF 文件解析

### 支持的元数据元素

- **标题**: `<dc:title>`
- **作者**: `<dc:creator>`
- **语言**: `<dc:language>`
- **出版社**: `<dc:publisher>`
- **描述**: `<dc:description>`
- **主题**: `<dc:subject>`
- **封面**: 通过 `<meta name="cover" content="cover-image"/>` 和 manifest 引用

### 封面处理

- 从 OPF 的 manifest 部分提取封面图片路径
- 将封面文件复制到智读的书籍存储目录
- 用于替换原有封面（如果存在）

## 使用场景

### 1. Calibre 书籍库导入

当用户从 Calibre 书籍库导入书籍时：

```
calibre_library/
├── Author Name/
│   └── Book Title (ID)/
│       ├── book.epub
│       ├── metadata.opf     ← 智读将自动读取此文件
│       └── cover.jpg
```

### 2. 优先级处理

1. **第一优先级**: OPF 文件中的元数据
2. **第二优先级**: 原有 EPUB/PDF 解析结果
3. **合并策略**: 优先使用 OPF 数据，其余字段使用原解析结果

## 错误处理

- **静默失败**: OPF 读取错误不会中断导入流程
- **日志记录**: 记录 OPF 读取过程，便于调试
- **回退机制**: OPF 不可用时完全回退到原逻辑
- **格式容错**: 支持不同版本的 OPF 格式

## 测试覆盖

- 单元测试：`test/opf_reader_service_test.dart`
- 集成测试：`test/opf_integration_test.dart`
- 验证了各种场景：有效 OPF、无效 OPF、缺失 OPF 等

## 向后兼容性

- 不破坏现有 EPUB/PDF 导入功能
- OPF 文件不存在时行为与之前完全一致
- 所有新增逻辑都在原有流程基础上扩展

## 性能影响

- 仅在导入时增加一次文件系统调用（检查 metadata.opf 是否存在）
- 仅当文件存在时才进行 XML 解析
- 对正常导入流程性能影响极小