# Chapter Navigation Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add left/right navigation buttons at the bottom of the chapter page to navigate to previous/next chapters.

**Architecture:** Use Stack + Positioned in Scaffold body to keep navigation buttons fixed at the bottom of the screen.

**Tech Stack:** Flutter, Dart

---

### Task 1: Add navigation buttons to ChapterScreen

**Files:**
- Modify: `lib/screens/chapter_screen.dart`

- [ ] **Step 1: Add _chapters field to store chapter list**

Add after line 47 (after `_contentTooShort`):
```dart
List<ChapterInfo> _chapters = [];
```

- [ ] **Step 2: Initialize _chapters in initState**

Find `initState` method (around line 49), add after super.initState():
```dart
// Initialize chapters from widget.chapters
if (widget.chapters != null) {
  _chapters = widget.chapters!;
}
```

- [ ] **Step 3: Modify build method to use Stack + Positioned**

Replace lines 302-310 (the build method):
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(_title.isNotEmpty ? _title : widget.chapterTitle),
      centerTitle: true,
    ),
    body: Stack(
      children: [
        _buildBody(),
        if (_chapters.isNotEmpty) _buildNavigationButtons(),
      ],
    ),
  );
}
```

- [ ] **Step 4: Add _buildNavigationButtons method**

Add at the end of the file (before the last closing brace):
```dart
Widget _buildNavigationButtons() {
  final isFirst = widget.chapterIndex <= 0;
  final isLast = widget.chapterIndex >= _chapters.length - 1;

  return Positioned(
    left: 0,
    right: 0,
    bottom: 16,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Previous button
            InkWell(
              onTap: isFirst
                  ? null
                  : () => _navigateToChapter(widget.chapterIndex - 1),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isFirst
                      ? Colors.grey.withAlpha(50)
                      : Theme.of(context).colorScheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: isFirst
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 32),
            // Next button
            InkWell(
              onTap: isLast
                  ? null
                  : () => _navigateToChapter(widget.chapterIndex + 1),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isLast
                      ? Colors.grey.withAlpha(50)
                      : Theme.of(context).colorScheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: isLast
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 5: Add _navigateToChapter method**

Add after _buildNavigationButtons:
```dart
void _navigateToChapter(int index) {
  if (index < 0 || index >= _chapters.length) return;
  
  final chapter = _chapters[index];
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => ChapterScreen(
        bookId: widget.bookId,
        chapterIndex: index,
        chapterTitle: chapter.title,
        filePath: widget.filePath,
        chapters: _chapters,
      ),
    ),
  );
}
```

- [ ] **Step 6: Run flutter analyze to verify**

Run: `flutter analyze lib/screens/chapter_screen.dart`
Expected: No errors

- [ ] **Step 7: Build to verify**

Run: `flutter build windows --release`
Expected: Build successful

- [ ] **Step 8: Commit**

```bash
git add lib/screens/chapter_screen.dart
git commit -m "feat: add chapter navigation buttons to ChapterScreen"
```

---

## Spec Coverage Checklist

- [x] Fixed at bottom of screen (Stack + Positioned)
- [x] Left button (<) for previous chapter
- [x] Right button (>) for next chapter
- [x] Circular buttons, 40x40px
- [x] First chapter disables < button
- [x] Last chapter disables > button
- [x] No text in middle