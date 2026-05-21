# AIService - AI 服务伪代码文档

## 概述

AIService 是一个单例模式的 AI 服务，负责与大语言模型 API 的交互。支持智谱 AI 和通义千问等 OpenAI 兼容接口，提供章节摘要和全书摘要生成能力。

---

## 单例模式实现

```pseudocode
CLASS AIService:
    // 单例实例 - 静态私有变量
    PRIVATE STATIC _instance: AIService = AIService._internal()
    
    // 工厂构造函数 - 返回单例实例
    PUBLIC STATIC FACTORY AIService():
        RETURN _instance
    
    // 私有命名构造函数 - 防止外部实例化
    PRIVATE CONSTRUCTOR _internal():
        _config = null
```

---

## 数据结构

### AiSettings 类

AiSettings 定义在 `app_settings.dart` 中，包含以下核心字段：

```pseudocode
CLASS AiSettings:
    provider: String              // 'zhipu', 'qwen', 'deepseek', 'minimax', 'ollama', 'lmstudio'
    apiKey: String                // API 密钥（本地模型可为空）
    model: String                 // 模型名称
    baseUrl: String               // API 基础 URL
    
    PROPERTY isValid -> Boolean:  // 检查配置是否有效
        IF requiresApiKey:
            RETURN apiKey.isNotEmpty AND NOT _isPlaceholderApiKey(apiKey)
        ELSE:
            RETURN baseUrl.isNotEmpty
            
    PROPERTY requiresApiKey -> Boolean:
        CONST localProviders = {'ollama', 'lmstudio'}
        RETURN NOT localProviders.contains(provider)
        
    METHOD _isPlaceholderApiKey(key: String) -> Boolean:
        RETURN key.startsWith('YOUR_') AND key.endsWith('_HERE')
```

### AIService 私有属性

```pseudocode
PRIVATE PROPERTIES:
    _config: AiSettings?          // AI 配置对象（直接使用 AiSettings）
    _log: LogService              // 日志服务实例
```

---

## 方法伪代码

### init() - 初始化 AI 服务

```pseudocode
ASYNC METHOD init():
    // 从 SettingsService 加载配置
    await reloadConfig()
    
    // 监听 AI 设置变化
    SettingsService().aiSettings.addListener(_onAiSettingsChanged)
```

**初始化流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│                     init() 初始化流程                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  reloadConfig()                                             │
│      ├─ 从 SettingsService 获取 AI 设置                     │
│      ├─ 验证配置有效性                                       │
│      ├─ 有效 → _config = aiSettings                         │
│      └─ 无效 → _config = null                               │
│      ↓                                                      │
│  添加监听器                                                  │
│      SettingsService().aiSettings.addListener(...)          │
│      ↓                                                      │
│  初始化完成                                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### _onAiSettingsChanged() - AI 设置变化回调

```pseudocode
PRIVATE METHOD _onAiSettingsChanged():
    _log.d('AIService', 'AI设置发生变化，重新加载配置')
    
    // 重新加载配置
    reloadConfig()
```

---

### reloadConfig() - 重新加载 AI 配置

```pseudocode
ASYNC METHOD reloadConfig():
    TRY:
        // 从 SettingsService 获取 AI 设置
        aiSettings = SettingsService().settings.aiSettings
        
        // 检查配置有效性
        IF aiSettings.isValid:
            // 直接使用 AiSettings 实例
            _config = aiSettings
            
            _log.d('AIService', 
                'AI配置加载成功: {_config.provider}, model: {_config.model}')
        
        ELSE:
            _log.w('AIService', 'AI配置无效，请检查设置')
            _config = null
    
    CATCH e:
        _log.e('AIService', '从SettingsService加载AI配置失败', e)
```

---

### isConfigured - 检查配置状态

```pseudocode
PUBLIC PROPERTY isConfigured -> Boolean:
    RETURN _config?.isValid ?? false
```

---

### generateFullChapterSummaryStream() - 生成章节摘要（流式）

