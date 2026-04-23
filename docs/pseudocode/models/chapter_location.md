# chapter_location.dart - Pseudocode Documentation

## Overview

This file defines the ChapterLocation model, which represents the position of a chapter within a book file. It supports two positioning methods: href-based (for EPUB) and page-range-based (for PDF).

---

## Class: ChapterLocation

Represents chapter position information, supporting both EPUB href positioning and PDF page range positioning.

### Purpose

1. Record user reading progress for position restoration
2. Locate target chapter during navigation
3. Associate chapter content during summary generation

### Positioning Methods

| Format | Positioning Method | Fields Used |
|--------|-------------------|-------------|
| EPUB | href (relative path) | `href` |
| PDF | Page range | `startPage`, `endPage` |

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `href` | `String?` | No | Chapter relative path reference (EPUB) |
| `startPage` | `int?` | No | Chapter start page number (PDF) |
| `endPage` | `int?` | No | Chapter end page number (PDF) |

### Property Details

#### href

- **Purpose**: EPUB chapter positioning
- **Format**: Relative path to HTML file within EPUB
- **Examples**:
  - `chapter1.xhtml`
  - `OEBPS/chapters/chapter01.html`
  - `content/part1/chapter01.xhtml#section2` (with anchor)

#### startPage

- **Purpose**: PDF chapter start position
- **Format**: Page number (1-based)
- **Example**: If chapter starts on page 10, startPage = 10

#### endPage

- **Purpose**: PDF chapter end position
- **Format**: Page number (1-based)
- **Example**: If chapter ends on page 25, endPage = 25

### Constructor

```
CONSTRUCTOR ChapterLocation(href, startPage, endPage):
    SET href = href            // Optional: for EPUB
    SET startPage = startPage // Optional: for PDF
    SET endPage = endPage     // Optional: for PDF
    
    // Note: Typically only one positioning method is used:
    // - EPUB: only href
    // - PDF: startPage and endPage
END CONSTRUCTOR
```

### Methods

#### `toJson() -> Map<String, dynamic>`

**Purpose**: Serialize chapter location to JSON for storage.

**Pseudocode**:
```
FUNCTION toJson():
    RETURN {
        'href': this.href,           // May be NULL
        'startPage': this.startPage, // May be NULL
        'endPage': this.endPage      // May be NULL
    }
END FUNCTION
```

**Output Example**:
```json
// EPUB location
{
    "href": "chapter1.xhtml",
    "startPage": null,
    "endPage": null
}

// PDF location
{
    "href": null,
    "startPage": 10,
    "endPage": 25
}
```

#### `fromJson(Map<String, dynamic> json) -> ChapterLocation` (Factory)

**Purpose**: Deserialize JSON to ChapterLocation instance.

**Pseudocode**:
```
FUNCTION fromJson(json):
    RETURN NEW ChapterLocation(
        href = json['href'],           // May be NULL
        startPage = json['startPage'], // May be NULL
        endPage = json['endPage']      // May be NULL
    )
END FUNCTION
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    EPUB Parsing Flow                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    EpubParser                               │
│  Parse NCX/NAV navigation                                   │
│  Extract href from navPoint                                 │
│                                                              │
│  Example:                                                   │
│  <navPoint>                                                 │
│    <navLabel>第一章</navLabel>                              │
│    <content src="OEBPS/chapter1.xhtml"/>                    │
│  </navPoint>                                                │
│                                                              │
│  → href = "OEBPS/chapter1.xhtml"                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           ChapterLocation(href="OEBPS/chapter1.xhtml")      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    PDF Parsing Flow                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PdfParser                                │
│  Detect chapter titles                                      │
│  Calculate page ranges                                      │
│                                                              │
│  Example:                                                   │
│  Chapter "第一章" detected on page 10-25                    │
│                                                              │
│  → startPage = 10, endPage = 25                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│        ChapterLocation(startPage=10, endPage=25)             │
└─────────────────────────────────────────────────────────────┘
```

---

## Relationship with Chapter Model

