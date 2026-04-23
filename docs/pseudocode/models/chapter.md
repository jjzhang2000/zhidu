# chapter.dart - Pseudocode Documentation

## Overview

This file defines the unified Chapter model used to represent chapter information for all book formats (EPUB/PDF). It provides a consistent interface for chapter data regardless of the underlying file format.

---

## Class: Chapter

Unified chapter model representing a single chapter in a book. Serves as the common data structure for both EPUB and PDF formats.

### Purpose

- Provide unified chapter data structure for EPUB and PDF
- Store chapter basic information (ID, index, title, location, level)
- Support JSON serialization/deserialization for persistence and transfer

### Callers

- EpubParser: Creates Chapter objects when parsing EPUB files
- PdfParser: Creates Chapter objects when parsing PDF files
- BookFormatParser: Uses as common return type
- SummaryService: Gets chapter info when generating summaries
- BookDetailScreen: Displays book table of contents
- SummaryScreen: Displays chapter summary info
- PdfReaderScreen: Locates chapters during PDF reading

### Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `id` | `String` | Yes | - | Unique chapter identifier |
| `index` | `int` | Yes | - | Chapter index in TOC (0-based) |
| `title` | `String` | Yes | - | Chapter title |
| `location` | `ChapterLocation` | Yes | - | Chapter location info |
| `level` | `int` | No | 0 | Chapter hierarchy depth |

### ID Format

| Format | EPUB | PDF |
|--------|------|-----|
| Pattern | `chapter_{index}` | `page_{pageNumber}` |
| Example | `chapter_0`, `chapter_1` | `page_1`, `page_10` |

### Level Hierarchy

| Level | Description |
|-------|-------------|
| 0 | Top-level chapter |
| 1 | First-level sub-chapter |
| 2 | Second-level sub-chapter |
| ... | Deeper nesting |

### Constructor

```
CONSTRUCTOR Chapter(id, index, title, location, level):
    SET id = id              // Required: unique identifier
    SET index = index        // Required: position in TOC
    SET title = title        // Required: chapter title
    SET location = location  // Required: location info
    SET level = level OR 0  // Optional: default 0
END CONSTRUCTOR
```

### Methods

#### `toJson() -> Map<String, dynamic>`

**Purpose**: Convert Chapter object to JSON format Map.

**Use Cases**:
- Database storage serialization
- Data transfer format conversion

**Callers**: SummaryService, database persistence layer

**Pseudocode**:
```
FUNCTION toJson():
    RETURN {
        'id': this.id,
        'index': this.index,
        'title': this.title,
        'location': this.location.toJson(),  // Delegate to ChapterLocation
        'level': this.level
    }
END FUNCTION
```

#### `fromJson(Map<String, dynamic> json) -> Chapter` (Factory)

**Purpose**: Create Chapter object from JSON format Map.

**Use Cases**:
- Database read deserialization
- API response parsing

**Callers**: SummaryService, database persistence layer

**Pseudocode**:
```
FUNCTION fromJson(json):
    RETURN NEW Chapter(
        id = json['id'],
        index = json['index'],
        title = json['title'],
        location = ChapterLocation.fromJson(json['location']),
        level = json['level'] OR 0  // Backward compatibility: default 0
    )
END FUNCTION
```

**Note**: The `level` field defaults to 0 for backward compatibility with old data that doesn't have this field.

---

## Data Relationships

```
Chapter
├── id: String
├── index: int
├── title: String
├── location: ChapterLocation ─────────────────┐
│   ├── href: String? (EPUB)                    │
│   ├── startPage: int? (PDF)                   │
│   └── endPage: int? (PDF)                     │
└── level: int                                  │
                                                │
Related Models:                                 │
├── Book (contains list of Chapters)            │
├── ChapterContent (text content)               │
├── ChapterSummary (AI-generated summary)       │
└── ChapterLocation (location details) ─────────┘
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    File Parsing Flow                        │
└─────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼                                   ▼
┌───────────────────────┐           ┌───────────────────────┐
│     EpubParser        │           │      PdfParser        │
│  Parse NCX/NAV        │           │  Extract bookmarks    │
│  Extract chapters     │           │  Detect chapter titles│
│  Build hierarchy      │           │  Calculate page ranges │
└───────────────────────┘           └───────────────────────┘
            │                                   │
            │ Create Chapter objects            │ Create Chapter objects
            │ with href location                │ with page range location
            ▼                                   ▼
┌─────────────────────────────────────────────────────────────┐
│                    List<Chapter>                            │
│  Chapter(id='chapter_0', index=0, title='第一章',           │
│          location=ChapterLocation(href='ch1.xhtml'))      │
│  Chapter(id='chapter_1', index=1, title='第二章',           │
│          location=ChapterLocation(href='ch2.xhtml'))      │
│  ...                                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Stored in Book.chapterTitles
                              │ Used by UI for navigation
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Usage Scenarios                          │
│  - BookDetailScreen: Display TOC                            │
│  - SummaryScreen: Navigate between chapters                │
│  - PdfReaderScreen: Jump to chapter page                   │
│  - SummaryService: Generate chapter summaries               │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Creating EPUB Chapter

```
// In EpubParser
FUNCTION parseEpubChapter(navPoint, index):
    // Extract chapter info from NCX/NAV navigation point
    id = 'chapter_${index}'
    title = navPoint.getLabel()
    href = navPoint.getContentSrc()
    level = navPoint.getDepth()
    
    // Create location with href
    location = NEW ChapterLocation(href = href)
    
    RETURN NEW Chapter(
        id = id,
        index = index,
        title = title,
        location = location,
        level = level
    )
