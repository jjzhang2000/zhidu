# 文件存储架构设计文档

## 背景

将原有的SQLite数据库架构改为基于文件的存储方案，简化项目复杂度，提高数据可访问性和可维护性。

## 设计目标

1. **简化架构** - 移除SQLite依赖，消除数据库初始化和代码生成问题
2. **数据可访问** - 用户可以直接查看、编辑、备份摘要文件
3. **格式统一** - 所有摘要使用Markdown格式，与AI输出一致
4. **向后兼容** - 保持原有Service接口，UI层无需修改

## 目录结构

```
Documents/zhidu/                    # 应用数据根目录
├── books.json                      # 书籍索引（所有书籍的基本信息）
├── settings.json                   # 应用设置
└── books/
    ├── {uuid-1}/                   # 每本书一个目录（UUID命名）
    │   ├── metadata.json           # 书籍元数据
    │   ├── summary.md              # 全书摘要（AI生成的Markdown）
    │   ├── chapter-000.md          # 第0章摘要
    │   ├── chapter-001.md          # 第1章摘要
    │   └── ...                     # 更多章节摘要
    ├── {uuid-2}/
    │   └── ...
    └── ...
```

## 文件格式规范

### 1. books.json（书籍索引）

**路径**: `Documents/zhidu/books.json`

**用途**: 快速列出所有书籍，无需遍历目录

**格式**:
```json
{
  "version": "1.0",
  "lastUpdated": "2026-04-13T10:30:00Z",
  "books": [
    {
      "id": "uuid-1",
      "title": "书名",
      "author": "作者",
      "format": "epub",
      "originalFilePath": "C:/Users/.../book.epub",
      "addedAt": "2026-04-13T10:00:00Z"
    }
  ]
}
```

**字段说明**:
- `version`: 数据格式版本号
- `lastUpdated`: 最后更新时间
- `books`: 书籍列表（只包含基本信息）

### 2. metadata.json（书籍元数据）

**路径**: `Documents/zhidu/books/{uuid}/metadata.json`

**用途**: 存储单本书的详细信息

**格式**:
```json
{
  "id": "uuid-1",
  "title": "书名",
  "author": "作者",
  "format": "epub",
  "originalFilePath": "C:/Users/.../book.epub",
  "coverPath": "cover.png",
  "currentChapterIndex": 0,
  "totalChapters": 12,
  "addedAt": "2026-04-13T10:00:00Z",
  "lastReadAt": "2026-04-13T15:30:00Z"
}
```

**字段说明**:
- `id`: 书籍唯一标识（UUID）
- `format`: 文件格式（epub/pdf）
- `originalFilePath`: 原始书籍文件路径
- `coverPath`: 封面图片相对路径（相对于书籍目录）
- `currentChapterIndex`: 当前阅读章节索引
- `totalChapters`: 总章节数

### 3. summary.md（全书摘要）

**路径**: `Documents/zhidu/books/{uuid}/summary.md`

**用途**: AI生成的全书摘要

**格式**: Markdown格式，由AI服务直接生成

### 4. chapter-{index}.md（章节摘要）

**路径**: `Documents/zhidu/books/{uuid}/chapter-{index}.md`

**命名规则**: 
- 使用3位数字零填充：`chapter-000.md`, `chapter-001.md`, `chapter-012.md`
- 确保文件系统排序正确

**用途**: 存储单个章节的AI摘要

**格式**: Markdown格式，由AI服务直接生成

## Service架构变更

### 需要重构的Service

1. **BookService** - 书籍管理服务
   - 从数据库读取改为从metadata.json读取
   - books.json作为索引缓存

2. **SummaryService** - 摘要管理服务
   - 从数据库读取改为从.md文件读取
   - 写入时直接写入.md文件

3. **移除的组件**
   - `data/database/database.dart` - 数据库定义
   - `data/database/database.g.dart` - 生成的数据库代码
   - `package:drift` 依赖
   - `package:sqlite3_flutter_libs` 依赖

### 保留的接口

所有Service的公共API保持不变，确保UI层无需修改：

```dart
// BookService
Future<void> init();
List<Book> get books;
Future<Book?> importBook();
Book? getBookById(String id);
Future<bool> deleteBook(String id);
Future<void> updateBook(Book book);

// SummaryService
Future<void> init();
Future<ChapterSummary?> getSummary(String bookId, int chapterIndex);
Future<void> saveSummary(ChapterSummary summary);
Future<void> deleteSummary(String bookId, int chapterIndex);
Future<String?> getBookSummary(String bookId);
Future<void> saveBookSummary(String bookId, String summary);
```

## 实现步骤

### Phase 1: 创建文件存储基础设施
1. 创建 `FileStorageService` - 文件操作基础服务
2. 实现路径管理（获取应用数据目录）
3. 实现JSON文件读写工具
4. 实现Markdown文件读写工具

### Phase 2: 重构BookService
1. 移除数据库依赖
2. 实现从metadata.json加载书籍
3. 实现保存书籍到metadata.json
4. 维护books.json索引

### Phase 3: 重构SummaryService
1. 移除数据库依赖
2. 实现从.md文件读取章节摘要
3. 实现保存章节摘要到.md文件
4. 实现全书摘要的读写

### Phase 4: 清理和测试
1. 删除数据库相关代码
2. 更新pubspec.yaml移除依赖
3. 测试所有功能
4. 验证数据持久化

## 数据迁移

由于这是破坏性变更（从数据库改为文件），不提供自动迁移方案。
建议用户：
1. 导出已有数据（如需要）
2. 删除旧版本
3. 重新导入书籍

## 依赖变更

### 移除的依赖
```yaml
# 从pubspec.yaml中移除
drift: ^2.14.0
sqlite3_flutter_libs: ^0.5.20
path_provider: ^2.1.2  # 保留，文件存储也需要
```

### 保留的依赖
```yaml
path_provider: ^2.1.2  # 获取应用文档目录
path: ^1.8.3           # 路径操作
```

## 错误处理

1. **文件不存在**: 返回null或默认值，不抛出异常
2. **JSON解析错误**: 记录日志，返回null，尝试备份损坏文件
3. **写入失败**: 重试3次，失败后记录错误并抛出异常
4. **目录创建失败**: 检查权限，记录详细错误信息

## 性能考虑

1. **索引缓存**: books.json在内存中缓存，修改时更新
2. **懒加载**: 章节摘要在需要时读取，不缓存所有章节
3. **批量操作**: 导入书籍时批量更新索引

## 扩展性

1. **版本兼容**: books.json包含version字段，便于未来格式升级
2. **增量更新**: 支持只更新修改的字段，避免重写整个文件
