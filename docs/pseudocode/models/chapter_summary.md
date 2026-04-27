# chapter_summary.dart - Pseudocode Documentation

## Overview

This file defines the ChapterSummary model, which represents AI-generated summaries for individual chapters. It is part of the hierarchical reading system, positioned between the full book summary and section summaries.

---

## Class: ChapterSummary

Represents AI-generated summary for a single book chapter, containing objective summary, AI insights, and key points.

### Purpose

- Store AI-generated summary content for each chapter
- Display chapter overview in chapter list interface
- Support JSON serialization for data storage and transmission

### Position in Hierarchical Reading

```
┌─────────────────────────────────────────────────────────────┐
│                    Full Book Summary                         │
│  (Highest level - overview of entire book)                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ChapterSummary                            │
│  (Middle level - summary of each chapter)                   │
│  ← THIS MODEL                                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Section Summary                           │
│  (Lowest level - summary of chapter sections)               │
│  (Note: Section summaries removed in code cleanup)          │
└─────────────────────────────────────────────────────────────┘
```

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `bookId` | `String` | Yes | Associated book's unique ID |
| `chapterIndex` | `int` | Yes | Chapter index in book (0-based) |
| `chapterTitle` | `String` | Yes | Chapter title |
| `objectiveSummary` | `String` | Yes | Objective summary content |
| `aiInsight` | `String` | Yes | AI insights and analysis |
| `keyPoints` | `List<String>` | Yes | List of key points (3-5 items) |
| `createdAt` | `DateTime` | Yes | Summary creation timestamp |

### Property Details

#### bookId

- **Purpose**: Associate summary with specific book
- **Format**: UUID string
- **Relationship**: Links to `Book.id`

#### chapterIndex

- **Purpose**: Identify chapter position in book
- **Format**: Integer (0-based)
- **Consistency**: Matches EPUB parsed chapter list order

#### chapterTitle

- **Purpose**: Display chapter name
- **Source**: Extracted from EPUB TOC or OPF file
- **Examples**: "第一章 引言", "Chapter 1: Introduction"

#### objectiveSummary

- **Purpose**: Objective chapter content overview
- **Content**:
  - Main content overview
  - Core arguments or plot points
  - Important information points
- **Use**: "Read thin" phase - quick understanding of chapter gist

#### aiInsight

- **Purpose**: AI's deep analysis and insights
- **Content**:
  - Viewpoint analysis
  - Writing technique commentary
  - Connections to other chapters
  - Knowledge extensions or extended thinking
- **Use**: "Read thick" phase - deep understanding of chapter meaning

#### keyPoints

- **Purpose**: Extracted core points (3-5 items)
- **Format**: List of concise strings
- **Example**: `['人工智能的发展历史', '机器学习的基本概念', '深度学习的应用场景']`

#### createdAt

- **Purpose**: Record summary generation time
- **Uses**:
  - Display summary timeliness
  - Support time-based sorting
  - Data statistics and analysis

### Constructor

```
CONSTRUCTOR ChapterSummary(bookId, chapterIndex, chapterTitle, 
                           objectiveSummary, aiInsight, keyPoints, createdAt):
    SET bookId = bookId              // Required: book ID
    SET chapterIndex = chapterIndex  // Required: chapter index
    SET chapterTitle = chapterTitle  // Required: chapter title
    SET objectiveSummary = objectiveSummary  // Required: objective summary
    SET aiInsight = aiInsight        // Required: AI insights
    SET keyPoints = keyPoints        // Required: key points list
    SET createdAt = createdAt        // Required: creation time
END CONSTRUCTOR
```

### Methods

#### `toJson() -> Map<String, dynamic>`

**Purpose**: Convert chapter summary to JSON format for storage and transmission.

**Pseudocode**:
```
FUNCTION toJson():
    RETURN {
        'bookId': this.bookId,
        'chapterIndex': this.chapterIndex,
        'chapterTitle': this.chapterTitle,
        'objectiveSummary': this.objectiveSummary,
        'aiInsight': this.aiInsight,
        'keyPoints': this.keyPoints,
        'createdAt': this.createdAt.toIso8601String()  // DateTime to ISO string
    }
END FUNCTION
```

**Output Example**:
```json
{
    "bookId": "550e8400-e29b-41d4-a716-446655440000",
    "chapterIndex": 0,
    "chapterTitle": "第一章 引言",
    "objectiveSummary": "本章介绍了...",
    "aiInsight": "作者通过...",
    "keyPoints": ["要点1", "要点2", "要点3"],
    "createdAt": "2024-04-14T10:30:00.000Z"
}
```

