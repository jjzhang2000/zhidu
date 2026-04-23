# chapter_content.dart - Pseudocode Documentation

## Overview

This file defines the ChapterContent model, which stores the content of a single chapter in an EPUB book. It supports both plain text and HTML format content.

---

## Class: ChapterContent

Represents the content of a single chapter in an EPUB book, containing both plain text and optional HTML format content.

### Purpose

- Store chapter content after EPUB parsing
- Display chapter text in reading interface
- Provide input for AI summary generation
- Support content serialization and deserialization

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `plainText` | `String` | Yes | Plain text content (HTML tags removed) |
| `htmlContent` | `String?` | Nullable | HTML format content (preserves formatting) |

### Property Details

#### plainText

- **Source**: Extracted from EPUB HTML content with all tags removed
- **Uses**:
  - AI summary generation (requires plain text input)
  - Simple text search and statistics
  - Text display without formatting requirements

#### htmlContent

- **Source**: Original HTML from EPUB chapter file
- **Uses**:
  - Preserve original formatting (bold, italic, etc.)
  - Rich text display in reading interface
  - Preserve chapter structure information
- **Note**: May be null for simple EPUB formats without separate HTML content

### Constructor

```
CONSTRUCTOR ChapterContent(plainText, htmlContent):
    SET plainText = plainText        // Required: chapter plain text
    SET htmlContent = htmlContent   // Optional: may be NULL
END CONSTRUCTOR
```

### Methods

#### `toJson() -> Map<String, dynamic>`

**Purpose**: Convert ChapterContent to JSON format Map for serialization.

**Use Cases**:
- Database storage
- Network transmission
- Cache management

**Pseudocode**:
```
FUNCTION toJson():
    RETURN {
        'plainText': this.plainText,
        'htmlContent': this.htmlContent  // May be NULL
    }
END FUNCTION
```

**Output Example**:
```json
{
    "plainText": "第一章的内容...",
    "htmlContent": "<p>第一章的内容...</p>"
}
```

#### `fromJson(Map<String, dynamic> json) -> ChapterContent` (Factory)

**Purpose**: Create ChapterContent instance from JSON format Map.

**Pseudocode**:
```
FUNCTION fromJson(json):
    RETURN NEW ChapterContent(
        plainText = json['plainText'],
        htmlContent = json['htmlContent']  // May be NULL
    )
END FUNCTION
```

**Input Requirements**:
- `plainText` field is required
- `htmlContent` field is optional

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
│  1. Read chapter HTML file                                  │
│  2. Parse HTML structure                                    │
│  3. Extract plain text (remove tags)                        │
│  4. Preserve HTML content                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ChapterContent                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ plainText: "第一章 科学边界..."                      │   │
│  │ htmlContent: "<h1>第一章</h1><p>科学边界...</p>"     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼                                   ▼
┌───────────────────────┐           ┌───────────────────────┐
│   Reading Interface   │           │    AI Summary Gen     │
│  Display HTML content │           │  Use plainText input   │
│  Preserve formatting  │           │  Generate summary      │
└───────────────────────┘           └───────────────────────┘
```

---

## Relationship with Other Models

```
┌─────────────────────────────────────────────────────────────┐
│                         Book                                │
│  (Contains chapter list and metadata)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Has many
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Chapter                              │
│  (Chapter metadata: id, index, title, location)             │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Has content
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ChapterContent                           │
│  - plainText: String (for AI processing)                   │
│  - htmlContent: String? (for display)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Generates
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ChapterSummary                           │
│  (AI-generated summary from plainText)                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Creating from EPUB Parsing

```
// In EpubParser
FUNCTION parseChapterContent(htmlFilePath):
    // Read HTML file
    htmlContent = readFile(htmlFilePath)
    
    // Extract plain text by removing HTML tags
    plainText = extractPlainText(htmlContent)
    // Algorithm:
    // 1. Remove all HTML tags using regex or parser
    // 2. Decode HTML entities (&amp; -> &, &lt; -> <, etc.)
    // 3. Normalize whitespace
    // 4. Remove extra blank lines
    
    RETURN NEW ChapterContent(
        plainText = plainText,
        htmlContent = htmlContent
    )
END FUNCTION

// Helper function
FUNCTION extractPlainText(html):
    // Remove script and style tags with content
    text = REMOVE_TAGS(html, 'script', 'style')
    
    // Remove all HTML tags
    text = REMOVE_ALL_TAGS(text)
    
    // Decode HTML entities
    text = DECODE_HTML_ENTITIES(text)
    
    // Normalize whitespace
    text = NORMALIZE_WHITESPACE(text)
    
    RETURN text
END FUNCTION
```

### Display in Reading Interface

```
// In EpubReaderScreen
WIDGET buildChapterView(ChapterContent content):
    IF content.htmlContent IS NOT NULL:
        // Use flutter_html to render HTML
        RETURN Html(
            data = content.htmlContent,
            style = {
                'p': Style(fontSize: FontSize(16)),
                'h1': Style(fontSize: FontSize(24)),
                'h2': Style(fontSize: FontSize(20)),
                // ... more styles
            }
        )
    ELSE:
        // Fallback to plain text
        RETURN Text(content.plainText)
    END IF
END WIDGET
```

### AI Summary Generation

```
// In SummaryService
FUNCTION generateChapterSummary(ChapterContent content):
    // Use plainText for AI input
    prompt = '''
    请为以下章节内容生成摘要：
    
    ${content.plainText}
    '''
    
    // Call AI API
    summary = await aiService.generateCompletion(prompt)
    
    RETURN summary
END FUNCTION
```

### Serialization for Storage

```
// Save chapter content to cache
FUNCTION cacheChapterContent(String bookId, int chapterIndex, ChapterContent content):
    json = content.toJson()
    cachePath = getCachePath(bookId, chapterIndex)
    writeJsonFile(cachePath, json)
END FUNCTION

// Load chapter content from cache
FUNCTION loadChapterContent(String bookId, int chapterIndex):
    cachePath = getCachePath(bookId, chapterIndex)
    json = readJsonFile(cachePath)
    RETURN ChapterContent.fromJson(json)
END FUNCTION
```

### Text Statistics

```
// Calculate chapter statistics
FUNCTION calculateChapterStats(ChapterContent content):
    RETURN {
        'characterCount': content.plainText.length,
        'wordCount': countWords(content.plainText),
        'paragraphCount': countParagraphs(content.plainText),
        'hasFormatting': content.htmlContent IS NOT NULL
    }
END FUNCTION

// Search in chapter
FUNCTION searchInChapter(ChapterContent content, String query):
    // Search in plain text for efficiency
    positions = findAllOccurrences(content.plainText, query)
    RETURN positions
END FUNCTION
```

---

## Notes

1. **Dual Format Support**: ChapterContent maintains both plain text and HTML to support different use cases:
   - Plain text for AI processing and search
   - HTML for rich display in reading interface

2. **Memory Consideration**: For large chapters, consider lazy loading or streaming to avoid memory issues.

3. **HTML Safety**: When displaying htmlContent, ensure proper sanitization to prevent XSS attacks (handled by flutter_html).

4. **Encoding**: Both plainText and htmlContent should be UTF-8 encoded.

5. **Whitespace Handling**: Plain text extraction should normalize whitespace while preserving paragraph breaks.

6. **PDF Note**: This model is primarily for EPUB. PDF chapters typically use page-based content retrieval rather than ChapterContent model.

7. **Caching Strategy**: ChapterContent can be cached to disk to avoid re-parsing EPUB files on each read.