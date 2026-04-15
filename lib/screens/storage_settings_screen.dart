import 'package:flutter/material.dart';
import '../services/storage_path_service.dart';

/// 存储设置页面
///
/// 提供存储目录的查看和修改功能：
/// - 显示当前书籍存储目录
/// - 允许用户选择新的存储目录
/// - 显示迁移数据警告提示
///
/// 使用 StatefulWidget 管理：
/// - 当前目录路径的异步加载
/// - 选择新目录后的状态更新
class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  /// 存储路径服务
  final _storagePathService = StoragePathService();

  /// 当前书籍目录路径
  String _currentPath = '';

  /// 是否正在加载路径
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
  }

  /// 加载当前书籍目录路径
  Future<void> _loadCurrentPath() async {
    final path = await _storagePathService.getBooksDirectoryPath();
    setState(() {
      _currentPath = path;
      _isLoading = false;
    });
  }

  /// 选择新的书籍目录
  ///
  /// 打开文件选择器让用户选择新目录，
  /// 选择成功后更新界面显示新路径
  Future<void> _pickNewDirectory() async {
    final newPath = await _storagePathService.pickBooksDirectory();
    if (newPath != null) {
      setState(() {
        _currentPath = newPath;
      });
      _showSnackBar('存储目录已更新');
    }
  }

  /// 显示 SnackBar 提示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('存储设置'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前目录标题
                  Text(
                    '当前书籍目录',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // 当前目录路径显示
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentPath,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 更改目录按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pickNewDirectory,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('更改存储目录'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 警告提示
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange[800],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '注意：更改目录后，需要手动迁移现有数据。',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