```pseudocode
STREAM METHOD generateFullChapterSummaryStream(
    content: String,
    chapterTitle: String? = null,
    bookId: String? = null
) -> Stream<String>:
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI 配置未设置或 API Key 无效')
        RETURN empty stream
    
    outputLanguage = await _resolveOutputLanguage(
        SettingsService().settings.languageSettings,
        content: content,
        bookId: bookId
    )
    
    loc = _getPromptLoc(outputLanguage)
    
    prompt = AiPrompts.chapterSummary(
        loc: loc,
        chapterTitle: chapterTitle,
        content: content
    )
    
    TRY:
        AWAIT FOR chunk IN _callAIStream(prompt):
            YIELD chunk
    
    CATCH e:
        _log.e('AIService', '生成章节摘要流失败', e)
```

---

### generateBookSummaryFromPrefaceStream() - 基于前言生成全书摘要（流式）

```pseudocode
STREAM METHOD generateBookSummaryFromPrefaceStream(
    title: String,
    author: String,
    prefaceContent: String,
    totalChapters: int? = null,
    bookId: String? = null
) -> Stream<String>:
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI 服务未配置或 API Key 无效')
        RETURN empty stream
    
    outputLanguage = await _resolveOutputLanguage(
        SettingsService().settings.languageSettings,
        content: prefaceContent,
        bookId: bookId
    )
    
    loc = _getPromptLoc(outputLanguage)
    
    prompt = AiPrompts.bookSummaryFromPreface(
        loc: loc,
        title: title,
        author: author,
        prefaceContent: prefaceContent,
        totalChapters: totalChapters
    )
    
    TRY:
        AWAIT FOR chunk IN _callAIStream(prompt):
            YIELD chunk
    
    CATCH e:
        _log.e('AIService', '基于前言生成全书摘要流失败', e)
```

---

### generateBookSummaryStream() - 基于章节摘要生成全书摘要（流式）

```pseudocode
STREAM METHOD generateBookSummaryStream(
    title: String,
    author: String,
    chapterSummaries: String,
    totalChapters: int? = null,
    bookId: String? = null
) -> Stream<String>:
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI 服务未配置或 API Key 无效')
        RETURN empty stream
    
    outputLanguage = await _resolveOutputLanguage(
        SettingsService().settings.languageSettings,
        content: chapterSummaries,
        bookId: bookId
    )
    
    loc = _getPromptLoc(outputLanguage)
    
    prompt = AiPrompts.bookSummary(
        loc: loc,
        title: title,
        author: author,
        chapterSummaries: chapterSummaries,
        totalChapters: totalChapters
    )
    
    TRY:
        AWAIT FOR chunk IN _callAIStream(prompt):
            YIELD chunk
    
    CATCH e:
        _log.e('AIService', '生成全书摘要流失败', e)
```

---

### detectLanguageFromContent() - 从内容中检测语言（AI 识别）

截取前 2000 字符发送给 AI 判断语言，消除纯字符统计对中/日文汉字的误判。

```pseudocode
ASYNC METHOD detectLanguageFromContent(content: String) -> String:
    IF content.isEmpty:
        RETURN 'zh'

    sample = content.length > 2000 ? content.substring(0, 2000) : content

    TRY:
        buffer = ''
        AWAIT FOR chunk IN _callAIStream(
            'Detect the language of the following text. Reply with exactly one code in lowercase: "zh" for Chinese, "en" for English, or "ja" for Japanese. Do not explain.\n\n' + sample
        ):
            buffer += chunk

        result = buffer.trim().toLowerCase()
        IF result.contains('ja') OR result.contains('jp'): RETURN 'ja'
        IF result.contains('en'): RETURN 'en'
        RETURN 'zh'
    CATCH e:
        _log.w('AI 语言检测失败，默认中文')
        RETURN 'zh'
```

---

### resolveOutputLanguage() - 解析 AI 输出语言

根据语言设置决定 AI 输出语言代码。统一入口，同时供内部流式生成方法和外部 ChapterScreen 使用。

