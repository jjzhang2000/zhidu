# Book Detail Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/book_screen.dart`
**Purpose**: Display book details, AI-generated summary, and chapter list
**Pattern**: StatefulWidget with timer-based refresh, streaming callbacks, background pre-generation

---

## StatefulWidget Structure

```
BookScreen (StatefulWidget)
├── Parameter: Book book
└── _BookScreenState (State) with TickerProviderStateMixin
    ├── Services: BookService, AIService, SummaryService, LogService
    ├── State: Book _book, List<Chapter> _flatChapters
    ├── Flags: _isLoadingChapters, _isPreGenerating
    ├── Streaming: _streamingBookSummary, _bookSummaryFromFile
    ├── Controllers: _tabController
    └── Timer: _refreshTimer (3-second interval)
```

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_bookService` | BookService | Book management singleton |
| `_aiService` | AIService | AI configuration check |
| `_summaryService` | SummaryService | Summary generation and streaming callbacks |
| `_log` | LogService | Debug logging |
| `_book` | Book | Current book (may be refreshed) |
| `_flatChapters` | List\<Chapter\> | Flattened chapter list |
| `_isLoadingChapters` | bool | Chapter loading state |
| `_isPreGenerating` | bool | Background generation flag |
| `_tabController` | TabController? | Controller for vertical tab navigation |
| `_refreshTimer` | Timer? | Periodic refresh timer (3s) |
| `_streamingBookSummary` | String | Streaming book summary content (real-time) |
| `_bookSummaryFromFile` | String? | Book summary loaded from file |

---

## Methods Pseudocode

### `initState()`

```
PROCEDURE initState():
  // Get latest book data (may have been updated elsewhere)
  _book = _bookService.getBookById(widget.book.id) OR widget.book

  // Load chapter structure
  _loadChapters()

  // Load book summary from file
  _loadBookSummary()

  // Register streaming callback for real-time book summary updates
  _summaryService.registerBookStreamingCallback(_book.id, (content):
    IF mounted:
      setState(): _streamingBookSummary = content
  )

  // Initialize tab controller for vertical tab layout
  _tabController = TabController(length: 2, vsync: this)
  _tabController.addListener():
    IF mounted: setState()

  // Start periodic refresh timer (checks for summary completion)
  _refreshTimer = Timer.periodic(3 seconds, _refreshBookIfNeeded)

  // Start background pre-generation after first build completes
  WidgetsBinding.instance.addPostFrameCallback(_startPreGeneration)
END PROCEDURE
```

### `dispose()`

```
PROCEDURE dispose():
  // Release tab controller
  _tabController?.dispose()
  // Cancel timer to prevent memory leak
  _refreshTimer?.cancel()
  // Unregister streaming callback
  _summaryService.unregisterBookStreamingCallback(_book.id)
  super.dispose()
END PROCEDURE
```

### `_loadChapters()`

```
ASYNC PROCEDURE _loadChapters():
  _log.v('BookScreen', '_loadChapters 开始执行')
  setState(): _isLoadingChapters = true

  TRY:
    // Get parser based on book format
    parser = FormatRegistry.getParser('.' + _book.format.name)

    IF parser == null:
      _log.e('BookScreen', '不支持的格式')
      setState(): _isLoadingChapters = false
      RETURN

    // Parse chapter structure
    chapters = AWAIT parser.getChapters(_book.filePath)

    setState():
      _flatChapters = chapters
      _isLoadingChapters = false

    _log.d('BookScreen', '章节加载完成: ${chapters.length} 个章节')
  CATCH e, stackTrace:
    _log.e('BookScreen', '加载章节列表失败', e, stackTrace)
    IF mounted:
      setState(): _isLoadingChapters = false
END PROCEDURE
```

### `_loadBookSummary()`

```
ASYNC PROCEDURE _loadBookSummary():
  TRY:
    summary = AWAIT _summaryService.getBookSummary(_book.id)
    IF mounted:
      setState(): _bookSummaryFromFile = summary
  CATCH e, stackTrace:
    _log.e('BookScreen', '加载全书摘要失败', e, stackTrace)
