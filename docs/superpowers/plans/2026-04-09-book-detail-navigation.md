# BookDetailScreen Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modify BookDetailScreen navigation to go directly to SummaryScreen when clicking chapters or content introduction box

**Architecture:** Transform SummaryScreen to support optional content loading via filePath; add flat chapter list in BookDetailScreen for index lookup; redirect navigation flows from ChapterListScreen to SummaryScreen

**Tech Stack:** Flutter, epub_plus for EPUB parsing, existing Service layer (EpubService, SummaryService)

---

## File Structure

```
lib/screens/
├── summary_screen.dart          # MODIFY - Add filePath parameter, internal content loading
└── book_detail_screen.dart      # MODIFY - Add flatChapters, change navigation logic
```

---

### Task 1: Modify SummaryScreen Constructor Parameters

**Files:**
- Modify: `lib/screens/summary_screen.dart:12-18`

**Goal:** Make chapterContent optional and add filePath parameter for internal content loading

- [ ] **Step 1: Import EpubService**

Add import at top of file (line 1-5):

```dart
import 'package:flutter/material.dart';
import '../models/chapter_summary.dart';
import '../services/ai_service.dart';
import '../services/summary_service.dart';
import '../services/epub_service.dart';  // NEW
```

- [ ] **Step 2: Modify constructor parameters**

Replace constructor (lines 12-18):

```dart
class SummaryScreen extends StatefulWidget {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String? chapterContent;  // CHANGED: now optional
  final String? filePath;  // NEW: for loading EPUB content

  const SummaryScreen({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.chapterContent,  // CHANGED: optional
    this.filePath,  // NEW: optional
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors related to SummaryScreen constructor changes

- [ ] **Step 4: Commit constructor parameter changes**

```bash
git add lib/screens/summary_screen.dart
git commit -m "refactor: make SummaryScreen.chapterContent optional, add filePath parameter"
```

---

### Task 2: Add Content Loading Logic to SummaryScreen State

**Files:**
- Modify: `lib/screens/summary_screen.dart:24-44`

**Goal:** Add internal content loading capability when filePath is provided

- [ ] **Step 1: Add new state variables**

Replace state class variables (lines 24-31):

```dart
class _SummaryScreenState extends State<SummaryScreen> {
  final _aiService = AIService();
  final _summaryService = SummaryService();
  final _epubService = EpubService();  // NEW

  ChapterSummary? _summary;
  bool _isGenerating = false;
  String? _error;
  
  // NEW: Content loading state
  bool _isLoadingContent = false;
  String _content = '';  // Internal content storage
  String _title = '';  // Updated title from EPUB
```

- [ ] **Step 2: Modify initState to handle content loading**

Replace initState (lines 33-36):

```dart
  @override
  void initState() {
    super.initState();
    _initializeContent();
    _loadSummary();
  }
```

- [ ] **Step 3: Add content initialization method**

Add new method after initState:

```dart
  Future<void> _initializeContent() async {
    // If chapterContent provided, use it directly
    if (widget.chapterContent != null && widget.chapterContent!.isNotEmpty) {
      _content = widget.chapterContent!;
      _title = widget.chapterTitle;
      setState(() => _isLoadingContent = false);
      return;
    }
    
    // If filePath provided, load content from EPUB
    if (widget.filePath != null) {
      setState(() => _isLoadingContent = true);
      await _loadChapterContent();
      return;
    }
    
    // Neither provided - show error
    setState(() {
      _error = '未提供章节内容或文件路径';
      _isLoadingContent = false;
    });
  }