END FUNCTION
```

### Creating PDF Chapter

```
// In PdfParser
FUNCTION parsePdfChapter(startPage, endPage, title, index):
    // Create chapter for PDF page range
    id = 'page_${startPage}'
    
    // Create location with page range
    location = NEW ChapterLocation(
        startPage = startPage,
        endPage = endPage
    )
    
    RETURN NEW Chapter(
        id = id,
        index = index,
        title = title,
        location = location,
        level = 0  // PDF chapters are typically flat
    )
END FUNCTION
```

### Serialization

```
// Save to JSON
chapter = NEW Chapter(
    id = 'chapter_0',
    index = 0,
    title = '第一章 引言',
    location = NEW ChapterLocation(href = 'chapter1.xhtml'),
    level = 0
)

json = chapter.toJson()
// Result:
// {
//   'id': 'chapter_0',
//   'index': 0,
//   'title': '第一章 引言',
//   'location': { 'href': 'chapter1.xhtml', 'startPage': null, 'endPage': null },
//   'level': 0
// }

// Load from JSON
restoredChapter = Chapter.fromJson(json)
```

### Navigation Usage

```
// In BookDetailScreen - Display TOC
WIDGET buildChapterList(List<Chapter> chapters):
    RETURN ListView.builder(
        itemCount = chapters.length,
        itemBuilder = (context, index):
            chapter = chapters[index]
            RETURN ListTile(
                leading = Text('${chapter.index + 1}'),
                title = Text(chapter.title),
                // Indent based on level
                contentPadding = EdgeInsets.only(left = chapter.level * 16.0),
                onTap = () => navigateToChapter(chapter)
            )
    )
END WIDGET

// In PdfReaderScreen - Jump to chapter
FUNCTION navigateToChapter(Chapter chapter):
    IF chapter.location.startPage IS NOT NULL:
        // PDF: jump to start page
        jumpToPage(chapter.location.startPage)
    END IF
END FUNCTION

// In EpubReader - Load chapter content
FUNCTION navigateToChapter(Chapter chapter):
    IF chapter.location.href IS NOT NULL:
        // EPUB: load HTML file
        loadChapterContent(chapter.location.href)
    END IF
END FUNCTION
```

### Summary Generation

```
// In SummaryService
FUNCTION generateChapterSummary(Book book, Chapter chapter):
    // Get chapter content
    content = getChapterContent(book, chapter)
    
    // Generate summary using AI
    summary = await aiService.generateSummary(
        chapterTitle = chapter.title,
        content = content
    )
    
    // Save summary
    saveChapterSummary(
        bookId = book.id,
        chapterIndex = chapter.index,
        summary = summary
    )
END FUNCTION
```

---

## Notes

1. **Unified Interface**: Chapter provides a consistent interface for both EPUB and PDF, abstracting format differences.

2. **Location Abstraction**: The `location` property uses ChapterLocation to handle both href-based (EPUB) and page-based (PDF) positioning.

3. **Level Support**: The `level` field supports hierarchical TOC structures, allowing nested chapters to be displayed with proper indentation.

4. **Backward Compatibility**: When deserializing, missing `level` field defaults to 0, ensuring compatibility with old data.

5. **ID Uniqueness**: The `id` field should be unique within a book, typically combining format prefix with index or page number.

6. **Index Consistency**: The `index` field should match the chapter's position in the book's chapter list for proper navigation.