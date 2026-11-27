// AI 服务：封装与大语言模型 API 的交互（配置管理、SSE 流式生成、翻译与语言检测）

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'ai_prompts.dart';
import 'log_service.dart';
import 'settings_service.dart';
import 'book_service.dart';
import '../models/app_settings.dart';
import '../l10n/app_localizations.dart';


/// AI 服务单例：加载配置、流式生成、翻译与语言检测
class AIService {
  static final AIService _instance = AIService._internal();

  factory AIService() => _instance;

  AIService._internal();

  /// AI配置对象，初始化时从SettingsService加载
  AiSettings? _config;

  /// 日志服务实例
  final _log = LogService();

  // ==========================================================================
  // 区域1：生命周期管理
  // ==========================================================================

  /// 测试用：重置服务状态
  @visibleForTesting
  static void resetForTest() {
    AIService._instance._config = null;
  }

  /// 初始化：加载 AI 配置并监听设置变化（应用启动时在 main.dart 调用）
  Future<void> init() async {
    await reloadConfig();

    // 监听AI设置变化
    SettingsService().aiSettings.addListener(_onAiSettingsChanged);
  }

  /// AI 设置变化时重新加载配置
  void _onAiSettingsChanged() {
    reloadConfig();
  }

  /// 从 SettingsService 重新加载 AI 配置，配置无效时记录警告并置空
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
  // 区域2：配置管理
  // ==========================================================================

  /// AI 服务是否已正确配置
  bool get isConfigured => _config?.isValid ?? false;

  /// 获取当前AI提供商（如 'zhipu', 'qwen', 'ollama' 等）
  String get currentProvider => _config?.provider ?? '';

  /// 直接替换当前配置（用于连接测试等临时场景）
  void updateConfig(AiSettings settings) {
    _config = settings;
  }

  /// 发送一条简单请求验证 AI 配置是否可用
  Future<bool> testConnection() async {
    if (!isConfigured) {
      _log.w('AIService', '测试连接失败：配置无效');
      return false;
    }

    try {
      await for (final _ in _callAIStream('Hello')) {
        return true;
      }
      return false;
    } catch (e) {
      _log.e('AIService', '测试连接异常', e);
      return false;
    }
  }

  /// 从 OpenAI 兼容的 /v1/models 端点获取模型列表，失败时返回空列表。
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

