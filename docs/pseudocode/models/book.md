# book.dart - Pseudocode Documentation

## Overview

This file defines the book entity model and the book format enumeration. The Book class represents a complete book with all its metadata, reading progress, and AI-generated content.

---

## Enum: BookFormat

Defines supported book file formats.

### Values

| Value | Description |
|-------|-------------|
| `pdf` | PDF format |
| `epub` | EPUB format (primary supported format) |

---

## Class: Book

Book entity class representing complete book information including metadata, reading progress, and AI-generated content.

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `String` | Yes | Unique identifier (UUID format) |
| `title` | `String` | Yes | Book title |
| `author` | `String` | Yes | Book author |
| `coverPath` | `String?` | No | Cover image path (nullable) |
| `filePath` | `String` | Yes | Local file path |
| `format` | `BookFormat` | Yes | File format (EPUB/PDF) |
| `totalChapters` | `int` | No | Total chapter count (default: 0) |
| `currentChapter` | `int` | No | Current reading chapter index (default: 0) |
| `readingProgress` | `double` | No | Reading progress percentage 0.0-1.0 (default: 0.0) |
| `addedAt` | `DateTime` | Yes | Time added to bookshelf |
| `lastReadAt` | `DateTime?` | No | Last reading time (nullable) |
| `aiIntroduction` | `String?` | No | AI-generated book introduction (nullable) |
| `chapterTitles` | `Map<int, String>?` | No | Chapter index to title mapping (nullable) |

### Constructor

```
CONSTRUCTOR Book(id, title, author, coverPath, filePath, format, 
                 totalChapters, currentChapter, readingProgress, 
                 addedAt, lastReadAt, aiIntroduction, chapterTitles):
    SET id = id                              // Required
    SET title = title                        // Required
    SET author = author                      // Required
    SET coverPath = coverPath                // Optional, default NULL
    SET filePath = filePath                  // Required
    SET format = format                      // Required
    SET totalChapters = totalChapters OR 0   // Default 0
    SET currentChapter = currentChapter OR 0 // Default 0
    SET readingProgress = readingProgress OR 0.0  // Default 0.0
    SET addedAt = addedAt                    // Required
    SET lastReadAt = lastReadAt              // Optional, default NULL
    SET aiIntroduction = aiIntroduction      // Optional, default NULL
    SET chapterTitles = chapterTitles        // Optional, default NULL
END CONSTRUCTOR
```

### Methods

#### `copyWith(...) -> Book`

**Purpose**: Create a copy of Book with optionally modified fields.

**Parameters**: All properties are optional parameters.

**Pseudocode**:
```
FUNCTION copyWith(id, title, author, coverPath, filePath, format,
                  totalChapters, currentChapter, readingProgress,
                  addedAt, lastReadAt, aiIntroduction, chapterTitles):
    RETURN NEW Book(
        id = id OR this.id,
        title = title OR this.title,
        author = author OR this.author,
        coverPath = coverPath OR this.coverPath,
        filePath = filePath OR this.filePath,
        format = format OR this.format,
        totalChapters = totalChapters OR this.totalChapters,
        currentChapter = currentChapter OR this.currentChapter,
        readingProgress = readingProgress OR this.readingProgress,
        addedAt = addedAt OR this.addedAt,
        lastReadAt = lastReadAt OR this.lastReadAt,
        aiIntroduction = aiIntroduction OR this.aiIntroduction,
        chapterTitles = chapterTitles OR this.chapterTitles
    )
END FUNCTION
```

**Callers**: BookService (when updating book information)

#### `toJson() -> Map<String, dynamic>`

**Purpose**: Serialize Book instance to JSON format Map.

**Pseudocode**:
```
FUNCTION toJson():
    // Convert chapterTitles map keys from int to String
    chapterTitlesJson = NULL
    IF this.chapterTitles IS NOT NULL:
        chapterTitlesJson = {}
        FOR EACH (key, value) IN this.chapterTitles:
            chapterTitlesJson[key.toString()] = value
        END FOR
    END IF

    RETURN {
        'id': this.id,
        'title': this.title,
        'author': this.author,
        'coverPath': this.coverPath,
        'filePath': this.filePath,
        'format': this.format.name,  // Convert enum to string
        'totalChapters': this.totalChapters,
        'currentChapter': this.currentChapter,
        'readingProgress': this.readingProgress,
        'addedAt': this.addedAt.toIso8601String(),  // DateTime to ISO string
        'lastReadAt': this.lastReadAt?.toIso8601String(),  // Nullable
        'aiIntroduction': this.aiIntroduction,
        'chapterTitles': chapterTitlesJson
    }
END FUNCTION
```

**Callers**: Database (storage), ExportService (export)

#### `fromJson(Map<String, dynamic> json) -> Book` (Factory)

**Purpose**: Deserialize JSON Map to Book instance.

