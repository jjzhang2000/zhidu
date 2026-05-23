/// PDF阅读器界面
///
/// 提供PDF格式书籍的阅读功能，支持页面导航和章节定位。
/// 使用pdfrx库实现PDF渲染和交互。
///
/// 主要功能：
/// - PDF文件渲染和显示
/// - 页面翻阅和导航
/// - 章节定位（通过初始页码）
/// - 阅读进度跟踪
///
/// 与EPUB阅读器的区别：
/// - PDF是固定布局，无法重排文本
/// - 使用pdfrx库而非自定义HTML渲染
/// - 页面导航基于页码，而非章节内的小节
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/log_service.dart';

/// PDF阅读器Widget
///
/// 用于显示PDF格式书籍内容，支持从特定章节或页面开始阅读。
///
/// 参数说明：
/// - [book]: 必需，要阅读的书籍对象，包含文件路径等元数据
/// - [chapter]: 可选，起始章节，用于设置AppBar标题和初始页码
/// - [initialPage]: 初始页码，默认为1，用于恢复阅读进度或章节定位
///
/// 使用示例：
/// ```dart
/// // 从头开始阅读
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => PdfReaderScreen(book: book),
///   ),
/// );
///
/// // 从指定章节开始阅读
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => PdfReaderScreen(
///       book: book,
///       chapter: chapter,
///       initialPage: chapter.startPage,
///     ),
///   ),
/// );
/// ```
class PdfReaderScreen extends StatefulWidget {
  /// 当前阅读的书籍对象
  ///
  /// 包含书籍的元数据，如标题、作者、文件路径等。
  /// 文件路径用于加载PDF内容。
  final Book book;

  /// 起始章节（可选）
  ///
  /// 当用户从章节列表点击进入时，传入对应的章节对象。
  /// 用于：
  /// - 设置AppBar标题为章节名称
  /// - 可用于计算初始页码（如果章节包含页码信息）
  final Chapter? chapter;

  /// 初始页码
  ///
  /// PDF阅读器首次显示时定位到该页码。
  /// 默认值为1（第一页）。
  ///
  /// 常见使用场景：
  /// - 新书阅读：从第1页开始
  /// - 继续阅读：从上次阅读位置恢复
  /// - 章节定位：从章节起始页开始
  final int initialPage;

  const PdfReaderScreen({
    Key? key,
    required this.book,
    this.chapter,
    this.initialPage = 1,
  }) : super(key: key);

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

/// PDF阅读器状态管理
///
/// 管理PDF阅读器的状态，包括当前页码、PDF查看器控制器等。
/// 使用pdfrx库提供的PdfViewer组件进行PDF渲染。
class _PdfReaderScreenState extends State<PdfReaderScreen> {
  /// 日志服务实例
  ///
  /// 用于记录调试信息和错误日志，便于问题排查。
  final _log = LogService();

  /// 当前阅读页码
  ///
  /// 记录用户当前阅读到第几页，用于：
  /// - 阅读进度追踪
  /// - 恢复阅读位置
  /// - 保存阅读进度到数据库
  ///
  /// 初始化时从widget.initialPage获取初始值。
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    // 初始化当前页码，从传入的初始页码开始
    // 这支持两种场景：
    // 1. 新书阅读：initialPage默认为1
    // 2. 继续阅读/章节定位：initialPage由调用方指定
    _currentPage = widget.initialPage;
    _log.d('PdfReaderScreen',
        '初始化PDF阅读器: ${widget.book.title}, 起始页: $_currentPage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 应用栏：显示当前阅读的书籍或章节标题
      appBar: AppBar(
        title: Text(
          // 优先显示章节标题，如果没有章节信息则显示书籍标题
          // 例如："第三章 数据结构" 或 "算法导论"
          widget.chapter?.title ?? widget.book.title,
          // 文本溢出时显示省略号，防止标题过长
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // PDF查看器主体
      //
      // 使用pdfrx库的PdfViewer组件渲染PDF文件。
      // 该组件提供：
      // - 高性能PDF渲染
      // - 手势支持（缩放、平移）
      // - 页面导航
      // - 文本选择（如果启用）
      body: PdfViewer.file(
        // PDF文件路径，从Book对象获取
        widget.book.filePath,
        // PDF查看器参数配置
        params: PdfViewerParams(
            // 可扩展的配置选项：
            // - scrollDirection: 滚动方向（垂直/水平）
            // - pageFitPolicy: 页面适配策略
            // - enableTextSelection: 启用文本选择
            // - scrollByMouseWheel: 鼠标滚轮滚动
            ),
        // 初始页码：打开PDF时定位到指定页面
        // 用于实现继续阅读和章节定位功能
        initialPageNumber: _currentPage,
      ),
    );
  }
}
