import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
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

  Future<String?> generateSummary(
    String content, {
    String? chapterTitle,
  }) async {
    _log.v(
      'AIService',
      'generateSummary 开始执行, content length: ${content.length}, chapterTitle: $chapterTitle',
    );
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI服务未配置或API Key无效');
      return null;
    }

    final prompt = _buildSummaryPrompt(content, chapterTitle);

    try {
      switch (_config!.provider) {
        case 'zhipu':
          return await _callZhipu(prompt);
        case 'qwen':
          return await _callQwen(prompt);
        default:
          _log.e('AIService', '不支持的AI提供商: ${_config!.provider}');
          return null;
      }
    } catch (e) {
      _log.e('AIService', '生成摘要失败', e);
      return null;
    }
  }

  Future<String?> generateObjectiveSummary(
    String content, {
    String? chapterTitle,
  }) async {
    _log.v(
      'AIService',
      'generateObjectiveSummary 开始执行, content length: ${content.length}, chapterTitle: $chapterTitle',
    );
    if (_config == null || !_config!.isValid) {
      _log.v('AIService', 'generateObjectiveSummary AI配置无效');
      return null;
    }
    _log.v('AIService', 'generateObjectiveSummary AI配置有效，继续执行');

    final prompt = '''
请对以下书籍章节内容进行客观摘要，要求：
1. 提取核心观点和关键信息
2. 保持客观中立，不加入个人观点
3. 使用简洁清晰的语言
4. 字数控制在200-300字

${chapterTitle != null ? '章节标题：$chapterTitle\n' : ''}

章节内容：
$content
''';

    try {
      switch (_config!.provider) {
        case 'zhipu':
          return await _callZhipu(prompt);
        case 'qwen':
          return await _callQwen(prompt);
        default:
          return null;
      }
    } catch (e) {
      _log.e('AIService', '生成客观摘要失败', e);
      return null;
    }
  }

  Future<String?> generateAIInsight(
    String content, {
    String? chapterTitle,
  }) async {
    _log.v('AIService',
        'generateAIInsight 开始执行, content length: ${content.length}, chapterTitle: $chapterTitle');
    if (_config == null || !_config!.isValid) {
      _log.v('AIService', 'generateAIInsight AI配置无效');
      return null;
    }
    _log.v('AIService', 'generateAIInsight AI配置有效，继续执行');

    final prompt = '''
请对以下书籍章节内容提供AI深度解读，要求：
1. 分析作者的写作意图和深层含义
2. 提供独特的视角和见解
3. 联系相关知识和背景
4. 提出值得思考的问题
5. 字数控制在200-300字

${chapterTitle != null ? '章节标题：$chapterTitle\n' : ''}

章节内容：
$content
''';

    try {
      switch (_config!.provider) {
        case 'zhipu':
          return await _callZhipu(prompt);
        case 'qwen':
          return await _callQwen(prompt);
        default:
          return null;
      }
    } catch (e) {
      _log.e('AIService', '生成AI见解失败', e);
      return null;
    }
  }

  Future<List<Map<String, String>>> generateReviewQuestions(
    String content, {
    String? chapterTitle,
    int count = 3,
  }) async {
    _log.v('AIService',
        'generateReviewQuestions 开始执行, content length: ${content.length}, chapterTitle: $chapterTitle, count: $count');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI服务未配置或API Key无效');
      return [];
    }

    final prompt = '''
请根据以下书籍章节内容，生成 $count 道复习问题，用于帮助读者巩固知识。

要求：
1. 问题应该涵盖章节的核心概念和关键知识点
2. 问题类型包括：概念理解、应用分析、批判思考
3. 每道问题都要有详细的参考答案
4. 按照以下JSON格式输出，不要添加其他文字：

[
  {
    "question": "问题内容",
    "answer": "参考答案"
  }
]

${chapterTitle != null ? '章节标题：$chapterTitle\n' : ''}

章节内容：
$content
''';

    try {
      String? response;
      switch (_config!.provider) {
        case 'zhipu':
          response = await _callZhipu(prompt);
          break;
        case 'qwen':
          response = await _callQwen(prompt);
          break;
        default:
          return [];
      }

      if (response == null) return [];

      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0);
        final List<dynamic> questions = jsonDecode(jsonStr!);
        return questions
            .map(
              (q) => {
                'question': q['question']?.toString() ?? '',
                'answer': q['answer']?.toString() ?? '',
              },
            )
            .toList();
      }

      return [];
    } catch (e) {
      _log.e('AIService', '生成复习问题失败', e);
      return [];
    }
  }

  Future<String?> generateBookIntroduction({
    required String title,
    required String author,
    String? prefaceContent,
    int? totalChapters,
  }) async {
    _log.v('AIService',
        'generateBookIntroduction 开始执行, title: $title, author: $author, hasPreface: ${prefaceContent != null}, totalChapters: $totalChapters');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI服务未配置或API Key无效');
      return null;
    }

    final prompt = '''
请为以下书籍生成一段简明的内容介绍，用于帮助读者快速了解这本书。

书籍信息：
- 书名：$title
- 作者：$author
${totalChapters != null ? '- 章节数：$totalChapters' : ''}

${prefaceContent != null && prefaceContent.isNotEmpty ? '''
前言/序言内容摘要：
$prefaceContent
''' : ''}

要求：
1. 介绍内容应该简洁明了，帮助读者快速了解书籍主题和核心内容
2. 如果有前言/序言内容，请基于其生成介绍；如果没有，请根据书名和作者推测可能的书籍类型和主题
3. 字数控制在300-500字
4. 使用通俗易懂的语言，避免过于学术化
5. 可以适当提及书籍的适用人群或阅读价值
''';

    try {
      switch (_config!.provider) {
        case 'zhipu':
          return await _callZhipu(prompt);
        case 'qwen':
          return await _callQwen(prompt);
        default:
          _log.e('AIService', '不支持的AI提供商: ${_config!.provider}');
          return null;
      }
    } catch (e) {
      _log.e('AIService', '生成书籍介绍失败', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> generateFullChapterSummary(
    String content, {
    String? chapterTitle,
  }) async {
    _log.v('AIService',
        'generateFullChapterSummary 开始执行, content length: ${content.length}, chapterTitle: $chapterTitle');
    if (_config == null || !_config!.isValid) {
      _log.w('AIService', 'AI服务未配置或API Key无效');
      return null;
    }

    final prompt = '''
请对以下书籍章节内容进行全面分析，按照JSON格式输出：

{
  "objectiveSummary": "客观摘要：提取核心观点和关键信息，保持客观中立，200-300字",
  "aiInsight": "AI洞察：分析深层含义，提供独特视角，提出思考问题，200-300字",
  "keyPoints": ["关键要点1", "关键要点2", "关键要点3", "关键要点4", "关键要点5"]
}

${chapterTitle != null ? '章节标题：$chapterTitle\n' : ''}

章节内容：
$content

请严格按照JSON格式输出，不要添加其他文字。''';

    try {
      String? response;
      switch (_config!.provider) {
        case 'zhipu':
          response = await _callZhipu(prompt);
          break;
        case 'qwen':
          response = await _callQwen(prompt);
          break;
        default:
          return null;
      }

      if (response == null) return null;

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0);
        final result = jsonDecode(jsonStr!) as Map<String, dynamic>;
        return {
          'objectiveSummary': result['objectiveSummary']?.toString() ?? '',
          'aiInsight': result['aiInsight']?.toString() ?? '',
          'keyPoints': List<String>.from(result['keyPoints'] ?? []),
        };
      }

      return null;
    } catch (e) {
      _log.e('AIService', '生成完整章节摘要失败', e);
      return null;
    }
  }

  String _buildSummaryPrompt(String content, String? chapterTitle) {
    return '''
请对以下书籍章节内容进行分层摘要，包含两个部分：

【客观摘要】
- 提取核心观点和关键信息
- 保持客观中立
- 200-300字

【AI见解】
- 分析深层含义
- 提供独特视角
- 提出思考问题
- 200-300字

${chapterTitle != null ? '章节标题：$chapterTitle\n' : ''}

章节内容：
$content
''';
  }

  Future<String?> _callZhipu(String prompt) async {
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

  Future<String?> _callQwen(String prompt) async {
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
        '通义API调用失败: ${response.statusCode} - ${response.body}',
      );
      return null;
    }
  }
}