```pseudocode
PUBLIC ASYNC METHOD resolveOutputLanguage(
    langSettings: LanguageSettings,
    content: String,
    bookId: String?,
    preResolvedLanguage: String?
) -> String:
    IF langSettings.aiLanguageMode == 'book' AND preResolvedLanguage != null:
        RETURN preResolvedLanguage
    IF langSettings.aiLanguageMode == 'book' AND bookId != null:
        RETURN await _detectLanguageFromMetadataAndContentWithBookId(bookId, content)
    IF langSettings.aiLanguageMode == 'book':
        RETURN await detectLanguageFromContent(content)
    SWITCH langSettings.aiLanguageMode:
        CASE 'manual':
            RETURN langSettings.aiOutputLanguage ?? 'zh'
        CASE 'system':
            RETURN detectSystemLanguage()
        DEFAULT:
            RETURN 'zh'
```

被调用方: 所有流式生成方法、`needsTranslation()`、`ChapterScreen._initializeLanguageSettings()`

---

### _getPromptLoc() - 获取目标语言对应的 AppLocalizations

```pseudocode
PRIVATE METHOD _getPromptLoc(languageCode: String) -> AppLocalizations:
    IF languageCode NOT IN ['en', 'ja', 'zh']:
        languageCode = 'zh'
    RETURN lookupAppLocalizations(Locale(languageCode))
```

被调用方: 所有生成方法 (`generateFullChapterSummaryStream`, `generateBookSummaryStream`, `generateBookSummaryFromPrefaceStream`, `translateHtmlStream`)

---

### detectSystemLanguage() - 检测系统语言

通过 `Platform.localeName` 获取操作系统语言设置，返回语言代码。

```pseudocode
PUBLIC METHOD detectSystemLanguage() -> String:
    TRY:
        locale = Platform.localeName
        _log.d('AIService', '系统 locale: {locale}')
        
        IF locale.startsWith('zh') OR locale.contains('_CN')
                                      OR locale.contains('_TW')
                                      OR locale.contains('_HK'):
            RETURN 'zh'
        ELSE IF locale.startsWith('ja') OR locale.contains('_JP'):
            RETURN 'ja'
        ELSE IF locale.startsWith('en') OR locale.contains('_US')
                                        OR locale.contains('_GB'):
            RETURN 'en'
        
        _log.d('AIService', '无法识别的系统 locale，默认使用中文')
        RETURN 'zh'
    CATCH e:
        _log.w('AIService', '检测系统语言失败: {e}，使用默认中文')
        RETURN 'zh'
```

被调用方: `resolveOutputLanguage()`, `_getPromptLoc()`, `detectSystemLanguage()`

---

### detectSourceLanguage() - 检测源语言

优先从书籍元数据获取语言并标准化，否则委托 AI 从内容中检测。AI 检测结果会回写到 `Book.language` 避免重复检测。

```pseudocode
PUBLIC ASYNC METHOD detectSourceLanguage({
    bookLanguage?: String,
    content?: String,
    bookId?: String
}) -> String:
    IF bookLanguage != null AND not empty:
        _log.d('从元数据获取语言: {bookLanguage}')
        RETURN convertLanguageCodeToStandard(bookLanguage)
    IF content != null AND not empty:
        detected = await detectLanguageFromContent(content)
        IF bookId != null:
            _persistDetectedLanguage(bookId, detected)
        RETURN detected
    RETURN 'zh'

PRIVATE ASYNC METHOD _persistDetectedLanguage(bookId: String, language: String):
    book = BookService().getBookById(bookId)
    IF book != null AND book.language != language:
        BookService().updateBook(book.copyWith(language: language))
```

被调用方: `ChapterScreen._initializeLanguageSettings()`, `_detectLanguageFromMetadataAndContentWithBookId()`

---

### needsTranslation() - 判断是否需要翻译

根据 AI 语言设置确定目标语言，与源语言比较，相同时无需翻译。

