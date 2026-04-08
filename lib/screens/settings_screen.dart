import 'package:flutter/material.dart';
import '../services/export_service.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _exportService = ExportService();
  final _bookService = BookService();
  final _summaryService = SummaryService();

  bool _isExporting = false;
  bool _isImporting = false;
  int _summaryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSummaryCount();
  }

  Future<void> _loadSummaryCount() async {
    final summaries = await _summaryService.getAllSummaries();
    setState(() {
      _summaryCount = summaries.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookCount = _bookService.books.length;
    final summaryCount = _summaryCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildDataSection(bookCount, summaryCount),
          const Divider(),
          _buildExportSection(),
          const Divider(),
          _buildBackupSection(),
          const Divider(),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildDataSection(int bookCount, int summaryCount) {
    return _buildSection(
      title: '数据统计',
      icon: Icons.analytics,
      children: [
        _buildStatTile('书籍数量', bookCount, Icons.book),
        _buildStatTile('摘要数量', summaryCount, Icons.summarize),
      ],
    );
  }

  Widget _buildStatTile(String label, int count, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return _buildSection(
      title: '数据导出',
      icon: Icons.upload_file,
      children: [
        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('导出书籍摘要'),
          subtitle: const Text('将所有书籍摘要导出为 Markdown 文件'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isExporting ? null : () => _exportBookSummaries(),
        ),
      ],
    );
  }

  Widget _buildBackupSection() {
    return _buildSection(
      title: '备份与恢复',
      icon: Icons.backup,
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_upload),
          title: const Text('备份数据'),
          subtitle: const Text('将所有数据导出为 JSON 备份文件'),
          trailing: _isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isExporting ? null : _backupAllData,
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download),
          title: const Text('恢复数据'),
          subtitle: const Text('从 JSON 备份文件恢复数据'),
          trailing: _isImporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isImporting ? null : _restoreData,
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      title: '关于',
      icon: Icons.info,
      children: [
        const ListTile(
          leading: Icon(Icons.apps),
          title: Text('智读'),
          subtitle: Text('版本 0.1.0'),
        ),
        const ListTile(
          leading: Icon(Icons.code),
          title: Text('AI 分层阅读器'),
          subtitle: Text('先读薄，再读厚'),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  Future<void> _exportBookSummaries() async {
    final books = _bookService.books;
    if (books.isEmpty) {
      _showSnackBar('暂无书籍数据');
      return;
    }

    setState(() => _isExporting = true);

    try {
      int successCount = 0;
      for (final book in books) {
        final result = await _exportService.exportBookSummaryToMarkdown(book);
        if (result != null) successCount++;
      }

      if (successCount > 0) {
        _showSnackBar('已导出 $successCount 本书籍摘要');
      } else {
        _showSnackBar('导出失败，请检查是否有摘要数据');
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _backupAllData() async {
    setState(() => _isExporting = true);

    try {
      final result = await _exportService.exportAllDataToJson();
      if (result != null) {
        _showSnackBar('备份成功: $result');
      } else {
        _showSnackBar('备份取消');
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _restoreData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复数据'),
        content: const Text('恢复数据将覆盖当前所有数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isImporting = true);

    try {
      final result = await _exportService.pickAndImportBackup();
      if (result != null) {
        _showSnackBar('恢复成功');
        setState(() {});
      } else {
        _showSnackBar('恢复取消或失败');
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
