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
import 'settings_service.dart';
import 'book_service.dart';
import '../models/app_settings.dart';

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
  /// 有效值：'zhipu'（智谱）、'qwen'（通义千问）、'ollama'（本地Ollama）、'lmstudio'（本地LM Studio）
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

  /// 方法名：fromAiSettings
  /// 功能：从AiSettings创建AIConfig实例
  ///
  /// 参数：
  /// - settings: AiSettings对象
  ///
  /// 使用场景：
  /// - 从SettingsService的AiSettings转换为AIConfig
  factory AIConfig.fromAiSettings(AiSettings settings) {
    return AIConfig(
      provider: settings.provider,
      apiKey: settings.apiKey,
      model: settings.model,
      baseUrl: settings.baseUrl,
    );
  }
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
  /// 功能：初始化AI服务，从SettingsService加载API配置
  ///
  /// 调用时机：
  /// - 应用启动时在main.dart中调用
  ///
  /// 算法逻辑：
  /// 1. 调用reloadConfig()从SettingsService加载配置
  /// 2. 监听SettingsService.aiSettings的变化
  /// 3. 配置变化时自动重新加载
  ///
  /// 异常处理：
  /// - SettingsService未初始化：记录警告，不抛出异常
  Future<void> init() async {
    await reloadConfig();

    // 监听AI设置变化
    SettingsService().aiSettings.addListener(_onAiSettingsChanged);
  }

  /// 方法名：dispose
  /// 功能：清理资源，移除监听器
  ///
  /// 调用时机：
  /// - 应用退出时调用
  void dispose() {
    SettingsService().aiSettings.removeListener(_onAiSettingsChanged);
  }

  /// 方法名：_onAiSettingsChanged
  /// 功能：AI设置变化时的回调，重新加载配置
  void _onAiSettingsChanged() {
    _log.d('AIService', 'AI设置发生变化，重新加载配置');
    reloadConfig();
  }

  /// 方法名：reloadConfig
  /// 功能：从SettingsService重新加载AI配置
  ///
  /// 算法逻辑：
  /// 1. 从SettingsService获取当前AI设置
  /// 2. 如果配置有效，创建AIConfig实例
  /// 3. 如果配置无效，记录警告日志
  ///
  /// 使用场景：
  /// - 初始化时调用
  /// - 用户在设置页面修改AI配置后调用
  Future<void> reloadConfig() async {
    try {
      final aiSettings = SettingsService().settings.aiSettings;

      if (aiSettings.isValid) {
        _config = AIConfig.fromAiSettings(aiSettings);
        _log.d(
          'AIService',
          'AI配置加载成功: ${_config?.provider}, model: ${_config?.model}',
        );
      } else {
        _log.w('AIService', 'AI配置无效，请检查设置');
        _config = null;
      }
    } catch (e) {
      _log.e('AIService', '从SettingsService加载AI配置失败', e);
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
  /// 功能：生成章节内容摘要
  ///
  /// 参数：
  /// - content: 章节内容的文本
  /// - chapterTitle: 章节标题（可选，用于提示词模板）
  /// - bookId: 书籍ID（可选，用于获取元数据中的语言信息）
  ///
  /// 返回值：
  /// - 成功时返回 AI 生成的章节摘要字符串（Markdown 格式）
  /// - 失败时返回 null（配置无效或 API 调用失败）
  ///
  /// 调用方：
  /// - summary_service.dart 的 generateSummary 方法
  ///
  /// 算法逻辑：
  /// 1. 记录详细日志（内容长度、章节标题）
  /// 2. 检查 AI 配置是否有效（无效则返回 null）
  /// 3. 从 SettingsService 读取语言设置
  /// 4. 使用 AiPrompts 构建提示词
  /// 5. 调用_callAI 方法发送请求
  /// 6. 返回结果或 null
  Future<String?> generateFullChapterSummary(
    String content, {
    String? chapterTitle,
    String? bookId,
  }) async {
    _log.v('AIService',
        'generateFullChapterSummary 开始执行，content length: ${content.length}, chapterTitle: $chapterTitle, bookId: $bookId');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI 配置未设置或 API Key 无效');
      return null;
    }

    // 从 SettingsService 读取语言设置
    final langSettings = SettingsService().settings.languageSettings;
    _log.d('AIService',
        '语言设置：aiLanguageMode=${langSettings.aiLanguageMode}, aiOutputLanguage=${langSettings.aiOutputLanguage}');

    String languageInstruction;

    // 如果是书籍语言模式，优先使用书籍元数据中的语言信息，否则从内容中检测语言
    if (langSettings.aiLanguageMode == 'book' && bookId != null) {
      String detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, content);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else if (langSettings.aiLanguageMode == 'book') {
      String detectedLanguage = _detectLanguageFromMetadataAndContent(content);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else {
      languageInstruction = AiPrompts.getLanguageInstruction(
        langSettings.aiLanguageMode,
        manualLanguage: langSettings.aiLanguageMode == 'manual'
            ? langSettings.aiOutputLanguage
            : null,
      );
    }

    _log.d('AIService', '生成的语言指令：$languageInstruction');

    final prompt = AiPrompts.chapterSummary(
      chapterTitle: chapterTitle,
      content: content,
      languageInstruction: languageInstruction,
    );

    try {
      return await _callAI(prompt, systemMessage: languageInstruction);
    } catch (e) {
      _log.e('AIService', '生成章节摘要失败', e);
      return null;
    }
  }

  /// 方法名：generateFullChapterSummaryStream
  /// 功能：生成章节内容摘要（流式）
  ///
  /// 参数：
  /// - content: 章节内容的文本
  /// - chapterTitle: 章节标题（可选，用于提示词模板）
  /// - bookId: 书籍ID（可选，用于获取元数据中的语言信息）
  ///
  /// 返回值：
  /// - 成功时返回 AI 生成的章节摘要内容流
  /// - 失败时返回空流
  ///
  /// 调用方：
  /// - summary_service.dart 的 generateSummaryStream 方法
  ///
  /// 算法逻辑：
  /// 1. 记录详细日志（内容长度、章节标题）
  /// 2. 检查 AI 配置是否有效（无效则返回空流）
  /// 3. 从 SettingsService 读取语言设置
  /// 4. 使用 AiPrompts 构建提示词
  /// 5. 调用_callAIStream 方法发送流式请求
  /// 6. 逐个返回内容片段
  Stream<String> generateFullChapterSummaryStream(
    String content, {
    String? chapterTitle,
    String? bookId,
  }) async* {
    _log.v('AIService',
        'generateFullChapterSummaryStream 开始执行，content length: ${content.length}, chapterTitle: $chapterTitle, bookId: $bookId');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI 配置未设置或 API Key 无效');
      return;
    }

    // 从 SettingsService 读取语言设置
    final langSettings = SettingsService().settings.languageSettings;
    _log.d('AIService',
        '语言设置：aiLanguageMode=${langSettings.aiLanguageMode}, aiOutputLanguage=${langSettings.aiOutputLanguage}');

    String languageInstruction;

    // 如果是书籍语言模式，优先使用书籍元数据中的语言信息，否则从内容中检测语言
    if (langSettings.aiLanguageMode == 'book' && bookId != null) {
      String detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, content);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else if (langSettings.aiLanguageMode == 'book') {
      String detectedLanguage = _detectLanguageFromMetadataAndContent(content);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else {
      languageInstruction = AiPrompts.getLanguageInstruction(
        langSettings.aiLanguageMode,
        manualLanguage: langSettings.aiLanguageMode == 'manual'
            ? langSettings.aiOutputLanguage
            : null,
      );
    }

    _log.d('AIService', '生成的语言指令：$languageInstruction');

    final prompt = AiPrompts.chapterSummary(
      chapterTitle: chapterTitle,
      content: content,
      languageInstruction: languageInstruction,
    );

    try {
      await for (final chunk in _callAIStream(prompt, systemMessage: languageInstruction)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('AIService', '生成章节摘要流失败', e);
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
  /// - bookId: 书籍ID（可选，用于获取元数据中的语言信息）
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
  /// 3. 如果bookId提供且语言模式为'book'，优先从元数据获取语言信息
  /// 4. 使用AiPrompts生成提示词
  /// 5. 调用_callAI发送请求
  /// 6. 返回生成结果或null
  Future<String?> generateBookSummaryFromPreface({
    required String title,
    required String author,
    required String prefaceContent,
    int? totalChapters,
    String? bookId,
  }) async {
    _log.v('AIService',
        'generateBookSummaryFromPreface 开始执行，title: $title, author: $author, prefaceContent length: ${prefaceContent.length}, bookId: $bookId');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI 服务未配置或 API Key 无效');
      return null;
    }

    // 从 SettingsService 读取语言设置
    final langSettings = SettingsService().settings.languageSettings;
    _log.d('AIService',
        '语言设置：aiLanguageMode=${langSettings.aiLanguageMode}, aiOutputLanguage=${langSettings.aiOutputLanguage}');

    String languageInstruction;

    // 如果是书籍语言模式，优先使用书籍元数据中的语言信息，否则从内容中检测语言
    if (langSettings.aiLanguageMode == 'book' && bookId != null) {
      String detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, prefaceContent);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else if (langSettings.aiLanguageMode == 'book') {
      String detectedLanguage = _detectLanguageFromMetadataAndContent(prefaceContent);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else {
      languageInstruction = AiPrompts.getLanguageInstruction(
        langSettings.aiLanguageMode,
        manualLanguage: langSettings.aiLanguageMode == 'manual'
            ? langSettings.aiOutputLanguage
            : null,
      );
    }

    _log.d('AIService', '生成的语言指令：$languageInstruction');

    final prompt = AiPrompts.bookSummaryFromPreface(
      title: title,
      author: author,
      prefaceContent: prefaceContent,
      totalChapters: totalChapters,
      languageInstruction: languageInstruction,
    );

    try {
      return await _callAI(prompt, systemMessage: languageInstruction);
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
  /// - bookId: 书籍ID（可选，用于获取元数据中的语言信息）
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
  /// 3. 如果bookId提供且语言模式为'book'，优先从元数据获取语言信息
  /// 4. 使用AiPrompts生成提示词
  /// 5. 调用_callAI发送请求
  /// 6. 返回生成结果或null
  Future<String?> generateBookSummary({
    required String title,
    required String author,
    required String chapterSummaries,
    int? totalChapters,
    String? bookId,
  }) async {
    _log.v('AIService',
        'generateBookSummary 开始执行，title: $title, author: $author, chapterSummaries length: ${chapterSummaries.length}, bookId: $bookId');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI 服务未配置或 API Key 无效');
      return null;
    }

    // 从 SettingsService 读取语言设置
    final langSettings = SettingsService().settings.languageSettings;
    _log.d('AIService',
        '语言设置：aiLanguageMode=${langSettings.aiLanguageMode}, aiOutputLanguage=${langSettings.aiOutputLanguage}');

    String languageInstruction;

    // 如果是书籍语言模式，优先使用书籍元数据中的语言信息，否则从内容中检测语言
    if (langSettings.aiLanguageMode == 'book' && bookId != null) {
      String detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, chapterSummaries);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else if (langSettings.aiLanguageMode == 'book') {
      String detectedLanguage = _detectLanguageFromMetadataAndContent(chapterSummaries);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else {
      languageInstruction = AiPrompts.getLanguageInstruction(
        langSettings.aiLanguageMode,
        manualLanguage: langSettings.aiLanguageMode == 'manual'
            ? langSettings.aiOutputLanguage
            : null,
      );
    }

    _log.d('AIService', '生成的语言指令：$languageInstruction');

    final prompt = AiPrompts.bookSummary(
      title: title,
      author: author,
      chapterSummaries: chapterSummaries,
      totalChapters: totalChapters,
      languageInstruction: languageInstruction,
    );

    try {
      // 将语言指令作为 system message 传递，强化语言要求
      return await _callAI(prompt, systemMessage: languageInstruction);
    } catch (e) {
      _log.e('AIService', '生成全书摘要失败', e);
      return null;
    }
  }

  /// 方法名：generateBookSummaryStream
  /// 功能：基于章节摘要生成全书摘要（流式）
  ///
  /// 参数：
  /// - title: 书籍标题
  /// - author: 书籍作者
  /// - chapterSummaries: 所有章节摘要的汇总文本（Markdown格式）
  /// - totalChapters: 总章节数（可选，用于提示词模板）
  /// - bookId: 书籍ID（可选，用于获取元数据中的语言信息）
  ///
  /// 返回值：
  /// - 成功时返回 AI 生成的内容流
  /// - 失败时返回空流
  Stream<String> generateBookSummaryStream({
    required String title,
    required String author,
    required String chapterSummaries,
    int? totalChapters,
    String? bookId,
  }) async* {
    _log.v('AIService',
        'generateBookSummaryStream 开始执行，title: $title, author: $author, chapterSummaries length: ${chapterSummaries.length}, bookId: $bookId');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI 服务未配置或 API Key 无效');
      return;
    }

    // 从 SettingsService 读取语言设置
    final langSettings = SettingsService().settings.languageSettings;

    String languageInstruction;

    if (langSettings.aiLanguageMode == 'book' && bookId != null) {
      String detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, chapterSummaries);
      languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage);
    } else if (langSettings.aiLanguageMode == 'book') {
      String detectedLanguage = _detectLanguageFromMetadataAndContent(chapterSummaries);
      languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage);
    } else {
      languageInstruction = AiPrompts.getLanguageInstruction(
        langSettings.aiLanguageMode,
        manualLanguage: langSettings.aiLanguageMode == 'manual'
            ? langSettings.aiOutputLanguage
            : null,
      );
    }

    final prompt = AiPrompts.bookSummary(
      title: title,
      author: author,
      chapterSummaries: chapterSummaries,
      totalChapters: totalChapters,
      languageInstruction: languageInstruction,
    );

    try {
      await for (final chunk in _callAIStream(prompt, systemMessage: languageInstruction)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('AIService', '生成全书摘要流失败', e);
    }
  }

  /// 方法名：generateBookSummaryFromPrefaceStream
  /// 功能：基于前言/序言内容生成全书摘要（流式）
  Stream<String> generateBookSummaryFromPrefaceStream({
    required String title,
    required String author,
    required String prefaceContent,
    int? totalChapters,
    String? bookId,
  }) async* {
    _log.v('AIService',
        'generateBookSummaryFromPrefaceStream 开始执行，title: $title, author: $author, prefaceContent length: ${prefaceContent.length}, bookId: $bookId');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI 服务未配置或 API Key 无效');
      return;
    }

    final langSettings = SettingsService().settings.languageSettings;

    String languageInstruction;

    if (langSettings.aiLanguageMode == 'book' && bookId != null) {
      String detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, prefaceContent);
      languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage);
    } else if (langSettings.aiLanguageMode == 'book') {
      String detectedLanguage = _detectLanguageFromMetadataAndContent(prefaceContent);
      languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage);
    } else {
      languageInstruction = AiPrompts.getLanguageInstruction(
        langSettings.aiLanguageMode,
        manualLanguage: langSettings.aiLanguageMode == 'manual'
            ? langSettings.aiOutputLanguage
            : null,
      );
    }

    final prompt = AiPrompts.bookSummaryFromPreface(
      title: title,
      author: author,
      prefaceContent: prefaceContent,
      totalChapters: totalChapters,
      languageInstruction: languageInstruction,
    );

    try {
      await for (final chunk in _callAIStream(prompt, systemMessage: languageInstruction)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('AIService', '基于前言生成全书摘要流失败', e);
    }
  }

  /// 从书籍元数据和内容中检测语言
  ///
  /// 优先从书籍元数据中的语言信息，如果元数据中没有语言信息，则从内容中检测语言
  /// 使用更精确的算法，考虑不同语言的字符比例和分布特点
  ///
  /// 参数:
  /// - bookId: 书籍ID，用于获取元数据
  /// - content: 文本内容，用于检测语言
  ///
  /// 返回:
  /// - 检测到的语言代码 ('zh', 'en', 'ja', 'ko'等)
  /// - 如果无法确定则返回 'zh' (默认中文)
  Future<String> _detectLanguageFromMetadataAndContentWithBookId(String bookId, String content) async {
    // 从元数据获取语言信息
    final bookService = BookService();
    final book = bookService.getBookById(bookId);
    
    if (book != null && book.language != null && book.language!.isNotEmpty) {
      _log.d('AIService', '从元数据获取到语言信息: ${book.language}');
      // 将常见的语言代码转换为标准格式
      return _convertLanguageCodeToStandard(book.language!);
    }
    
    // 如果元数据中没有语言信息，则从内容中检测
    _log.d('AIService', '元数据中没有语言信息，从内容中检测语言');
    return _detectLanguageFromMetadataAndContent(content);
  }

  /// 从内容中检测语言
  ///
  /// 通过分析文本内容中的字符特征来判断语言
  /// 使用更精确的算法，考虑不同语言的字符比例和分布特点
  ///
  /// 参数:
  /// - content: 要分析的文本内容
  ///
  /// 返回:
  /// - 检测到的语言代码 ('zh', 'en', 'ja', 'ko'等)
  /// - 如果无法确定则返回 'zh' (默认中文)
  String _detectLanguageFromMetadataAndContent(String content) {
    if (content.isEmpty) return 'zh';

    // 计算不同语言的字符数量
    int chineseChars = 0;
    int englishChars = 0;
    int japaneseChars = 0;
    int koreanChars = 0;
    int punctuationChars = 0; // 标点符号和特殊字符

    for (int i = 0; i < content.length; i++) {
      int charCode = content.codeUnitAt(i);

      // 检测中文字符
      if ((charCode >= 0x4e00 && charCode <= 0x9fff) || // CJK统一汉字
          (charCode >= 0x3400 && charCode <= 0x4dbf) || // CJK扩展A
          (charCode >= 0xf900 && charCode <= 0xfaff)) {
        // CJK兼容汉字
        chineseChars++;
      }
      // 检测日文字符
      else if ((charCode >= 0x3040 && charCode <= 0x309f) || // 平假名
          (charCode >= 0x30a0 && charCode <= 0x30ff) || // 片假名
          (charCode >= 0x31f0 && charCode <= 0x31ff)) {
        // 日文片假名扩展
        japaneseChars++;
      }
      // 检测韩文字符
      else if (charCode >= 0xac00 && charCode <= 0xd7af) {
        // 韩文音节
        koreanChars++;
      }
      // 检测英文字符
      else if ((charCode >= 65 && charCode <= 90) || // A-Z
          (charCode >= 97 && charCode <= 122)) {
        // a-z
        englishChars++;
      }
      // 检测常见标点符号和特殊字符（这些在各种语言中都存在，但需要分开统计）
      else if ((charCode >= 32 && charCode <= 47) || // 空格和标点
          (charCode >= 58 && charCode <= 64) || // 标点和特殊符号
          (charCode >= 91 && charCode <= 96) || // 标点和特殊符号
          (charCode >= 123 && charCode <= 126) || // 标点和特殊符号
          (charCode >= 12288 && charCode <= 12543)) {
        // 中文标点符号
        punctuationChars++;
      }
    }

    // 计算总的有效字符数（不包括空格等空白字符）
    int totalChars = chineseChars + englishChars + japaneseChars + koreanChars;

    // 如果没有有效字符，返回默认语言
    if (totalChars == 0) {
      return 'zh';
    }

    // 计算各种语言字符的比例
    double chineseRatio = chineseChars / totalChars;
    double englishRatio = englishChars / totalChars;
    double japaneseRatio = japaneseChars / totalChars;
    double koreanRatio = koreanChars / totalChars;

    // 更加严格的中文判断：如果中文字符比例超过阈值，优先判断为中文
    // 中文文本中常常混有英文单词和技术术语，所以不能仅凭英文字符数量判断
    if (chineseRatio >= 0.3) {
      // 如果中文字符占比超过30%，判断为中文
      return 'zh';
    } else if (japaneseRatio > englishRatio && japaneseRatio > koreanRatio) {
      return 'ja';
    } else if (koreanRatio > englishRatio) {
      return 'ko';
    } else if (englishRatio > chineseRatio &&
        englishRatio > japaneseRatio &&
        englishRatio > koreanRatio) {
      return 'en';
    }

    // 如果都不满足条件，根据数量判断
    int maxCount = 0;
    String detectedLanguage = 'zh'; // 默认中文

    if (chineseChars > maxCount) {
      maxCount = chineseChars;
      detectedLanguage = 'zh';
    }
    if (englishChars > maxCount) {
      maxCount = englishChars;
      detectedLanguage = 'en';
    }
    if (japaneseChars > maxCount) {
      maxCount = japaneseChars;
      detectedLanguage = 'ja';
    }
    if (koreanChars > maxCount) {
      maxCount = koreanChars;
      detectedLanguage = 'ko';
    }

    return detectedLanguage;
  }

  /// 从内容中检测语言
  ///
  /// 通过分析文本内容中的字符特征来判断语言
  /// 使用更精确的算法，考虑不同语言的字符比例和分布特点
  ///
  /// 参数:
  /// - content: 要分析的文本内容
  ///
  /// 返回:
  /// - 检测到的语言代码 ('zh', 'en', 'ja', 'ko'等)
  /// - 如果无法确定则返回 'zh' (默认中文)
  String _detectLanguageFromContent(String content) {
    if (content.isEmpty) return 'zh';

    // 计算不同语言的字符数量
    int chineseChars = 0;
    int englishChars = 0;
    int japaneseChars = 0;
    int koreanChars = 0;
    int punctuationChars = 0; // 标点符号和特殊字符

    for (int i = 0; i < content.length; i++) {
      int charCode = content.codeUnitAt(i);

      // 检测中文字符
      if ((charCode >= 0x4e00 && charCode <= 0x9fff) || // CJK统一汉字
          (charCode >= 0x3400 && charCode <= 0x4dbf) || // CJK扩展A
          (charCode >= 0xf900 && charCode <= 0xfaff)) {
        // CJK兼容汉字
        chineseChars++;
      }
      // 检测日文字符
      else if ((charCode >= 0x3040 && charCode <= 0x309f) || // 平假名
          (charCode >= 0x30a0 && charCode <= 0x30ff) || // 片假名
          (charCode >= 0x31f0 && charCode <= 0x31ff)) {
        // 日文片假名扩展
        japaneseChars++;
      }
      // 检测韩文字符
      else if (charCode >= 0xac00 && charCode <= 0xd7af) {
        // 韩文音节
        koreanChars++;
      }
      // 检测英文字符
      else if ((charCode >= 65 && charCode <= 90) || // A-Z
          (charCode >= 97 && charCode <= 122)) {
        // a-z
        englishChars++;
      }
      // 检测常见标点符号和特殊字符（这些在各种语言中都存在，但需要分开统计）
      else if ((charCode >= 32 && charCode <= 47) || // 空格和标点
          (charCode >= 58 && charCode <= 64) || // 标点和特殊符号
          (charCode >= 91 && charCode <= 96) || // 标点和特殊符号
          (charCode >= 123 && charCode <= 126) || // 标点和特殊符号
          (charCode >= 12288 && charCode <= 12543)) {
        // 中文标点符号
        punctuationChars++;
      }
    }

    // 计算总的有效字符数（不包括空格等空白字符）
    int totalChars = chineseChars + englishChars + japaneseChars + koreanChars;

    // 如果没有有效字符，返回默认语言
    if (totalChars == 0) {
      return 'zh';
    }

    // 计算各种语言字符的比例
    double chineseRatio = chineseChars / totalChars;
    double englishRatio = englishChars / totalChars;
    double japaneseRatio = japaneseChars / totalChars;
    double koreanRatio = koreanChars / totalChars;

    // 更加严格的中文判断：如果中文字符比例超过阈值，优先判断为中文
    // 中文文本中常常混有英文单词和技术术语，所以不能仅凭英文字符数量判断
    if (chineseRatio >= 0.3) {
      // 如果中文字符占比超过30%，判断为中文
      return 'zh';
    } else if (japaneseRatio > englishRatio && japaneseRatio > koreanRatio) {
      return 'ja';
    } else if (koreanRatio > englishRatio) {
      return 'ko';
    } else if (englishRatio > chineseRatio &&
        englishRatio > japaneseRatio &&
        englishRatio > koreanRatio) {
      return 'en';
    }

    // 如果都不满足条件，根据数量判断
    int maxCount = 0;
    String detectedLanguage = 'zh'; // 默认中文

    if (chineseChars > maxCount) {
      maxCount = chineseChars;
      detectedLanguage = 'zh';
    }
    if (englishChars > maxCount) {
      maxCount = englishChars;
      detectedLanguage = 'en';
    }
    if (japaneseChars > maxCount) {
      maxCount = japaneseChars;
      detectedLanguage = 'ja';
    }
    if (koreanChars > maxCount) {
      maxCount = koreanChars;
      detectedLanguage = 'ko';
    }

    return detectedLanguage;
  }

  /// 将语言代码转换为标准格式
  ///
  /// 将常见的语言代码格式转换为内部使用的标准格式
  /// 如 'zh-CN' -> 'zh', 'en-US' -> 'en' 等
  ///
  /// 参数:
  /// - languageCode: 输入的语言代码
  ///
  /// 返回:
  /// - 标准化的语言代码
  String _convertLanguageCodeToStandard(String languageCode) {
    // 处理常见的语言代码格式
    if (languageCode.contains('-')) {
      // 如 'zh-CN' -> 'zh', 'en-US' -> 'en'
      return languageCode.split('-')[0];
    } else if (languageCode.contains('_')) {
      // 如 'zh_CN' -> 'zh'
      return languageCode.split('_')[0];
    }
    
    // 如果已经是标准格式，直接返回
    return languageCode;
  }

  /// 为特定语言生成语言指令
  ///
  /// 参数:
  /// - languageCode: 语言代码 ('zh', 'en', 'ja', 'ko'等)
  ///
  /// 返回:
  /// - 对应语言的指令字符串
  String _getLanguageInstructionForLanguage(String languageCode) {
    switch (languageCode) {
      case 'zh':
        return 'IMPORTANT: Respond in Chinese (简体中文).';
      case 'en':
        return 'IMPORTANT: Respond in English.';
      case 'ja':
        return 'IMPORTANT: Respond in Japanese (日本語).';
      case 'ko':
        return 'IMPORTANT: Respond in Korean (한국어).';
      case 'fr':
        return 'IMPORTANT: Respond in French (Français).';
      case 'de':
        return 'IMPORTANT: Respond in German (Deutsch).';
      case 'ru':
        return 'IMPORTANT: Respond in Russian (Русский).';
      case 'es':
        return 'IMPORTANT: Respond in Spanish (Español).';
      default:
        return 'IMPORTANT: Respond in Chinese (简体中文).'; // 默认中文
    }
  }

  /// 方法名：_callAI
  /// 功能：调用 AI API 发送请求并获取响应
  ///
  /// 参数：
  /// - prompt: 发送给 AI 的提示词
  /// - systemMessage: 系统级指令（可选），用于设置行为准则
  ///
  /// 返回值：
  /// - 成功时返回 AI 生成的内容字符串
  /// - 失败时返回 null
  ///
  /// 使用场景：
  /// - 所有 AI 调用的统一入口
  ///
  /// 算法逻辑：
  /// 1. 构建请求 URL：{baseUrl}/chat/completions
  /// 2. 设置请求头：Content-Type、Authorization
  /// 3. 构建请求体：模型名称、消息列表、温度参数、最大 token 数
  /// 4. 发送 POST 请求
  /// 5. 如果状态码为 200，解析响应 JSON 并提取内容
  /// 6. 如果状态码非 200，记录错误日志并返回 null
  ///
  /// 请求体格式：
  /// ```json
  /// {
  ///   "model": "glm-4-flash",
  ///   "messages": [
  ///     {"role": "system", "content": "系统指令"},
  ///     {"role": "user", "content": "用户提示词"}
  ///   ],
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
  ///         "content": "AI 生成的内容"
  ///       }
  ///     }
  ///   ]
  /// }
  /// ```
  Future<String?> _callAI(String prompt, {String? systemMessage}) async {
    final url = Uri.parse('${_config!.baseUrl}/chat/completions');

    final client = _httpClient ?? http.Client();

    // 构建消息列表
    final messages = <Map<String, String>>[];

    // 如果有系统消息，添加为 system role
    if (systemMessage != null && systemMessage.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemMessage});
    }

    // 添加用户提示词
    messages.add({'role': 'user', 'content': prompt});

    final response = await client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config!.apiKey}',
      },
      body: jsonEncode({
        'model': _config!.model,
        'messages': messages,
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
        'AI API 调用失败：${response.statusCode} - ${response.body}',
      );
      return null;
    }
  }

  /// 方法名：_callAIStream
  /// 功能：调用 AI API 发送流式请求并获取响应
  ///
  /// 参数：
  /// - prompt: 发送给 AI 的提示词
  /// - systemMessage: 系统级指令（可选），用于设置行为准则
  ///
  /// 返回值：
  /// - 成功时返回 AI 生成的内容流
  /// - 失败时返回空流
  ///
  /// 使用场景：
  /// - 需要流式响应的 AI 调用
  ///
  /// 算法逻辑：
  /// 1. 构建请求 URL：{baseUrl}/chat/completions
  /// 2. 设置请求头：Content-Type、Authorization、Accept、Cache-Control、Connection
  /// 3. 构建请求体：模型名称、消息列表、温度参数、最大 token 数、stream: true
  /// 4. 发送 POST 请求
  /// 5. 解析 SSE 数据流，逐个 yield 内容片段
  ///
  /// 请求体格式：
  /// ```json
  /// {
  ///   "model": "glm-4-flash",
  ///   "messages": [
  ///     {"role": "system", "content": "系统指令"},
  ///     {"role": "user", "content": "用户提示词"}
  ///   ],
  ///   "temperature": 0.7,
  ///   "max_tokens": 1000,
  ///   "stream": true
  /// }
  /// ```
  ///
  /// 响应体格式（SSE）：
  /// ```
  /// data: {"choices":[{"delta":{"content":"AI生成的内容片段"},"index":0,"finish_reason":null}]}
  /// data: [DONE]
  /// ```
  Stream<String> _callAIStream(String prompt, {String? systemMessage}) async* {
    final url = Uri.parse('${_config!.baseUrl}/chat/completions');

    // 构建消息列表
    final messages = <Map<String, String>>[];

    // 如果有系统消息，添加为 system role
    if (systemMessage != null && systemMessage.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemMessage});
    }

    // 添加用户提示词
    messages.add({'role': 'user', 'content': prompt});

    // 构建请求体
    final requestBody = jsonEncode({
      'model': _config!.model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 8000,  // 增加 token 限制以支持全文翻译
      'stream': true,  // 启用流式响应
    });

    // 使用 dart:io 的原生 HttpClient 实现真正的流式请求
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 30);

    try {
      final request = await httpClient.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer ${_config!.apiKey}');
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');

      // 写入请求体
      request.add(utf8.encode(requestBody));

      // 获取响应流
      final response = await request.close();

      if (response.statusCode == 200) {
        // SSE 数据缓冲区和状态
        String buffer = '';
        bool insideDataEvent = false;
        String currentDataContent = '';

        // 监听数据到达事件
        await for (final chunk in response.transform(utf8.decoder)) {
          _log.d('AIService', '收到数据块，长度: ${chunk.length}');

          buffer += chunk;

          // 持续处理缓冲区，直到没有完整的事件
          while (buffer.isNotEmpty) {
            // 如果不在数据事件中，查找 "data: " 起始位置
            if (!insideDataEvent) {
              final dataIndex = buffer.indexOf('data: ');
              if (dataIndex == -1) {
                // 没有找到 data: ，清除缓冲区（通常是空白或无效内容）
                buffer = '';
                break;
              } else if (dataIndex > 0) {
                // 去掉 data: 之前的内容
                buffer = buffer.substring(dataIndex);
                continue;
              }

              // 找到 data: ，开始收集数据
              insideDataEvent = true;
              buffer = buffer.substring(6); // 去掉 "data: " 前缀
              currentDataContent = '';
            }

            // 查找行结束符
            final lineEnd = buffer.indexOf('\n');
            if (lineEnd == -1) {
              // 没有完整的行，需要等待更多数据
              currentDataContent += buffer;
              buffer = '';
              break;
            }

            // 提取完整行
            final line = currentDataContent + buffer.substring(0, lineEnd).trim();
            buffer = buffer.substring(lineEnd + 1);

            if (line == '[DONE]') {
              _log.d('AIService', '收到 [DONE]，流式响应结束');
              return;
            }

            if (line.isEmpty) {
              // 空行表示事件结束
              insideDataEvent = false;
              continue;
            }

                        // 解析 JSON
            try {
              final jsonData = jsonDecode(line);
              final content = jsonData['choices']?[0]?['delta']?['content'];
              if (content != null && content.isNotEmpty) {
                _log.d('AIService', '解析到内容片段: "$content"');
                yield content;  // 流式返回内容片段
              }
            } catch (e) {
              _log.w('AIService', '解析SSE数据失败: $e, line: $line');
            }

            // 重置状态
            insideDataEvent = false;
            currentDataContent = '';
          }
        }
      } else {
        _log.e('AIService', 'AI API 流式调用失败：${response.statusCode}');
      }
    } catch (e) {
      _log.e('AIService', '流式请求异常', e);
    } finally {
      httpClient.close();
    }
  }

  /// 方法名：updateConfig
  /// 功能：从AiSettings更新AI配置
  ///
  /// 参数：
  /// - settings: AiSettings对象，包含新的配置信息
  ///
  /// 使用场景：
  /// - AI配置页面保存新配置后，立即更新AIService
  void updateConfig(AiSettings settings) {
    _config = AIConfig(
      provider: settings.provider,
      apiKey: settings.apiKey,
      model: settings.model,
      baseUrl: settings.baseUrl,
    );
    _log.d('AIService',
        '配置已更新: provider=${settings.provider}, model=${settings.model}');
  }

  /// 方法名：testConnection
  /// 功能：测试AI连接是否可用
  ///
  /// 发送一个简单的测试请求到AI服务，验证配置是否正确
  ///
  /// 返回值：
  /// - true: 连接成功，配置有效
  /// - false: 连接失败，配置可能不正确
  Future<bool> testConnection() async {
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', '测试连接失败：配置无效');
      return false;
    }

    try {
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
            {'role': 'user', 'content': 'Hello'},
          ],
          'temperature': 0.7,
          'max_tokens': 10,
        }),
      );

      if (response.statusCode == 200) {
        _log.d('AIService', '测试连接成功');
        return true;
      } else {
        _log.w('AIService', '测试连接失败: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _log.e('AIService', '测试连接异常', e);
      return false;
    }
  }

  /// 方法名：translateChapterStream
  /// 功能：流式翻译章节内容
  ///
  /// 参数：
  /// - content: 章节原文内容
  /// - chapterTitle: 章节标题（可选）
  /// - sourceLang: 源语言代码（如 'zh', 'en', 'ja'）
  /// - targetLang: 目标语言代码（如 'zh', 'en', 'ja'）
  ///
  /// 返回值：
  /// - 成功时返回 AI 生成的翻译内容流
  /// - 失败时返回空流
  Stream<String> translateChapterStream(
    String content, {
    String? chapterTitle,
    required String sourceLang,
    required String targetLang,
  }) async* {
    _log.v('AIService',
        'translateChapterStream 开始执行，content length: ${content.length}, sourceLang: $sourceLang, targetLang: $targetLang');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI 配置未设置或 API Key 无效');
      return;
    }

    final prompt = AiPrompts.translateChapter(
      content: content,
      chapterTitle: chapterTitle,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    final systemMessage = 'IMPORTANT: Respond in $targetLang.';

    try {
      await for (final chunk in _callAIStream(prompt, systemMessage: systemMessage)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('AIService', '翻译章节流失败', e);
    }
  }
}