```pseudocode
PUBLIC ASYNC METHOD needsTranslation(sourceLang: String) -> Boolean:
    lang = SettingsService().settings.languageSettings
    targetLang = await resolveOutputLanguage(
        lang,
        content: '',
        preResolvedLanguage: sourceLang
    )
    RETURN sourceLang != targetLang
```

被调用方: `ChapterScreen._initializeLanguageSettings()`

---

### _detectLanguageFromMetadataAndContentWithBookId() - 从书籍元数据和内容检测语言

```pseudocode
PRIVATE ASYNC METHOD _detectLanguageFromMetadataAndContentWithBookId(
    bookId: String,
    content: String
) -> String:
    book = BookService().getBookById(bookId)
    RETURN detectSourceLanguage(bookLanguage: book?.language, content: content)
```

---

### convertLanguageCodeToStandard() - 转换语言代码为标准 ISO 639-1 格式

```pseudocode
METHOD convertLanguageCodeToStandard(languageCode: String) -> String:
    // 处理 BCP 47 区域标签
    IF languageCode.contains('-'):
        baseCode = languageCode.split('-')[0]     // 'zh-CN' → 'zh'
    ELSE IF languageCode.contains('_'):
        baseCode = languageCode.split('_')[0]     // 'zh_CN' → 'zh'
    ELSE:
        baseCode = languageCode
    
    // ISO 639-2/B → ISO 639-1 映射表
    iso2To1Map = {
        'zho': 'zh', 'chi': 'zh',    // 中文
        'eng': 'en',                  // 英文
        'jpn': 'ja',                  // 日文
        'kor': 'ko',                  // 韩文
        'fra': 'fr', 'fre': 'fr',    // 法文
        'deu': 'de', 'ger': 'de',    // 德文
        'spa': 'es',                  // 西班牙文
        'por': 'pt',                  // 葡萄牙文
        'ita': 'it',                  // 意大利文
        'rus': 'ru',                  // 俄文
        'ara': 'ar',                  // 阿拉伯文
    }
    
    RETURN iso2To1Map[baseCode] ?? baseCode
```

---

### _callAIStream() - 调用 AI API（流式）

```pseudocode
PRIVATE STREAM METHOD _callAIStream(prompt: String) -> Stream<String>:
    url = Uri.parse('{_config.baseUrl}/chat/completions')
    
    messages = [{'role': 'user', 'content': prompt}]
    
    requestBody = jsonEncode({
        'model': _config.model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 8000,
        'stream': true
    })
    
    // 使用 dart:io HttpClient 实现真正的流式请求
    httpClient = HttpClient()
    httpClient.connectionTimeout = Duration(seconds: 30)
    
    TRY:
        // 创建请求
        request = await httpClient.postUrl(url)
        request.headers.set('Content-Type', 'application/json')
        request.headers.set('Authorization', 'Bearer {_config.apiKey}')
        request.headers.set('Accept', 'text/event-stream')
        request.headers.set('Cache-Control', 'no-cache')
        
        // 写入请求体
        request.add(utf8.encode(requestBody))
        
        // 获取响应流
        response = await request.close()
        
        IF response.statusCode == 200:
            // SSE 数据缓冲区
            buffer = ''
            insideDataEvent = false
            currentDataContent = ''
            
            // 监听数据到达事件
            AWAIT FOR chunk IN response.transform(utf8.decoder):
                _log.d('AIService', '收到数据块，长度: {chunk.length}')
                
                buffer += chunk
                
                // 持续处理缓冲区
                WHILE buffer.isNotEmpty:
                    // 查找 "data: " 起始位置
                    IF NOT insideDataEvent:
                        dataIndex = buffer.indexOf('data: ')
                        
                        IF dataIndex == -1:
                            // 未找到 data: ，清除缓冲区
                            buffer = ''
                            BREAK
                        
                        ELSE IF dataIndex > 0:
                            // 去掉 data: 之前的内容
                            buffer = buffer.substring(dataIndex)
                            CONTINUE
                        
                        // 找到 data: ，开始收集数据
                        insideDataEvent = true
                        buffer = buffer.substring(6)  // 去掉 "data: " 前缀
                        currentDataContent = ''
                    
                    // 查找行结束符
                    lineEnd = buffer.indexOf('\n')
                    
                    IF lineEnd == -1:
                        // 没有完整的行，需要等待更多数据
                        currentDataContent += buffer
                        buffer = ''
                        BREAK
                    
                    // 提取完整行
                    line = currentDataContent + buffer.substring(0, lineEnd).trim()
                    buffer = buffer.substring(lineEnd + 1)
                    
                    // 检查是否是 [DONE] 标记
                    IF line == '[DONE]':
                        _log.d('AIService', '收到 [DONE]，流式响应结束')
                        RETURN
                    
                    IF line.isEmpty:
                        // 空行表示事件结束
                        insideDataEvent = false
                        CONTINUE
                    
                    // 解析 JSON
                    TRY:
                        jsonData = jsonDecode(line)
                        content = jsonData['choices']?[0]?['delta']?['content']
                        
                        IF content != null AND content.isNotEmpty:
                            _log.d('AIService', '解析到内容片段: "{content}"')
                            YIELD content  // 流式返回内容片段
                    
                    CATCH e:
                        _log.w('AIService', '解析SSE数据失败: {e}, line: {line}')
            
        ELSE:
            _log.e('AIService', 'AI API 流式调用失败：{response.statusCode}')
    
    CATCH e:
        _log.e('AIService', '流式请求异常', e)
    
    FINALLY:
        httpClient.close()
```

