# Book Detail Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/book_detail_screen.dart`
**Purpose**: Display book details, AI-generated summary, and chapter list
**Pattern**: StatefulWidget with timer-based refresh and background pre-generation

---

## StatefulWidget Structure

```
BookDetailScreen (StatefulWidget)
├── Parameter: Book book
└── _BookDetailScreenState (State)
    ├── Services: BookService, AIService, SummaryService, LogService
    ├── State: Book _book, List<Chapter> _flatChapters
    ├── Flags: _isLoadingChapters, _showChapterStructure, _isPreGenerating
    └── Timer: _refreshTimer (3-second interval)
```

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_bookService` | BookService | Book management singleton |
| `_aiService` | AIService | AI configuration check |
| `_summaryService` | SummaryService | Summary generation |
| `_log` | LogService | Debug logging |
| `_book` | Book | Current book (may be refreshed) |
| `_flatChapters` | List<Chapter> | Flattened chapter list |
| `_isLoadingChapters` | bool | Chapter loading state |
| `_showChapterStructure` | bool | View mode toggle (false=summary, true=chapters) |
| `_isPreGenerating` | bool | Background generation flag |
| `_refreshTimer` | Timer? | Periodic refresh timer (3s) |

---

## Methods Pseudocode

### `initState()`

```
PROCEDURE initState():
  // Get latest book data (may have been updated elsewhere)
  _book = _bookService.getBookById(widget.book.id) OR widget.book
  
  // Load chapter structure
  _loadChapters()
  
  // Start background summary pre-generation
  _startPreGeneration()
  
  // Start periodic refresh timer (checks for summary completion)
  _refreshTimer = Timer.periodic(3 seconds, _refreshBookIfNeeded)
END PROCEDURE
```

### `dispose()`

```
PROCEDURE dispose():
  // Cancel timer to prevent memory leak
  _refreshTimer?.cancel()
  super.dispose()
END PROCEDURE
```

### `_loadChapters()`

```
ASYNC PROCEDURE _loadChapters():
  _log.v('BookDetailScreen', '_loadChapters 开始执行')
  setState(): _isLoadingChapters = true
  
  TRY:
    // Get parser based on book format
    parser = FormatRegistry.getParser('.' + _book.format.name)
    
    IF parser == null:
      _log.e('BookDetailScreen', '不支持的格式')
      setState(): _isLoadingChapters = false
      RETURN
    
    // Parse chapter structure
    chapters = AWAIT parser.getChapters(_book.filePath)
    
    setState():
      _flatChapters = chapters
      _isLoadingChapters = false
    
    _log.d('BookDetailScreen', '章节加载完成: ${chapters.length} 个章节')
  CATCH e, stackTrace:
    _log.e('BookDetailScreen', '加载章节列表失败', e, stackTrace)
    IF mounted:
      setState(): _isLoadingChapters = false
END PROCEDURE
```

### `_startPreGeneration()`

```
PROCEDURE _startPreGeneration():
  // Skip if AI not configured
  IF NOT _aiService.isConfigured:
    _log.d('BookDetailScreen', 'AI服务未配置，跳过预生成')
    RETURN
  
  // Prevent duplicate pre-generation tasks
  IF _isPreGenerating:
    _log.d('BookDetailScreen', '已在预生成中，跳过')
    RETURN
  
  _isPreGenerating = true
  
  // Execute asynchronously (non-blocking)
  Future():
    TRY:
      _log.d('BookDetailScreen', '开始后台预生成章节摘要')
      
      // Refresh first to avoid duplicate generation
      _refreshBookIfNeeded()
      
      // Generate summaries for all chapters
      AWAIT _summaryService.generateSummariesForBook(_book)
      _log.d('BookDetailScreen', '后台预生成章节摘要完成')
      
      // Refresh again after completion
      _refreshBookIfNeeded()
    CATCH e, stackTrace:
      _log.e('BookDetailScreen', '后台预生成章节摘要失败', e, stackTrace)
    FINALLY:
      _isPreGenerating = false
END PROCEDURE
```

### `_refreshBookIfNeeded()`

```
PROCEDURE _refreshBookIfNeeded():
  refreshedBook = _bookService.getBookById(_book.id)
  
  IF refreshedBook != null AND mounted:
    // Check if AI introduction changed
    IF refreshedBook.aiIntroduction != _book.aiIntroduction:
      // Summary changed, update UI
      setState():
        _book = refreshedBook
    ELSE:
      // No change, silent update
      _book = refreshedBook
