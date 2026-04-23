# Summary Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/summary_screen.dart`
**Purpose**: Core reading interface for chapter summaries and original text
**Pattern**: Complex StatefulWidget with dual view modes and PDF/EPUB handling

---

## StatefulWidget Structure

```
SummaryScreen (StatefulWidget)
├── Parameters:
│   ├── String bookId (required)
│   ├── int chapterIndex (required)
│   ├── String chapterTitle (required)
│   ├── String? chapterContent (optional)
│   ├── String? filePath (optional)
│   ├── List<Chapter>? chapters (optional)
│   └── Book? book (optional)
│
└── _SummaryScreenState (State)
    ├── Services: AIService, LogService, SummaryService, BookService
    ├── State Variables: summary, content, title, flags
    ├── PDF State: _pdfCurrentPage, _pdfTotalPages
    └── Navigation: _chapters (filtered top-level)
```

---

## Parameters

| Parameter | Type | Required | Purpose |
|-----------|------|----------|---------|
| `bookId` | String | Yes | Book unique identifier |
| `chapterIndex` | int | Yes | Chapter position in list |
| `chapterTitle` | String | Yes | Default chapter title |
| `chapterContent` | String? | No | Pre-loaded HTML content |
| `filePath` | String? | No | Book file path |
| `chapters` | List<Chapter>? | No | Chapter list for navigation |
| `book` | Book? | No | Book object with metadata |

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_aiService` | AIService | Check AI configuration |
| `_log` | LogService | Debug logging |
| `_summaryService` | SummaryService | Load/generate summaries |
| `_bookService` | BookService | Get updated book info |
| `_summary` | ChapterSummary? | Current chapter summary |
| `_isGenerating` | bool | Summary generation state |
| `_error` | String? | Error message |
| `_isLoadingContent` | bool | Content loading state |
| `_content` | String | Chapter HTML content |
| `_title` | String | Dynamic chapter title |
| `_showOriginalText` | bool | View mode toggle |
| `_contentTooShort` | bool | Content length flag |
| `_chapters` | List<Chapter> | Top-level chapters only |
| `_pdfCurrentPage` | int | PDF current page |
| `_pdfTotalPages` | int | PDF total pages |

---

## Methods Pseudocode

### `initState()`

```
PROCEDURE initState():
  // Filter chapters to top-level only (level == 0)
  IF widget.chapters != null:
    _chapters = widget.chapters.where(c => c.level == 0).toList()
  
  // Initialize content then load summary
  _initializeContent().then():
    _loadSummary()
END PROCEDURE
```

### `_initializeContent()`

```
ASYNC PROCEDURE _initializeContent():
  // Priority 1: Use pre-loaded content
  IF widget.chapterContent != null AND not empty:
    _content = widget.chapterContent
    _title = widget.chapterTitle
    _checkContentLength()
    setState(): _isLoadingContent = false
    RETURN
  
  // Priority 2: Load from file
  IF widget.filePath != null:
    setState(): _isLoadingContent = true
    AWAIT _loadChapterContent()
    RETURN
  
  // No content available
  setState():
    _error = '未提供章节内容或文件路径'
    _isLoadingContent = false
END PROCEDURE
```

### `_checkContentLength()`

```
PROCEDURE _checkContentLength():
  textContent = _extractTextContent(_content)
  byteLength = utf8.encode(textContent).length
  
  _contentTooShort = byteLength < 2000
  
  // Auto-switch to original view if content too short and no summary
  IF _contentTooShort AND _summary == null:
    _showOriginalText = true