```
┌─────────────────────────────────────────────────────────────┐
│                         Chapter                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ id: String                                           │   │
│  │ index: int                                           │   │
│  │ title: String                                        │   │
│  │ level: int                                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          │ contains                         │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              ChapterLocation                         │   │
│  │  ┌─────────────────┐  ┌─────────────────────────┐   │   │
│  │  │ EPUB Position   │  │ PDF Position            │   │   │
│  │  │ href: String?   │  │ startPage: int?         │   │   │
│  │  │                 │  │ endPage: int?           │   │   │
│  │  └─────────────────┘  └─────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Creating EPUB Location

```
// In EpubParser
FUNCTION createEpubLocation(navPoint):
    // Extract href from navigation point
    href = navPoint.getContentSrc()
    
    // Clean href (remove anchor if needed)
    IF href CONTAINS '#':
        href = href.split('#')[0]
    END IF
    
    RETURN NEW ChapterLocation(href = href)
END FUNCTION

// Example usage
location = NEW ChapterLocation(href = 'OEBPS/chapter1.xhtml')
```

### Creating PDF Location

```
// In PdfParser
FUNCTION createPdfLocation(startPage, endPage):
    RETURN NEW ChapterLocation(
        startPage = startPage,
        endPage = endPage
    )
END FUNCTION

// Example usage
location = NEW ChapterLocation(startPage = 10, endPage = 25)
```

### Navigation in EPUB Reader

```
// In EpubReaderScreen
FUNCTION navigateToChapter(Chapter chapter):
    location = chapter.location
    
    IF location.href IS NOT NULL:
        // Resolve full path within EPUB
        fullPath = resolveEpubPath(location.href)
        
        // Load chapter content
        htmlContent = loadChapterHtml(fullPath)
        
        // Display in reader
        displayChapter(htmlContent)
    END IF
END FUNCTION
```

### Navigation in PDF Reader

```
// In PdfReaderScreen
FUNCTION navigateToChapter(Chapter chapter):
    location = chapter.location
    
    IF location.startPage IS NOT NULL:
        // Jump to start page
        pdfController.jumpToPage(location.startPage)
        
        // Update UI to show chapter range
        updateChapterInfo(
            startPage = location.startPage,
            endPage = location.endPage
        )
    END IF
END FUNCTION
```

### Reading Progress Tracking

```
// Save reading progress
FUNCTION saveReadingProgress(Book book, Chapter chapter, int position):
    progress = {
        'bookId': book.id,
        'chapterId': chapter.id,
        'chapterLocation': chapter.location.toJson(),
        'position': position,
        'timestamp': DateTime.now().toIso8601String()
    }
    saveToStorage(progress)
END FUNCTION

// Restore reading progress
FUNCTION restoreReadingProgress(Book book):
    progress = loadFromStorage(book.id)
    
    IF progress IS NOT NULL:
        location = ChapterLocation.fromJson(progress['chapterLocation'])
        
        // Navigate to saved position
        IF location.href IS NOT NULL:
            // EPUB: load chapter by href
            loadEpubChapter(location.href)
        ELSE IF location.startPage IS NOT NULL:
            // PDF: jump to page
            jumpToPdfPage(location.startPage)
        END IF
    END IF
END FUNCTION
```

### Serialization

```
// EPUB location
epubLocation = NEW ChapterLocation(href = 'chapter1.xhtml')
json = epubLocation.toJson()
// { 'href': 'chapter1.xhtml', 'startPage': null, 'endPage': null }
restored = ChapterLocation.fromJson(json)

// PDF location
pdfLocation = NEW ChapterLocation(startPage = 10, endPage = 25)
json = pdfLocation.toJson()
// { 'href': null, 'startPage': 10, 'endPage': 25 }
restored = ChapterLocation.fromJson(json)
```

---

## Notes

1. **Format-Specific Usage**: Typically, only one positioning method is used per location:
   - EPUB: Only `href` is set
   - PDF: Only `startPage` and `endPage` are set

2. **Page Numbering**: PDF page numbers are 1-based (first page is 1, not 0).

3. **Anchor Support**: EPUB href may contain anchors (e.g., `chapter1.xhtml#section2`), which should be handled by the reader.

4. **Null Safety**: All fields are nullable to support both positioning methods without requiring dummy values.

5. **Chapter Range**: For PDF, `startPage` and `endPage` define the complete page range of a chapter, useful for:
   - Progress calculation
   - Page navigation boundaries
   - Chapter length estimation

6. **Href Resolution**: EPUB href is relative to the EPUB root, not the file system. The reader must resolve it within the EPUB structure.

7. **Storage Efficiency**: When serializing, null fields are preserved to maintain format information (EPUB vs PDF).