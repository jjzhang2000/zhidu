/// AI配置页面
///
/// 提供AI服务提供商的配置界面，包括：
/// - 提供商选择（智谱/通义千问）
/// - API Key输入（支持显示/隐藏切换）
/// - 模型选择（根据提供商动态变化）
/// - Base URL配置（带默认值）
/// - 连接测试功能
///
/// 数据流向：
/// - 读取：SettingsService().settings.ai
/// - 保存：SettingsService().updateAiSettings(AiSettings)
/// - 重载：AIService().reloadConfig()

import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';

/// AI配置页面组件
///
/// 使用StatefulWidget管理表单状态：
/// - 表单控制器（TextEditingController）
/// - API Key显示/隐藏状态
/// - 提供商/模型选择状态
/// - 表单验证状态
/// - 保存/测试操作的loading状态
class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({super.key});

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

/// AI配置页面状态管理
class _AiConfigScreenState extends State<AiConfigScreen> {
  /// 设置服务单例
  final _settingsService = SettingsService();

  /// AI服务单例
  final _aiService = AIService();

  /// 表单Key，用于验证
  final _formKey = GlobalKey<FormState>();

  /// 提供商选项
  static const _providers = [
    MapEntry('zhipu', '智谱'),
    MapEntry('qwen', '通义千问'),
  ];

  /// 模型映射表
  /// 每个提供商对应不同的推荐模型选项
  static const _modelsByProvider = {
    'zhipu': ['glm-4-flash', 'glm-4', 'glm-4-plus'],
    'qwen': ['qwen-turbo', 'qwen-plus', 'qwen-max'],
  };

