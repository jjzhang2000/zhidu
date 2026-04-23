# PDF Reader Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/pdf_reader_screen.dart`
**Purpose**: PDF format book reading interface
**Pattern**: Simple StatefulWidget with pdfrx library integration

---

## StatefulWidget Structure

```
PdfReaderScreen (StatefulWidget)
├── Parameters:
│   ├── Book book (required)
│   ├── Chapter? chapter (optional)
│   └── int initialPage (default: 1)
└── _PdfReaderScreenState (State)
    ├── Service: LogService
    └── State: int _currentPage
```

---

## Parameters

| Parameter | Type | Required | Purpose |
|-----------|------|----------|---------|
| `book` | Book | Yes | Book object with file path |
| `chapter` | Chapter? | No | Starting chapter for title |
| `initialPage` | int | No (default: 1) | Starting page number |

---

## State Variables

| Variable | Type | Purpose |
|----------|------|---------|
| `_log` | LogService | Debug logging |
| `_currentPage` | int | Current reading page |

---

## Methods Pseudocode

### `initState()`

```
PROCEDURE initState():
  // Initialize current page from parameter
  _currentPage = widget.initialPage
  
  _log.d('PdfReaderScreen', 
    '初始化PDF阅读器: ${widget.book.title}, 起始页: $_currentPage')
END PROCEDURE
```

### `build(context)`

```
PROCEDURE build(context):
  RETURN Scaffold
    ├── AppBar
    │   └── Title: Text
    │       ├── widget.chapter?.title OR widget.book.title
    │       └── overflow: ellipsis
    │
    └── Body: PdfViewer.file
        ├── widget.book.filePath
        ├── params: PdfViewerParams()
        └── initialPageNumber: _currentPage
END PROCEDURE
```

---

## Widget Tree Structure

```
Scaffold
├── AppBar
│   └── Title: Text
│       ├── content: chapter.title OR book.title
│       └── overflow: TextOverflow.ellipsis
│
└── Body: PdfViewer.file
    ├── path: book.filePath
    ├── params: PdfViewerParams
    │   ├── (extensible configuration)
    │   ├── scrollDirection (optional)
    │   ├── pageFitPolicy (optional)
    │   ├── enableTextSelection (optional)
    │   └── scrollByMouseWheel (optional)
    │
    └── initialPageNumber: _currentPage
```

---

## User Interaction Flows

### Flow 1: Open PDF from Beginning

```
User taps book (PDF format)
    ↓
Navigator.push(PdfReaderScreen(book: book))
    ↓
initialPage defaults to 1
    ↓
PDF opens at first page
    ↓
User reads and navigates
```

### Flow 2: Open PDF from Chapter

```
User taps chapter in BookDetailScreen
    ↓
Navigator.push(PdfReaderScreen(
  book: book,
  chapter: chapter,
  initialPage: chapter.startPage
))
    ↓
PDF opens at chapter start page
    ↓
AppBar shows chapter title
    ↓
User reads chapter content
```

### Flow 3: Continue Reading

```
User returns to previously read book
    ↓
Book has readingProgress saved
    ↓
Calculate last read page from progress
    ↓
Navigator.push(PdfReaderScreen(
  book: book,
  initialPage: lastReadPage
))
    ↓
PDF opens at last position
```

---

## PDF Viewer Features

### Built-in Features (pdfrx)

```
PdfViewer provides:
├── High-performance PDF rendering
├── Gesture support:
│   ├── Pinch to zoom
│   ├── Pan/scroll
│   └── Double-tap zoom
├── Page navigation:
│   ├── Swipe between pages
│   ├── Scroll through document
├── Text selection (if enabled)
└── Mouse wheel scrolling (if enabled)
```

### Configuration Options

```
PdfViewerParams:
├── scrollDirection: Axis.vertical/horizontal
├── pageFitPolicy: PageFitPolicy.width/height/contain
├── enableTextSelection: bool
├── scrollByMouseWheel: ScrollByMouseWheel
└── ... (other pdfrx options)
```

---

## Comparison with EPUB Reader

| Feature | PDF Reader | EPUB Reader |
|---------|------------|-------------|
| Layout | Fixed layout | Reflowable text |
| Rendering | pdfrx PdfViewer | flutter_html Html |
| Navigation | Page numbers | Chapter sections |
| Zoom | Native support | Not applicable |
| Text selection | Built-in | HTML-based |

---

## Navigation Flow

```
BookDetailScreen (PDF book)
    ↓ (tap chapter)
PdfReaderScreen
    ├── Displays PDF content
    ├── Shows chapter title in AppBar
    └── Starts at chapter page
    ↓ (user reads)
PdfViewer handles navigation
    ↓ (back button)
Navigator.pop()
    ↓
Return to BookDetailScreen
```

---

## Data Flow

### Book Data Usage

```
PdfReaderScreen uses:
├── book.filePath → PDF file location
├── book.title → AppBar title (fallback)
├── book.format → Confirms PDF format
└── chapter?.title → AppBar title (priority)
└── chapter?.startPage → Initial page number
```

### Page Tracking

```
_currentPage tracks current position
    ↓
Used for:
├── Initial page display
├── (Future: progress saving)
└── (Future: position restoration)
```

---

## Integration with SummaryScreen

```
SummaryScreen (PDF book)
    ↓ (tap "阅读原文" button)
Shows PDF original text view
    ↓
Uses PdfDocumentViewBuilder
    ↓
Single page view with navigation buttons
    ↓
Different from full PdfReaderScreen

PdfReaderScreen = Full-screen PDF reader
SummaryScreen PDF view = Embedded single-page viewer
```

---

## Error Handling

```
PdfViewer.file handles:
├── File not found → Error display
├── Corrupted PDF → Error display
├── Encrypted PDF → May require password
└── Large files → Progressive loading
```

---

## Performance Considerations

```
pdfrx library benefits:
├── Native PDF rendering (pdfium)
├── Efficient memory usage
├── Progressive page loading
├── Hardware-accelerated rendering
└── Cross-platform support
```

---

## Use Cases

### Use Case 1: New Book Reading

```
User imports PDF book
    ↓
User taps book card
    ↓
BookDetailScreen shows summary
    ↓
User taps summary or chapter
    ↓
PdfReaderScreen opens at page 1
```

### Use Case 2: Chapter Navigation

```
User views chapter list
    ↓
User taps specific chapter
    ↓
PdfReaderScreen opens at chapter.startPage
    ↓
AppBar shows chapter.title
    ↓
User reads chapter content
```

### Use Case 3: Resume Reading

```
User previously read book
    ↓
book.readingProgress > 0
    ↓
Calculate page from progress
    ↓
PdfReaderScreen opens at saved position
    ↓
User continues reading
```

---

## Limitations

```
Current implementation:
├── No progress saving (future feature)
├── No bookmark support
├── No annotation support
├── No search within PDF
├── No night mode specific settings
└── Basic viewer only

Future enhancements:
├── Save reading position
├── Add bookmark feature
├── Support annotations
├── In-document search
└── Custom viewing modes
```