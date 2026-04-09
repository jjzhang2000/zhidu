import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../models/book.dart' as model;

part 'books_dao.g.dart';

@DriftAccessor(tables: [Books])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(AppDatabase db) : super(db);

  Future<List<model.Book>> getAllBooks() async {
    final books = await select(books).get();
    return books.map(_tableToModel).toList();
  }

  Future<model.Book?> getBookById(String id) async {
    final book =
        await (select(books)..where((b) => b.id.equals(id))).getSingleOrNull();
    return book != null ? _tableToModel(book) : null;
  }

  Future<void> insertBook(model.Book book) async {
    await into(books).insert(_modelToCompanion(book));
  }

  Future<void> updateBook(model.Book bookModel) async {
    await (update(books)..where((b) => b.id.equals(bookModel.id))).write(
      BooksCompanion(
        title: Value(bookModel.title),
        author: Value(bookModel.author),
        filePath: Value(bookModel.filePath),
        coverPath: Value(bookModel.coverPath),
        currentChapter: Value(bookModel.currentChapter),
        readingProgress: Value(bookModel.readingProgress),
        lastReadAt: Value(bookModel.lastReadAt?.millisecondsSinceEpoch),
        aiIntroduction: Value(bookModel.aiIntroduction),
        totalChapters: Value(bookModel.totalChapters),
      ),
    );
  }

  Future<void> deleteBook(String id) async {
    await (delete(books)..where((b) => b.id.equals(id))).go();
  }

  Stream<List<model.Book>> watchAllBooks() {
    return select(books).watch().map(
          (books) => books.map(_tableToModel).toList(),
        );
  }

  model.Book _tableToModel(BookTable table) {
    return model.Book(
      id: table.id,
      title: table.title,
      author: table.author,
      filePath: table.filePath,
      coverPath: table.coverPath,
      currentChapter: table.currentChapter,
      readingProgress: table.readingProgress,
      lastReadAt: table.lastReadAt != null
          ? DateTime.fromMillisecondsSinceEpoch(table.lastReadAt!)
          : null,
      aiIntroduction: table.aiIntroduction,
      totalChapters: table.totalChapters,
    );
  }

  BooksCompanion _modelToCompanion(model.Book model) {
    return BooksCompanion(
      id: Value(model.id),
      title: Value(model.title),
      author: Value(model.author),
      filePath: Value(model.filePath),
      coverPath: Value(model.coverPath),
      currentChapter: Value(model.currentChapter),
      readingProgress: Value(model.readingProgress),
      lastReadAt: Value(model.lastReadAt?.millisecondsSinceEpoch),
      aiIntroduction: Value(model.aiIntroduction),
      totalChapters: Value(model.totalChapters),
    );
  }
}