END PROCEDURE
```

### `_loadChapterContent()`

```
ASYNC PROCEDURE _loadChapterContent():
  TRY:
    chapters = widget.chapters OR []
    
    // Parse chapters if not provided
    IF chapters.isEmpty AND widget.filePath != null:
      extension = _getFileExtension(widget.filePath)
      parser = FormatRegistry.getParser(extension)
      
      IF parser != null:
        chapters = AWAIT parser.getChapters(widget.filePath)
    
    // Filter to top-level
    topLevelChapters = chapters.where(c => c.level == 0).toList()
    _chapters = topLevelChapters
    
    // Validate index
    IF chapterIndex out of range:
      setState():
        _error = '章节索引超出范围'
        _isLoadingContent = false
      RETURN
    
    chapter = topLevelChapters[widget.chapterIndex]
    _title = chapter.title
    
    // Get chapter content via parser
    IF widget.filePath != null:
      extension = _getFileExtension(widget.filePath)
      parser = FormatRegistry.getParser(extension)
      
      IF parser != null:
        chapterContent = AWAIT parser.getChapterContent(filePath, chapter)
        content = chapterContent.htmlContent
    
    IF content == null OR empty:
      setState():
        _error = '章节内容为空'
        _isLoadingContent = false
      RETURN
    
    setState():
      _content = content
      _isLoadingContent = false
    
    _checkContentLength()
  CATCH e:
    setState():
      _error = '加载章节内容失败: $e'
      _isLoadingContent = false
END PROCEDURE
```

### `_loadSummary()`

```
ASYNC PROCEDURE _loadSummary():
  // Check if generation in progress
  generatingFuture = _summaryService.getGeneratingFuture(bookId, chapterIndex)
  
  IF generatingFuture != null:
    // Wait for background generation
    setState(): _isGenerating = true
    
    TRY:
      AWAIT generatingFuture
      
      // Load completed summary
      summary = AWAIT _summaryService.getSummary(bookId, chapterIndex)
      setState():
        _summary = summary
        _isGenerating = false
    CATCH e:
      setState():
        _error = '生成摘要失败: $e'
        _isGenerating = false
    RETURN
  
  // Load existing summary
  summary = AWAIT _summaryService.getSummary(bookId, chapterIndex)
  setState(): _summary = summary
END PROCEDURE
```

### `_generateSummary()`

```
ASYNC PROCEDURE _generateSummary():
  IF _content.isEmpty:
    setState(): _error = '无法生成摘要：章节内容为空'
    RETURN
  
  setState():
    _isGenerating = true
    _error = null
  
  TRY:
    // Extract plain text for AI
    plainText = _extractTextContent(_content)
    
    // Generate summary
    success = AWAIT _summaryService.generateSingleSummary(
      bookId, chapterIndex, _title, plainText
    )
    
    IF NOT mounted: RETURN
    
    IF success:
      // Load new summary
      summary = AWAIT _summaryService.getSummary(bookId, chapterIndex)
      
      // Check for updated chapter title
      updatedBook = _bookService.getBookById(bookId)
      
      IF updatedBook != null:
        newTitle = updatedBook.chapterTitles?[chapterIndex]
        setState():
          _summary = summary
          _title = newTitle OR _title
          _isGenerating = false
      ELSE:
        setState():
          _summary = summary
          _isGenerating = false
    ELSE:
      setState():
        _error = '生成摘要失败'
        _isGenerating = false
  CATCH e:
    setState():
      _error = '生成摘要失败: $e'
      _isGenerating = false
END PROCEDURE
```

### `_extractTextContent(html)`

```
PROCEDURE _extractTextContent(html):
  // Remove HTML tags
  text = html.replaceAll(RegExp(r'<[^>]+>'), '')
  
  // Decode HTML entities
  text = text
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .trim()
  
  RETURN text
END PROCEDURE
```

### `_getFileExtension(filePath)`

```
PROCEDURE _getFileExtension(filePath):
  lastDot = filePath.lastIndexOf('.')
  
  IF lastDot == -1:
    RETURN ''
  
  RETURN filePath.substring(lastDot).toLowerCase()
END PROCEDURE
```

### `_getChapterTitle(index, defaultTitle)`

```
PROCEDURE _getChapterTitle(index, defaultTitle):
  // Priority: AI-updated title from book.chapterTitles
  IF widget.book != null:
    titles = widget.book!.chapterTitles
    IF titles != null AND titles.containsKey(index):
      RETURN titles[index]
  
  RETURN defaultTitle
