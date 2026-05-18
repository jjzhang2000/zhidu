# 章节阅读页面 - 伪代码文档

## Overview

**File**: `lib/screens/chapter_screen.dart`
**Purpose**: Core reading interface for chapter summaries, translations, and original text
**Pattern**: Complex StatefulWidget with vertical 3-tab layout and PDF/EPUB handling

---

## StatefulWidget Structure

```
ChapterScreen (StatefulWidget)
├── Parameters:
│   ├── String bookId (required)
│   ├── int chapterIndex (required)
│   ├── String chapterTitle (required)
│   ├── String? chapterContent (optional)
│   ├── String? filePath (optional)
│   ├── List<Chapter>? chapters (optional)
│   └── Book? book (optional)
│
└── _ChapterScreenState (State)
    ├── Services: AIService, LogService, SummaryService, BookService
    ├── State Variables: summary, content, title, flags
    ├── PDF State: _pdfCurrentPage, _pdfTotalPages
    ├── Translation State: _translationContent, _isTranslating, _streamingTranslation
    ├── Language State: _targetLang, _sourceLang, _summaryLang
    ├── Navigation: _chapters (filtered top-level)
    └── Controllers: _tabController (3 tabs), _translationScrollController, _originalScrollController
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
| `_summaryChapter` | Chapter? | Current chapter summary data |
| `_isGenerating` | bool | Summary generation in progress |
| `_error` | String? | Error message |
| `_isLoadingContent` | bool | Content loading state |
| `_content` | String | Chapter HTML content |
| `_title` | String | Dynamic chapter title |
| `_contentTooShort` | bool | Content < 2000 bytes flag |
| `_chapters` | List\<Chapter\> | Top-level chapters only |
| `_pdfCurrentPage` | int | PDF current page |
| `_pdfTotalPages` | int | PDF total pages |
| `_tabController` | TabController? | Vertical tab (3 tabs: summary/translation/original) |
| `_streamingSummary` | String | Real-time streaming summary content |
| `_translationContent` | String? | Cached translation HTML |
| `_isTranslating` | bool | Translation generation in progress |
| `_streamingTranslation` | String | Real-time streaming translation |
| `_targetLang` | String? | Target language for translation |
| `_sourceLang` | String? | Source language from book metadata |
| `_summaryLang` | String | Current summary language (default: zh) |
| `_translationTabDisabled` | bool | Disable translation tab when source==target lang |
| `_translationScrollController` | ScrollController? | Translation view scroll sync |
| `_originalScrollController` | ScrollController? | Original text view scroll sync |
| `_currentScrollAnchor` | ScrollAnchor | Shared scroll position for tab sync |
| `_hasLoadedSummary` | bool | Prevent duplicate summary loading |
| `_listeningChapterKey` | String? | Current chapter key for dedup |

---

## Extracted Public Properties

### `_htmlStyle` getter

```
GETTER _htmlStyle → Map<String, Style>:
  RETURN {
    'body':   Style(fontSize: 14, lineHeight: 1.6, margin: 0, padding: 0),
    'h2':     Style(fontSize: 15, fontWeight: bold, margin: bottom 8 top 16),
    'h3':     Style(fontSize: 14, fontWeight: bold, margin: bottom 6 top 12),
    'p':      Style(fontSize: 14, lineHeight: 1.6, margin: bottom 8),
    'ul':     Style(margin: bottom 8),
    'li':     Style(fontSize: 14, lineHeight: 1.5),
    'strong': Style(fontWeight: bold),
    'code':   Style(fontFamily: Consolas, fontSize: 13),
    'pre':    Style(fontFamily: Consolas, fontSize: 13, padding: 8, margin: bottom 12),
  }