**SSE 流式响应处理流程:**

```
┌─────────────────────────────────────────────────────────────┐
│               _callAIStream() 流式响应流程                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  发送请求 (stream: true)                                    │
│      ↓                                                      │
│  获取响应流 (response.transform(utf8.decoder))              │
│      ↓                                                      │
│  接收数据块 (chunk)                                         │
│      ↓                                                      │
│  累积到 buffer                                               │
│      ↓                                                      │
│  查找 "data: " 标记                                        │
│      ↓                                                      │
│  提取完整行 (以 \n 结束)                                    │
│      ↓                                                      │
│  检查是否是 [DONE]                                          │
│      ├─ 是 → 流结束                                        │
│      ↓ 否                                                   │
│  解析 JSON                                                  │
│      ↓                                                      │
│  提取 content 字段                                          │
│      ↓                                                      │
│  YIELD 内容片段                                             │
│      ↓                                                      │
│  继续接收下一个数据块                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**API 请求格式:**

```json
{
  "model": "qwen-plus",
  "messages": [
    {"role": "user", "content": "请用中文回复。\n\n请对以下章节内容生成摘要..."}
  ],
  "temperature": 0.7,
  "max_tokens": 1000
}
```

**API 响应格式:**

```json
{
  "choices": [
    {
      "message": {
        "content": "## 核心内容\n本章介绍了..."
      }
    }
  ]
}
```

---

### updateConfig() - 更新配置

```pseudocode
PUBLIC METHOD updateConfig(settings: AiSettings):
    // 直接使用 AiSettings 实例
    _config = settings
    
    _log.d('AIService', 
        '配置已更新: provider={settings.provider}, model={settings.model}')
```

---

### testConnection() - 测试连接

```pseudocode
PUBLIC ASYNC METHOD testConnection() -> Boolean:
    IF NOT isConfigured:
        _log.w('AIService', '测试连接失败：配置无效')
        RETURN false
    
    TRY:
        AWAIT FOR _ IN _callAIStream('Hello'):
            RETURN true
        RETURN false
    
    CATCH e:
        _log.e('AIService', '测试连接异常', e)
        RETURN false
```

---

### resetForTest() - 重置服务状态

```pseudocode
PUBLIC STATIC METHOD resetForTest():
    _instance._config = null
```

---

---

## 错误处理

### 配置无效

```pseudocode
IF _config == null OR NOT _config.isValid:
    _log.w('AIService', 'AI配置未设置或API Key无效')
    RETURN null
