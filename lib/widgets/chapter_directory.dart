// 书籍封面与章节目录组件
//
// 书籍详情页与阅读页「目录」Tab 共用同一套封面与章节列表样式，
// 避免两处重复维护缩进/字号/配色规则。
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/chapter.dart';

/// 书籍封面（无封面或读取失败时回退到默认图标）
class BookCover extends StatelessWidget {
  final Book book;

  /// 封面宽度，高度按 2:3 比例计算
  final double width;

  const BookCover({super.key, required this.book, this.width = 200});

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    final path = book.coverPath;
    if (path != null && File(path).existsSync()) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildDefaultCover(height),
        ),
      );
    }
    return _buildDefaultCover(height);
  }

  Widget _buildDefaultCover(double height) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blueGrey[100],
        ),
        child: Center(
          child: Icon(
            Icons.book,
            size: width * 0.4,
            color: Colors.blueGrey[300],
          ),
        ),
      ),
    );
  }
}

/// 章节列表项（按层级缩进、字号递减、子章节灰色）
///
/// [onChapterTap] 为点击回调；[currentChapterIndex] 用于高亮当前阅读的顶层章节。
List<Widget> buildChapterTiles(
  BuildContext context, {
  required List<Chapter> chapters,
  required void Function(Chapter) onChapterTap,
  int? currentChapterIndex,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  // 章节标题字号基于主题正文字号，随主题/系统字号变化
  final baseFontSize = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16;
  final widgets = <Widget>[];
  for (final chapter in chapters) {
    // 根据层级添加缩进（每层缩进16像素）
    final indent = chapter.level * 16.0;
    final isCurrent = chapter.level == 0 &&
        currentChapterIndex != null &&
        chapter.index == currentChapterIndex;

    widgets.add(
      Padding(
        padding: EdgeInsets.only(left: indent),
        child: ListTile(
          dense: true,
          title: Text(
            chapter.title,
            style: TextStyle(
              // 字体大小随层级递减（相对正文字号）
              fontSize: baseFontSize - 1 - chapter.level,
              // 子章节颜色较淡；当前章节用主题色
              color: isCurrent
                  ? primary
                  : chapter.level > 0
                      ? Colors.grey[600]
                      : null,
              fontWeight: isCurrent ? FontWeight.bold : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onChapterTap(chapter),
        ),
      ),
    );
  }
  return widgets;
}

/// 章节目录（封面 + 全层级章节列表），供阅读页「目录」Tab 使用
class ChapterDirectory extends StatelessWidget {
  final Book? book;
  final List<Chapter> chapters;

  /// 当前阅读的顶层章节索引（用于高亮）
  final int? currentChapterIndex;

  final void Function(Chapter) onChapterTap;

  const ChapterDirectory({
    super.key,
    required this.book,
    required this.chapters,
    required this.onChapterTap,
    this.currentChapterIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return const Center(child: Text('暂无章节信息'));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (book != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BookCover(book: book!, width: 88),
            ),
          ),
        ...buildChapterTiles(
          context,
          chapters: chapters,
          onChapterTap: onChapterTap,
          currentChapterIndex: currentChapterIndex,
        ),
      ],
    );
  }
}