#### `fromJson(Map<String, dynamic> json) -> ChapterSummary` (Factory)

**Purpose**: Create ChapterSummary instance from JSON data.

**Pseudocode**:
```
FUNCTION fromJson(json):
    RETURN NEW ChapterSummary(
        bookId = json['bookId'] OR '',           // Default empty string
        chapterIndex = json['chapterIndex'] OR 0, // Default 0
        chapterTitle = json['chapterTitle'] OR '', // Default empty string
        objectiveSummary = json['objectiveSummary'] OR '', // Default empty string
        aiInsight = json['aiInsight'] OR '',     // Default empty string
        keyPoints = List<String>.from(json['keyPoints'] OR []), // Default empty list
        createdAt = DateTime.parse(json['createdAt'])  // Required, no default
    )
END FUNCTION
```

**Default Value Handling**:
- String fields: Empty string `''`
- Integer fields: `0`
- List fields: Empty list `[]`
- DateTime field: No default, must exist

---

## Data Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                         Book                                │
│  id: String (UUID)                                          │
│  title: String                                              │
│  ...                                                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Has many (via bookId)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ChapterSummary                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ bookId: String ──────────────────────────────────────┼───┐
│  │ chapterIndex: int                                    │   │
│  │ chapterTitle: String                                 │   │
│  │ objectiveSummary: String                             │   │
│  │ aiInsight: String                                    │   │
│  │ keyPoints: List<String>                              │   │
│  │ createdAt: DateTime                                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ References
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Chapter                              │
│  index: int ────────────────────────────────────────────────┼───┐
│  title: String                                              │   │
│  ...                                                         │   │
│  (chapterIndex matches Chapter.index)                       │   │
└─────────────────────────────────────────────────────────────┘   │
                                                                  │
                    Storage:                                      │
                    books/{bookId}/chapter-{index}.md ────────────┘
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Summary Generation Flow                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    SummaryService                           │
│  1. Get chapter content                                     │
│  2. Build AI prompt                                         │
│  3. Call AI API                                             │
│  4. Parse AI response                                       │
│  5. Create ChapterSummary                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    AI Service                               │
│  Input: Chapter plain text                                  │
│  Output: Structured summary                                 │
│                                                              │
│  Prompt Template:                                            │
│  "请为以下章节生成摘要：                                     │
│   1. 客观摘要（200字以内）                                   │
│   2. AI见解（100字以内）                                     │
│   3. 关键要点（3-5个）                                       │
│   章节标题：{chapterTitle}                                   │
│   章节内容：{content}"                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ChapterSummary                           │
│  - objectiveSummary: AI生成的客观摘要                       │
│  - aiInsight: AI生成的见解                                  │
│  - keyPoints: AI提取的关键要点                              │
│  - createdAt: 当前时间                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Storage                                  │
│  books/{bookId}/chapter-{chapterIndex}.md                   │
│                                                              │
│  Markdown Format:                                            │
│  ## {chapterTitle}                                          │
│                                                              │
│  ### 客观摘要                                                │
│  {objectiveSummary}                                         │
│                                                              │
│  ### AI见解                                                  │
│  {aiInsight}                                                │
│                                                              │
│  ### 关键要点                                                │
│  - {keyPoint1}                                              │
│  - {keyPoint2}                                              │
│  - {keyPoint3}                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Usage Examples

### Creating Summary from AI Response

```
// In SummaryService
FUNCTION generateChapterSummary(Book book, Chapter chapter, ChapterContent content):
    // Build AI prompt
    prompt = buildChapterSummaryPrompt(
        chapterTitle = chapter.title,
        content = content.plainText
    )
    
    // Call AI API
    aiResponse = await aiService.generateCompletion(prompt)
    
    // Parse AI response
    parsedResult = parseAiResponse(aiResponse)
    
    // Create ChapterSummary
    summary = NEW ChapterSummary(
        bookId = book.id,
        chapterIndex = chapter.index,
        chapterTitle = chapter.title,
        objectiveSummary = parsedResult.objectiveSummary,
        aiInsight = parsedResult.aiInsight,
        keyPoints = parsedResult.keyPoints,
        createdAt = DateTime.now()
    )
    
    // Save summary
    saveChapterSummary(summary)
    
    RETURN summary
END FUNCTION
```

### Parsing AI Response

