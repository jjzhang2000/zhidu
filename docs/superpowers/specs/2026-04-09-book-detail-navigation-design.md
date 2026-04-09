# BookDetailScreen Navigation Design

## Overview

Modify navigation flow from BookDetailScreen to improve user experience:
- Clicking a chapter in the TOC should directly navigate to that chapter's summary page (SummaryScreen)
- Clicking the content introduction box should navigate to the last read chapter's summary, or the first chapter's summary if no previous reading history

## Requirements

### 1. Chapter Click Navigation

When user clicks any chapter in the TOC (目录) in BookDetailScreen:
- Navigate directly to SummaryScreen (章节摘要界面)
- Pass chapter index, title, and file path
- SummaryScreen loads chapter content internally if not provided

### 2. Content Introduction Box Click Navigation

When user clicks the AI-generated content introduction box:
- If `book.currentChapter >= 1`: navigate to that chapter's SummaryScreen (索引从1开始表示有阅读历史)
- If `book.currentChapter == 0`: navigate to first chapter (index 0) SummaryScreen
- Pass chapter index, title, and file path

## Design

### SummaryScreen Modifications

**Parameter Changes:**
- `chapterContent` becomes optional: `String? chapterContent`
- Add new optional parameter: `String? filePath` (for loading EPUB content)

**Internal State:**
- Add `_isLoadingContent` bool to track content loading state
- Add `_content` String to store loaded content
- Add `_filePath` String from parameter

**Loading Flow:**
```
initState() {
  if (chapterContent != null) {
    _content = chapterContent
    _isLoadingContent = false
  } else if (filePath != null) {
    _isLoadingContent = true
    _loadChapterContent()
  } else {
    // Both null - show error
    _error = '未提供章节内容或文件路径'
    _isLoadingContent = false
  }
  _loadSummary()
}

_loadChapterContent() async {
  try {
    final chapters = await _epubService.getChapterList(filePath!)
    if (chapterIndex >= 0 && chapterIndex < chapters.length) {
      final chapter = chapters[chapterIndex]
      _title = chapter.title  // Update title if needed
      _content = await _epubService.getChapterHtml(filePath!, chapterIndex) ?? ''
    } else {
      _error = '章节索引超出范围'
    }
  } catch (e) {
    _error = '加载章节内容失败: $e'
  }
  setState(() => _isLoadingContent = false)
}
```

**UI Changes:**
- Add loading indicator when `_isLoadingContent == true`
- Existing `_isGenerating` indicator for summary generation remains

### BookDetailScreen Modifications

**New Data:**
- `List<ChapterInfo> _flatChapters = []` - Flat chapter list for index lookup

**Modified Loading:**
```dart
Future<void> _loadChapters() async {
  try {
    // Load hierarchical list for display (existing)
    final chapters = await _epubService.getHierarchicalChapterList(_book.filePath)
    
    // Load flat list for index lookup (new)
    final flatChapters = await _epubService.getChapterList(_book.filePath)
    
    setState(() {
      _chapters = chapters
      _flatChapters = flatChapters
      _isLoadingChapters = false
    })
  } catch (e) {
    // Handle loading failure
    setState(() {
      _isLoadingChapters = false
      // _flatChapters remains empty, click handlers will check this
    })
  }
}
```

**Chapter Click Handler:**
```dart
void _onChapterClick(ChapterInfo chapter) {
  // Check if flat chapters list is loaded
  if (_flatChapters.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('章节列表未加载完成')),
    )
    return
  }
  
  // Find chapter index in flat list by title
  final index = _flatChapters.indexWhere((c) => c.title == chapter.title)
  if (index < 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('无法找到章节：${chapter.title}')),
    )
    return
  }
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SummaryScreen(
        bookId: _book.id,
        chapterIndex: index,
        chapterTitle: chapter.title,
        filePath: _book.filePath,
      ),
    ),
  )
}
```

**Content Introduction Box Click Handler:**
```dart
void _onIntroductionClick() {
  // Check if flat chapters list is loaded
  if (_flatChapters.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('章节列表未加载完成')),
    )
    return
  }
  
  // Determine chapter index (currentChapter >= 1 means has reading history)
  final targetIndex = _book.currentChapter >= 1 ? _book.currentChapter : 0
  
  // Check index is in valid range
  if (targetIndex >= _flatChapters.length) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('章节索引超出范围')),
    )
    return
  }
  
  final chapter = _flatChapters[targetIndex]
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SummaryScreen(
        bookId: _book.id,
        chapterIndex: targetIndex,
        chapterTitle: chapter.title,
        filePath: _book.filePath,
      ),
    ),
  )
}
```

**Removed Code:**
- Remove navigation to ChapterListScreen from all click handlers
- Remove `_openChapter` method or repurpose for SummaryScreen

## Data Flow

```
BookDetailScreen
│
├─ Click TOC chapter
│   ├─ Find index in _flatChapters by title
│   └─ Navigate to SummaryScreen
│       └─ SummaryScreen loads content from filePath
│
└─ Click content introduction box
    ├─ Determine index: currentChapter > 0 ? currentChapter : 0
    ├─ Get title from _flatChapters[index]
    └─ Navigate to SummaryScreen
        └─ SummaryScreen loads content from filePath
```

## Error Handling

All error cases are handled with SnackBar notifications:

1. **Flat chapters list empty:** "章节列表未加载完成"
2. **Chapter not found in flat list:** "无法找到章节：{title}"
3. **Chapter index out of range:** "章节索引超出范围"
4. **SummaryScreen content loading failure:** Shows error state in UI with retry option
5. **SummaryScreen missing both content and filePath:** Shows error "未提供章节内容或文件路径"

## Files to Modify

1. `lib/screens/summary_screen.dart`
   - Modify constructor parameters
   - Add content loading logic
   - Add loading state UI

2. `lib/screens/book_detail_screen.dart`
   - Add `_flatChapters` data
   - Modify `_loadChapters` to load flat list
   - Modify chapter click handlers
   - Modify introduction box click handler
   - Remove ChapterListScreen navigation

## Testing Considerations

- Test with EPUB that has hierarchical chapters (nested structure)
- Test chapter title matching between hierarchical and flat lists
- Test navigation from both TOC and introduction box
- Test error cases: empty chapter list, out of range index
- Test back navigation and state preservation