```

Used by: `_buildStreamingSummaryView()`, `_buildNormalSummaryView()`, `_buildTranslationHtmlView()`

---

## Methods Pseudocode

### `initState()`

```
PROCEDURE initState():
  // Filter chapters to top-level only (level == 0)
  IF widget.chapters != null:
    _chapters = widget.chapters.where(c => c.level == 0).toList()

  // Initialize scroll controllers for tab sync
  _translationScrollController = ScrollController()
  _originalScrollController = ScrollController()

  // Initialize 3-tab vertical layout (0=summary, 1=translation, 2=original)
  _tabController = TabController(length: 3, vsync: this)
  _tabController.addListener():
    IF mounted:
      setState()
      IF NOT indexIsChanging:
        // Tab switch completed — sync scroll
        addPostFrameCallback: _syncScrollToTab(_tabController.index)

        IF _tabController.index == 2:
          // Switched to translation tab — load translation
          _loadTranslation()
      ELSE:
        // Tab switch in progress — capture current scroll position
        _captureScrollAnchor(_tabController.previousIndex)

  // Initialize language settings (source/target lang)
  _initializeLanguageSettings()

  // Load chapter content first, then summary on first frame
  _initializeContent().then():
    addPostFrameCallback: _loadSummary()
END PROCEDURE
```

### `dispose()`

```
PROCEDURE dispose():
  _translationScrollController?.dispose()
  _originalScrollController?.dispose()
  _tabController?.dispose()
  super.dispose()
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
    IF NOT mounted: RETURN
    setState(): _isLoadingContent = false
    RETURN

  // Priority 2: Load from file
  IF widget.filePath != null:
    IF NOT mounted: RETURN
    setState(): _isLoadingContent = true
    AWAIT _loadChapterContent()
    RETURN

  // No content available
  IF NOT mounted: RETURN
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
  IF _contentTooShort AND _summaryChapter == null:
    _tabController?.animateTo(1)  // Tab 1 = original text
END PROCEDURE
```

### `_initializeLanguageSettings()`

```
ASYNC PROCEDURE _initializeLanguageSettings():
  // Determine source language via AIService
  _sourceLang = _aiService.detectSourceLanguage(
    bookLanguage: widget.book?.language,
    content: _content
  )

  // Resolve target language via shared method
  _resolveTargetLang()

  // Sync summary language with target language
  _summaryLang = _targetLang ?? 'zh'

  // Disable translation tab when source == target
  _translationTabDisabled = _sourceLang == _targetLang
END PROCEDURE
```

### `_resolveTargetLang()` (extracted shared method)

```
PROCEDURE _resolveTargetLang():
  lang = SettingsService().settings.languageSettings

  SWITCH lang.aiLanguageMode:
    CASE 'system':
      _targetLang = _aiService.detectSystemLanguage()
    CASE 'manual':
      _targetLang = lang.aiOutputLanguage
    CASE 'book' / DEFAULT:
      _targetLang = _sourceLang
  END SWITCH

  _log.d: '目标语言: $_targetLang (模式: ${lang.aiLanguageMode})'
END PROCEDURE
```

Used by: `_initializeLanguageSettings()`

### `_detectSystemLanguage()`

已合并到 `AIService.detectSystemLanguage()`（public），ChapterScreen 通过 `_aiService.detectSystemLanguage()` 调用。

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
  chapterKey = '${widget.bookId}_${widget.chapterIndex}'

  // Prevent duplicate loading
  IF _hasLoadedSummary AND _listeningChapterKey == chapterKey:
    RETURN

  _hasLoadedSummary = true
  _listeningChapterKey = chapterKey

  summary = AWAIT _summaryService.getSummary(bookId, chapterIndex, language: _summaryLang)

  IF summary != null:
    // Have existing summary — display directly
    IF NOT mounted: RETURN
    setState(): _summaryChapter = summary
  ELSE:
    // No summary — auto-generate if conditions met
    IF _content.isNotEmpty AND _aiService.isConfigured:
      setState():
        _isGenerating = true
        _streamingSummary = ''
      _generateSummaryWithStreaming()
    ELSE:
      IF NOT mounted: RETURN
      setState(): _summaryChapter = summary
END PROCEDURE
```

### `_generateSummaryWithStreaming()`

