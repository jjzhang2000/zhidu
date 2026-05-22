// ============================================================================
// 文件名：ai_service.dart
// 功能：AI服务核心模块，负责与大语言模型API的交互
//
// 主要职责：
// - 加载和管理AI配置（API Key、模型、Base URL等）
// - 封装AI API调用逻辑（兼容智谱/通义千问等OpenAI兼容接口）
// - 提供章节摘要、全书摘要、翻译等 AI 生成能力（流式）
//
// 调用方：
// - summary_service.dart：摘要生成与翻译
// - chapter_screen.dart：语言检测与翻译判断
// - ai_config_screen.dart：连接测试、模型获取
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logger/logger.dart';
import 'ai_prompts.dart';
import 'settings_service.dart';
import 'book_service.dart';
import '../models/app_settings.dart';
import '../l10n/app_localizations.dart';
import 'log_helper.dart';


/// 功能：AI服务单例类，封装与大语言模型API的所有交互
///
/// 主要职责：
/// - 初始化时加载AI配置文件
/// - 提供章节摘要、全书摘要、翻译的流式生成接口
/// - 提供语言检测与翻译判断
/// - 封装HTTP请求和SSE流式响应处理
///
/// 设计模式：
/// - 单例模式：确保全局只有一个AIService实例
class AIService {
  /// 单例实例
  static final AIService _instance = AIService._internal();

  /// 工厂构造函数，返回单例实例
  factory AIService() => _instance;

  /// 私有构造函数，实现单例模式
  AIService._internal();

  /// AI配置对象，初始化时从SettingsService加载
  AiSettings? _config;

  /// 日志服务实例
  final _log = createLogger('AIService');

  // ==========================================================================
  // 区域1：生命周期管理
  // ==========================================================================