END PROCEDURE
```

### `_navigateToChapter(index)`

```
PROCEDURE _navigateToChapter(index):
  IF index < 0 OR index >= _chapters.length:
    RETURN
  
  chapter = _chapters[index]
  
  Navigator.pushReplacement(
    SummaryScreen(
      bookId: widget.bookId,
      chapterIndex: index,
      chapterTitle: chapter.title,
      filePath: widget.filePath,
      chapters: _chapters,
      book: widget.book
    )
  )
END PROCEDURE
```

---

## Widget Tree Structure

```
Scaffold
├── AppBar
│   ├── Title: Text(_getChapterTitle(...))
│   ├── centerTitle: true
│   ├── elevation: 0
│   └── actions: [
│       IF _summary == null AND NOT _isGenerating AND _content.isNotEmpty:
│         TextButton.icon
│         ├── icon: Icon(Icons.auto_awesome)
│         ├── label: Text("生成摘要")
│         └── onPressed: _generateSummary
│     ]
│
└── Body: Stack
    ├── _buildBody()
    └── IF _chapters.length > 1: _buildNavigationButtons()
```

### Body Widget Tree (_buildBody)

```
IF _isLoadingContent:
  _buildLoadingView()
    └── Center: Column
        ├── CircularProgressIndicator()
        ├── SizedBox(height: 16)
        └── Text("正在加载章节内容...")

ELSE IF _error != null AND _content.isEmpty:
  _buildErrorView()
    └── Center: Column
        ├── Icon(Icons.error_outline, size: 64)
        ├── Text("出错了")
        ├── Text(_error)
        └── ElevatedButton.icon("重试")

ELSE IF _isGenerating:
  _buildGeneratingView()
    └── Center: Column
        ├── CircularProgressIndicator()
        ├── Text("AI 正在生成摘要...")
        └── Text("这可能需要几秒钟")

ELSE:
  _buildSummaryView()
```

### Summary View Widget Tree

```
Padding(16)
└── Row
    ├── Left Toggle Button
    │   └── InkWell
    │       └── Container(primary.withAlpha(30), borderRadius: 20)
    │           └── Icon:
    │               IF _showOriginalText: auto_awesome (switch to summary)
    │               ELSE: menu_book (switch to original)
    │
    ├── SizedBox(width: 8)
    │
    └── Expanded Content
        ├── IF _showOriginalText OR _summary == null:
        │   _buildOriginalTextView()
        │
        └── ELSE:
            _buildSummaryContent()
```

### Summary Content Widget Tree

```
LayoutBuilder
└── SingleChildScrollView
    └── Card
        └── Padding(16)
            └── Column
                ├── Row: Icon(auto_awesome) + Text("本章摘要")
                ├── Divider(height: 24)
                └── Html(markdownToHtml(summary.objectiveSummary))
                    └── Styles: body, h2, h3, p, ul, li, strong
```

### Original Text View Widget Tree (EPUB)

```
LayoutBuilder
└── SingleChildScrollView
    └── Container(grey.withAlpha(30), borderRadius: 12)
        └── Padding(16)
            └── Html(data: _content)
                └── Styles: body, p, h1, h2, h3, code, pre
```

### Original Text View Widget Tree (PDF)

```
PdfDocumentViewBuilder.file(filePath)
└── builder(context, document)
    ├── IF document == null: CircularProgressIndicator()
    └── ELSE:
        _pdfTotalPages = document.pages.length
        ClipRRect(borderRadius: 8)
            └── Container(grey.withAlpha(30))
                └── PdfPageView
                    ├── document: document
                    └── pageNumber: _pdfCurrentPage.clamp(1, totalPages)
