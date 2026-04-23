# Home Screen - Pseudocode Documentation

## Overview

**File**: `lib/screens/home_screen.dart`
**Purpose**: Application home screen with bookshelf, import, and search
**Pattern**: StatefulWidget with GlobalKey for child state management

---

## StatefulWidget Structure

```
HomeScreen (StatefulWidget)
└── _HomeScreenState (State)
    ├── Services: BookService, LogService
    ├── GlobalKey: _bookshelfKey (for child refresh)
    └── Methods: _importBook()
```

```
BookshelfScreen (StatefulWidget)
└── _BookshelfScreenState (State)
    ├── Services: BookService, LogService
    ├── Controller: _searchController
    ├── State: _searchQuery
    └── Methods: refresh(), _buildEmptyState(), _buildBookGrid()
```

```
BookCard (StatefulWidget)
├── Parameters: Book book, VoidCallback? onDeleted
└── _BookCardState (State)
    ├── State: _isHovered
    ├── Services: BookService, SummaryService
    └── Methods: _openBook(), _showDeleteConfirmDialog()
```

---

## State Variables

### HomeScreen State

| Variable | Type | Purpose |
|----------|------|---------|
| `_bookService` | BookService | Book import singleton |
| `_log` | LogService | Debug logging |
| `_bookshelfKey` | GlobalKey | Access BookshelfScreen state |

### BookshelfScreen State

| Variable | Type | Purpose |
|----------|------|---------|
| `_bookService` | BookService | Book list and search |
| `_log` | LogService | Debug logging |
| `_searchController` | TextEditingController | Search input |
| `_searchQuery` | String | Current search filter |

### BookCard State

| Variable | Type | Purpose |
|----------|------|---------|
| `_isHovered` | bool | Mouse hover state (delete button) |
| `_bookService` | BookService | Book operations |
| `_summaryService` | SummaryService | Summary cleanup |

---

## Methods Pseudocode

### HomeScreen Methods

#### `_importBook()`

```
ASYNC PROCEDURE _importBook():
  _log.v('HomeScreen', '_importBook 开始执行')
  
  book = AWAIT _bookService.importBook()
  
  IF book != null AND mounted:
    _log.v('HomeScreen', '书籍导入成功: ${book.title}')
    
    // Refresh bookshelf via GlobalKey
    _bookshelfKey.currentState?.refresh()
    
    // Show success message
    loc = AppLocalizations.of(context)
    ScaffoldMessenger.showSnackBar(
      content: Text(loc.addedSuccessfully(book.title)),
      duration: 2 seconds
    )
  ELSE:
    _log.v('HomeScreen', '书籍导入被取消或失败')
END PROCEDURE
```

### BookshelfScreen Methods

#### `refresh()`

```
PROCEDURE refresh():
  _log.v('BookshelfScreen', 'refresh 开始执行')
  
  setState():
    _log.v('BookshelfScreen', 'setState called in refresh')
  
  // Triggers rebuild, re-fetches books from BookService
END PROCEDURE
```

#### `dispose()`

```
PROCEDURE dispose():
  _log.v('BookshelfScreen', 'dispose 开始执行')
  _searchController.dispose()
  super.dispose()
  _log.v('BookshelfScreen', 'dispose 执行完成')
END PROCEDURE
```

#### `_buildEmptyState(isSearching)`

```
PROCEDURE _buildEmptyState(isSearching):
  RETURN Center: Column
    ├── Icon:
    │   IF isSearching: Icons.search_off (size: 80)
    │   ELSE: Icons.library_books (size: 80)
    ├── SizedBox(height: 16)
    ├── Text:
    │   IF isSearching: "未找到相关书籍"
    │   ELSE: "书架空空如也"
    ├── SizedBox(height: 8)
    └── Text:
        IF isSearching: "请尝试其他关键词"
        ELSE: "点击右下角按钮添加书籍"
END PROCEDURE
```

#### `_buildBookGrid(books)`

```
PROCEDURE _buildBookGrid(books):
  RETURN GridView.builder
    ├── padding: 12
    ├── gridDelegate:
    │   ├── crossAxisCount: 4
    │   ├── childAspectRatio: 0.7
    │   ├── crossAxisSpacing: 12
    │   └── mainAxisSpacing: 12
    ├── itemCount: books.length
    └── itemBuilder: BookCard(book, onDeleted: setState)
END PROCEDURE
```

### BookCard Methods

#### `_buildCover()`

```
PROCEDURE _buildCover():
  IF book.coverPath != null AND File(coverPath).existsSync():
    RETURN Image.file(coverPath, fit: cover)
      └── errorBuilder: _buildDefaultCover()
  ELSE:
    RETURN _buildDefaultCover()
END PROCEDURE
```

