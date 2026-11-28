// AI 配置页面
//
// 配置提供商（云端/本地）、API Key、模型与 Base URL，并支持连接测试。
// 保存时写入 SettingsService，并调用 AIService.reloadConfig() 使其生效。

import 'package:flutter/material.dart';
import 'package:zhidu/l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';
import '../services/log_service.dart';

/// AI 配置页面
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

  /// 日志服务实例
  final _log = LogService();

  /// 表单Key，用于验证
  final _formKey = GlobalKey<FormState>();

  /// 模型下拉菜单定位锚点Key
  final _modelBoxKey = GlobalKey();

  /// 提供商选项
  static const _providers = [
    MapEntry('zhipu', '智谱'),
    MapEntry('qwen', '通义千问'),
    MapEntry('deepseek', 'DeepSeek'),
    MapEntry('minimax', 'MiniMax'),
    MapEntry('ollama', 'Ollama（本地）'),
    MapEntry('lmstudio', 'LM Studio（本地）'),
  ];

  /// 获取当前上下文的提供商选项（国际化优先，回退默认中文列表）
  List<MapEntry<String, String>> _getCurrentProviders() {
    final localizations = AppLocalizations.of(context);
    if (localizations != null) {
      return [
        MapEntry('zhipu', localizations.zhipuProvider),
        MapEntry('qwen', localizations.qwenProvider),
        MapEntry('deepseek', localizations.deepseekProvider),
        MapEntry('minimax', localizations.minimaxProvider),
        MapEntry('ollama', localizations.ollamaProvider),
        MapEntry('lmstudio', localizations.lmstudioProvider),
      ];
    }
    return _providers;
  }

  /// 默认Base URL映射
  static const _defaultBaseUrls = {
    'zhipu': 'https://open.bigmodel.cn/api/paas/v4',
    'qwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    'deepseek': 'https://api.deepseek.com/v1',
    'minimax': 'https://api.minimaxi.com/v1',
    'ollama': 'http://localhost:11434/v1',
    'lmstudio': 'http://localhost:1234/v1',
  };

  /// 当前选中的提供商
  String _selectedProvider = '';

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

  /// 当前可用的模型列表
  List<String> _availableModels = [];

  /// 当前选中的提供商是否需要 API Key
  bool get _requiresApiKey {
    final settings = AiSettings(
      provider: _selectedProvider,
      model: '',
      baseUrl: '',
    );
    return settings.requiresApiKey;
  }

  /// 用当前表单内容构建 AI 配置对象
  AiSettings _buildFormAiSettings() {
    return AiSettings(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
    );
  }

  /// 加载当前 AI 设置并初始化表单
  void _loadCurrentSettings() {
    final aiSettings = _settingsService.settings.aiSettings;
    _selectedProvider = aiSettings.provider;
    if (!_providers.any((entry) => entry.key == _selectedProvider)) {
      _selectedProvider = _providers.first.key;
    }
    final needsApiKey = _requiresApiKey;
    _apiKeyController = TextEditingController(
      text: needsApiKey ? aiSettings.apiKey : '',
    );
    _modelController = TextEditingController(text: aiSettings.model);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchModelsForCurrentProvider();
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// 切换提供商：优先回填已保存配置，其次是当前有效配置，否则用默认值
  void _onProviderChanged(String? newProvider) {
    if (newProvider == null || newProvider == _selectedProvider) return;

    setState(() {
      _selectedProvider = newProvider;
      _testResultMessage = null;

      final savedConfig =
          _settingsService.getSavedAiConfigForProvider(newProvider);
      final currentAiSettings = _settingsService.settings.aiSettings;
      final isCurrentConfig = newProvider == currentAiSettings.provider &&
          currentAiSettings.isValid;

      if (savedConfig != null) {
        _apiKeyController.text = savedConfig.apiKey;
        _modelController.text = savedConfig.model;
        _baseUrlController.text = savedConfig.baseUrl;
      } else if (isCurrentConfig) {
        _apiKeyController.text = currentAiSettings.apiKey;
        _modelController.text = currentAiSettings.model;
        _baseUrlController.text = currentAiSettings.baseUrl;
      } else {
        _baseUrlController.text = _defaultBaseUrls[newProvider]!;
        _apiKeyController.clear();
        _modelController.clear();
        _availableModels.clear();
      }
    });

    _fetchModelsForCurrentProvider();
  }

  /// 获取当前提供商的可用模型列表（失败仅记录日志）
  Future<void> _fetchModelsForCurrentProvider() async {
    final provider = _selectedProvider;
    if (provider.isEmpty) return;

    final baseUrl = _baseUrlController.text.trim();

    setState(() {
      _availableModels.clear();
    });

    try {
      final models = await _aiService.fetchAvailableModels(
        baseUrl: baseUrl,
        apiKey: _apiKeyController.text.trim(),
      );

      if (models.isNotEmpty && mounted) {
        setState(() {
          _availableModels = models;
        });
      }
    } catch (e) {
      _log.w('AiConfigScreen', '获取模型列表失败: $e');
    }
  }

  /// 校验表单并保存配置，成功后重载 AIService 并返回
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final newSettings = _buildFormAiSettings();

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

  /// 用当前表单配置测试连接（临时更新 AIService，不保存）
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResultMessage = null;
      _testResultSuccess = null;
    });

    try {
      // 临时更新AIService配置进行测试
      _aiService.updateConfig(_buildFormAiSettings());
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
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.aiConfigScreenTitle),
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
              _buildActionButtons(localizations),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建提供商选择区块（已配置的提供商带 ✓ 标记）
  Widget _buildProviderSection() {
    final currentAiSettings = _settingsService.settings.aiSettings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)?.aiProvider ?? 'AI提供商',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedProvider,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: _getCurrentProviders().map((entry) {
            final isSavedConfig =
                _settingsService.hasSavedAiConfigForProvider(entry.key);
            final isCurrentValidConfig =
                entry.key == currentAiSettings.provider &&
                    currentAiSettings.isValid;
            final hasConfig = isSavedConfig || isCurrentValidConfig;

            final displayText = hasConfig ? '${entry.value} ✓' : entry.value;
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                displayText,
                style: hasConfig
                    ? TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
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

  /// 构建 API Key 输入区块（本地模型显示无需 Key 的提示）
  Widget _buildApiKeySection() {
    final loc = AppLocalizations.of(context);

    if (!_requiresApiKey) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc?.apiKey ?? 'API Key',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '本地模型不需要 API Key',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc?.apiKey ?? 'API Key',
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

  /// 构建模型选择区块（无模型列表时点击触发联网获取）
  Widget _buildModelSection() {
    final models = _availableModels;
    final hasSelectedModel = models.isNotEmpty &&
        _modelController.text.isNotEmpty &&
        models.contains(_modelController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)?.model ?? '模型',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            if (models.isEmpty) {
              await _tryFetchModels();
              return;
            }
            await _showModelMenu();
          },
          child: Container(
            key: _modelBoxKey,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hasSelectedModel ? _modelController.text : '请选择模型',
                    style: TextStyle(
                      color: hasSelectedModel
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 计算菜单弹出位置（紧贴模型框下方、等宽）
  RelativeRect _getMenuPosition() {
    final renderBox =
        _modelBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return const RelativeRect.fromLTRB(0, 0, 0, 0);
    }
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight =
        MediaQuery.of(_modelBoxKey.currentContext!).size.height;

    return RelativeRect.fromLTRB(
      position.dx,
      position.dy + size.height,
      position.dx + size.width,
      screenHeight - position.dy,
    );
  }

  /// 弹出已排序的模型下拉菜单，选中后写入 _modelController
  Future<void> _showModelMenu() async {
    final position = _getMenuPosition();
    final renderBox =
        _modelBoxKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 200;

    final selected = await showMenu<String>(
      context: context,
      position: position,
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
      ),
      items: (_availableModels.toList()..sort((a, b) => a.compareTo(b)))
          .map((model) {
        return PopupMenuItem<String>(
          value: model,
          child: Text(model),
        );
      }).toList(),
    );
    if (selected != null) {
      _modelController.text = selected;
      setState(() {});
    }
  }

  /// 尝试获取模型列表
  Future<void> _tryFetchModels() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      await _fetchModelsForCurrentProvider();
      if (mounted && _availableModels.isNotEmpty) {
        await _showModelMenu();
      }
    }
  }

  /// 构建 Base URL 输入区块（校验非空且以 http/https 开头）
  Widget _buildBaseUrlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)?.baseUrl ?? 'Base URL',
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

  /// 构建连接测试结果提示（成功/失败配色）
  Widget _buildTestResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _testResultSuccess == true
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
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
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部操作按钮（测试连接 / 保存）
  Widget _buildActionButtons(AppLocalizations localizations) {
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
            label: Text(_isTesting ? localizations.testing : '测试连接'),
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
            label: Text(_isSaving ? localizations.saving : '保存'),
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
