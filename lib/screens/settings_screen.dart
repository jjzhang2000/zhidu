/// 设置页面
///
/// 提供应用的设置和管理功能，包括：
/// - AI配置：显示和配置AI服务状态
/// - 外观设置：主题和语言设置
/// - 数据管理：存储和备份设置
/// - 数据统计：显示书籍和摘要数量
/// - 关于信息：应用版本和描述
///
/// 设置项管理：
/// - 使用 ListView 分组展示不同设置类别
/// - 每个设置组使用 _buildSection 统一风格
/// - 状态变量控制操作进行中的 UI 反馈

import 'package:flutter/material.dart' hide ThemeMode;
import '../services/export_service.dart';
import '../services/book_service.dart';
import '../services/summary_service.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';
import 'ai_config_screen.dart';
import 'backup_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'language_settings_screen.dart';

/// 设置页面组件
///
/// 使用 StatefulWidget 管理：
/// - 导出/备份操作的 loading 状态
/// - 摘要数量的动态统计
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// 设置页面状态管理
class _SettingsScreenState extends State<SettingsScreen> {
  /// 导出服务 - 处理 Markdown 导出和 JSON 备份
  final _exportService = ExportService();

  /// 书籍服务 - 获取书籍列表和数量
  final _bookService = BookService();

  /// 摘要服务 - 获取摘要统计数据
  final _summaryService = SummaryService();

  /// 导出操作进行中状态
  /// 用于禁用重复点击和显示加载指示器
  bool _isExporting = false;

  /// 导入操作进行中状态
  /// 用于禁用重复点击和显示加载指示器
  bool _isImporting = false;