  /// 测试用：重置服务状态
  @visibleForTesting
  static void resetForTest() {
    AIService._instance._config = null;
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

  /// 方法名：_onAiSettingsChanged
  /// 功能：AI设置变化时的回调，重新加载配置
  void _onAiSettingsChanged() {
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
        _log.i('AI配置加载成功: ${_config?.provider}, model: ${_config?.model}');
      } else {
        _log.w('AI配置无效，请检查设置');
        _config = null;
      }
    } catch (e) {
      _log.e('从SettingsService加载AI配置失败', error: e);
    }
  }

  // ==========================================================================
  // 区域2：配置管理
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

  /// 获取当前AI提供商（如 'zhipu', stackTrace: 'qwen', 'ollama' 等）
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
      _log.w('测试连接失败：配置无效');
      return false;
    }

    try {
      await for (final _ in _callAIStream('Hello')) {
        return true;
      }
      return false;
    } catch (e) {
      _log.e('测试连接异常', error: e);
      return false;
    }
  }

  /// 方法名：fetchAvailableModels
  /// 功能：从 AI 提供商获取可用模型列表
  ///
  /// 调用 OpenAI 兼容的 /v1/models 端点获取模型列表
  ///
  /// 参数：
  /// - baseUrl: API 基础 URL
  /// - apiKey: API 密钥
  ///
  /// 返回值：
  /// - 成功时返回模型 ID 列表
  /// - 失败时返回空列表
  Future<List<String>> fetchAvailableModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/models');
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 10);

      final request = await httpClient.getUrl(url);
      request.headers.set('Content-Type', 'application/json');
      if (apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }

      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        if (json['data'] != null && json['data'] is List) {
          final models = (json['data'] as List)
              .map((m) => m['id']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .cast<String>()
              .toList();

          _log.i('获取到 ${models.length} 个可用模型');
          return models;
        }
      } else {
        _log.w('获取模型列表失败：${response.statusCode}');
      }
    } catch (e) {
      _log.e('获取模型列表异常', error: e);
    }

    return [];
  }

  // ==========================================================================
  // 区域3：核心AI调用（所有摘要方法的基础）
  // ==========================================================================

  /// 构建 AI 请求消息列表
  List<Map<String, String>> _buildMessages(String prompt) {
    final messages = <Map<String, String>>[];
    messages.add({'role': 'user', 'content': prompt});
    return messages;
  }

  /// 方法名：_callAIStream
  /// 功能：调用 AI API 发送流式请求并获取响应
  ///
  /// 参数：
  /// - prompt: 发送给 AI 的提示词
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
  ///     {"role": "user", "content": "用户提示词"}
  ///   ],
  ///   "temperature": 0.7,
  ///   "max_tokens": 8000,
  ///   "stream": true
  /// }
  /// ```
  ///
  /// 响应体格式（SSE）：
  /// ```
  /// data: {"choices":[{"delta":{"content":"AI生成的内容片段"},"index":0,"finish_reason":null}]}
  /// data: [DONE]
  /// ```
  Stream<String> _callAIStream(String prompt) async* {
    final url = Uri.parse('${_config!.baseUrl}/chat/completions');

    // 构建请求体
    final requestBody = jsonEncode({
      'model': _config!.model,
      'messages': _buildMessages(prompt),
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
              _log.w('解析SSE数据失败: $e, line: $line');
            }

            // 重置状态
            insideDataEvent = false;
            currentDataContent = '';
          }
        }
      } else {
        _log.e('AI API 流式调用失败：${response.statusCode}');
      }
    } catch (e) {
      _log.e('流式请求异常', error: e);
    } finally {
      httpClient.close();
    }
  }

  // ==========================================================================
  // 区域4：摘要生成 - 流式版
  // ==========================================================================

  /// 方法名：generateFullChapterSummaryStream
  /// 功能：生成章节内容摘要（流式）
  ///
  /// 参数：
  /// - content: 章节内容的文本
  /// - chapterTitle: 章节标题（可选）
  /// - bookId: 书籍ID（可选，用于获取元数据中的语言信息）
  ///
  /// 返回值：
  /// - 成功时返回 AI 生成的章节摘要内容流
  /// - 失败时返回空流
  ///
  /// 调用方：
  /// - summary_service.dart 的 generateSummaryStream 方法
  Stream<String> generateFullChapterSummaryStream(
    String content, {
    String? chapterTitle,
    String? bookId,
  }) async* {
    if (!isConfigured) {
      _log.w('AI 配置未设置或 API Key 无效');
      return;
    }

    final outputLanguage = await resolveOutputLanguage(
      SettingsService().settings.languageSettings,
      content: content,
      bookId: bookId,
    );

    final loc = _getPromptLoc(outputLanguage);

    final prompt = AiPrompts.chapterSummary(
      loc: loc,
      chapterTitle: chapterTitle,
      content: content,
    );

    try {
      await for (final chunk in _callAIStream(prompt)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('生成章节摘要流失败', error: e);
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
    if (!isConfigured) {
      _log.w('AI 服务未配置或 API Key 无效');
      return;
    }

    final outputLanguage = await resolveOutputLanguage(
      SettingsService().settings.languageSettings,
      content: chapterSummaries,
      bookId: bookId,
    );

    final loc = _getPromptLoc(outputLanguage);

    final prompt = AiPrompts.bookSummary(
      loc: loc,
      title: title,
      author: author,
      chapterSummaries: chapterSummaries,
      totalChapters: totalChapters,
    );

    try {
      await for (final chunk in _callAIStream(prompt)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('生成全书摘要流失败', error: e);
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
    if (!isConfigured) {
      _log.w('AI 服务未配置或 API Key 无效');
      return;
    }

    final outputLanguage = await resolveOutputLanguage(
      SettingsService().settings.languageSettings,
      content: prefaceContent,
      bookId: bookId,
    );

    final loc = _getPromptLoc(outputLanguage);

    final prompt = AiPrompts.bookSummaryFromPreface(
      loc: loc,
      title: title,
      author: author,
      prefaceContent: prefaceContent,
      totalChapters: totalChapters,
    );

    try {
      await for (final chunk in _callAIStream(prompt)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('基于前言生成全书摘要流失败', error: e);
    }
  }

  // ==========================================================================
  // 区域5：翻译
  // ==========================================================================

  /// 方法名：translateHtmlStream
  /// 功能：流式翻译HTML内容（保留HTML标签）
  Stream<String> translateHtmlStream(
    String content, {
    String? chapterTitle,
    required String sourceLang,
    required String targetLang,
  }) async* {
    if (!isConfigured) {
      _log.w('AI 配置未设置或 API Key 无效');
      return;
    }

    final loc = _getPromptLoc(targetLang);

    final prompt = AiPrompts.translateHtml(
      loc: loc,
      content: content,
      chapterTitle: chapterTitle,
    );

    try {
      await for (final chunk in _callAIStream(prompt)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('翻译HTML流失败', error: e);
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
      _log.w('AI服务未配置，无法翻译');
      return '';
    }

    final buffer = StringBuffer();

    await for (final chunk in translateHtmlStream(
      content,
      chapterTitle: chapterTitle,
      sourceLang: sourceLang,
      targetLang: targetLang,
    )) {
      buffer.write(chunk);

      if (onProgress != null) {
        onProgress(buffer.toString());
      }
    }

    final result = buffer.toString();
    return result;
  }

  // ==========================================================================
  // 区域6：语言检测与转换
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
    final bookService = BookService();
    final book = bookService.getBookById(bookId);
    return await detectSourceLanguage(bookLanguage: book?.language, content: content, bookId: bookId);
  }

  /// 从内容中检测语言
  ///
  /// 截取前 2000 字符发送给 AI 判断语言，
  /// 消除纯字符统计对中/日文汉字的误判。
  ///
  /// 参数:
  /// - content: 要分析的文本内容
  ///
  /// 返回:
  /// - 检测到的语言代码 ('zh', 'en', 'ja')
  /// - 如果 AI 调用失败则返回 'zh'
  Future<String> detectLanguageFromContent(String content) async {
    if (content.isEmpty) return 'zh';

    final sample = content.length > 2000 ? content.substring(0, 2000) : content;

    try {
      final buffer = StringBuffer();
      await for (final chunk in _callAIStream(
        'Detect the language of the following text. Reply with exactly one code in lowercase: "zh" for Chinese, "en" for English, or "ja" for Japanese. Do not explain.\n\n$sample',
      )) {
        buffer.write(chunk);
      }
      final result = buffer.toString().trim().toLowerCase();
      if (result.contains('ja') || result.contains('jp')) return 'ja';
      if (result.contains('en')) return 'en';
      return 'zh';
    } catch (e) {
      _log.w('AI 语言检测失败，默认中文: $e');
      return 'zh';
    }
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
      'zho': 'zh',
      'chi': 'zh',
      'eng': 'en',
      'jpn': 'ja',
    };

    return iso2To1Map[baseCode] ?? baseCode;
  }

  /// 检测系统语言
  ///
  /// 通过 Platform.localeName 获取系统语言设置
  /// 返回语言代码：'zh'（中文）、'en'（英文）、'ja'（日文）等
  String detectSystemLanguage() {
    try {
      final locale = Platform.localeName;
      _log.d('系统 locale: $locale');
      
      if (locale.startsWith('zh') || locale.contains('_CN') || locale.contains('_TW') || locale.contains('_HK')) {
        return 'zh';
      } else if (locale.startsWith('ja') || locale.contains('_JP')) {
        return 'ja';
      } else if (locale.startsWith('en') || locale.contains('_US') || locale.contains('_GB')) {
        return 'en';
      }
      
      return 'zh';
    } catch (e) {
      _log.w('检测系统语言失败: $e，使用默认中文');
      return 'zh';
    }
  }

  /// 检测源语言
  ///
  /// 优先从书籍元数据获取语言并标准化，否则委托 AI 从内容中检测。
  /// AI 检测结果会回写到 [Book.language] 避免重复检测。
  /// - [bookLanguage]: 书籍元数据中的语言字段（可为 null）
  /// - [content]: 用于回退检测的内容文本
  /// - [bookId]: 书籍ID，AI 检测时用于回写结果
  /// 返回语言代码：'zh'、'en'、'ja' 等
  Future<String> detectSourceLanguage({String? bookLanguage, String? content, String? bookId}) async {
    if (bookLanguage != null && bookLanguage.isNotEmpty) {
      _log.d('从元数据获取语言: $bookLanguage');
      return convertLanguageCodeToStandard(bookLanguage);
    }
    if (content != null && content.isNotEmpty) {
      final detected = await detectLanguageFromContent(content);
      if (bookId != null) {
        await _persistDetectedLanguage(bookId, detected);
      }
      return detected;
    }
    return 'zh';
  }

  Future<void> _persistDetectedLanguage(String bookId, String language) async {
    final book = BookService().getBookById(bookId);
    if (book != null && book.language != language) {
      await BookService().updateBook(book.copyWith(language: language));
      _log.d('已保存 AI 检测的语言到 Book: $language');
    }
  }

  /// 获取 AI 输出语言对应的 AppLocalizations 实例
  AppLocalizations _getPromptLoc(String languageCode) {
    if (!const ['en', 'ja', 'zh'].contains(languageCode)) {
      languageCode = 'zh';
    }
    return lookupAppLocalizations(Locale(languageCode));
  }

  /// 解析 AI 输出语言
  ///
  /// 根据语言设置决定 AI 输出语言代码。
  /// - [langSettings]: 语言设置对象
  /// - [content]: 用于 AI 检测的文本内容
  /// - [bookId]: 书籍ID，book 模式时用于查元数据 + AI 检测 + 回写
  /// - [preResolvedLanguage]: 已解析的语言代码，book 模式时直接使用（跳过检测）
  Future<String> resolveOutputLanguage(
    LanguageSettings langSettings, {
    required String content,
    String? bookId,
    String? preResolvedLanguage,
  }) async {
    if (langSettings.aiLanguageMode == 'book' && preResolvedLanguage != null) {
      return preResolvedLanguage;
    }
    if (langSettings.aiLanguageMode == 'book' && bookId != null) {
      return await _detectLanguageFromMetadataAndContentWithBookId(bookId, content);
    }
    if (langSettings.aiLanguageMode == 'book') {
      return await detectLanguageFromContent(content);
    }
    switch (langSettings.aiLanguageMode) {
      case 'manual':
        return langSettings.aiOutputLanguage ?? 'zh';
      case 'system':
        return detectSystemLanguage();
      default:
        return 'zh';
    }
  }

  /// 判断是否需要翻译
  ///
  /// 根据 AI 语言设置确定目标语言，与源语言比较。
  /// 当源语言与目标语言相同时无需翻译。
  Future<bool> needsTranslation(String sourceLang) async {
    final lang = SettingsService().settings.languageSettings;
    final targetLang = await resolveOutputLanguage(
      lang,
      content: '',
      preResolvedLanguage: sourceLang,
    );
    return sourceLang != targetLang;
  }
}