END PROCEDURE
```

### `_getChapterTitle(index, chapter)`

```
PROCEDURE _getChapterTitle(index, chapter):
  // Priority 1: AI-extracted title from book.chapterTitles
  titles = _book.chapterTitles
  IF titles != null AND titles.containsKey(index):
    RETURN titles[index]
  
  // Priority 2: Original chapter title from EPUB/PDF
  RETURN chapter.title
END PROCEDURE
```

### `_toggleView()`

```
PROCEDURE _toggleView():
  setState():
    _showChapterStructure = NOT _showChapterStructure
END PROCEDURE
```

---

## Widget Tree Structure

```
Scaffold
├── AppBar
│   └── Title: "书籍详情"
│
└── Body: Column
    ├── Padding(16)
    │   └── _buildBookHeader()
    ├── Divider(height: 1)
    └── Expanded
        └── Padding(16)
            └── _buildAIIntroduction()
```

### Book Header Widget Tree

```
Row
├── _buildCover() (width: 84, height: 120)
├── SizedBox(width: 16)
└── Expanded: Column
    ├── Text: _book.title (titleLarge, bold, maxLines: 2)
    ├── SizedBox(height: 8)
    ├── Text: _book.author (bodyMedium, grey)
    ├── SizedBox(height: 12)
    └── Wrap
        ├── _buildInfoChip(Icons.menu_book, "${chapters.length} 章")
        └── _buildInfoChip(Icons.calendar_today, formattedDate)
```

### Cover Widget Tree

```
IF _book.coverPath exists AND file exists:
  ClipRRect(borderRadius: 8)
    └── Image.file(coverPath, fit: cover)
        └── errorBuilder: _buildDefaultCover()
ELSE:
  _buildDefaultCover()
    └── Container(blueGrey[100], borderRadius: 8)
        └── Icon(Icons.book, size: 40)
```

### Main Content Widget Tree (_buildAIIntroduction)

```
Row
├── Padding(top: 14, right: 8)
│   └── InkWell(onTap: _toggleView)
│       └── Container(primary.withAlpha(30), borderRadius: 20)
│           └── Icon: 
│               IF _showChapterStructure: auto_awesome (switch to summary)
│               ELSE: format_list_numbered (switch to chapters)
│
└── Expanded: Card
    └── Column
        ├── Padding(16): Row
        │   ├── Icon: current mode icon
        │   ├── SizedBox(width: 8)
        │   └── Text: "目录" OR "内容介绍"
        ├── Divider(height: 1)
        └── Expanded: Padding(16)
            ├── IF _showChapterStructure: _buildChapterStructureContent()
            └── ELSE: _buildAIIntroductionContent()
```

### AI Introduction Content Widget Tree

```
IF _book.aiIntroduction == null OR empty:
  Center: Column
    ├── Icon(Icons.article_outlined, size: 48, grey)
    ├── SizedBox(height: 12)
    └── Text: 
        IF _aiService.isConfigured: "全书摘要生成中，请稍候..."
        ELSE: "AI服务未配置，无法生成全书摘要"
ELSE:
  GestureDetector(onTap: navigate to first chapter)
    └── SingleChildScrollView
        └── Padding(8)
            └── Html(data: markdownToHtml(aiIntroduction))
                └── Styles: body, h2, h3, p, ul, li, strong
```

### Chapter Structure Content Widget Tree

```
IF _isLoadingChapters:
  Center: CircularProgressIndicator()
ELSE IF _flatChapters.isEmpty:
  Center: Text("暂无章节信息")
ELSE:
  ListView
    └── _buildChapterList()
        └── FOR each chapter:
            Padding(left: chapter.level * 16)
                └── ListTile
                    ├── dense: true
                    ├── title: Text(_getChapterTitle(...))
                    │   ├── fontSize: 13 - level
                    │   ├── color: grey IF level > 0
                    │   └── maxLines: 1, ellipsis
                    └── onTap: 
                        IF level == 0: navigate to SummaryScreen
                        ELSE: null (sub-chapters not clickable)
```

---

## User Interaction Flows

### Flow 1: Open Book Detail

```
User taps book card on home screen
    ↓
Navigator.push(BookDetailScreen(book: book))
    ↓
initState():
    ├── Get latest book data
    ├── Load chapters from file
    ├── Start background pre-generation
    └── Start refresh timer
    ↓