```

### Navigation Buttons Widget Tree

```
Positioned(left: 16, right: 16, bottom: 16)
└── Row
    ├── << Previous Chapter Button
    │   └── Container(black.withAlpha(76), circle)
    │       └── IconButton(Icons.keyboard_double_arrow_left)
    │           └── onPressed: _navigateToChapter(chapterIndex - 1)
    │
    ├── IF isPdfOriginalView: < Previous Page Button
    │   └── Container(black.withAlpha(76), circle)
    │       └── IconButton(Icons.chevron_left)
    │           └── onPressed: setState(_pdfCurrentPage--)
    │
    ├── IF NOT isPdfOriginalView: SizedBox(width: 48) (spacer)
    │
    ├── IF isPdfOriginalView: > Next Page Button
    │   └── Container(black.withAlpha(76), circle)
    │       └── IconButton(Icons.chevron_right)
    │           └── onPressed: setState(_pdfCurrentPage++)
    │
    ├── IF NOT isPdfOriginalView: SizedBox(width: 48) (spacer)
    │
    └── >> Next Chapter Button
        └── Container(black.withAlpha(76), circle)
            └── IconButton(Icons.keyboard_double_arrow_right)
                └── onPressed: _navigateToChapter(chapterIndex + 1)
```

---

## User Interaction Flows

### Flow 1: Open Chapter

```
User taps chapter in BookDetailScreen
    ↓
Navigator.push(SummaryScreen)
    ↓
initState():
    ├── Filter chapters to top-level
    └── _initializeContent()
    ↓
Load chapter content (EPUB/PDF)
    ↓
_checkContentLength()
    ↓
_loadSummary()
    ↓
IF summary exists: Show summary view
IF no summary: Show original text view
```

### Flow 2: Generate Summary

```
User views original text (no summary)
    ↓
AppBar shows "生成摘要" button
    ↓
User taps button
    ↓
_generateSummary()
    ↓
Set _isGenerating = true
    ↓
Extract plain text from HTML
    ↓
SummaryService.generateSingleSummary()
    ↓
AI generates summary
    ↓
Summary saved to file
    ↓
Load new summary
    ↓
Check for updated chapter title
    ↓
Set _isGenerating = false
    ↓
Display summary view
```

### Flow 3: Toggle View

```
User views summary
    ↓
Tap left toggle button (menu_book icon)
    ↓
setState(): _showOriginalText = true
    ↓
Display original text view
    ↓
User views original
    ↓
Tap left toggle button (auto_awesome icon)
    ↓
setState(): _showOriginalText = false
    ↓
Display summary view
```

### Flow 4: Navigate Chapters

```
User views chapter
    ↓
Tap << button (previous chapter)
    ↓
_navigateToChapter(chapterIndex - 1)
    ↓
Navigator.pushReplacement(new SummaryScreen)
    ↓
New chapter loads
    ↓
Display new chapter summary/original
```

### Flow 5: PDF Page Navigation

```
User views PDF original text
    ↓
isPdfOriginalView = true
    ↓
Page navigation buttons visible
    ↓
Tap < button (previous page)
    ↓
IF _pdfCurrentPage > startPage:
    setState(): _pdfCurrentPage--
    ↓
PdfPageView updates to new page
    ↓
Tap > button (next page)
    ↓
IF _pdfCurrentPage < endPage:
    setState(): _pdfCurrentPage++
    ↓
PdfPageView updates to new page
```

---

## Conditional Rendering Logic

### View Mode Toggle

```
_showOriginalText = false AND _summary != null:
    → Show summary content (Markdown rendered)

_showOriginalText = true OR _summary == null:
    → Show original text (HTML or PDF)

Toggle button disabled conditions:
    ├── _contentTooShort AND _showOriginalText (content too short)
    └── NOT _aiService.isConfigured AND _showOriginalText AND _summary == null
```

### Generate Button Visibility

```
Show "生成摘要" button when:
    ├── _summary == null (no existing summary)
    ├── NOT _isGenerating (not currently generating)
    └── _content.isNotEmpty (content available)

Hide button when:
    ├── Summary exists
    ├── Currently generating
    └── No content available