  Future<void> _loadChapterContent() async {
    try {
      final chapters = await _epubService.getChapterList(widget.filePath!);
      
      if (widget.chapterIndex < 0 || widget.chapterIndex >= chapters.length) {
        setState(() {
          _error = '章节索引超出范围: ${widget.chapterIndex}';
          _isLoadingContent = false;
        });
        return;
      }
      
      final chapter = chapters[widget.chapterIndex];
      _title = chapter.title;
      
      final html = await _epubService.getChapterHtml(
        widget.filePath!,
        widget.chapterIndex,
      );
      
      if (html == null || html.isEmpty) {
        setState(() {
          _error = '章节内容为空';
          _isLoadingContent = false;
        });
        return;
      }
      
      setState(() {
        _content = html;
        _isLoadingContent = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载章节内容失败: $e';
        _isLoadingContent = false;
      });
    }
  }
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit content loading logic**

```bash
git add lib/screens/summary_screen.dart
git commit -m "feat: add internal content loading to SummaryScreen"
```

---

### Task 3: Modify SummaryScreen UI to Handle Loading State

**Files:**
- Modify: `lib/screens/summary_screen.dart:159-192`

**Goal:** Add content loading indicator in UI

- [ ] **Step 1: Modify appBar title to use _title**

Replace appBar title (lines 162-164):

```dart
      appBar: AppBar(
        title: Text(_title.isNotEmpty ? _title : widget.chapterTitle),
        centerTitle: true,
```

- [ ] **Step 2: Modify _buildBody to handle content loading**

Replace _buildBody method (lines 178-192):

```dart
  Widget _buildBody() {
    if (_isLoadingContent) {
      return _buildContentLoadingView();
    }
    
    if (_isGenerating) {
      return _buildGeneratingView();
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_summary == null) {
      return _buildEmptyView();
    }

    return _buildSummaryView();
  }
```

- [ ] **Step 3: Add content loading view**

Add new method after _buildBody:

```dart
  Widget _buildContentLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '正在加载章节内容...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit UI loading state changes**

```bash
git add lib/screens/summary_screen.dart
git commit -m "feat: add content loading UI to SummaryScreen"
```

---

### Task 4: Update SummaryScreen Generate Summary Method

**Files:**
- Modify: `lib/screens/summary_screen.dart:46-126`

**Goal:** Use internal _content variable instead of widget.chapterContent

- [ ] **Step 1: Modify _generateSummary to use _content**

Replace validation check in _generateSummary (lines 61-67):

```dart
      // 检查内容是否为空
      if (_content.isEmpty) {
        setState(() {
          _error = '章节内容为空，无法生成摘要';
          _isGenerating = false;
        });
        return;
      }
```

- [ ] **Step 2: Update content extraction**

Replace content extraction (line 69):

```dart
      final content = _extractTextContent(_content);
```

- [ ] **Step 3: Update error message for content length**

Replace error message (lines 72-78):

```dart
      if (content.length < 100) {
        setState(() {
          _error = '章节内容太短（仅 ${content.length} 个字符），无法生成摘要';
          _isGenerating = false;
        });
        return;
      }
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit generate summary changes**

```bash
git add lib/screens/summary_screen.dart
git commit -m "refactor: use internal _content in SummaryScreen._generateSummary"
```

---

### Task 5: Add Flat Chapter List to BookDetailScreen

**Files:**
- Modify: `lib/screens/book_detail_screen.dart:22-57`

**Goal:** Add flat chapter list for index lookup alongside hierarchical list

- [ ] **Step 1: Add flatChapters state variable**

Add after line 27:

```dart
  List<ChapterInfo> _chapters = [];
  List<ChapterInfo> _flatChapters = [];  // NEW: flat list for index lookup
  bool _isLoadingChapters = false;
```

- [ ] **Step 2: Modify _loadChapters to load both lists**

Replace _loadChapters method (lines 40-57):

```dart
  Future<void> _loadChapters() async {
    setState(() => _isLoadingChapters = true);
    try {
      // Load hierarchical list for display
      final chapters =
          await _epubService.getHierarchicalChapterList(_book.filePath);
      
      // Load flat list for index lookup
      final flatChapters =
          await _epubService.getChapterList(_book.filePath);
      
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _flatChapters = flatChapters;
          _isLoadingChapters = false;
        });
      }
    } catch (e, stackTrace) {
      _log.e('BookDetailScreen', '加载章节列表失败', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
    }
  }
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit flat chapter list changes**

```bash
git add lib/screens/book_detail_screen.dart
git commit -m "feat: add flat chapter list to BookDetailScreen"
```

---

### Task 6: Modify Chapter Click Handler in BookDetailScreen

**Files:**
- Modify: `lib/screens/book_detail_screen.dart:443-459`

**Goal:** Navigate to SummaryScreen directly when clicking chapter in TOC

- [ ] **Step 1: Replace chapter onTap handler**

Replace _buildChapterTree onTap (lines 443-450):

```dart
          onTap: () {
            if (_flatChapters.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('章节列表未加载完成')),
              );
              return;
            }
            
            // Find chapter index in flat list
            final index = _flatChapters.indexWhere(
              (c) => c.title == chapter.title,
            );
            
            if (index < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('无法找到章节：${chapter.title}')),
              );
              return;
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
            );
          },
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit chapter click handler changes**