  /// 摘要总数
  /// 从 SummaryService 异步加载
  int _summaryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSummaryCount();
  }

  /// 加载摘要统计数据
  ///
  /// 从 SummaryService 获取所有摘要并计数，
  /// 更新界面显示摘要总数
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
          _buildAiSection(),
          const Divider(),
          _buildAppearanceSection(),
          const Divider(),
          _buildDataManagementSection(),
          const Divider(),
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

  /// 构建AI配置区块
  ///
  /// 提供AI服务配置入口：
  /// - 点击跳转到AI配置页面
  /// - 显示当前配置状态（provider/model 或 未配置）
  Widget _buildAiSection() {
    return _buildSection(
      title: 'AI配置',
      icon: Icons.smart_toy,
      children: [
        ListenableBuilder(
          listenable: SettingsService().aiSettings,
          builder: (context, _) {
            return ListTile(
              leading: const Icon(Icons.api),
              title: const Text('AI 服务设置'),
              subtitle: Text(_getAiConfigStatus()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AiConfigScreen(),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// 获取AI配置状态显示文本
  String _getAiConfigStatus() {
    final ai = SettingsService().settings.aiSettings;
    if (ai.isValid) {
      return '${ai.provider} / ${ai.model}';
    }
    return '未配置';
  }

  /// 构建外观设置区块
  ///
  /// 提供主题和语言设置入口
  Widget _buildAppearanceSection() {
    return _buildSection(
      title: '外观设置',
      icon: Icons.palette,
      children: [
        ListTile(
          leading: const Icon(Icons.brightness_6),
          title: const Text('主题设置'),
          subtitle: Text(_getThemeStatus()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ThemeSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('语言设置'),
          subtitle: Text(_getLanguageStatus()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 获取主题状态显示文本
  String _getThemeStatus() {
    final mode = SettingsService().settings.themeSettings.mode;
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '亮色';
      case ThemeMode.dark:
        return '暗色';
    }
  }

  /// 获取语言状态显示文本
  String _getLanguageStatus() {
    final lang = SettingsService().settings.languageSettings.aiOutputLanguage;
    switch (lang) {
      case 'zh':
        return '中文';
      case 'en':
        return '英文';
      case 'auto':
        return '自动';
      default:
        return '中文';
    }
  }

  /// 构建数据管理区块
  ///
  /// 提供存储和备份设置入口
  Widget _buildDataManagementSection() {
    return _buildSection(
      title: '数据管理',
      icon: Icons.storage,
      children: [
        ListTile(
          leading: const Icon(Icons.folder),
          title: const Text('存储路径'),
          subtitle: const Text('设置书籍和备份存储位置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _showSnackBar('存储设置功能即将推出');
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore),
          title: const Text('备份设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BackupSettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建数据导出区块
  ///
  /// 提供书籍摘要导出功能：
  /// - 点击后遍历所有书籍
  /// - 调用 ExportService 导出每本书的摘要为 Markdown
  /// - 导出过程中禁用按钮，防止重复操作
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

  /// 构建备份与恢复区块
  ///
  /// 提供备份设置入口和快速备份/恢复功能：
  /// 1. 备份设置：跳转到备份设置页面进行详细配置
  /// 2. 备份数据：将所有数据导出为 JSON 文件
  /// 3. 恢复数据：从 JSON 备份文件恢复数据
  ///
  /// 注意事项：
  /// - 备份/恢复过程中显示加载指示器
  /// - 恢复数据会覆盖当前数据，需用户确认
  Widget _buildBackupSection() {
    return _buildSection(
      title: '备份与恢复',
      icon: Icons.backup,
      children: [
        ListTile(
          leading: const Icon(Icons.settings_backup_restore),
          title: const Text('备份设置'),
          subtitle: const Text('配置自动备份、备份目录等'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BackupSettingsScreen(),
              ),
            );
          },
        ),
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

  /// 构建数据统计区块
  ///
  /// 显示：
  /// - 书籍数量：当前导入的书籍总数
  /// - 摘要数量：已生成的所有摘要总数
  ///
  /// 参数：
  /// - bookCount: 书籍数量
  /// - summaryCount: 摘要数量
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

  /// 构建统计条目
  ///
  /// 创建一个 ListTile 显示标签和计数值
  /// 计数值显示在带背景的圆角容器中
  ///
  /// 参数：
  /// - label: 统计项名称
  /// - count: 统计数值
  /// - icon: 前置图标
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

  /// 构建关于区块
  ///
  /// 显示应用信息：
  /// - 应用名称：智读
  /// - 版本号：0.1.0
  /// - 副标题：AI 分层阅读器 - 先读薄，再读厚
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

  /// 构建设置分组区块
  ///
  /// 统一的分组样式，包含：
  /// - 标题行：图标 + 文字
  /// - 子组件列表
  ///
  /// 参数：
  /// - title: 分组标题
  /// - icon: 分组图标
  /// - children: 分组内的设置项列表
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

  /// 导出所有书籍摘要
  ///
  /// 功能流程：
  /// 1. 检查是否有书籍数据
  /// 2. 设置导出状态为进行中
  /// 3. 遍历所有书籍，调用 ExportService 导出
  /// 4. 统计成功导出数量并提示用户
  /// 5. 重置导出状态
  ///
  /// 导出文件位置：由 ExportService 决定（用户选择的目录）
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

  /// 备份所有数据
  ///
  /// 功能流程：
  /// 1. 设置导出状态为进行中
  /// 2. 调用 ExportService 导出所有数据为 JSON
  /// 3. 显示备份结果
  /// 4. 重置导出状态
  ///
  /// 备份内容包括：
  /// - 书籍信息
  /// - 章节摘要
  /// - 全书摘要
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

  /// 从备份恢复数据
  ///
  /// 功能流程：
  /// 1. 弹出确认对话框，警告用户数据将被覆盖
  /// 2. 用户确认后设置导入状态为进行中
  /// 3. 调用 ExportService 选择并导入备份文件
  /// 4. 恢复成功后刷新界面
  /// 5. 重置导入状态
  ///
  /// 警告：恢复操作会覆盖当前所有数据
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

  /// 显示 SnackBar 提示
  ///
  /// 参数：
  /// - message: 提示消息内容
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