```

### API 调用失败

```pseudocode
IF response.statusCode != 200:
    _log.e('AIService', 'AI API调用失败：{response.statusCode}')
    RETURN null
```

### 网络异常

```pseudocode
CATCH e:
    _log.e('AIService', '生成摘要失败', e)
    RETURN null
```

---

## 并发控制

AIService 不使用并发控制，原因:

1. AI 调用是异步操作，不会阻塞
2. HTTP 客户端支持并发请求
3. 并发控制在 SummaryService 层实现

**注意事项:**

- 高频调用可能导致 API 限流
- 建议在调用层（SummaryService）控制并发数
- API Key 泄露风险需注意安全存储

---

## API 兼容性

### 支持的提供商

| 提供商 | Base URL | 模型示例 |
|--------|----------|----------|
| 智谱 AI | https://open.bigmodel.cn/api/paas/v4 | glm-4-flash, glm-4 |
| 通义千问 | https://dashscope.aliyuncs.com/compatible-mode/v1 | qwen-plus, qwen-turbo |

### OpenAI 兼容接口

所有提供商使用 OpenAI 兼容的 `/chat/completions` 端点:

**非流式请求:**
```
POST {baseUrl}/chat/completions
Headers:
  Content-Type: application/json
  Authorization: Bearer {apiKey}
Body:
  model, messages, temperature, max_tokens
```

**流式请求:**
```
POST {baseUrl}/chat/completions
Headers:
  Content-Type: application/json
  Authorization: Bearer {apiKey}
  Accept: text/event-stream
  Cache-Control: no-cache
Body:
  model, messages, temperature, max_tokens, stream: true
```

---

## 版本历史

- **2026-05-21**: AI 语言检测 + 合并 resolveOutputLanguage — `detectLanguageFromContent` 改为 AI 识别（截取前 2000 字符），消除中/日文汉字误判；`detectSourceLanguage` 新增 `bookId` 参数，AI 检测后回写 `Book.language` 避免重复检测；合并 `getTargetLanguage` 至 `resolveOutputLanguage`（新增 `preResolvedLanguage` 快路径）；连带 `detectSourceLanguage`/`needsTranslation`/`getTargetLanguage` 签名从 sync 改为 async
- **2026-05-21**: 删除 `_callAI` + 统一 `dart:io` `HttpClient` — 删除 `_callAI()` 阻塞方法（~70行）、`_httpClient` 字段、`setMockClient()` 及 `package:http`/`http_testing` 依赖；`testConnection` 改用 `_callAIStream('Hello')`；`fetchAvailableModels` 改用 `HttpClient()`；删除 `dispose()` 僵尸方法；删除 3 个非流式方法的伪代码；`resetForTest` 简化为仅重置 `_config`
- **2026-05-20**: AiPrompts 提示词 l10n 化 + 占位符消除 — 删除 `_englishBookSummary`/`_englishBookSummaryFromPreface`/`_englishChapterSummary`/`_englishTranslateHtml`/`_getLanguageName` 5 个死方法；`getLanguageInstruction` 简化签名
  - 合并 ChapterScreen 和 AIService 内部两处重复的「元数据→内容」源语言检测模式
  - `_detectLanguageFromMetadataAndContentWithBookId` 简化为委托调用
- **2026-05-18**: `detectSystemLanguage()` 改为 public
- **2026-05-17**: 新增 `fetchAvailableModels()` 方法
  - 调用 `/v1/models` 端点获取提供商可用模型列表
  - 返回模型 ID 列表，按字母排序
- **2026-04-24**: 添加流式显示功能
  - 新增流式方法：generateFullChapterSummaryStream()
  - 新增流式方法：generateBookSummaryStream()
  - 新增流式方法：generateBookSummaryFromPrefaceStream()
  - 新增内部方法：_callAIStream() 支持 SSE 数据解析
  - 新增语言检测方法：_detectLanguageFromMetadataAndContentWithBookId()
  - 新增语言代码转换方法：convertLanguageCodeToStandard()
  - 所有生成方法支持 bookId 参数用于元数据语言检测