```
ASYNC PROCEDURE _generateSummaryWithStreaming():
  IF _content.isEmpty:
    setState(): _error = '无法生成摘要：章节内容为空'
    RETURN

  setState():
    _isGenerating = true
    _error = null
    _streamingSummary = ''

  TRY:
    plainText = _extractTextContent(_content)

    success = AWAIT _summaryService.generateSingleSummary(
      bookId, chapterIndex, _title, plainText,
      language: _summaryLang,
      onContentUpdate: (content):
        IF mounted: setState(): _streamingSummary = content
    )

    IF NOT mounted: RETURN

    IF success:
      // Load final summary
      summary = AWAIT _summaryService.getSummary(bookId, chapterIndex, language: _summaryLang)
      updatedBook = _bookService.getBookById(bookId)

      IF updatedBook != null:
        newTitle = updatedBook.chapterTitles?[chapterIndex]
        setState():
          _summaryChapter = summary
          _title = newTitle ?? _title
          _streamingSummary = ''
          _isGenerating = false
      ELSE:
        setState():
          _summaryChapter = summary
          _streamingSummary = ''
          _isGenerating = false
    ELSE:
      setState():
        _error = '生成摘要失败'
        _streamingSummary = ''
        _isGenerating = false
  CATCH e:
    IF NOT mounted: RETURN
    setState():
      _error = '生成摘要失败: $e'
      _streamingSummary = ''
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
  IF lastDot == -1: RETURN ''
  RETURN filePath.substring(lastDot).toLowerCase()
END PROCEDURE
```

### `_getChapterTitle(index, defaultTitle)`

```
PROCEDURE _getChapterTitle(index, defaultTitle):
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
  IF index < 0 OR index >= _chapters.length: RETURN

  chapter = _chapters[index]
  Navigator.pushReplacement(
    ChapterScreen(
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

### `_captureScrollAnchor(tabIndex)`

```
PROCEDURE _captureScrollAnchor(tabIndex):
  controller = switch(tabIndex):
    1 → _originalScrollController
    2 → _translationScrollController
    default → return

  IF controller == null OR NOT hasClients: RETURN

  maxScroll = controller.position.maxScrollExtent
  IF maxScroll > 0:
    _currentScrollAnchor = ScrollAnchor(
      scrollRatio: controller.offset / maxScroll
    )
END PROCEDURE
```

### `_syncScrollToTab(tabIndex)`

```
PROCEDURE _syncScrollToTab(tabIndex):
  IF tabIndex == 0: RETURN

  controller = switch(tabIndex):
    1 → _originalScrollController
    2 → _translationScrollController
    default → return

  IF controller == null OR NOT hasClients: RETURN

  maxScroll = controller.position.maxScrollExtent
  targetOffset = _currentScrollAnchor.scrollRatio * maxScroll
  controller.jumpTo(targetOffset.clamp(0.0, maxScroll))
END PROCEDURE
```

### `_loadTranslation()`

```
ASYNC PROCEDURE _loadTranslation():
  IF _translationTabDisabled OR _targetLang == null OR _content.isEmpty: RETURN

  TRY:
    cached = AWAIT _summaryService.getTranslation(bookId, chapterIndex, _targetLang)

    IF cached != null AND not empty:
      // Have cached translation — restore code blocks and display
      IF mounted: setState():
        _translationContent = _restoreCodeBlocks(_cleanBackslashes(cached))
        _isTranslating = false
        _streamingTranslation = ''
    ELSEIF _aiService.isConfigured AND _content.isNotEmpty:
      // No cache — auto-generate translation
      IF mounted: setState():
        _translationContent = null
        _isTranslating = true
        _streamingTranslation = ''
      _generateTranslationWithStreaming()
    ELSE:
      IF mounted: setState():
        _translationContent = null
        _isTranslating = false
        _streamingTranslation = ''
  CATCH e:
    _log.e('加载译文失败', e)
