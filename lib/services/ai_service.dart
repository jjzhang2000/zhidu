import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'ai_prompts.dart';
import 'log_service.dart';

class AIConfig {
  final String provider;
  final String apiKey;
  final String model;
  final String baseUrl;

  AIConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.baseUrl,
  });

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

  bool get isValid =>
      apiKey.isNotEmpty &&
      apiKey != 'YOUR_ZHIPU_API_KEY_HERE' &&
      apiKey != 'YOUR_QWEN_API_KEY_HERE';
}

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  AIConfig? _config;
  final _log = LogService();

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

  bool get isConfigured => _config?.isValid ?? false;

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

  Future<String?> _callAI(String prompt) async {
    final url = Uri.parse('${_config!.baseUrl}/chat/completions');

    final response = await http.post(
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