**Pseudocode**:
```
FUNCTION fromJson(json):
    // Parse chapterTitles map keys from String to int
    chapterTitlesRaw = json['chapterTitles'] AS Map<String, dynamic>?
    chapterTitles = NULL
    IF chapterTitlesRaw IS NOT NULL:
        chapterTitles = {}
        FOR EACH (key, value) IN chapterTitlesRaw:
            chapterTitles[int.parse(key)] = value AS String
        END FOR
    END IF

    // Parse format enum from string
    formatString = json['format']
    format = BookFormat.values.FIRST_WHERE(
        (e) => e.name == formatString,
        orElse: () => BookFormat.epub  // Default fallback
    )

    // Parse DateTime fields
    addedAt = DateTime.parse(json['addedAt'])
    lastReadAt = NULL
    IF json['lastReadAt'] IS NOT NULL:
        lastReadAt = DateTime.parse(json['lastReadAt'])
    END IF

    RETURN NEW Book(
        id = json['id'],
        title = json['title'],
        author = json['author'],
        coverPath = json['coverPath'],
        filePath = json['filePath'],
        format = format,
        totalChapters = json['totalChapters'] OR 0,
        currentChapter = json['currentChapter'] OR 0,
        readingProgress = json['readingProgress']?.toDouble() OR 0.0,
        addedAt = addedAt,
        lastReadAt = lastReadAt,
        aiIntroduction = json['aiIntroduction'],
        chapterTitles = chapterTitles
    )
END FUNCTION
```

**Callers**: Database (reading), BookService (loading data)

---

## Data Relationships

```
Book
├── id: String (UUID)
├── title: String
├── author: String
├── coverPath: String? ──────────────────┐
├── filePath: String                     │
├── format: BookFormat (enum)           │
├── totalChapters: int                   │
├── currentChapter: int                  │
├── readingProgress: double              │
├── addedAt: DateTime                    │
├── lastReadAt: DateTime?                │
├── aiIntroduction: String?              │
└── chapterTitles: Map<int, String>?     │
                                         │
        Related Models:                  │
        ┌────────────────────────────────┘
        │
        ├── BookMetadata (simplified book info)
        ├── Chapter (chapter details)
        ├── ChapterSummary (AI-generated summary)
        └── ChapterContent (chapter text content)
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    File Import Flow                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  BookService.importBook()                                    │
│  1. Parse file (EPUB/PDF)                                    │
│  2. Extract metadata → BookMetadata                         │
│  3. Create Book with metadata                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Book Instance                           │
│  - id: generated UUID                                        │
│  - title, author: from metadata                              │
│  - filePath: original file path                              │
│  - format: detected format                                   │
│  - addedAt: current timestamp                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Storage Flow                               │
│  books_index.json ─────────────────────────────────────────┐│
│  books/{bookId}/metadata.json ─────────────────────────────┼┤
│  books/{bookId}/cover.jpg ────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Creating a Book

```
// Create book from parsed metadata
book = NEW Book(
    id = generateUUID(),
    title = '三体',
    author = '刘慈欣',
    filePath = '/path/to/book.epub',
    format = BookFormat.epub,
    addedAt = DateTime.now(),
    totalChapters = 45,
    coverPath = '/path/to/cover.jpg'
)
```

### Updating Reading Progress

```
// Update reading progress
updatedBook = book.copyWith(
    currentChapter = 10,
    readingProgress = 0.35,
    lastReadAt = DateTime.now()
)
```

### Updating AI Introduction

```
// After AI generates book introduction
updatedBook = book.copyWith(
    aiIntroduction = '这是一部科幻小说...'
)
```

### Updating Chapter Titles

```
// After parsing chapter structure
chapterTitles = {
    0: '第一章 科学边界',
    1: '第二章 三体',
    2: '第三章 人类落日'
}
updatedBook = book.copyWith(
    chapterTitles = chapterTitles,
    totalChapters = 3
)
```

### Serialization

```
// Save to JSON
json = book.toJson()
// Result:
// {
//   'id': '550e8400-e29b-41d4-a716-446655440000',
//   'title': '三体',
//   'author': '刘慈欣',
//   'format': 'epub',
//   ...
// }

// Load from JSON
restoredBook = Book.fromJson(json)
```

---

## Notes

1. **UUID Generation**: The `id` field should be generated using UUID to ensure uniqueness.

2. **Progress Calculation**: `readingProgress` is a value between 0.0 and 1.0, typically calculated as `currentChapter / totalChapters`.

3. **Chapter Titles Map**: The `chapterTitles` map uses integer keys (chapter index) for efficient lookup.

4. **Nullable Fields**: `coverPath`, `lastReadAt`, `aiIntroduction`, and `chapterTitles` are nullable to handle cases where:
   - Book has no cover image
   - Book has never been read
   - AI introduction hasn't been generated
   - Chapter titles haven't been parsed

5. **Format Fallback**: When deserializing, if the format string doesn't match any enum value, it defaults to `BookFormat.epub`.