END PROCEDURE
```

### `_generateTranslationWithStreaming()`

```
ASYNC PROCEDURE _generateTranslationWithStreaming():
  IF _content.isEmpty OR _targetLang == null: RETURN

  setState():
    _isTranslating = true
    _streamingTranslation = ''

  TRY:
    // Extract code blocks to placeholders for protection
    (contentWithPlaceholders, codeBlocks) = _extractCodeBlocksToPlaceholders(_content)

    bookFormat = widget.book?.format.name ?? 'epub'

    success = AWAIT _summaryService.generateTranslationStream(
      bookId, chapterIndex, contentWithPlaceholders,
      chapterTitle: _title,
      sourceLang: _sourceLang ?? 'zh',
      targetLang: _targetLang,
      bookFormat: bookFormat,
      onContentUpdate: (content):
        IF mounted:
          _captureScrollAnchor(2)
          setState(): _streamingTranslation = _restorePlaceholdersToCodeBlocks(content, codeBlocks)
          addPostFrameCallback: _syncScrollToTab(2)
    )

    IF NOT mounted: RETURN

    IF success:
      translation = AWAIT _summaryService.getTranslation(bookId, chapterIndex, _targetLang)
      setState():
        _translationContent = _restorePlaceholdersToCodeBlocks(_cleanCodeBackslashes(translation), codeBlocks)
        _isTranslating = false
        _streamingTranslation = ''
    ELSE:
      setState():
        _isTranslating = false
        _streamingTranslation = ''
  CATCH e:
    IF mounted: setState():
      _isTranslating = false
      _streamingTranslation = ''
END PROCEDURE
```

### `_cleanCodeBackslashes(html)`

```
PROCEDURE _cleanCodeBackslashes(html):
  RETURN html.replaceAllMapped(
    RegExp <code> or <pre> tags,
    match → replace \\ with \ inside code/pre
  )
END PROCEDURE
```

### `_extractCodeBlocksToPlaceholders(html)`

```
PROCEDURE _extractCodeBlocksToPlaceholders(html):
  codeBlocks = []
  result = html.replaceAllMapped(
    RegExp <code> or <pre> blocks,
    match:
      codeBlocks.add(match)
      RETURN '%%ZHIDU_CODE_BLOCK_{n}%%'
  )
  RETURN [result, codeBlocks]
END PROCEDURE
```

### `_restorePlaceholdersToCodeBlocks(html, codeBlocks)`

```
PROCEDURE _restorePlaceholdersToCodeBlocks(html, codeBlocks):
  RETURN html.replaceAllMapped(
    RegExp '%%ZHIDU_CODE_BLOCK_(\d+)%%',
    match: RETURN codeBlocks[index] OR placeholder
  )
END PROCEDURE
```

---

## Widget Methods

### `build(context)`

```
WIDGET build(context):
  RETURN Scaffold
    ├── AppBar
    │   ├── Title: Text(_getChapterTitle(...))
    │   ├── actions:
    │   │   IF _summaryChapter == null AND NOT _isGenerating AND _content.isNotEmpty AND aiConfigured:
    │   │     TextButton.icon('生成摘要', onPressed: _generateSummaryWithStreaming)
    │
    └── Body: Stack
        ├── _buildBody()
        └── IF _chapters.length > 1: _buildNavigationButtons()
```

### `_buildBody()`

```
WIDGET _buildBody():
  IF _isLoadingContent:  RETURN _buildLoadingView()
  IF _error != null AND _content.isEmpty: RETURN _buildErrorView()
  RETURN _buildSummaryView()  // Always use tab layout
```

### `_buildSummaryView()` (Vertical Tab Layout)

```
WIDGET _buildSummaryView():
  selectedColor = theme.primary.withAlpha(40)
  unselectedColor = grey.withAlpha(80)

  RETURN Padding(16)
    └── Row
        ├── Column (Vertical Tab Bar)
        │   ├── _buildVerticalTab(0, Icons.auto_awesome)    // Summary
        │   ├── Divider(height: 1, width: 60)
        │   ├── _buildVerticalTab(1, Icons.menu_book, disabled: contentTooShort) // Original
        │   ├── Divider(height: 1, width: 60)
        │   └── _buildVerticalTab(2, Icons.translate, disabled: _translationTabDisabled) // Translation
        └── Expanded: Container(selectedColor)
            └── TabBarView(controller: _tabController)
                ├── Tab 0: _buildSummaryContent()
                ├── Tab 1: _buildOriginalTextView()
                └── Tab 2: _buildTranslationView()