```

### PDF Page Navigation

```
Show page buttons (< and >) when:
    ├── book.format == BookFormat.pdf
    └── _showOriginalText = true (original view mode)

Page navigation limits:
    ├── startPage = chapter.location.startPage
    ├── endPage = chapter.location.endPage
    ├── canPrevPage = _pdfCurrentPage > startPage
    └── canNextPage = _pdfCurrentPage < endPage
```

### Chapter Navigation

```
Show navigation buttons when:
    _chapters.length > 1 (multiple chapters)

Button states:
    ├── isFirst = chapterIndex <= 0 → << disabled
    └── isLast = chapterIndex >= chapters.length - 1 → >> disabled
```

---

## State Management

### Content Loading State

```
_isLoadingContent = true → Show loading spinner
_isLoadingContent = false → Show content/error

Transitions:
    ├── Start: true (loading)
    ├── Content loaded: false
    └── Error: false (with _error set)
```

### Summary Generation State

```
_isGenerating = true → Show "AI正在生成摘要..."
_isGenerating = false → Show summary or original

Transitions:
    ├── Start generation: true
    ├── Generation success: false, _summary set
    └── Generation failure: false, _error set
```

### View Mode State

```
_showOriginalText = false → Summary view
_showOriginalText = true → Original text view

Auto-switch conditions:
    ├── _contentTooShort AND _summary == null → true
    └── User toggle → flip value
```

---

## PDF vs EPUB Handling

### EPUB Original Text

```
Content: HTML string
Rendering: flutter_html Html component
Navigation: Chapter-level only
Features: Styled text, images, links
```

### PDF Original Text

```
Content: PDF file
Rendering: pdfrx PdfPageView component
Navigation: Chapter-level + Page-level
Features: Fixed layout, zoom support
Page range: chapter.location.startPage to endPage
```

---

## Service Integration

### SummaryService

```
READ: getSummary(bookId, chapterIndex) → ChapterSummary?
  - Load existing summary from file

GENERATE: generateSingleSummary(bookId, chapterIndex, title, content)
  - Call AIService for summary generation
  - Save summary to file
  - Update book metadata
  - RETURN success bool

CHECK: getGeneratingFuture(bookId, chapterIndex) → Future?
  - Check if generation in progress
  - Used to wait for background generation
```

### BookService

```
READ: getBookById(bookId) → Book?
  - Get latest book data
  - Includes chapterTitles (AI-updated titles)
```

### FormatRegistry

```
GET PARSER: FormatRegistry.getParser(extension)
  - Returns EpubParser or PdfParser

USE PARSER:
  - getChapters(filePath) → List<Chapter>
  - getChapterContent(filePath, chapter) → ChapterContent
```

---

## Navigation Flow

```
BookDetailScreen
    ↓ (tap chapter or summary)
SummaryScreen
    ├── View summary
    ├── View original text
    ├── Generate summary
    ├── Navigate chapters (<< >>)
    └── PDF page navigation (< >)
    ↓ (back button)
Navigator.pop()
    ↓
Return to BookDetailScreen
```

---

## Background Generation Handling

```
SummaryService maintains generation futures:
    ↓
User opens chapter while generation in progress
    ↓
_loadSummary() checks getGeneratingFuture()
    ↓
IF future exists:
    ├── Set _isGenerating = true
    ├── AWAIT future
    └── Load completed summary
    ↓
User sees "AI正在生成摘要..." briefly
    ↓
Summary appears when complete
```

---

## Title Update Mechanism

```
AI generates summary
    ↓
May also generate better chapter title
    ↓
SummaryService updates book.chapterTitles
    ↓
BookService saves updated book
    ↓
_generateSummary() checks for new title
    ↓
updatedBook = _bookService.getBookById(bookId)
    ↓
newTitle = updatedBook.chapterTitles?[chapterIndex]
    ↓
setState(): _title = newTitle OR _title
    ↓
AppBar shows updated title
```