```
FUNCTION parseAiResponse(String response):
    // Expected format:
    // 客观摘要：...
    // AI见解：...
    // 关键要点：1. ... 2. ... 3. ...
    
    sections = splitBySections(response)
    
    objectiveSummary = extractSection(sections, '客观摘要')
    aiInsight = extractSection(sections, 'AI见解')
    keyPoints = extractKeyPoints(sections, '关键要点')
    
    RETURN {
        'objectiveSummary': objectiveSummary,
        'aiInsight': aiInsight,
        'keyPoints': keyPoints
    }
END FUNCTION

FUNCTION extractKeyPoints(String section):
    // Parse numbered or bulleted list
    points = []
    
    FOR EACH line IN section.split('\n'):
        IF line MATCHES pattern '^\d+\.' OR '^-' OR '^•':
            // Remove prefix and add to list
            point = removePrefix(line)
            points.add(point.trim())
        END IF
    END FOR
    
    RETURN points
END FUNCTION
```

### Display in UI

```
// In ChapterScreen
WIDGET buildChapterSummaryView(ChapterSummary summary):
    RETURN Column(
        children: [
            // Chapter title
            Text(
                summary.chapterTitle,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            
            // Objective summary section
            ExpansionTile(
                title: Text('客观摘要'),
                children: [
                    MarkdownBody(data: summary.objectiveSummary)
                ]
            ),
            
            // AI insight section
            ExpansionTile(
                title: Text('AI见解'),
                children: [
                    MarkdownBody(data: summary.aiInsight)
                ]
            ),
            
            // Key points section
            ExpansionTile(
                title: Text('关键要点'),
                children: [
                    FOR EACH point IN summary.keyPoints:
                        ListTile(
                            leading: Icon(Icons.circle, size: 8),
                            title: Text(point)
                        )
                    END FOR
                ]
            ),
            
            // Creation time
            Text(
                '生成时间：${formatDateTime(summary.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey)
            )
        ]
    )
END WIDGET
```

### Serialization

```
// Save to JSON
summary = NEW ChapterSummary(
    bookId = '550e8400-e29b-41d4-a716-446655440000',
    chapterIndex = 0,
    chapterTitle = '第一章 引言',
    objectiveSummary = '本章介绍了...',
    aiInsight = '作者通过...',
    keyPoints = ['要点1', '要点2', '要点3'],
    createdAt = DateTime.now()
)

json = summary.toJson()
// Result:
// {
//   'bookId': '550e8400-e29b-41d4-a716-446655440000',
//   'chapterIndex': 0,
//   'chapterTitle': '第一章 引言',
//   'objectiveSummary': '本章介绍了...',
//   'aiInsight': '作者通过...',
//   'keyPoints': ['要点1', '要点2', '要点3'],
//   'createdAt': '2024-04-14T10:30:00.000Z'
// }

// Load from JSON
restoredSummary = ChapterSummary.fromJson(json)
```

### Export to Markdown

```
// In ExportService
FUNCTION exportChapterSummary(ChapterSummary summary):
    markdown = '''
## ${summary.chapterTitle}

### 客观摘要
${summary.objectiveSummary}

### AI见解
${summary.aiInsight}

### 关键要点
${summary.keyPoints.map((p) => '- $p').join('\n')}

---
生成时间：${formatDateTime(summary.createdAt)}
'''
    
    RETURN markdown
END FUNCTION
```

---

## Notes

1. **Hierarchical Reading**: ChapterSummary is the middle layer in the hierarchical reading system:
   - "Read thin": Use objectiveSummary for quick understanding
   - "Read thick": Use aiInsight for deep analysis

2. **Key Points Count**: Typically 3-5 key points are extracted, providing a balance between completeness and brevity.

3. **Timestamp Importance**: The `createdAt` field is crucial for:
   - Tracking summary freshness
   - Re-generating outdated summaries
   - User progress tracking

4. **Default Values**: When deserializing, default values are provided for robustness:
   - Empty strings for text fields
   - Empty list for keyPoints
   - No default for createdAt (must exist in JSON)

5. **Storage Format**: Summaries are stored as Markdown files in `books/{bookId}/chapter-{index}.md`, allowing:
   - Human-readable format
   - Easy export
   - Version control compatibility

6. **AI Prompt Design**: The prompt template should request structured output:
   - Objective summary (neutral, factual)
   - AI insight (analytical, interpretive)
   - Key points (concise, actionable)

7. **Chapter Index Consistency**: The `chapterIndex` must match the corresponding `Chapter.index` for proper association.