```

### `_buildSummaryContent()`

```
WIDGET _buildSummaryContent():
  IF _isGenerating AND _streamingSummary.isNotEmpty:
    RETURN _buildStreamingSummaryView()
  IF _isGenerating AND _streamingSummary.isEmpty:
    RETURN _buildGeneratingView()
  IF _summaryChapter != null AND has objectiveSummary:
    htmlContent = md.markdownToHtml(_summaryChapter.objectiveSummary)
    RETURN _buildNormalSummaryView(htmlContent)
  RETURN _buildEmptySummaryView()
```

### `_buildStreamingSummaryView()`

```
WIDGET _buildStreamingSummaryView():
  htmlContent = md.markdownToHtml(_streamingSummary)
  RETURN LayoutBuilder → SingleChildScrollView → Padding
    └── Column
        ├── Html(data: htmlContent, style: _htmlStyle)
        ├── SizedBox(height: 16)
        └── _buildTypingIndicator()
```

### `_buildNormalSummaryView(htmlContent)`

```
WIDGET _buildNormalSummaryView(htmlContent):
  RETURN LayoutBuilder → SingleChildScrollView → Padding
    └── Html(data: htmlContent, style: _htmlStyle)
```

### `_buildEmptySummaryView()`

```
WIDGET _buildEmptySummaryView():
  RETURN Center: Text('暂无摘要', color: grey)
```

### `_buildTypingIndicator()` (extracted shared widget)

```
WIDGET _buildTypingIndicator():
  RETURN Row
    ├── _typingDot()
    ├── SizedBox(width: 4)
    ├── _typingDot()
    ├── SizedBox(width: 4)
    └── _typingDot()

WIDGET _typingDot():
  RETURN Container(width: 8, height: 8,
    decoration: BoxDecoration(color: blue, shape: circle))
```

Used by: `_buildStreamingSummaryView()`, `_buildStreamingTranslationView()`

### `_buildTranslationView()`

```
WIDGET _buildTranslationView():
  IF _translationTabDisabled:
    RETURN Center: '书籍语言与译文语言相同，无需翻译'

  IF _isTranslating OR _streamingTranslation.isNotEmpty:
    RETURN _buildStreamingTranslationView()

  IF _translationContent != null AND not empty:
    RETURN _buildTranslationHtmlView(_translationContent)

  RETURN Center: CircularProgressIndicator + '翻译中...'
```

### `_buildStreamingTranslationView()`

```
WIDGET _buildStreamingTranslationView():
  htmlContent = _cleanCodeBackslashes(_streamingTranslation)
  RETURN LayoutBuilder → SingleChildScrollView(controller: _translationScrollController) → Padding
    └── Column
        ├── Html(data: htmlContent, style: translationHtmlStyle)
        ├── SizedBox(height: 16)
        └── _buildTypingIndicator()
```

### `_buildTranslationHtmlView(htmlContent)`

```
WIDGET _buildTranslationHtmlView(htmlContent):
  RETURN LayoutBuilder → SingleChildScrollView(controller: _translationScrollController) → Padding
    └── Html(data: htmlContent, style: _htmlStyle)
```

### `_buildOriginalTextView()`

```
WIDGET _buildOriginalTextView():
  IF isPdf AND filePath != null:
    RETURN PdfDocumentViewBuilder.file(filePath)
      builder: (context, document):
        IF document == null: RETURN CircularProgressIndicator()
        _pdfTotalPages = document.pages.length
        RETURN PdfPageView(document: document, pageNumber: _pdfCurrentPage.clamp(1, _pdfTotalPages))

  // EPUB/Other
  RETURN LayoutBuilder → SingleChildScrollView(controller: _originalScrollController) → Padding
    └── Html(data: _content, style: originalStyle)
```

### `_buildNavigationButtons()`

```
WIDGET _buildNavigationButtons():
  // Same as before — 4 navigation buttons with PDF page support
  RETURN Positioned → Row
    ├── << Previous Chapter
    ├── < Previous Page (PDF only)
    ├── > Next Page (PDF only)
    └── >> Next Chapter