  /// 默认Base URL映射
  static const _defaultBaseUrls = {
    'zhipu': 'https://open.bigmodel.cn/api/paas/v4',
    'qwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  };

  /// 当前选中的提供商
  String _selectedProvider = '';

  /// 当前选中的模型
  String _selectedModel = '';

  /// API Key控制器
  late TextEditingController _apiKeyController;

  /// Base URL控制器
  late TextEditingController _baseUrlController;

  /// 模型控制器
  late TextEditingController _modelController;

  /// API Key是否隐藏（obscure）
  bool _isApiKeyObscured = true;

  /// 是否正在保存
  bool _isSaving = false;

  /// 是否正在测试连接
  bool _isTesting = false;

  /// 测试连接结果消息
  String? _testResultMessage;

  /// 测试连接是否成功
  bool? _testResultSuccess;

  /// 获取当前可用模型列表
  ///
  /// 根据选中的提供商返回对应的推荐模型选项
  List<String> get _recommendedModels {
    return _selectedProvider.isNotEmpty
        ? (_modelsByProvider[_selectedProvider] ?? [])
        : [];
  }

  /// 加载当前AI设置
  ///
  /// 从SettingsService读取当前配置，初始化表单状态
  void _loadCurrentSettings() {
    final aiSettings = _settingsService.settings.aiSettings;
    _selectedProvider = aiSettings.provider;
    // 确保 provider 在有效范围内
    if (!_providers.any((entry) => entry.key == _selectedProvider)) {
      _selectedProvider = _providers.first.key; // 默认选择第一个
    }
    _selectedModel = aiSettings.model;
    _apiKeyController = TextEditingController(text: aiSettings.apiKey);
    _modelController =
        TextEditingController(text: aiSettings.model); // 添加模型控制器初始化
    _baseUrlController = TextEditingController(
      text: aiSettings.baseUrl.isNotEmpty
          ? aiSettings.baseUrl
          : _defaultBaseUrls[_selectedProvider]!,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose(); // 添加模型控制器销毁
    super.dispose();
  }

  /// 切换提供商
  ///
  /// 当用户选择新的提供商时：
  /// 1. 更新选中的提供商
  /// 2. 自动切换到该提供商的第一个推荐模型（用于模型输入框的建议）
  /// 3. 更新Base URL为默认值
  void _onProviderChanged(String? newProvider) {
    if (newProvider == null || newProvider == _selectedProvider) return;

    setState(() {
      _selectedProvider = newProvider;
      _baseUrlController.text = _defaultBaseUrls[newProvider]!;
      _testResultMessage = null;
    });
  }

  /// 更新模型值
  ///
  /// 当模型文本输入框内容变化时更新
  void _onModelChanged() {
    setState(() {
      _selectedModel = _modelController.text.trim();
    });
  }

  /// 保存配置
  ///
  /// 执行流程：
  /// 1. 验证表单
  /// 2. 构建AiSettings对象
  /// 3. 调用SettingsService保存
  /// 4. 调用AIService重载配置
  /// 5. 显示成功提示并返回
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final newSettings = AiSettings(
        provider: _selectedProvider,
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(), // 使用文本输入框的值
        baseUrl: _baseUrlController.text.trim(),
      );

      await _settingsService.updateAiSettings(newSettings);
      _aiService.reloadConfig();

      _showSnackBar('AI配置已保存');
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('保存失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// 测试连接
  ///
  /// 执行流程：
  /// 1. 验证表单
  /// 2. 临时保存当前配置到AIService
  /// 3. 调用testConnection测试
  /// 4. 显示测试结果
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResultMessage = null;
      _testResultSuccess = null;
    });

    try {
      // 创建临时配置用于测试
      final tempSettings = AiSettings(
        provider: _selectedProvider,
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(), // 使用文本输入框的值
        baseUrl: _baseUrlController.text.trim(),
      );

      // 临时更新AIService配置进行测试
      _aiService.updateConfig(tempSettings);
      final isValid = await _aiService.testConnection();

      setState(() {
        _testResultSuccess = isValid;
        _testResultMessage = isValid ? '连接成功！' : '连接失败，请检查配置';
      });
    } catch (e) {
      setState(() {
        _testResultSuccess = false;
        _testResultMessage = '连接失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  /// 显示SnackBar提示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI配置'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProviderSection(),
              const SizedBox(height: 24),
              _buildApiKeySection(),
              const SizedBox(height: 24),
              _buildModelSection(),
              const SizedBox(height: 24),
              _buildBaseUrlSection(),
              const SizedBox(height: 32),
              if (_testResultMessage != null) _buildTestResult(),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建提供商选择区块
  ///
  /// 包含：
  /// - 标签文字
  /// - 下拉选择框（智谱/通义千问）
  Widget _buildProviderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI提供商',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedProvider,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: _providers.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: _onProviderChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请选择AI提供商';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// 构建API Key输入区块
  ///
  /// 包含：
  /// - 标签文字
  /// - 文本输入框（支持显示/隐藏切换）
  /// - 验证：不能为空
  Widget _buildApiKeySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'API Key',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _apiKeyController,
          obscureText: _isApiKeyObscured,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintText: '请输入您的API Key',
            suffixIcon: IconButton(
              icon: Icon(
                _isApiKeyObscured ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _isApiKeyObscured = !_isApiKeyObscured;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入API Key';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// 构建模型选择区块
  ///
  /// 包含：
  /// - 标签文字
  /// - 文本输入框（允许用户直接输入模型名称）
  Widget _buildModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '模型',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _modelController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintText: '请输入模型名称，例如：qwen-plus、glm-4等',
            suffixIcon: PopupMenuButton<String>(
              icon: const Icon(Icons.info_outline),
              tooltip: '推荐模型',
              itemBuilder: (context) {
                return _recommendedModels.map((model) {
                  return PopupMenuItem(
                    value: model,
                    child: Text(model),
                  );
                }).toList();
              },
              onSelected: (model) {
                _modelController.text = model;
                _onModelChanged();
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入模型名称';
            }
            return null;
          },
          onChanged: (value) => _onModelChanged(),
        ),
      ],
    );
  }

  /// 构建Base URL输入区块
  ///
  /// 包含：
  /// - 标签文字
  /// - 文本输入框
  /// - 验证：不能为空
  Widget _buildBaseUrlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base URL',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _baseUrlController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintText: 'https://...',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入Base URL';
            }
            if (!value.startsWith('http://') && !value.startsWith('https://')) {
              return 'URL必须以http://或https://开头';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// 构建测试结果显示
  ///
  /// 显示连接测试的结果（成功或失败）
  Widget _buildTestResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _testResultSuccess == true
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _testResultSuccess == true ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _testResultSuccess == true ? Icons.check_circle : Icons.error,
            color: _testResultSuccess == true ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _testResultMessage!,
              style: TextStyle(
                color: _testResultSuccess == true
                    ? Colors.green[700]
                    : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮区块
  ///
  /// 包含：
  /// - 测试连接按钮
  /// - 保存按钮
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isTesting || _isSaving ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: Text(_isTesting ? '测试中...' : '测试连接'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: _isTesting || _isSaving ? null : _saveConfig,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? '保存中...' : '保存'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