END PROCEDURE
```

### `_startPreGeneration()`

```
PROCEDURE _startPreGeneration():
  // Skip if AI not configured
  IF NOT _aiService.isConfigured:
    _log.d('BookScreen', 'AI服务未配置，跳过预生成')
    RETURN

  // Prevent duplicate pre-generation tasks
  IF _isPreGenerating:
    _log.d('BookScreen', '已在预生成中，跳过')
    RETURN

  _isPreGenerating = true

  // Execute asynchronously (non-blocking)
  Future():
    TRY:
      _log.d('BookScreen', '开始后台预生成摘要')

      // Refresh first to avoid duplicate generation
      _refreshBookIfNeeded()

      // Generate book summary + all chapter summaries
      AWAIT _summaryService.generateSummariesForBook(_book)
      _log.d('BookScreen', '后台预生成摘要完成')

      // Refresh again after completion
      _refreshBookIfNeeded()
    CATCH e, stackTrace:
      _log.e('BookScreen', '后台预生成摘要失败', e, stackTrace)
    FINALLY:
      _isPreGenerating = false
END PROCEDURE
```

### `_refreshBookIfNeeded()`

```
ASYNC PROCEDURE _refreshBookIfNeeded():
  TRY:
    summary = AWAIT _summaryService.getBookSummary(_book.id)
    IF mounted:
      hasNewSummary = summary != null AND summary.isNotEmpty
      hadOldSummary = _bookSummaryFromFile != null AND _bookSummaryFromFile.isNotEmpty

      IF hasNewSummary != hadOldSummary OR summary != _bookSummaryFromFile:
        setState():
          _bookSummaryFromFile = summary
          // If summary has content, generation is complete; clear streaming state
          IF hasNewSummary:
            _streamingBookSummary = ''
  CATCH e:
    _log.w('BookScreen', '刷新书籍摘要失败: $e')
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

### `_htmlStyle` getter

```
PROPERTY _htmlStyle (Map<String, Style>):
  RETURN {
    'body': Style(fontSize: 14, lineHeight: 1.6, margin: 0, padding: 0),
    'h2': Style(fontSize: 16, fontWeight: bold, margin: bottom(8) top(16)),
    'h3': Style(fontSize: 15, fontWeight: bold, margin: bottom(6) top(12)),
    'p': Style(fontSize: 14, lineHeight: 1.6, margin: bottom(8)),
    'ul': Style(margin: bottom(8)),
    'li': Style(fontSize: 14, lineHeight: 1.5),
    'strong': Style(fontWeight: bold),
  }
```

### `_buildSummaryWithMarkdown(markdownContent, {onBeforeNavigate?})`

```
WIDGET _buildSummaryWithMarkdown(markdownContent, {onBeforeNavigate}):
  htmlContent = md.markdownToHtml(markdownContent)
  RETURN GestureDetector(
    onTap: IF _flatChapters.isNotEmpty:
      onBeforeNavigate?.call()
      Navigator.push(ChapterScreen(firstChapter))
    ELSE: null,

    child: SingleChildScrollView(
      child: Padding(all: 8,
        child: Html(data: htmlContent, style: _htmlStyle)
      )
    )
  )
END WIDGET
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
├── _buildCover() (width: 100, height: 150)
├── SizedBox(width: 16)
└── Expanded: Column
    ├── Text: _book.title (titleLarge, bold, maxLines: 2)
    ├── SizedBox(height: 8)
    ├── Text: _book.author (bodyMedium, grey)
    ├── SizedBox(height: 12)
    └── Wrap
        ├── _buildInfoChip(Icons.menu_book, chapter count / "加载中...")
        └── _buildInfoChip(Icons.calendar_today, formattedDate)
```

### Cover Widget Tree

```
IF _book.coverPath exists AND file exists:
  Card(clipBehavior: antiAlias)
    └── Image.file(coverPath, fit: cover)
        └── errorBuilder: _buildDefaultCover()
ELSE:
  _buildDefaultCover()
    └── Card → Container(blueGrey[100])
        └── Icon(Icons.book, size: 40)
```

### Main Content Widget Tree (_buildAIIntroduction)

```
Row
├── Column (Vertical Tab Bar)
│   ├── _buildVerticalTab(0, Icons.auto_awesome)
│   ├── Container(height: 1, width: 60, divider)
│   └── _buildVerticalTab(1, Icons.format_list_numbered)
└── Expanded: Container(selectedColor)
    └── TabBarView(controller: _tabController)
        ├── _buildAIIntroductionContent() (tab 0 - book summary)
        └── _buildChapterStructureContent() (tab 1 - chapters)

_buildVerticalTab(index, icon):
    InkWell(onTap: animateTo(index))
        Container(width: 60, padding: vertical(12))
        └── Icon(icon, size: 24)
```

### AI Introduction Content Widget Tree