```bash
git add lib/screens/book_detail_screen.dart
git commit -m "feat: navigate to SummaryScreen on chapter click in TOC"
```

---

### Task 7: Modify Content Introduction Box Click Handler

**Files:**
- Modify: `lib/screens/book_detail_screen.dart:386-403`

**Goal:** Navigate to SummaryScreen when clicking content introduction box

- [ ] **Step 1: Replace introduction box onTap**

Replace InkWell onTap in _buildAIIntroductionContent (lines 387-393):

```dart
        onTap: () {
          if (_flatChapters.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('章节列表未加载完成')),
            );
            return;
          }
          
          // Determine chapter index
          final targetIndex = _book.currentChapter >= 1 
              ? _book.currentChapter 
              : 0;
          
          if (targetIndex >= _flatChapters.length) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('章节索引超出范围')),
            );
            return;
          }
          
          final chapter = _flatChapters[targetIndex];
          
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
          );
        },
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit introduction box click changes**

```bash
git add lib/screens/book_detail_screen.dart
git commit -m "feat: navigate to SummaryScreen on introduction box click"
```

---

### Task 8: Remove ChapterListScreen Import and Navigation

**Files:**
- Modify: `lib/screens/book_detail_screen.dart:10`

**Goal:** Remove unused ChapterListScreen import since we no longer navigate to it

- [ ] **Step 1: Remove ChapterListScreen import**

Delete line 10:

```dart
import 'chapter_list_screen.dart';  // REMOVE THIS LINE
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors (unused import warning should disappear)

- [ ] **Step 3: Commit import removal**

```bash
git add lib/screens/book_detail_screen.dart
git commit -m "refactor: remove unused ChapterListScreen import"
```

---

### Task 9: Final Verification

**Goal:** Verify all changes work correctly

- [ ] **Step 1: Run flutter analyze on entire project**

Run: `flutter analyze`
Expected: No errors, no warnings

- [ ] **Step 2: Run flutter test**

Run: `flutter test`
Expected: All existing tests pass (widget_test.dart)

- [ ] **Step 3: Test manually with flutter run**

Run: `flutter run`
Manual verification:
1. Open a book in BookDetailScreen
2. Click a chapter in TOC → Should navigate to SummaryScreen
3. Click content introduction box → Should navigate to first chapter SummaryScreen
4. Verify SummaryScreen loads content when filePath provided
5. Verify error handling when chapter not found

- [ ] **Step 4: Create final commit if needed**

If manual testing reveals issues, fix them and commit:

```bash
git add -A
git commit -m "fix: resolve issues found during testing"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** All requirements from spec implemented
  - Chapter click → SummaryScreen ✓
  - Introduction box click → SummaryScreen ✓
  - currentChapter handling ✓
  - Error handling ✓
  
- [x] **Placeholder scan:** No TBD, TODO, or vague descriptions
  
- [x] **Type consistency:** All method signatures and variable names consistent across tasks