Display book header + summary/chapters
```

### Flow 2: View Chapter List

```
User taps toggle button (left side)
    ↓
_toggleView()
    ↓
setState(): _showChapterStructure = true
    ↓
Display chapter list with hierarchy
    ↓
User taps top-level chapter
    ↓
Navigator.push(SummaryScreen(chapter))
```

### Flow 3: Read from Summary

```
User views AI-generated summary
    ↓
User taps summary content area
    ↓
IF chapters exist:
    Navigator.push(SummaryScreen(firstChapter))
    ↓
Enter chapter reading mode
```

### Flow 4: Background Pre-generation

```
BookDetailScreen opens
    ↓
_startPreGeneration() called
    ↓
Check AI configured → YES
    ↓
Check not already generating → YES
    ↓
Set _isPreGenerating = true
    ↓
Async execution:
    ├── Refresh book state
    ├── Call SummaryService.generateSummariesForBook()
    ├── Generate all chapter summaries
    └── Refresh book state again
    ↓
Set _isPreGenerating = false
    ↓
Timer detects summary completion
    ↓
UI updates with new summary
```

### Flow 5: Periodic Refresh

```
Timer fires every 3 seconds
    ↓
_refreshBookIfNeeded()
    ↓
Get latest book from BookService
    ↓
Compare aiIntroduction with current
    ↓
IF changed:
    setState(): update _book
    ↓
UI shows new summary
```

---

## Navigation Flow

```
HomeScreen (BookCard)
    ↓ (tap book card)
BookDetailScreen
    ├── Shows book info + AI summary
    ├── Shows chapter list (toggle)
    ↓ (tap chapter OR summary)
SummaryScreen
    ├── Chapter summary display
    ├── Original text view
    └── Chapter navigation
```

---

## Data Loading Patterns

### Chapter Loading Pattern

```
_loadChapters():
    ↓
FormatRegistry.getParser(format)
    ↓
EpubParser OR PdfParser
    ↓
parser.getChapters(filePath)
    ↓
List<Chapter> with:
    - index: chapter position
    - title: chapter name
    - level: hierarchy depth (0=top, 1=sub...)
    - location: start/end positions
```

### Summary Pre-generation Pattern

```
_startPreGeneration():
    ↓
SummaryService.generateSummariesForBook(book)
    ↓
FOR each chapter:
    ├── Get chapter content
    ├── Call AIService for summary
    ├── Save summary to file
    └── Update book metadata
    ↓
All summaries ready for reading
```

---

## Conditional Rendering Logic

### View Mode Toggle

```
_showChapterStructure = false → Show AI Introduction
_showChapterStructure = true → Show Chapter List

Toggle button icon:
    IF showing chapters → auto_awesome (hint: click for summary)
    IF showing summary → format_list_numbered (hint: click for chapters)
```

### Chapter Clickability

```
chapter.level == 0 → Clickable, navigates to SummaryScreen
chapter.level > 0 → Not clickable (sub-chapters)

Reason: Only navigate between top-level chapters
Sub-chapters are part of parent chapter content
```

### Summary Display

```
IF aiIntroduction exists → Show Markdown-rendered summary
IF aiIntroduction null AND AI configured → Show "generating" message
IF aiIntroduction null AND AI not configured → Show "not configured" message
```

---

## Timer-based State Management

```
Timer (3-second interval)
    ↓
_refreshBookIfNeeded()
    ↓
Poll BookService for latest data
    ↓
Compare aiIntroduction
    ↓
IF changed → setState()
    ↓
UI reflects new summary

Purpose: Detect when background generation completes
Benefit: User sees summary appear without manual refresh
```

---

## Service Integration

### BookService

```
READ: _bookService.getBookById(id)
  - Returns latest Book object
  - Includes aiIntroduction, chapterTitles

READ: _bookService.books (list)
  - All books in library
```

### SummaryService

```
GENERATE: _summaryService.generateSummariesForBook(book)
  - Generates all chapter summaries
  - Updates book metadata
  - Async, non-blocking
```

### FormatRegistry

```
GET PARSER: FormatRegistry.getParser(extension)
  - Returns EpubParser or PdfParser
  - Based on file extension

USE PARSER:
  - parser.getChapters(filePath) → List<Chapter>
  - parser.getChapterContent(filePath, chapter) → ChapterContent
```