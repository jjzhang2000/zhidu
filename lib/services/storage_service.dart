
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';

class StorageService {
  static const String _booksFileName = 'books.json';
  static const String _summariesDirName = 'Summaries';
  
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  
  StorageService._();
  
  Future<String> get _appDirPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
  
  Future<String> get _summariesDirPath async {
    final appDir = await _appDirPath;
    return '$appDir/$_summariesDirName';
  }
  
  Future<void> init() async {
    // 确保Summaries目录存在
    final summariesDir = Directory(await _summariesDirPath);
    if (!await summariesDir.exists()) {
      await summariesDir.create(recursive: true);
    }
  }
  
  // 书籍列表管理
  Future<List<Book>> getBooks() async {
    final appDir = await _appDirPath;
    final file = File('$appDir/$_booksFileName');
    
    if (!await file.exists()) {
      return [];
    }
    
    final content = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(content);
    return jsonList.map((json) => Book.fromJson(json)).toList();
  }
  
  Future<void> saveBooks(List<Book> books) async {
    final appDir = await _appDirPath;
    final file = File('$appDir/$_booksFileName');
    
    final jsonList = books.map((book) => book.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }
  
  Future<void> addBook(Book book) async {
    final books = await getBooks();
    books.add(book);
    await saveBooks(books);
  }
  
  Future<void> updateBook(Book book) async {
    final books = await getBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      books[index] = book;
      await saveBooks(books);
    }
  }
  
  Future<void> deleteBook(String bookId) async {
    final books = await getBooks();
    books.removeWhere((b) => b.id == bookId);
    await saveBooks(books);
    
    // 同时删除对应的摘要文件
    await deleteSummary(bookId);
  }
  
  // 摘要文件管理
  Future<String> getSummaryFilePath(String bookTitle, String author) async {
    final summariesDir = await _summariesDirPath;
    final fileName = '${bookTitle}_${author}_Summary.md'
        .replaceAll(RegExp(r'[<>"/\\|?*]'), '_');
    return '$summariesDir/$fileName';
  }
  
  Future<void> saveSummary(String bookTitle, String author, String content) async {
    final filePath = await getSummaryFilePath(bookTitle, author);
    final file = File(filePath);
    await file.writeAsString(content);
  }
  
  Future<String?> getSummary(String bookTitle, String author) async {
    final filePath = await getSummaryFilePath(bookTitle, author);
    final file = File(filePath);
    
    if (!await file.exists()) {
      return null;
    }
    
    return await file.readAsString();
  }
  
  Future<void> deleteSummary(String bookId) async {
    // 根据bookId找到对应的书籍，然后删除摘要
    final books = await getBooks();
    final book = books.firstWhere(
      (b) => b.id == bookId,
      orElse: () => throw Exception('Book not found'),
    );
    
    final filePath = await getSummaryFilePath(book.title, book.author);
    final file = File(filePath);
    
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  Future<List<String>> getAllSummaries() async {
    final summariesDir = Directory(await _summariesDirPath);
    
    if (!await summariesDir.exists()) {
      return [];
    }
    
    final files = await summariesDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.md'))
        .map((entity) => entity.path)
        .toList();
    
    return files;
  }
}