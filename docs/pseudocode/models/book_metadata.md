# book_metadata.dart - Pseudocode Documentation

## Overview

This file defines the BookMetadata model, which stores basic book information during the parsing stage. Unlike the full Book model, BookMetadata is a lightweight model used for file parsing and preview purposes.

---

## Class: BookMetadata

Lightweight book metadata model used during file parsing stage. Contains essential book information without reading state or AI-generated content.

### Purpose

- Store basic book information extracted during EPUB/PDF parsing
- Display book preview in import interface
- Provide simplified book list display
- Transfer metadata between parsing components

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `title` | `String` | Yes | Book title |
| `author` | `String` | Yes | Book author |
| `coverPath` | `String?` | No | Cover image local path (nullable) |
| `totalChapters` | `int` | Yes | Total chapter count |
| `format` | `BookFormat` | Yes | Book format (EPUB/PDF) |

### Constructor

```
CONSTRUCTOR BookMetadata(title, author, coverPath, totalChapters, format):
    SET title = title              // Required: book title
    SET author = author            // Required: book author
    SET coverPath = coverPath      // Optional: default NULL
    SET totalChapters = totalChapters  // Required: chapter count
    SET format = format            // Required: EPUB or PDF
END CONSTRUCTOR
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
│  - Parse OPF/NCX      │           │  - Extract metadata   │
│  - Extract title      │           │  - Count pages        │
│  - Extract author     │           │  - Extract cover     │
│  - Extract cover      │           │                       │
└───────────────────────┘           └───────────────────────┘
            │                                   │
            └─────────────────┬─────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    BookMetadata                             │
│  - title: String                                            │
│  - author: String                                           │
│  - coverPath: String?                                       │
│  - totalChapters: int                                       │
│  - format: BookFormat                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Book Creation                            │
│  BookService creates Book from BookMetadata                 │
│  + id (UUID)                                                │
│  + filePath                                                 │
│  + addedAt                                                  │
│  + reading progress (default 0)                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Relationship with Book Model

```
┌─────────────────────────────────────────────────────────────┐
│                    BookMetadata                             │
│  (Lightweight, parsing stage only)                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ title, author, coverPath, totalChapters, format     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Used to create
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         Book                                 │
│  (Complete, persistent storage)                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ From BookMetadata:                                  │   │
│  │   - title, author, coverPath, totalChapters, format│   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ Additional fields:                                  │   │
│  │   - id (UUID)                                       │   │
│  │   - filePath                                        │   │
│  │   - currentChapter                                  │   │
│  │   - readingProgress                                 │   │
│  │   - addedAt, lastReadAt                             │   │
│  │   - aiIntroduction                                  │   │
│  │   - chapterTitles                                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Creating from EPUB Parsing

```
// In EpubParser
FUNCTION parseEpub(filePath):
    // Parse OPF file
    opf = parseOpfFile(filePath)
    
    // Extract metadata
    title = opf.getTitle() OR extractTitleFromFileName(filePath)
    author = opf.getCreator() OR '未知'
    
    // Extract cover
    coverPath = extractCoverImage(filePath, opf)
    
    // Count chapters from spine
    totalChapters = countChapters(opf.getSpine())
    
    RETURN NEW BookMetadata(
        title = title,
        author = author,
        coverPath = coverPath,
        totalChapters = totalChapters,
        format = BookFormat.epub
    )
END FUNCTION
```

### Creating from PDF Parsing

```
// In PdfParser
FUNCTION parsePdf(filePath):
    // Open PDF document
    document = openPdf(filePath)
    
    // Extract metadata
    title = document.getInfo().getTitle() OR extractTitleFromFileName(filePath)
    author = document.getInfo().getAuthor() OR '未知'
    
    // Extract cover (first page)
    coverPath = extractFirstPageAsImage(filePath)
    
    // Count pages
    totalChapters = document.getPageCount()
    
    RETURN NEW BookMetadata(
        title = title,
        author = author,
        coverPath = coverPath,
        totalChapters = totalChapters,
        format = BookFormat.pdf
    )
END FUNCTION
```

### Using in Book Creation

```
// In BookService
FUNCTION importBook(filePath):
    // Detect format and parse
    format = detectFormat(filePath)
    
    IF format == BookFormat.epub:
        metadata = epubParser.parse(filePath)
    ELSE IF format == BookFormat.pdf:
        metadata = pdfParser.parse(filePath)
    END IF
    
    // Create Book from metadata
    book = NEW Book(
        id = generateUUID(),
        title = metadata.title,
        author = metadata.author,
        coverPath = metadata.coverPath,
        filePath = filePath,
        format = metadata.format,
        totalChapters = metadata.totalChapters,
        addedAt = DateTime.now()
    )
    
    RETURN book
END FUNCTION
```

### Display in Import Preview

```
// In ImportPreviewScreen
WIDGET buildPreview(BookMetadata metadata):
    RETURN Column(
        children: [
            // Cover image
            IF metadata.coverPath IS NOT NULL:
                Image.file(File(metadata.coverPath))
            ELSE:
                DefaultCoverPlaceholder()
            END IF,
            
            // Title
            Text(metadata.title),
            
            // Author
            Text(metadata.author),
            
            // Format and chapter count
            Text('${metadata.format.name} - ${metadata.totalChapters} chapters'),
            
            // Import button
            ElevatedButton(
                child: Text('Import'),
                onPressed: () => importBook(metadata)
            )
        ]
    )
END WIDGET
```

---

## Notes

1. **No Serialization**: Unlike Book, BookMetadata does not have `toJson()`/`fromJson()` methods because it's only used during parsing and not persisted directly.

2. **Transient Nature**: BookMetadata is a transient object that exists only during the parsing phase. Once a Book is created, the metadata is discarded.

3. **Default Values**: When source file doesn't provide title or author:
   - Title: Use file name (without extension)
   - Author: Use '未知' (Unknown)

4. **Cover Extraction**:
   - EPUB: Extract from OPF manifest or first image
   - PDF: Render first page as image

5. **Chapter Count**:
   - EPUB: Count items in spine or NCX navigation
   - PDF: Use page count (each page treated as a chapter)

6. **Format Detection**: The format is determined by file extension before parsing:
   - `.epub` → BookFormat.epub
   - `.pdf` → BookFormat.pdf