// ============================================================================
// 文件名：ai_service.dart
// 功能：AI服务核心模块，负责与大语言模型API的交互
//
// 主要职责：
// - 加载和管理AI配置（API Key、模型、Base URL等）
// - 封装AI API调用逻辑（兼容智谱/通义千问等OpenAI兼容接口）
// - 提供章节摘要、全书摘要等AI生成能力
//
// 依赖：
// - ai_prompts.dart：AI提示词模板
// - log_service.dart：日志服务
// - http包：HTTP请求
//
// 调用方：
// - summary_service.dart：摘要生成服务
// - settings_screen.dart：设置页面（检查AI配置状态）
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'ai_prompts.dart';
import 'log_service.dart';

/// 类名：AIConfig
/// 功能：AI服务配置数据模型
///
/// 主要职责：
/// - 封装AI API所需的配置参数
/// - 从JSON配置文件解析配置信息
/// - 验证配置有效性（API Key是否为有效值）
///
/// 使用场景：
/// - 从ai_config.json加载配置时创建实例
/// - AIService初始化时使用
class AIConfig {
  /// AI服务提供商标识
  /// 有效值：'zhipu'（智谱）或 'qwen'（通义千问）
  final String provider;

  /// API密钥
  /// 用于身份验证，从配置文件中读取
  final String apiKey;

  /// 使用的模型名称
  /// 智谱示例：'glm-4-flash', 'glm-4'
  /// 通义千问示例：'qwen-plus', 'qwen-turbo'
  final String model;

  /// API基础URL
  /// 智谱：https://open.bigmodel.cn/api/paas/v4
  /// 通义千问：https://dashscope.aliyuncs.com/compatible-mode/v1
  final String baseUrl;

  /// 构造函数：AIConfig
  /// 功能：创建AI配置实例
  ///
  /// 参数：
  /// - provider: AI服务提供商标识
  /// - apiKey: API密钥
  /// - model: 模型名称
  /// - baseUrl: API基础URL
  AIConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.baseUrl,
  });

  /// 方法名：fromJson
  /// 功能：从JSON配置文件内容创建AIConfig实例
  ///
  /// 参数：
  /// - json: 解析后的JSON对象，包含ai_provider和对应提供商的配置
  ///
  /// 返回值：AIConfig实例
  ///
  /// 算法逻辑：
  /// 1. 读取ai_provider字段确定使用的提供商（默认zhipu）
  /// 2. 读取对应提供商的配置块
  /// 3. 提取api_key、model、base_url字段，使用默认值兜底
  ///
  /// 配置文件格式示例：
  /// ```json
  /// {
  ///   "ai_provider": "qwen",
  ///   "qwen": {
  ///     "api_key": "sk-xxx",
  ///     "model": "qwen-plus",
  ///     "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1"
  ///   }
  /// }
  /// ```
  factory AIConfig.fromJson(Map<String, dynamic> json) {
    final provider = json['ai_provider'] ?? 'zhipu';
    final providerConfig = json[provider] ?? {};

    return AIConfig(
      provider: provider,
      apiKey: providerConfig['api_key'] ?? '',
      model: providerConfig['model'] ?? 'glm-4-flash',
      baseUrl: providerConfig['base_url'] ?? '',
    );
  }

  /// 属性名：isValid
  /// 功能：检查配置是否有效
  ///
  /// 验证规则：
  /// - API Key不能为空
  /// - API Key不能为占位符字符串（YOUR_ZHIPU_API_KEY_HERE、YOUR_QWEN_API_KEY_HERE）
  ///
  /// 返回值：true表示配置有效，false表示无效
  bool get isValid =>
      apiKey.isNotEmpty &&
      apiKey != 'YOUR_ZHIPU_API_KEY_HERE' &&
      apiKey != 'YOUR_QWEN_API_KEY_HERE';
}

/// 类名：AIService
/// 功能：AI服务单例类，封装与大语言模型API的所有交互
///
/// 主要职责：
/// - 初始化时加载AI配置文件
/// - 提供章节摘要生成接口
/// - 提供全书摘要生成接口（基于前言/章节摘要）
/// - 封装HTTP请求和响应处理逻辑
///
/// 设计模式：
/// - 单例模式：确保全局只有一个AIService实例
///
/// 调用方：
/// - summary_service.dart：调用generateFullChapterSummary、generateBookSummary等方法
/// - settings_screen.dart：检查isConfigured属性
class AIService {
  /// 单例实例
  static final AIService _instance = AIService._internal();

  /// 工厂构造函数，返回单例实例
  factory AIService() => _instance;

