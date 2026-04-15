import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/storage_path_service.dart';
import '../services/export_service.dart';
import '../models/app_settings.dart';

/// 备份设置页面组件
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

/// 备份设置页面状态管理
class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  /// 设置服务实例
  final _settingsService = SettingsService();

  /// 存储路径服务实例
  final _storagePathService = StoragePathService();

  /// 导出服务实例
  final _exportService = ExportService();

  /// 当前备份目录路径
  String _backupDirectory = '';

  /// 是否正在备份
  bool _isBackingUp = false;

  /// 是否正在恢复
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadBackupDirectory();
  }

  /// 加载当前备份目录路径
  Future<void> _loadBackupDirectory() async {
    final path = await _storagePathService.getBackupDirectoryPath();
    setState(() {
      _backupDirectory = path;
    });
  }

  /// 格式化日期时间显示
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '从未备份';
    }
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化备份间隔显示
  String _formatBackupInterval(int days) {
    switch (days) {
      case 1:
        return '每天';
      case 7:
        return '每周';
      default:
        return '每$days天';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildBackupDirectorySection(),
          const Divider(),
          _buildAutoBackupSection(),
          const Divider(),
          _buildManualBackupSection(),
          const Divider(),
          _buildRestoreSection(),
        ],
      ),
    );
  }

  /// 构建备份目录信息区块
  Widget _buildBackupDirectorySection() {
    return _buildSection(
      title: '备份目录',
      icon: Icons.folder,
      children: [
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('当前目录'),
          subtitle: Text(
            _backupDirectory,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: TextButton(
            onPressed: _changeBackupDirectory,
            child: const Text('更改'),
          ),
        ),
      ],
    );
  }

  /// 构建自动备份设置区块
  Widget _buildAutoBackupSection() {
    return ValueListenableBuilder<StorageSettings>(
      valueListenable: _settingsService.storageSettings,
      builder: (context, storageSettings, child) {
        return _buildSection(
          title: '自动备份',
          icon: Icons.schedule,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.autorenew),
              title: const Text('启用自动备份'),
              subtitle: const Text('按设定频率自动备份数据'),
              value: storageSettings.autoBackupEnabled,
              onChanged: (value) async {
                await _settingsService.updateStorageSettings(
                  storageSettings.copyWith(autoBackupEnabled: value),
                );
              },
            ),
            // 仅在启用自动备份时显示频率选择
            if (storageSettings.autoBackupEnabled)
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('备份频率'),
                subtitle: Text(
                    _formatBackupInterval(storageSettings.autoBackupInterval)),
                trailing: DropdownButton<int>(
                  value: storageSettings.autoBackupInterval,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text('每天'),
                    ),
                    DropdownMenuItem(
                      value: 7,
                      child: Text('每周'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value != null) {
                      await _settingsService.updateStorageSettings(
                        storageSettings.copyWith(autoBackupInterval: value),
                      );
                    }
                  },
                ),
              ),
            // 显示上次备份时间
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('上次备份'),
              trailing: Text(
                _formatDateTime(storageSettings.lastBackupTime),
                style: TextStyle(
                  color: storageSettings.lastBackupTime != null
                      ? Colors.grey[700]
                      : Colors.grey[400],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建手动备份区块
  Widget _buildManualBackupSection() {
    return _buildSection(
      title: '手动备份',
      icon: Icons.cloud_upload,
      children: [
        ListTile(
          leading: const Icon(Icons.backup),
          title: const Text('立即备份'),
          subtitle: const Text('将所有数据导出为JSON备份文件'),
          trailing: _isBackingUp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isBackingUp ? null : _performBackup,
        ),
      ],
    );
  }

  /// 构建数据恢复区块
  Widget _buildRestoreSection() {
    return _buildSection(
      title: '数据恢复',
      icon: Icons.cloud_download,
      children: [
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('恢复数据'),
          subtitle: const Text('从JSON备份文件恢复数据'),
          trailing: _isRestoring
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isRestoring ? null : _performRestore,
        ),
      ],
    );
  }

  /// 构建设置分组区块
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

  /// 更改备份目录
  Future<void> _changeBackupDirectory() async {
    final newPath = await _storagePathService.pickBackupDirectory();
    if (newPath != null) {
      // 更新设置
      final currentSettings = _settingsService.settings.storageSettings;
      await _settingsService.updateStorageSettings(
        currentSettings.copyWith(backupDirectory: newPath),
      );
      // 刷新显示的目录
      await _loadBackupDirectory();
      if (mounted) {
        _showSnackBar('备份目录已更新');
      }
    }
  }

  /// 执行手动备份
  Future<void> _performBackup() async {
    setState(() => _isBackingUp = true);

    try {
      final result = await _exportService.exportAllDataToJson();
      if (result != null) {
        // 更新上次备份时间
        final currentSettings = _settingsService.settings.storageSettings;
        await _settingsService.updateStorageSettings(
          currentSettings.copyWith(lastBackupTime: DateTime.now()),
        );
        if (mounted) {
          _showSnackBar('备份成功: $result');
        }
      } else {
        if (mounted) {
          _showSnackBar('备份取消');
        }
      }
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  /// 执行数据恢复
  Future<void> _performRestore() async {
    // 显示确认对话框
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

    setState(() => _isRestoring = true);

    try {
      final result = await _exportService.pickAndImportBackup();
      if (result != null) {
        if (mounted) {
          _showSnackBar('恢复成功');
        }
      } else {
        if (mounted) {
          _showSnackBar('恢复取消或失败');
        }
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  /// 显示SnackBar提示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