          _log.d('AIService', '获取到 ${models.length} 个可用模型');
          return models;
        }
      } else {
        _log.w(
          'AIService',
          '获取模型列表失败：${response.statusCode}',
        );
      }
    } catch (e) {
      _log.e('AIService', '获取模型列表异常', e);
    }

    return [];
  }

  // ==========================================================================
  // 区域3：核心AI调用（所有摘要方法的基础）
  // ==========================================================================

  /// 构建 AI 请求消息列表
  ///
  /// [isAbbreviation] 为 true 时使用「章节缩写」提示词（缩写至约 1/5），
  /// 否则使用默认提示词（供翻译、语言检测等场景复用）。
  List<Map<String, String>> _buildMessages(String prompt, String? language,
      {bool isAbbreviation = false, int? targetLength}) {
    final actualLanguage = language ?? 'zh';
    final systemPrompt = isAbbreviation
        ? _abbreviationSystemPrompt(actualLanguage)
        : switch (actualLanguage) {
            'en' => 'Write a book summary in English. Write plain text only, no markdown, no code blocks, no lists, no headers, no XML/HTML tags. Do not include any thinking process, reasoning, or explanation tags such as <thinking> or <think>. Do not write any introduction or explanation. Start writing the summary content immediately, without any preamble.',
            'ja' => '日本語で書籍要約を書いてください。プレーンテキストのみ、マークダウン、コードブロック、リスト、ヘッダー、XML/HTMLタグは不要です。<thinking>、<think> などの思考過程、推論、説明タグを含めないでください。導入や説明を書かないでください。要約内容を前置きなしで直に書き始めてください。',
            _ => '用中文写书籍摘要。只写纯文本，不要 markdown、不要代码块、不要列表、不要标题、不要 XML/HTML 标签。不要包含任何思考过程、推理或解释标签，如 <thinking>、<think>。不要写任何前言或解释。立即开始写摘要内容，不要任何开场白。',
          };
    _log.d('AIService', 'systemPrompt[$actualLanguage]: $systemPrompt');
    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': systemPrompt});
    final userPrompt = isAbbreviation
        ? _abbreviationUserPrompt(actualLanguage, prompt, targetLength)
        : switch (actualLanguage) {
            'en' => 'Summarize this in English:\n$prompt',
            'ja' => '日本語で要約してください：\n$prompt',
            _ => '请用中文摘要：\n$prompt',
          };
    messages.add({'role': 'user', 'content': userPrompt});
    return messages;
  }

  /// 章节缩写系统提示词
  String _abbreviationSystemPrompt(String language) {
    return switch (language) {
      'en' => 'You are a text condensing assistant. Condense the given chapter content to about one-fifth (1/5) of its original length. Preserve all key information, main ideas, logical structure, and important details while removing redundant descriptions and repetition. Write in the original language. Output plain text only — no markdown, no code blocks, no lists, no headers, no XML/HTML tags. Do not include any thinking tags such as <thinking> or <think>. Do not write any preamble or explanation; output the condensed text directly.',
      'ja' => 'あなたは文章要約アシスタントです。与えられた章の内容を元の長さの約5分の1に凝縮してください。重要な情報、主要な考え、論理構造、重要な詳細をすべて保持し、冗長な説明や繰り返しを削除してください。元の言語で書いてください。プレーンテキストのみ出力し、マークダウン、コードブロック、リスト、見出し、XML/HTMLタグは使わないでください。<thinking>や<think>などの思考タグを含めないでください。前置きや説明を書かず、凝縮した内容を直接出力してください。',
      _ => '你是一名文本缩写助手。请将给定的章节内容缩写为原文长度的约五分之一，保留所有关键信息、主要观点、逻辑结构和重要细节，删除冗余描述与重复内容。使用原文语言输出。只输出纯文本，不要 markdown、不要代码块、不要列表、不要标题、不要 XML/HTML 标签。不要包含任何思考过程标签（如 <thinking>、<think>）。不要写任何前言或解释，直接输出缩写内容。',
    };
  }

  /// 章节缩写用户提示词
  String _abbreviationUserPrompt(String language, String prompt, int? targetLength) {
    return switch (language) {
      'en' => 'Condense the following chapter content to about one-fifth of its original length${targetLength != null ? ' (about $targetLength characters)' : ''}:\n$prompt',
      'ja' => '以下の章の内容を元の長さの約5分の1に凝縮してください${targetLength != null ? '（約 $targetLength 文字）' : ''}：\n$prompt',
      _ => '请将以下章节内容缩写至原长度的约五分之一${targetLength != null ? '（约 $targetLength 字）' : ''}：\n$prompt',
    };
  }

  /// 调用 AI API 发送流式请求，返回内容片段流（未配置或失败时为空流）
  ///
  /// 请求体：模型、消息列表、temperature 0.7、max_tokens 32000、stream: true。
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
  Stream<String> _callAIStream(String prompt,
      {String? language, bool isAbbreviation = false, int? targetLength}) async* {
    final url = Uri.parse('${_config!.baseUrl}/chat/completions');

    // 构建请求体
    final requestBody = jsonEncode({
      'model': _config!.model,
      'messages': _buildMessages(prompt, language,
          isAbbreviation: isAbbreviation, targetLength: targetLength),
      'temperature': 0.7,
      'max_tokens': 32000,
      'stream': true,  // 启用流式响应
    });

    _log.d('AIService', '调用 AI API，language=$language, max_tokens=32000');

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
  // 区域4：章节缩写生成 - 流式版
  // ==========================================================================

  /// 生成章节缩写（流式）
  ///
  /// 将章节正文缩写为原长度的约五分之一；[targetLength] 为可选目标字数，
  /// [language] 缺省时跟随统一语言设置。
  Stream<String> generateChapterAbbreviationStream(
    String content, {
    int? targetLength,
    String? language,
  }) async* {
    if (!isConfigured) {
      _log.w('AIService', 'AI 配置未设置或 API Key 无效');
      return;
    }

    final outputLanguage = language ??
        resolveOutputLanguage(SettingsService().settings.languageSettings);

    try {
      await for (final chunk in _callAIStream(
        content,
        language: outputLanguage,
        isAbbreviation: true,
        targetLength: targetLength,
      )) {
        yield chunk;
      }
    } catch (e) {
      _log.e('AIService', '生成章节缩写流失败', e);
    }
  }

  // ==========================================================================
  // 区域5：翻译服务
  // ==========================================================================

  /// 流式翻译 HTML 内容（保留 HTML 标签）
  Stream<String> translateHtmlStream(
    String content, {
    String? chapterTitle,
    required String sourceLang,
    required String targetLang,
  }) async* {
    if (!isConfigured) {
      _log.w('AIService', 'AI 配置未设置或 API Key 无效');
      return;
    }

    final loc = _getPromptLoc(targetLang);

    final prompt = AiPrompts.translateHtml(
      loc: loc,
      content: content,
      chapterTitle: chapterTitle,
    );

    try {
      await for (final chunk in _callAIStream(prompt, language: targetLang)) {
        yield chunk;
      }
    } catch (e) {
      _log.e('AIService', '翻译HTML流失败', e);
    }
  }

  /// 翻译内容：收集流式译文并返回完整结果，[onProgress] 可实时接收当前译文
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
      _log.w('AIService', 'AI 语言检测失败，默认中文: $e');
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
      _log.d('AIService', '系统 locale: $locale');
      
      if (locale.startsWith('zh') || locale.contains('_CN') || locale.contains('_TW') || locale.contains('_HK')) {
        return 'zh';
      } else if (locale.startsWith('ja') || locale.contains('_JP')) {
        return 'ja';
      } else if (locale.startsWith('en') || locale.contains('_US') || locale.contains('_GB')) {
        return 'en';
      }

      return 'zh';
    } catch (e) {
      _log.w('AIService', '检测系统语言失败: $e，使用默认中文');
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
      _log.d('AIService', '从元数据获取语言: $bookLanguage');
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
      _log.d('AIService', '已保存 AI 检测的语言到 Book: $language');
    }
  }

  /// 获取 AI 输出语言对应的 AppLocalizations 实例
  AppLocalizations _getPromptLoc(String languageCode) {
    if (!const ['en', 'ja', 'zh'].contains(languageCode)) {
      languageCode = 'zh';
    }
    return lookupAppLocalizations(Locale(languageCode));
  }

  /// 解析输出语言
  ///
  /// 根据统一语言设置返回输出语言代码（AI 摘要与翻译共用）。
  /// - 'manual'：使用用户自选语言
  /// - 'system'：跟随系统语言
  String resolveOutputLanguage(LanguageSettings langSettings) {
    switch (langSettings.languageMode) {
      case 'manual':
        return langSettings.language;
      case 'system':
        return detectSystemLanguage();
      default:
        return 'zh';
    }
  }

  /// 判断是否需要翻译
  ///
  /// 根据统一语言设置确定目标语言，与源语言比较。
  /// 当源语言与目标语言相同时无需翻译。
  bool needsTranslation(String sourceLang) {
    final lang = SettingsService().settings.languageSettings;
    final targetLang = resolveOutputLanguage(lang);
    return sourceLang != targetLang;
  }
}