  /// 私有构造函数，实现单例模式
  AIService._internal();

  /// AI配置对象，初始化时从配置文件加载
  AIConfig? _config;

  /// HTTP客户端（可被测试替换）
  http.Client? _httpClient;

  /// 日志服务实例
  final _log = LogService();

  /// 测试用：重置服务状态
  @visibleForTesting
  static void resetForTest() {
    AIService._instance._config = null;
    AIService._instance._httpClient = null;
  }

  /// 测试用：设置Mock HTTP客户端
  @visibleForTesting
  void setMockClient(http_testing.MockClient client) {
    _httpClient = client;
  }

  /// 方法名：init
  /// 功能：初始化AI服务，从配置文件加载API配置
  ///
  /// 调用时机：
  /// - 应用启动时在main.dart中调用
  ///
  /// 算法逻辑：
  /// 1. 尝试读取项目根目录的ai_config.json文件
  /// 2. 如果文件存在，解析JSON内容并创建AIConfig实例
  /// 3. 记录加载成功的日志（包含提供商和模型信息）
  /// 4. 如果文件不存在，记录警告日志提示用户创建配置文件
  /// 5. 如果解析失败，记录错误日志
  ///
  /// 异常处理：
  /// - 文件不存在：记录警告，不抛出异常
  /// - JSON解析失败：记录错误，不抛出异常
  Future<void> init() async {
    try {
      final configFile = File('ai_config.json');
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _config = AIConfig.fromJson(json);
        _log.d(
          'AIService',
          'AI配置加载成功: ${_config?.provider}, model: ${_config?.model}',
        );
      } else {
        _log.w('AIService', 'AI配置文件不存在，请创建 ai_config.json');
      }
    } catch (e) {
      _log.e('AIService', '加载AI配置失败', e);
    }
  }

  /// 属性名：isConfigured
  /// 功能：检查AI服务是否已正确配置
  ///
  /// 返回值：true表示配置有效可用，false表示未配置或配置无效
  ///
  /// 使用场景：
  /// - 设置页面显示配置状态
  /// - 生成摘要前检查服务可用性
  bool get isConfigured => _config?.isValid ?? false;

  /// 方法名：generateFullChapterSummary
  /// 功能：生成章节完整摘要
  ///
  /// 参数：
  /// - content: 章节正文内容
  /// - chapterTitle: 章节标题（可选，用于提示词模板）
  ///
  /// 返回值：
  /// - 成功：返回AI生成的章节摘要字符串（Markdown格式）
  /// - 失败：返回null（配置无效或API调用失败）
  ///
  /// 调用方：
  /// - summary_service.dart的generateSummary方法
  ///
  /// 算法逻辑：
  /// 1. 记录详细日志（内容长度、章节标题）
  /// 2. 检查AI配置是否有效，无效则返回null
  /// 3. 使用AiPrompts生成提示词
  /// 4. 调用_callAI发送请求
  /// 5. 返回生成结果或null
  Future<String?> generateFullChapterSummary(
    String content, {
    String? chapterTitle,
  }) async {
    _log.v('AIService',
        'generateFullChapterSummary 开始执行, content length: ${content.length}, chapterTitle: $chapterTitle');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI服务未配置或API Key无效');
      return null;
    }

    final prompt = AiPrompts.chapterSummary(
      chapterTitle: chapterTitle,
      content: content,
    );

    try {
      return await _callAI(prompt);
    } catch (e) {
      _log.e('AIService', '生成完整章节摘要失败', e);
      return null;
    }
  }

  /// 方法名：generateBookSummaryFromPreface
  /// 功能：基于前言/序言内容生成全书摘要
  ///
  /// 参数：
  /// - title: 书籍标题
  /// - author: 书籍作者
  /// - prefaceContent: 前言/序言正文内容
  /// - totalChapters: 总章节数（可选，用于提示词模板）
  ///
  /// 返回值：
  /// - 成功：返回AI生成的全书摘要字符串（Markdown格式，800-900字）
  /// - 失败：返回null（配置无效或API调用失败）
  ///
  /// 调用方：
  /// - summary_service.dart的generateBookSummaryFromPreface方法
  ///
  /// 使用场景：
  /// - 书籍首次导入时，基于前言快速生成全书概览
  /// - 用户手动触发生成全书摘要
  ///
  /// 算法逻辑：
  /// 1. 记录详细日志（书名、作者、前言内容长度）
  /// 2. 检查AI配置是否有效，无效则返回null
  /// 3. 使用AiPrompts生成提示词
  /// 4. 调用_callAI发送请求
  /// 5. 返回生成结果或null
  Future<String?> generateBookSummaryFromPreface({
    required String title,
    required String author,
    required String prefaceContent,
    int? totalChapters,
  }) async {
    _log.v('AIService',
        'generateBookSummaryFromPreface 开始执行, title: $title, author: $author, prefaceContent length: ${prefaceContent.length}');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI服务未配置或API Key无效');
      return null;
    }

    final prompt = AiPrompts.bookSummaryFromPreface(
      title: title,
      author: author,
      prefaceContent: prefaceContent,
      totalChapters: totalChapters,
    );

    try {
      return await _callAI(prompt);
    } catch (e) {
      _log.e('AIService', '基于前言生成全书摘要失败', e);
      return null;
    }
  }

  /// 方法名：generateBookSummary
  /// 功能：基于章节摘要生成全书摘要
  ///
  /// 参数：
  /// - title: 书籍标题
  /// - author: 书籍作者
  /// - chapterSummaries: 所有章节摘要的汇总文本（Markdown格式）
  /// - totalChapters: 总章节数（可选，用于提示词模板）
  ///
  /// 返回值：
  /// - 成功：返回AI生成的全书摘要字符串（Markdown格式，800-900字）
  /// - 失败：返回null（配置无效或API调用失败）
  ///
  /// 调用方：
  /// - summary_service.dart的generateBookSummary方法
  ///
  /// 使用场景：
  /// - 所有章节摘要生成完成后，综合生成全书摘要
  /// - 比基于前言的摘要更准确，因为包含完整章节内容
  ///
  /// 算法逻辑：
  /// 1. 记录详细日志（书名、作者、章节摘要总长度）
  /// 2. 检查AI配置是否有效，无效则返回null
  /// 3. 使用AiPrompts生成提示词
  /// 4. 调用_callAI发送请求
  /// 5. 返回生成结果或null
  Future<String?> generateBookSummary({
    required String title,
    required String author,
    required String chapterSummaries,
    int? totalChapters,
  }) async {
    _log.v('AIService',
        'generateBookSummary 开始执行, title: $title, author: $author, chapterSummaries length: ${chapterSummaries.length}');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI服务未配置或API Key无效');
      return null;
    }

    final prompt = AiPrompts.bookSummary(
      title: title,
      author: author,
      chapterSummaries: chapterSummaries,
      totalChapters: totalChapters,
    );

    try {
      return await _callAI(prompt);
    } catch (e) {
      _log.e('AIService', '生成全书摘要失败', e);
      return null;
    }
  }

  /// 方法名：_callAI
  /// 功能：调用AI API发送请求并获取响应
  ///
  /// 参数：
  /// - prompt: 发送给AI的提示词
  ///
  /// 返回值：
  /// - 成功：返回AI生成的内容字符串
  /// - 失败：返回null（API调用失败或响应格式错误）
  ///
  /// 调用方：
  /// - generateFullChapterSummary（内部方法）
  /// - generateBookSummaryFromPreface（内部方法）
  /// - generateBookSummary（内部方法）
  ///
  /// API兼容性：
  /// - 支持OpenAI兼容接口格式
  /// - 已验证：智谱GLM、通义千问
  ///
  /// 算法逻辑：
  /// 1. 构建请求URL：{baseUrl}/chat/completions
  /// 2. 设置请求头：Content-Type和Authorization
  /// 3. 构建请求体：模型名称、消息列表、温度参数、最大令牌数
  /// 4. 发送POST请求
  /// 5. 如果状态码为200，解析响应JSON并提取内容
  /// 6. 如果状态码非200，记录错误日志并返回null
  ///
  /// 请求体格式：
  /// ```json
  /// {
  ///   "model": "glm-4-flash",
  ///   "messages": [{"role": "user", "content": "提示词"}],
  ///   "temperature": 0.7,
  ///   "max_tokens": 1000
  /// }
  /// ```
  ///
  /// 响应体格式：
  /// ```json
  /// {
  ///   "choices": [
  ///     {
  ///       "message": {
  ///         "content": "AI生成的内容"
  ///       }
  ///     }
  ///   ]
  /// }
  /// ```
  Future<String?> _callAI(String prompt) async {
    final url = Uri.parse('${_config!.baseUrl}/chat/completions');

    final client = _httpClient ?? http.Client();
    final response = await client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config!.apiKey}',
      },
      body: jsonEncode({
        'model': _config!.model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
        'max_tokens': 1000,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['choices']?[0]?['message']?['content'];
    } else {
      _log.e(
        'AIService',
        '智谱API调用失败: ${response.statusCode} - ${response.body}',
      );
      return null;
    }
  }
}