#### `_buildDefaultCover()`

```
PROCEDURE _buildDefaultCover():
  RETURN Container
    ├── color: blueGrey[100]
    └── Center: Icon(Icons.book, size: 48, blueGrey[300])
END PROCEDURE
```

#### `_openBook(context)`

```
ASYNC PROCEDURE _openBook(context):
  // Get latest book data (avoid stale data)
  latestBook = _bookService.getBookById(book.id) OR book
  
  AWAIT Navigator.push(
    BookDetailScreen(book: latestBook)
  )
  
  // Refresh card after return (update progress)
  IF mounted:
    setState()
END PROCEDURE
```

#### `_showDeleteConfirmDialog(context)`

```
ASYNC PROCEDURE _showDeleteConfirmDialog(context):
  confirmed = AWAIT showDialog<bool>
    ├── AlertDialog
    │   ├── title: "确认移除"
    │   ├── content: "确定要从书架移除《${book.title}》吗？"
    │   └── actions:
    │       ├── TextButton("取消") → pop(false)
    │       └── TextButton("移除", red) → pop(true)
  
  IF confirmed == true AND mounted:
    // Delete book record
    AWAIT _bookService.deleteBook(book.id)
    
    // Delete all summaries for this book
    AWAIT _summaryService.deleteAllSummariesForBook(book.id)
    
    // Notify parent to refresh list
    onDeleted?.call()
    
    // Show success message
    IF mounted:
      ScaffoldMessenger.showSnackBar(
        content: Text("已移除《${book.title}》")
      )
END PROCEDURE
```

---

## Widget Tree Structure

### HomeScreen Widget Tree

```
Scaffold
├── Body: BookshelfScreen(key: _bookshelfKey)
└── FloatingActionButton
    ├── child: Icon(Icons.add)
    └── onPressed: _importBook()
```

### BookshelfScreen Widget Tree

```
Scaffold
├── AppBar
│   ├── Title: "智读"
│   ├── centerTitle: true
│   └── actions: [
│       ├── Container (search box)
│       │   ├── width: 160, height: 32
│       │   ├── decoration: white.withOpacity(0.15), borderRadius: 16
│       │   └── TextField
│       │       ├── controller: _searchController
│       │       ├── hintText: "搜索"
│       │       ├── prefixIcon: Icon(Icons.search)
│       │       └── onChanged: update _searchQuery
│       ├── IconButton(Icons.settings)
│       │   └── onPressed: navigate to SettingsScreen
│       └── SizedBox(width: 8)
│   ]
│
└── Body:
    IF books.isEmpty:
      _buildEmptyState(isSearching: _searchQuery.isNotEmpty)
    ELSE:
      _buildBookGrid(books)
```

### BookCard Widget Tree

```
MouseRegion
├── onEnter: setState(_isHovered = true)
├── onExit: setState(_isHovered = false)
└── GestureDetector(onTap: _openBook)
    └── Card(clipBehavior: antiAlias)
        └── Column
            ├── Expanded(flex: 4): Stack
            │   ├── _buildCover() (fit: expand)
            │   └── IF _isHovered: Positioned(right: 4, bottom: 4)
            │       └── Material(red circle)
            │           └── InkWell(onTap: _showDeleteConfirmDialog)
            │               └── Icon(Icons.remove, white, size: 18)
            │
            └── Expanded(flex: 1): Padding(8)
                └── Column
                    ├── Text: book.title (bold, fontSize: 12, maxLines: 1)
                    ├── SizedBox(height: 2)
                    ├── Text: book.author (grey, fontSize: 10, maxLines: 1)
                    ├── Spacer()
                    └── IF book.readingProgress > 0:
                        LinearProgressIndicator(value: progress)
```

---

## User Interaction Flows

### Flow 1: Import Book

```
User taps FAB (+) button
    ↓
_importBook() called
    ↓
BookService.importBook()
    ↓
File picker opens (EPUB/PDF filter)
    ↓
User selects file
    ↓
BookService parses file
    ├── Extract metadata (title, author, cover)
    ├── Parse chapter structure
    └── Save to books_index.json
    ↓
RETURN Book object
    ↓
_bookshelfKey.currentState.refresh()
    ↓
BookshelfScreen rebuilds
    ↓
New book appears in grid
    ↓
SnackBar shows success message
```

### Flow 2: Search Books

```
User types in search box
    ↓
onChanged callback
    ↓
setState(): _searchQuery = input
    ↓
build() re-executes
    ↓
IF _searchQuery.isEmpty:
  books = _bookService.books (all books)
ELSE:
  books = _bookService.searchBooks(_searchQuery)
    ↓
Display filtered book grid
    ↓
IF no results:
  Show "未找到相关书籍" empty state
```

