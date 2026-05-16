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

  /// AI配置对象，初始化时从SettingsService加载
  AiSettings? _config;

  /// HTTP客户端（可被测试替换）
  http.Client? _httpClient;

  /// 日志服务实例
  final _log = LogService();

  // ==========================================================================
  // 区域1：测试辅助方法
  // ==========================================================================

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

  // ==========================================================================
  // 区域2：生命周期管理
  // ==========================================================================

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
  /// 2. 如果配置有效，直接使用AiSettings实例
  /// 3. 如果配置无效，记录警告日志
  ///
  /// 使用场景：
  /// - 初始化时调用
  /// - 用户在设置页面修改AI配置后调用
  Future<void> reloadConfig() async {
    try {
      final aiSettings = SettingsService().settings.aiSettings;

      if (aiSettings.isValid) {
        _config = aiSettings;
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

  // ==========================================================================
  // 区域3：配置管理
  // ==========================================================================

  /// 属性名：isConfigured
  /// 功能：检查AI服务是否已正确配置
  ///
  /// 返回值：true表示配置有效可用，false表示未配置或配置无效
  ///
  /// 使用场景：
  /// - 设置页面显示配置状态
  /// - 生成摘要前检查服务可用性
  bool get isConfigured => _config?.isValid ?? false;

  /// 获取当前AI提供商（如 'zhipu', 'qwen', 'ollama' 等）
  String get currentProvider => _config?.provider ?? '';

  /// 方法名：updateConfig
  /// 功能：从AiSettings更新AI配置
  ///
  /// 参数：
  /// - settings: AiSettings对象，包含新的配置信息
  ///
  /// 使用场景：
  /// - AI配置页面保存新配置后，立即更新AIService
  void updateConfig(AiSettings settings) {
    _config = settings;
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
    if (!isConfigured) {
      _log.w('AIService', '测试连接失败：配置无效');
      return false;
    }

    try {
      final result = await _callAI('Hello');
      if (result != null) {
        _log.d('AIService', '测试连接成功');
        return true;
      } else {
        _log.w('AIService', '测试连接失败：AI返回null');
        return false;
      }
    } catch (e) {
      _log.e('AIService', '测试连接异常', e);
      return false;
    }
  }

  // ==========================================================================
  // 区域4：核心AI调用（所有摘要方法的基础）
  // ==========================================================================

  /// 构建 AI 请求消息列表
  List<Map<String, String>> _buildMessages(String prompt, {String? systemMessage}) {
    final messages = <Map<String, String>>[];

    if (systemMessage != null && systemMessage.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemMessage});
    }

    messages.add({'role': 'user', 'content': prompt});
    return messages;
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

    final response = await client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_config!.apiKey}',
      },
      body: jsonEncode({
        'model': _config!.model,
        'messages': _buildMessages(prompt, systemMessage: systemMessage),
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

    // 构建请求体
    final requestBody = jsonEncode({
      'model': _config!.model,
      'messages': _buildMessages(prompt, systemMessage: systemMessage),
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
        int chunkCount = 0;
        await for (final chunk in response.transform(utf8.decoder)) {
          chunkCount++;
          if (chunkCount <= 3) {
            _log.d('AIService', '收到数据块 #$chunkCount，长度: ${chunk.length}');
          }

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
                // 去掉 data: 之前内容
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
                yield content;
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

  // ==========================================================================
  // 区域5：摘要生成 - 流式版
  // ==========================================================================

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
    if (!isConfigured) {
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
      String detectedLanguage = detectLanguageFromContent(content);
      languageInstruction =
          _getLanguageInstructionForLanguage(detectedLanguage);
      _log.d('AIService',
          '检测到书籍语言为: $detectedLanguage, 使用语言指令: $languageInstruction');
    } else {
      languageInstruction = _getLanguageInstructionForModel(
        aiLanguageMode: langSettings.aiLanguageMode,
        aiOutputLanguage: langSettings.aiOutputLanguage,
      );
    }

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
    if (!isConfigured) {
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
      String detectedLanguage = detectLanguageFromContent(chapterSummaries);
      languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage);
    } else {
      languageInstruction = _getLanguageInstructionForModel(
        aiLanguageMode: langSettings.aiLanguageMode,
        aiOutputLanguage: langSettings.aiOutputLanguage,
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
  ///
  /// 参数：
  /// - title: 书籍标题
  /// - author: 书籍作者
  /// - prefaceContent: 前言/序言正文内容
  /// - totalChapters: 总章节数（可选，用于提示词模板）
  /// - bookId: 书籍ID（可选，用于获取元数据中的语言信息）
  ///
  /// 返回值：
  /// - 成功时返回 AI 生成的内容流
  /// - 失败时返回空流
  Stream<String> generateBookSummaryFromPrefaceStream({
    required String title,
    required String author,
    required String prefaceContent,
    int? totalChapters,
    String? bookId,
  }) async* {
    _log.v('AIService',
        'generateBookSummaryFromPrefaceStream 开始执行，title: $title, author: $author, prefaceContent length: ${prefaceContent.length}, bookId: $bookId');
    if (!isConfigured) {
      _log.w('AIService', 'AI 服务未配置或 API Key 无效');
      return;
    }

    final langSettings = SettingsService().settings.languageSettings;

    String languageInstruction;

    if (langSettings.aiLanguageMode == 'book' && bookId != null) {
      String detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, prefaceContent);
      languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage);
    } else if (langSettings.aiLanguageMode == 'book') {
      String detectedLanguage = detectLanguageFromContent(prefaceContent);
      languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage);
    } else {
      languageInstruction = _getLanguageInstructionForModel(
        aiLanguageMode: langSettings.aiLanguageMode,
        aiOutputLanguage: langSettings.aiOutputLanguage,
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

  // ==========================================================================
  // 区域7：翻译
  // ==========================================================================

  /// 方法名：translateHtmlStream
  /// 功能：流式翻译HTML内容（保留HTML标签）
  Stream<String> translateHtmlStream(
    String content, {
    String? chapterTitle,
    required String sourceLang,
    required String targetLang,
  }) async* {
    _log.v('AIService',
        'translateHtmlStream 开始执行，content length: ${content.length}, sourceLang: $sourceLang, targetLang: $targetLang');
    if (!isConfigured) {
      _log.w('AIService', 'AI 配置未设置或 API Key 无效');
      return;
    }

    final prompt = AiPrompts.translateHtml(
      content: content,
      chapterTitle: chapterTitle,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    final systemMessage = 'You are a professional translator. Translate ALL text content to $targetLang. Do NOT mix languages. Preserve ALL HTML tags exactly as they appear.';

    try {
      await for (final chunk in _callAIStream(prompt, systemMessage: systemMessage)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('AIService', '翻译HTML流失败', e);
    }
  }

  /// 方法名：translateContent
  /// 功能：翻译文本内容（收集流式内容，支持进度回调）
  ///
  /// 参数：
  /// - [content]: 待翻译的内容
  /// - [sourceLang]: 源语言代码
  /// - [targetLang]: 目标语言代码
  /// - [chapterTitle]: 章节标题（可选）
  /// - [onProgress]: 进度回调（当前译文内容）
  ///
  /// 返回：完整的译文
  Future<String> translateContent(
    String content, {
    required String sourceLang,
    required String targetLang,
    String? chapterTitle,
    Function(String)? onProgress,
  }) async {
    if (!isConfigured) {
      _log.w('AIService', 'AI服务未配置，无法翻译');
      return '';
    }

    final buffer = StringBuffer();
    int chunkCount = 0;

    await for (final chunk in translateHtmlStream(
      content,
      chapterTitle: chapterTitle,
      sourceLang: sourceLang,
      targetLang: targetLang,
    )) {
      buffer.write(chunk);
      chunkCount++;

      if (chunkCount <= 3) {
        _log.d('AIService', 'Chunk $chunkCount: $chunk');
      }

      if (onProgress != null) {
        onProgress(buffer.toString());
      }
    }

    final result = buffer.toString();
    _log.d('AIService', '翻译完成，译文长度: ${result.length}, chunk数: $chunkCount');
    return result;
  }

  // ==========================================================================
  // 区域8：语言检测与转换
  // ==========================================================================

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
  /// - 检测到的语言代码 ('zh', 'en', 'ja'等)
  /// - 如果无法确定则返回 'zh' (默认中文)
  Future<String> _detectLanguageFromMetadataAndContentWithBookId(String bookId, String content) async {
    // 从元数据获取语言信息
    final bookService = BookService();
    final book = bookService.getBookById(bookId);
    
    if (book != null && book.language != null && book.language!.isNotEmpty) {
      _log.d('AIService', '从元数据获取到语言信息: ${book.language}');
      // 将常见的语言代码转换为标准格式
      return convertLanguageCodeToStandard(book.language!);
    }
    
    // 如果元数据中没有语言信息，则从内容中检测
    _log.d('AIService', '元数据中没有语言信息，从内容中检测语言');
    return detectLanguageFromContent(content);
  }

  /// 从内容中检测语言
  ///
  /// 通过分析文本内容中的字符特征来判断语言。
  /// 使用比率分析算法：中文字符占比≥30% → zh，
  /// 正确处理中文文本中混合英文单词的情况。
  ///
  /// 参数:
  /// - content: 要分析的文本内容
  ///
  /// 返回:
  /// - 检测到的语言代码 ('zh', 'en', 'ja'等)
  /// - 如果无法确定则返回 'zh' (默认中文)
  String detectLanguageFromContent(String content) {
    if (content.isEmpty) return 'zh';

    // 计算不同语言的字符数量
    int chineseChars = 0;
    int englishChars = 0;
    int japaneseChars = 0;

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
      // 检测英文字符
      else if ((charCode >= 65 && charCode <= 90) || // A-Z
          (charCode >= 97 && charCode <= 122)) {
        // a-z
        englishChars++;
      }
    }

    // 计算总的有效字符数（不包括空格等空白字符）
    int totalChars = chineseChars + englishChars + japaneseChars;

    // 如果没有有效字符，返回默认语言
    if (totalChars == 0) {
      return 'zh';
    }

    // 计算各种语言字符的比例
    double chineseRatio = chineseChars / totalChars;
    double englishRatio = englishChars / totalChars;
    double japaneseRatio = japaneseChars / totalChars;

    // 更加严格的中文判断：如果中文字符比例超过阈值，优先判断为中文
    // 中文文本中常常混有英文单词和技术术语，所以不能仅凭英文字符数量判断
    if (chineseRatio >= 0.3) {
      // 如果中文字符占比超过30%，判断为中文
      return 'zh';
    } else if (japaneseRatio > englishRatio) {
      return 'ja';
    } else if (englishRatio > chineseRatio && englishRatio > japaneseRatio) {
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

    return detectedLanguage;
  }

  /// 将语言代码转换为标准 ISO 639-1 格式
  ///
  /// 处理多种可能的输入格式：
  /// - BCP 47 区域标签：'zh-CN' → 'zh', 'en-US' → 'en'
  /// - ISO 639-2/B 3字母码：'zho' → 'zh', 'chi' → 'zh', 'eng' → 'en'
  /// - 已标准化的2字母码：'zh' → 'zh'
  ///
  /// 参数:
  /// - languageCode: 输入的语言代码
  ///
  /// 返回:
  /// - ISO 639-1 标准2字母语言代码
  String convertLanguageCodeToStandard(String languageCode) {
    // 处理 BCP 47 区域标签 (如 'zh-CN', 'en-US')
    String baseCode;
    if (languageCode.contains('-')) {
      baseCode = languageCode.split('-')[0];
    } else if (languageCode.contains('_')) {
      baseCode = languageCode.split('_')[0];
    } else {
      baseCode = languageCode;
    }

    // ISO 639-2/B → ISO 639-1 映射表
    // 常见3字母语言代码映射到2字母标准代码
    const iso2To1Map = {
      'zho': 'zh', 'chi': 'zh',
      'eng': 'en',
      'jpn': 'ja',
      'fra': 'fr', 'fre': 'fr',
      'deu': 'de', 'ger': 'de',
      'spa': 'es',
      'por': 'pt',
      'ita': 'it',
      'rus': 'ru',
      'ara': 'ar',
    };

    return iso2To1Map[baseCode] ?? baseCode;
  }

  /// 为特定语言生成语言指令
  ///
  /// 参数:
  /// - languageCode: 语言代码 ('zh', 'en', 'ja'等)
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

  /// 检测系统语言
  ///
  /// 通过 Platform.localeName 获取系统语言设置
  /// 返回语言代码：'zh'（中文）、'en'（英文）、'ja'（日文）等
  String _detectSystemLanguage() {
    try {
      final locale = Platform.localeName;
      _log.d('AIService', '系统 locale: $locale');
      
      if (locale.startsWith('zh') || locale.contains('_CN') || locale.contains('_TW') || locale.contains('_HK')) {
        return 'zh';
      } else if (locale.startsWith('ja') || locale.contains('_JP')) {
        return 'ja';
      } else if (locale.startsWith('en') || locale.contains('_US') || locale.contains('_GB')) {
        return 'en';
      }
      
      // 默认中文
      _log.d('AIService', '无法识别的系统 locale，默认使用中文');
      return 'zh';
    } catch (e) {
      _log.w('AIService', '检测系统语言失败: $e，使用默认中文');
      return 'zh';
    }
  }

  /// 获取语言指令（包含系统语言检测）
  ///
  /// 根据语言设置模式和系统语言生成具体的AI语言指令
  String _getLanguageInstructionForModel({
    required String aiLanguageMode,
    String? aiOutputLanguage,
  }) {
    String systemLanguage = _detectSystemLanguage();
    
    return AiPrompts.getLanguageInstruction(
      aiLanguageMode,
      manualLanguage: aiLanguageMode == 'manual' ? aiOutputLanguage : null,
      systemLanguage: aiLanguageMode == 'system' ? systemLanguage : null,
    );
  }

  /// 获取当前目标语言代码
  ///
  /// 根据AI语言模式动态确定目标语言：
  /// - 'book' 模式：从书籍元数据或内容中检测语言
  /// - 'system' 模式：检测系统语言
  /// - 'manual' 模式：使用用户配置的语言
  ///
  /// 参数：
  /// - [aiLanguageMode]: AI语言模式 ('book', 'system', 'manual')
  /// - [aiOutputLanguage]: 用户配置的语言（manual模式时使用）
  /// - [bookLanguage]: 书籍语言（book模式时使用）
  /// - [content]: 章节内容（book模式且无书籍语言时用于检测）
  ///
  /// 返回：目标语言代码（如 'zh', 'en', 'ja'）
  String getTargetLanguage({
    required String aiLanguageMode,
    String? aiOutputLanguage,
    String? bookLanguage,
    String? content,
  }) {
    switch (aiLanguageMode) {
      case 'system':
        return _detectSystemLanguage();
      case 'manual':
        return aiOutputLanguage ?? 'zh';
      case 'book':
      default:
        if (bookLanguage != null && bookLanguage.isNotEmpty) {
          return bookLanguage;
        } else if (content != null && content.isNotEmpty) {
          return detectLanguageFromContent(content);
        }
        return 'zh';
    }
  }
}