```

---

## User Interaction Flows

### Flow 1: Open Chapter

```
User taps chapter in BookScreen
    ↓
Navigator.push(ChapterScreen)
    ↓
initState():
    ├── Filter chapters to top-level
    ├── Initialize scroll controllers
    ├── TabController(length: 3)
    ├── _initializeLanguageSettings()
    └── _initializeContent()
    ↓
Load chapter content (EPUB/PDF)
    ↓
_checkContentLength()
    ↓
addPostFrameCallback → _loadSummary()
    ↓
IF summary exists: Show summary (Tab 0)
IF no summary and content available: Auto-generate stream
IF no content: Show error
```

### Flow 2: Generate Summary (Streaming)

```
User taps "生成摘要" button (or auto-triggered)
    ↓
_generateSummaryWithStreaming()
    ↓
Extract plain text from HTML
    ↓
SummaryService.generateSingleSummary() with onContentUpdate callback
    ↓
setState: _streamingSummary = content  (real-time UI update)
    ↓
_buildStreamingSummaryView() renders Markdown→HTML live
    ↓
Generation complete → load final summary
    ↓
Check for updated chapter title
    ↓
setState: _summaryChapter = summary, _isGenerating = false
    ↓
_buildNormalSummaryView() renders final summary
```

### Flow 3: Tab Switching (with Scroll Sync)

```
User taps left tab icon
    ↓
_tabController.addListener:
    indexIsChanging=true: _captureScrollAnchor(previousIndex)
    ↓
_tabController.animateTo(newIndex)
    ↓
indexIsChanging=false: _syncScrollToTab(newIndex)
    ↓
IF newIndex == 2 (Translation):
    _loadTranslation()
```

### Flow 4: Translation View

```
User switches to Translation tab (Tab 2)
    ↓
_loadTranslation()
    ├── Has cache → Display translation HTML (_buildTranslationHtmlView)
    ├── No cache & AI configured → _generateTranslationWithStreaming()
    │       ├── Extract code blocks to placeholders
    │       ├── SummaryService.generateTranslationStream()
    │       └── onContentUpdate → setState _streamingTranslation
    └── Not configured → Empty state
```

---

## Service Integration

### SummaryService

```
READ: getSummary(bookId, chapterIndex, language) → Chapter?
  - Load existing summary from file

GENERATE: generateSingleSummary(bookId, chapterIndex, title, content, {language, onContentUpdate})
  - Call AIService for streaming summary generation
  - onContentUpdate: real-time content callback for UI streaming
  - Save summary to file
  - RETURN success bool

TRANSLATE: generateTranslationStream(bookId, chapterIndex, content, ...)
  - Code block placeholder protection
  - onContentUpdate: real-time translation callback
  - RETURN success bool

READ TR: getTranslation(bookId, chapterIndex, targetLang) → String?
  - Load existing translation from file
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
USE PARSER: getChapters(filePath) | getChapterContent(filePath, chapter)
```

---

## Title Update Mechanism

```
AI generates summary via _generateSummaryWithStreaming()
    ↓
May also generate better chapter title
    ↓
SummaryService updates book.chapterTitles
    ↓
BookService saves updated book
    ↓
_generateSummaryWithStreaming() checks for new title
    ↓
updatedBook = _bookService.getBookById(bookId)
    ↓
newTitle = updatedBook.chapterTitles?[chapterIndex]
    ↓
setState(): _title = newTitle ?? _title
    ↓
AppBar shows updated title
```

---

## Vertical Tab Controller Management

```
initState():
    ↓
_tabController = TabController(length: 3, vsync: this)
    ↓
_tabController.addListener():
    IF mounted: setState()
    ├── IF indexIsChanging → _captureScrollAnchor(previousIndex)
    └── ELSE → _syncScrollToTab(currentIndex)
                └── IF tab==2 → _loadTranslation

dispose():
    ↓
_translationScrollController?.dispose()
_originalScrollController?.dispose()
_tabController?.dispose()
    ↓
super.dispose()
```