### Flow 3: Open Book

```
User taps book card
    ↓
_openBook() called
    ↓
Get latest book from BookService
    ↓
Navigator.push(BookDetailScreen)
    ↓
User views book details
    ↓
Navigator.pop (return)
    ↓
setState() refreshes card
    ↓
Reading progress updates
```

### Flow 4: Delete Book

```
User hovers over book card
    ↓
_isHovered = true
    ↓
Delete button appears (red circle)
    ↓
User taps delete button
    ↓
_showDeleteConfirmDialog()
    ↓
AlertDialog appears
    ↓
User confirms "移除"
    ↓
BookService.deleteBook(book.id)
    ↓
SummaryService.deleteAllSummariesForBook(book.id)
    ↓
onDeleted callback
    ↓
Parent setState() refreshes grid
    ↓
Book removed from display
    ↓
SnackBar shows removal message
```

### Flow 5: Navigate to Settings

```
User taps settings icon in AppBar
    ↓
Navigator.push(SettingsScreen)
    ↓
Settings screen displays
    ↓
User configures AI/theme/etc.
    ↓
Navigator.pop (return)
    ↓
Back to bookshelf
```

---

## Navigation Flow

```
HomeScreen
├── FloatingActionButton → Import Book
├── BookshelfScreen
│   ├── BookCard → BookDetailScreen
│   └── Settings icon → SettingsScreen
│   └── Search box → Filter books
```

---

## Data Flow

### Book Import Flow

```
User selects file
    ↓
BookService.importBook()
    ├── file_picker.pickFiles()
    ├── FormatRegistry.getParser(extension)
    ├── parser.parse(filePath)
    ├── Create Book object
    ├── Save metadata.json
    ├── Save cover image
    └── Update books_index.json
    ↓
RETURN Book
```

### Book Search Flow

```
_searchQuery updated
    ↓
BookService.searchBooks(query)
    ├── Filter books by title/author
    ├── Case-insensitive match
    └── RETURN filtered list
    ↓
Display in GridView
```

### Book Delete Flow

```
User confirms deletion
    ↓
BookService.deleteBook(bookId)
    ├── Remove from books_index.json
    └── Delete book directory
    ↓
SummaryService.deleteAllSummariesForBook(bookId)
    ├── Delete all chapter summaries
    └── Delete book summary
    ↓
UI refresh via onDeleted callback
```

---

## GlobalKey Pattern

```
HomeScreen
├── _bookshelfKey = GlobalKey<_BookshelfScreenState>
├── BookshelfScreen(key: _bookshelfKey)
│   └── _BookshelfScreenState
│       └── refresh() method
│
Import success:
    ↓
_bookshelfKey.currentState?.refresh()
    ↓
BookshelfScreen.setState()
    ↓
Grid rebuilds with new book
```

**Purpose**: Allow parent (HomeScreen) to trigger child (BookshelfScreen) refresh without rebuilding entire tree.

---

## Conditional Rendering

### Empty State Logic

```
books.isEmpty AND _searchQuery.isEmpty
    → "书架空空如也" (empty bookshelf)

books.isEmpty AND _searchQuery.isNotEmpty
    → "未找到相关书籍" (search no results)

books.isNotEmpty
    → GridView with BookCards
```

### Delete Button Visibility

```
_isHovered = false → Delete button hidden
_isHovered = true → Delete button visible (red circle)

Trigger: MouseRegion onEnter/onExit
```

### Reading Progress Bar

```
book.readingProgress == 0 → No progress bar
book.readingProgress > 0 → LinearProgressIndicator shown

Progress value: 0.0 to 1.0
```

---

## Service Integration

### BookService

```
IMPORT: importBook() → Book?
  - Opens file picker
  - Parses selected file
  - Saves to storage

READ: books → List<Book>
  - All books in library

READ: getBookById(id) → Book?
  - Single book lookup

SEARCH: searchBooks(query) → List<Book>
  - Filter by title/author

DELETE: deleteBook(id)
  - Remove from index
  - Delete directory
```

### SummaryService

```
DELETE: deleteAllSummariesForBook(bookId)
  - Remove all chapter summaries
  - Remove book summary
  - Clean up storage
```

---

## Responsive Layout

```
GridView configuration:
├── crossAxisCount: 4 (4 books per row)
├── childAspectRatio: 0.7 (vertical cards)
├── crossAxisSpacing: 12 (horizontal gap)
└── mainAxisSpacing: 12 (vertical gap)

BookCard proportions:
├── Cover: 4/5 height (flex: 4)
└── Info: 1/5 height (flex: 1)
```