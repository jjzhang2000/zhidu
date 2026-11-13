# chapter.dart - Pseudocode Documentation

## Overview

This file defines the unified Chapter model, along with ChapterLocation, used to represent chapter information and content for all book formats (EPUB/PDF). Chapter serves as the single model for chapter metadata, content, and AI-generated summaries.

---

## Class: Chapter

Unified chapter model representing a single chapter in a book, combining metadata, HTML content, and AI summary.

### Purpose

- Provide unified chapter data structure for EPUB and PDF
- Store chapter basic information (index, title, location, level)
- Carry chapter HTML content for rendering
- Store AI-generated chapter summary

### Callers

- EpubParser: Creates Chapter objects when parsing EPUB files
- PdfParser: Creates Chapter objects when parsing PDF files
- BookFormatParser: Uses as common return type for getChapterContent
- SummaryService: Gets chapter info when generating summaries
- BookScreen: Displays book table of contents
- ChapterScreen: Displays chapter content and summary
- PdfReaderScreen: Locates chapters during PDF reading

### Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `bookId` | `String` | No | `''` | Associated book's unique identifier |
| `index` | `int` | Yes | - | Chapter index in TOC (0-based) |
| `title` | `String` | Yes | - | Chapter title |
| `location` | `ChapterLocation` | Yes | - | Chapter location info |
| `level` | `int` | No | 0 | Chapter hierarchy depth |
| `htmlContent` | `String?` | No | null | Chapter HTML content |
| `objectiveSummary` | `String?` | No | null | AI-generated chapter summary |

### Level Hierarchy

| Level | Description |
|-------|-------------|
| 0 | Top-level chapter |
| 1 | First-level sub-chapter |
| 2 | Second-level sub-chapter |
| ... | Deeper nesting |

### Constructor

```
CONSTRUCTOR Chapter(bookId, index, title, location, level, htmlContent, objectiveSummary):
    SET bookId = bookId OR ''        // Optional: associated book ID
    SET index = index                // Required: position in TOC
    SET title = title                // Required: chapter title
    SET location = location          // Required: location info
    SET level = level OR 0           // Optional: default 0
    SET htmlContent = htmlContent    // Optional: HTML content
    SET objectiveSummary = objectiveSummary  // Optional: AI summary
END CONSTRUCTOR
```

---

## Class: ChapterLocation

Represents chapter position information within a book file, supporting both EPUB href and PDF page range positioning.

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `href` | `String?` | No | Chapter relative path reference (EPUB) |
| `startPage` | `int?` | No | Chapter start page number (PDF) |
| `endPage` | `int?` | No | Chapter end page number (PDF) |

### Constructor

```
CONSTRUCTOR ChapterLocation(href, startPage, endPage):
    SET href = href            // Optional: for EPUB
    SET startPage = startPage  // Optional: for PDF
    SET endPage = endPage      // Optional: for PDF
END CONSTRUCTOR
```

---

## Data Relationships

```
Chapter
├── bookId: String
├── index: int
├── title: String
├── location: ChapterLocation ─────────────────┐
│   ├── href: String? (EPUB)                    │
│   ├── startPage: int? (PDF)                   │
│   └── endPage: int? (PDF)                     │
├── level: int                                  │
├── htmlContent: String? (chapter text content) │
└── objectiveSummary: String? (AI summary)      │
                                                │
Related Models:                                 │
├── Book (contains list of Chapters)            │
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
│  Chapter(index=0, title='第一章',                           │
│          location=ChapterLocation(href='ch1.xhtml'))      │
│  Chapter(index=1, title='第二章',                           │
│          location=ChapterLocation(href='ch2.xhtml'))      │
│  ...                                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Used by UI for navigation
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Usage Scenarios                          │
│  - BookScreen: Display TOC                            │
│  - ChapterScreen: Navigate between chapters                │
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
    title = navPoint.getLabel()
    href = navPoint.getContentSrc()
    level = navPoint.getDepth()
    
    // Create location with href
    location = NEW ChapterLocation(href = href)
    
    RETURN NEW Chapter(
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
    location = NEW ChapterLocation(
        startPage = startPage,
        endPage = endPage
    )
    
    RETURN NEW Chapter(
        index = index,
        title = title,
        location = location,
        level = 0  // PDF chapters are typically flat
    )
END FUNCTION
```

### Content Retrieval

```
// In SummaryService or ChapterScreen
FUNCTION loadChapterContent(filePath, chapter):
    parser = FormatRegistry.getParser(extension)
    updatedChapter = await parser.getChapterContent(filePath, chapter)
    
    RETURN updatedChapter.htmlContent  // HTML content for rendering
END FUNCTION
```

### Navigation Usage

```
// In BookScreen - Display TOC
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
        loadChapterHtml(chapter.location.href)
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
    
    // Save summary as markdown file
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

4. **Content + Metadata in One**: Chapter now carries both metadata (index/title/location) and runtime content (htmlContent/objectiveSummary), eliminating the need for separate ChapterContent and ChapterSummary models.

5. **Index Consistency**: The `index` field should match the chapter's position in the book's chapter list for proper navigation.