```
IF _streamingBookSummary.isNotEmpty:
  _buildStreamingBookSummary()
    → _buildSummaryWithMarkdown(_streamingBookSummary)

ELSE IF _bookSummaryFromFile is null/empty:
  Center: Column
    ├── Icon(Icons.article_outlined, size: 48, grey)
    ├── SizedBox(height: 12)
    └── Text:
        IF _aiService.isConfigured: "全书摘要生成中，请稍候..."
        ELSE: "AI服务未配置，无法生成全书摘要"

ELSE:
  _buildSummaryWithMarkdown(_bookSummaryFromFile,
    onBeforeNavigate: _log.d(...))
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
                        IF level == 0: navigate to ChapterScreen
                        ELSE: null (sub-chapters not clickable)
```

---

## User Interaction Flows

### Flow 1: Open Book Detail

```
User taps book card on home screen
    ↓
Navigator.push(BookScreen(book: book))
    ↓
initState():
    ├── Get latest book data
    ├── Load chapters from file
    ├── Load book summary from file
    ├── Register streaming callback
    ├── Init tab controller
    ├── Start refresh timer
    └── addPostFrameCallback → start pre-generation
    ↓
Display book header + summary/chapters (streaming if in progress)
```

### Flow 2: View Chapter List

```
User taps chapter list tab (right side vertical tab)
    ↓
TabController switches to tab 1
    ↓
_buildChapterStructureContent() displayed
    ↓
User taps top-level chapter
    ↓
Navigator.push(ChapterScreen(chapter))
```

### Flow 3: Read from Summary

```
User views AI-generated summary
    ↓
User taps summary content area
    ↓
IF chapters exist:
    _log.d('BookScreen', '点击全书摘要，进入第一章: ...')
    Navigator.push(ChapterScreen(firstChapter))
    ↓
Enter chapter reading mode
```

### Flow 4: Background Pre-generation

```
BookScreen opens
    ↓
addPostFrameCallback → _startPreGeneration() called
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
    ├── Generate book summary + all chapter summaries
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
Get book summary from file
    ↓
Compare with _bookSummaryFromFile
    ↓
IF changed:
    setState(): update _bookSummaryFromFile, clear streaming state
    ↓
UI shows new summary
```

---

## Navigation Flow

```
HomeScreen (BookCard)
    ↓ (tap book card)
BookScreen
    ├── Shows book info + streaming/final summary
    ├── Shows chapter list (vertical tab)
    ↓ (tap top-level chapter OR summary)
ChapterScreen
    ├── Chapter summary display
    ├── Original text view
    └── Translation view
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
EPUB: _generateBookSummaryFromPreface() → book summary
      + generateSingleSummary() × N → chapter summaries
PDF:  generateSingleSummary() × N → chapter summaries
      + _generateBookSummaryFromChapters() → book summary
    ↓
Streaming callbacks → real-time UI updates
    ↓
All summaries saved to files, ready for reading
```

---

## Conditional Rendering Logic

### Summary Display (3 states)

```
State 1: Streaming (AI generating now)
  → _streamingBookSummary.isNotEmpty
  → _buildSummaryWithMarkdown(streaming content, no log)

State 2: No summary yet
  → _bookSummaryFromFile is null/empty
  → Placeholder message (generating / not configured)

State 3: Summary ready
  → _bookSummaryFromFile exists and not empty
  → _buildSummaryWithMarkdown(file content, with log callback)
```

### Chapter Clickability

```
chapter.level == 0 → Clickable, navigates to ChapterScreen
chapter.level > 0 → Not clickable (sub-chapters)

Reason: Only navigate between top-level chapters
Sub-chapters are part of parent chapter content
```

---

## Timer-based State Management

```
Timer (3-second interval)
    ↓
_refreshBookIfNeeded()
    ↓
Poll SummaryService.getBookSummary()
    ↓
Compare _bookSummaryFromFile
    ↓
IF changed → setState() and clear _streamingBookSummary
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
  - Includes chapterTitles, reading progress
```

### SummaryService

```
GENERATE: _summaryService.generateSummariesForBook(book)
  - Generates book summary + all chapter summaries
  - Streaming callbacks for real-time UI updates
  - Async, non-blocking

STREAM: _summaryService.registerBookStreamingCallback(bookId, callback)
  - Registers callback for real-time book summary content
  - Unregistered in dispose()

READ: _summaryService.getBookSummary(bookId)
  - Returns book summary from file (summary-zh.md)
  - Used by _loadBookSummary() and _refreshBookIfNeeded()
```

### FormatRegistry

```
GET PARSER: FormatRegistry.getParser(extension)
  - Returns EpubParser or PdfParser
  - Based on file extension

USE PARSER:
  - parser.getChapters(filePath) → List<Chapter>
```

---
