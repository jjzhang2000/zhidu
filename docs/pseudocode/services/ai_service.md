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
        _httpClient = null
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
    _httpClient: http.Client?     // HTTP 客户端（可被测试替换）
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

### dispose() - 清理资源

```pseudocode
METHOD dispose():
    // 移除监听器
    SettingsService().aiSettings.removeListener(_onAiSettingsChanged)
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

### generateFullChapterSummary() - 生成章节摘要

```pseudocode
ASYNC METHOD generateFullChapterSummary(
    content: String,
    chapterTitle: String? = null,
    bookId: String? = null
) -> String?:
    // 记录详细日志
    _log.v('AIService', 
        'generateFullChapterSummary 开始，content length: {content.length}, chapterTitle: {chapterTitle}')
    
    // 检查配置有效性
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI配置未设置或API Key无效')
        RETURN null
    
    // 从 SettingsService 读取语言设置
    langSettings = SettingsService().settings.languageSettings
    _log.d('AIService', 
        '语言设置：aiLanguageMode={langSettings.aiLanguageMode}, aiOutputLanguage={langSettings.aiOutputLanguage}')
    
    // 根据语言模式生成语言指令
    languageInstruction: String
    
    IF langSettings.aiLanguageMode == 'book':
        IF bookId != null:
            // 优先从书籍元数据获取语言信息
            detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, content)
        ELSE:
            // 从内容检测语言
            detectedLanguage = detectLanguageFromContent(content)
        languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage)
        _log.d('AIService', 
            '检测到书籍语言为: {detectedLanguage}, 使用语言指令: {languageInstruction}')
    
    ELSE:
        // 使用预设语言指令
        languageInstruction = AiPrompts.getLanguageInstruction(
            langSettings.aiLanguageMode,
            manualLanguage: IF langSettings.aiLanguageMode == 'manual' 
                           THEN langSettings.aiOutputLanguage 
                           ELSE null
        )
    
    _log.d('AIService', '生成的语言指令：{languageInstruction}')
    
    // 构建提示词
    prompt = AiPrompts.chapterSummary(
        chapterTitle: chapterTitle,
        content: content,
        languageInstruction: languageInstruction
    )
    
    TRY:
        // 调用 AI API
        RETURN await _callAI(prompt, systemMessage: languageInstruction)
    
    CATCH e:
        _log.e('AIService', '生成章节摘要失败', e)
        RETURN null
```

**生成流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│         generateFullChapterSummary() 生成流程                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  输入: content, chapterTitle                                 │
│      ↓                                                      │
│  检查配置有效性                                              │
│      ├─ 无效 → RETURN null                                  │
│      ↓                                                      │
│  获取语言设置                                                │
│      ↓                                                      │
│  确定语言指令                                                │
│      ├─ 'book' 模式 → 检测内容语言                          │
│      ├─ 'system' 模式 → 使用系统语言                        │
│      └─ 'manual' 模式 → 使用指定语言                        │
│      ↓                                                      │
│  构建提示词 (AiPrompts.chapterSummary)                       │
│      ↓                                                      │
│  调用 AI API (_callAI)                                       │
│      ├─ 成功 → RETURN 摘要内容                              │
│      └─ 失败 → RETURN null                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### generateFullChapterSummaryStream() - 生成章节摘要（流式）

```pseudocode
STREAM METHOD generateFullChapterSummaryStream(
    content: String,
    chapterTitle: String? = null,
    bookId: String? = null
) -> Stream<String>:
    // 记录详细日志
    _log.v('AIService', 
        'generateFullChapterSummaryStream 开始，content length: {content.length}, chapterTitle: {chapterTitle}')
    
    // 检查配置有效性
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI 配置未设置或 API Key 无效')
        RETURN empty stream
    
    // 从 SettingsService 读取语言设置
    langSettings = SettingsService().settings.languageSettings
    
    // 根据语言模式生成语言指令
    languageInstruction: String
    
    IF langSettings.aiLanguageMode == 'book':
        IF bookId != null:
            detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, content)
        ELSE:
            detectedLanguage = detectLanguageFromContent(content)
        languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage)
    
    ELSE:
        languageInstruction = AiPrompts.getLanguageInstruction(
            langSettings.aiLanguageMode,
            manualLanguage: IF langSettings.aiLanguageMode == 'manual' 
                           THEN langSettings.aiOutputLanguage 
                           ELSE null
        )
    
    // 构建提示词
    prompt = AiPrompts.chapterSummary(
        chapterTitle: chapterTitle,
        content: content,
        languageInstruction: languageInstruction
    )
    
    TRY:
        // 调用流式 AI API，逐个 yield 内容片段
        AWAIT FOR chunk IN _callAIStream(prompt, systemMessage: languageInstruction):
            YIELD chunk
    
    CATCH e:
        _log.e('AIService', '生成章节摘要流失败', e)
```

---

### generateBookSummaryFromPreface() - 基于前言生成全书摘要

```pseudocode
ASYNC METHOD generateBookSummaryFromPreface(
    title: String, 
    author: String, 
    prefaceContent: String, 
    totalChapters: int? = null,
    bookId: String? = null
) -> String?:
    // 记录详细日志
    _log.v('AIService', 
        'generateBookSummaryFromPreface 开始，title: {title}, author: {author}, prefaceContent length: {prefaceContent.length}')
    
    // 检查配置有效性
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI服务未配置或API Key无效')
        RETURN null
    
    // 获取语言设置
    langSettings = SettingsService().settings.languageSettings
    
    // 根据语言模式生成语言指令
    languageInstruction: String
    
    IF langSettings.aiLanguageMode == 'book':
        IF bookId != null:
            detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, prefaceContent)
        ELSE:
            detectedLanguage = detectLanguageFromContent(prefaceContent)
        languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage)
    
    ELSE:
        languageInstruction = AiPrompts.getLanguageInstruction(
            langSettings.aiLanguageMode,
            manualLanguage: IF langSettings.aiLanguageMode == 'manual' 
                           THEN langSettings.aiOutputLanguage 
                           ELSE null
        )
    
    // 构建提示词
    prompt = AiPrompts.bookSummaryFromPreface(
        title: title,
        author: author,
        prefaceContent: prefaceContent,
        totalChapters: totalChapters,
        languageInstruction: languageInstruction
    )
    
    TRY:
        RETURN await _callAI(prompt, systemMessage: languageInstruction)
    
    CATCH e:
        _log.e('AIService', '基于前言生成全书摘要失败', e)
        RETURN null
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
    // 记录详细日志
    _log.v('AIService', 
        'generateBookSummaryFromPrefaceStream 开始，title: {title}, author: {author}')
    
    // 检查配置有效性
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI 服务未配置或 API Key 无效')
        RETURN empty stream
    
    // 获取语言设置
    langSettings = SettingsService().settings.languageSettings
    
    // 根据语言模式生成语言指令
    languageInstruction: String
    
    IF langSettings.aiLanguageMode == 'book':
        IF bookId != null:
            detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, prefaceContent)
        ELSE:
            detectedLanguage = detectLanguageFromContent(prefaceContent)
        languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage)
    
    ELSE:
        languageInstruction = AiPrompts.getLanguageInstruction(
            langSettings.aiLanguageMode,
            manualLanguage: IF langSettings.aiLanguageMode == 'manual' 
                           THEN langSettings.aiOutputLanguage 
                           ELSE null
        )
    
    // 构建提示词
    prompt = AiPrompts.bookSummaryFromPreface(
        title: title,
        author: author,
        prefaceContent: prefaceContent,
        totalChapters: totalChapters,
        languageInstruction: languageInstruction
    )
    
    TRY:
        // 调用流式 AI API
        AWAIT FOR chunk IN _callAIStream(prompt, systemMessage: languageInstruction):
            YIELD chunk
    
    CATCH e:
        _log.e('AIService', '基于前言生成全书摘要流失败', e)
```

---

### generateBookSummary() - 基于章节摘要生成全书摘要

```pseudocode
ASYNC METHOD generateBookSummary(
    title: String, 
    author: String, 
    chapterSummaries: String, 
    totalChapters: int? = null,
    bookId: String? = null
) -> String?:
    // 记录详细日志
    _log.v('AIService', 
        'generateBookSummary 开始，title: {title}, author: {author}, chapterSummaries length: {chapterSummaries.length}')
    
    // 检查配置有效性
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI服务未配置或API Key无效')
        RETURN null
    
    // 获取语言设置
    langSettings = SettingsService().settings.languageSettings
    
    // 根据语言模式生成语言指令
    languageInstruction: String
    
    IF langSettings.aiLanguageMode == 'book':
        IF bookId != null:
            detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, chapterSummaries)
        ELSE:
            detectedLanguage = detectLanguageFromContent(chapterSummaries)
        languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage)
    
    ELSE:
        languageInstruction = AiPrompts.getLanguageInstruction(
            langSettings.aiLanguageMode,
            manualLanguage: IF langSettings.aiLanguageMode == 'manual' 
                           THEN langSettings.aiOutputLanguage 
                           ELSE null
        )
    
    // 构建提示词
    prompt = AiPrompts.bookSummary(
        title: title,
        author: author,
        chapterSummaries: chapterSummaries,
        totalChapters: totalChapters,
        languageInstruction: languageInstruction
    )
    
    TRY:
        RETURN await _callAI(prompt, systemMessage: languageInstruction)
    
    CATCH e:
        _log.e('AIService', '生成全书摘要失败', e)
        RETURN null
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
    // 记录详细日志
    _log.v('AIService', 
        'generateBookSummaryStream 开始，title: {title}, author: {author}')
    
    // 检查配置有效性
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', 'AI 服务未配置或 API Key 无效')
        RETURN empty stream
    
    // 获取语言设置
    langSettings = SettingsService().settings.languageSettings
    
    // 根据语言模式生成语言指令
    languageInstruction: String
    
    IF langSettings.aiLanguageMode == 'book':
        IF bookId != null:
            detectedLanguage = await _detectLanguageFromMetadataAndContentWithBookId(bookId, chapterSummaries)
        ELSE:
            detectedLanguage = detectLanguageFromContent(chapterSummaries)
        languageInstruction = _getLanguageInstructionForLanguage(detectedLanguage)
    
    ELSE:
        languageInstruction = AiPrompts.getLanguageInstruction(
            langSettings.aiLanguageMode,
            manualLanguage: IF langSettings.aiLanguageMode == 'manual' 
                           THEN langSettings.aiOutputLanguage 
                           ELSE null
        )
    
    // 构建提示词
    prompt = AiPrompts.bookSummary(
        title: title,
        author: author,
        chapterSummaries: chapterSummaries,
        totalChapters: totalChapters,
        languageInstruction: languageInstruction
    )
    
    TRY:
        // 调用流式 AI API
        AWAIT FOR chunk IN _callAIStream(prompt, systemMessage: languageInstruction):
            YIELD chunk
    
    CATCH e:
        _log.e('AIService', '生成全书摘要流失败', e)
```

---

### detectLanguageFromContent() - 从内容检测语言

```pseudocode
METHOD detectLanguageFromContent(content: String) -> String:
    // 空内容返回默认语言
    IF content.isEmpty:
        RETURN 'zh'
    
    // 初始化字符计数器
    chineseChars = 0
    englishChars = 0
    japaneseChars = 0
    koreanChars = 0
    punctuationChars = 0
    
    // 遍历每个字符
    FOR i = 0 TO content.length - 1:
        charCode = content.codeUnitAt(i)
        
        // 检测中文字符 (CJK 统一汉字、扩展A、兼容汉字)
        IF (charCode >= 0x4e00 AND charCode <= 0x9fff) OR
           (charCode >= 0x3400 AND charCode <= 0x4dbf) OR
           (charCode >= 0xf900 AND charCode <= 0xfaff):
            chineseChars++
        
        // 检测日文字符 (平假名、片假名)
        ELSE IF (charCode >= 0x3040 AND charCode <= 0x309f) OR
                (charCode >= 0x30a0 AND charCode <= 0x30ff) OR
                (charCode >= 0x31f0 AND charCode <= 0x31ff):
            japaneseChars++
        
        // 检测韩文字符 (韩文音节)
        ELSE IF charCode >= 0xac00 AND charCode <= 0xd7af:
            koreanChars++
        
        // 检测英文字符 (A-Z, a-z)
        ELSE IF (charCode >= 65 AND charCode <= 90) OR
                (charCode >= 97 AND charCode <= 122):
            englishChars++
        
        // 检测标点符号
        ELSE IF (charCode >= 32 AND charCode <= 47) OR
                (charCode >= 58 AND charCode <= 64) OR
                (charCode >= 12288 AND charCode <= 12543):
            punctuationChars++
    
    // 计算总有效字符数
    totalChars = chineseChars + englishChars + japaneseChars + koreanChars
    
    // 无有效字符返回默认
    IF totalChars == 0:
        RETURN 'zh'
    
    // 计算各语言比例
    chineseRatio = chineseChars / totalChars
    englishRatio = englishChars / totalChars
    japaneseRatio = japaneseChars / totalChars
    koreanRatio = koreanChars / totalChars
    
    // 中文优先判断（30%阈值）
    IF chineseRatio >= 0.3:
        RETURN 'zh'
    
    // 其他语言按比例判断
    ELSE IF japaneseRatio > englishRatio AND japaneseRatio > koreanRatio:
        RETURN 'ja'
    
    ELSE IF koreanRatio > englishRatio:
        RETURN 'ko'
    
    ELSE IF englishRatio > chineseRatio AND 
            englishRatio > japaneseRatio AND 
            englishRatio > koreanRatio:
        RETURN 'en'
    
    // 按数量判断
    maxCount = 0
    detectedLanguage = 'zh'
    
    IF chineseChars > maxCount:
        maxCount = chineseChars
        detectedLanguage = 'zh'
    
    IF englishChars > maxCount:
        maxCount = englishChars
        detectedLanguage = 'en'
    
    IF japaneseChars > maxCount:
        maxCount = japaneseChars
        detectedLanguage = 'ja'
    
    IF koreanChars > maxCount:
        maxCount = koreanChars
        detectedLanguage = 'ko'
    
    RETURN detectedLanguage
```

**语言检测流程图:**

```
┌─────────────────────────────────────────────────────────────┐
│           detectLanguageFromContent() 检测流程                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  输入: content (文本内容)                                    │
│      ↓                                                      │
│  遍历每个字符，统计各类字符数量                               │
│      ├─ 中文字符 (CJK)                                       │
│      ├─ 日文字符 (假名)                                      │
│      ├─ 韩文字符 (音节)                                      │
│      ├─ 英文字符 (A-Z, a-z)                                  │
│      └─ 标点符号                                             │
│      ↓                                                      │
│  计算各语言比例                                              │
│      ↓                                                      │
│  判断语言                                                    │
│      ├─ 中文比例 >= 30% → 'zh'                              │
│      ├─ 日文比例最高 → 'ja'                                  │
│      ├─ 韩文比例最高 → 'ko'                                  │
│      ├─ 英文比例最高 → 'en'                                  │
│      └─ 按数量判断 → 最大数量的语言                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### _getLanguageInstructionForLanguage() - 生成语言指令

```pseudocode
PRIVATE METHOD _getLanguageInstructionForLanguage(languageCode: String) -> String:
    SWITCH languageCode:
        CASE 'zh':
            RETURN 'IMPORTANT: Respond in Chinese (简体中文).'
        CASE 'en':
            RETURN 'IMPORTANT: Respond in English.'
        CASE 'ja':
            RETURN 'IMPORTANT: Respond in Japanese (日本語).'
        CASE 'ko':
            RETURN 'IMPORTANT: Respond in Korean (한국어).'
        CASE 'fr':
            RETURN 'IMPORTANT: Respond in French (Français).'
        CASE 'de':
            RETURN 'IMPORTANT: Respond in German (Deutsch).'
        CASE 'ru':
            RETURN 'IMPORTANT: Respond in Russian (Русский).'
        CASE 'es':
            RETURN 'IMPORTANT: Respond in Spanish (Español).'
        DEFAULT:
            RETURN 'IMPORTANT: Respond in Chinese (简体中文).'
```

---

### _detectLanguageFromMetadataAndContentWithBookId() - 从书籍元数据和内容检测语言

```pseudocode
PRIVATE ASYNC METHOD _detectLanguageFromMetadataAndContentWithBookId(
    bookId: String,
    content: String
) -> String:
    // 从书籍元数据获取语言信息
    book = BookService().getBookById(bookId)
    
    IF book != null AND book.language != null AND book.language.isNotEmpty:
        _log.d('AIService', '从元数据获取到语言信息: {book.language}')
        // 转换为标准语言代码
        RETURN convertLanguageCodeToStandard(book.language)
    
    // 元数据中没有，从内容中检测
    _log.d('AIService', '元数据中没有语言信息，从内容中检测语言')
    RETURN detectLanguageFromContent(content)
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

### _callAI() - 调用 AI API

```pseudocode
PRIVATE ASYNC METHOD _callAI(prompt: String, systemMessage: String? = null) -> String?:
    // 构建请求 URL
    url = Uri.parse('{_config.baseUrl}/chat/completions')
    
    // 获取 HTTP 客户端（使用 Mock 或真实客户端）
    client = _httpClient ?? http.Client()
    
    // 构建消息列表
    messages = []
    
    // 如果有系统消息，添加为 system role
    IF systemMessage != null AND systemMessage.isNotEmpty:
        messages.add({'role': 'system', 'content': systemMessage})
    
    // 添加用户提示词
    messages.add({'role': 'user', 'content': prompt})
    
    // 发送 POST 请求
    response = await client.post(
        url,
        headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer {_config.apiKey}'
        },
        body: jsonEncode({
            'model': _config.model,
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 1000
        })
    )
    
    // 处理响应
    IF response.statusCode == 200:
        // 解析 JSON 响应
        json = jsonDecode(response.body)
        
        // 提取 AI 生成的内容
        RETURN json['choices']?[0]?['message']?['content']
    
    ELSE:
        // 记录错误
        _log.e('AIService', 
            'AI API调用失败：{response.statusCode} - {response.body}')
        RETURN null
```

---

### _callAIStream() - 调用 AI API（流式）

```pseudocode
PRIVATE STREAM METHOD _callAIStream(prompt: String, systemMessage: String? = null) -> Stream<String>:
    // 构建请求 URL
    url = Uri.parse('{_config.baseUrl}/chat/completions')
    
    // 构建消息列表
    messages = []
    
    // 如果有系统消息，添加为 system role
    IF systemMessage != null AND systemMessage.isNotEmpty:
        messages.add({'role': 'system', 'content': systemMessage})
    
    // 添加用户提示词
    messages.add({'role': 'user', 'content': prompt})
    
    // 构建请求体（启用流式响应）
    requestBody = jsonEncode({
        'model': _config.model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1000,
        'stream': true  // 启用流式响应
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
    {"role": "system", "content": "IMPORTANT: Respond in Chinese."},
    {"role": "user", "content": "请对以下章节内容生成摘要..."}
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
    // 检查配置有效性
    IF _config == null OR NOT _config.isValid:
        _log.w('AIService', '测试连接失败：配置无效')
        RETURN false
    
    TRY:
        // 构建请求 URL
        url = Uri.parse('{_config.baseUrl}/chat/completions')
        
        // 获取客户端
        client = _httpClient ?? http.Client()
        
        // 发送简单测试请求
        response = await client.post(
            url,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer {_config.apiKey}'
            },
            body: jsonEncode({
                'model': _config.model,
                'messages': [{'role': 'user', 'content': 'Hello'}],
                'temperature': 0.7,
                'max_tokens': 10
            })
        )
        
        // 检查响应状态
        IF response.statusCode == 200:
            _log.d('AIService', '测试连接成功')
            RETURN true
        
        ELSE:
            _log.w('AIService', '测试连接失败: {response.statusCode}')
            RETURN false
    
    CATCH e:
        _log.e('AIService', '测试连接异常', e)
        RETURN false
```

---

## 测试支持方法

### resetForTest() - 重置服务状态

```pseudocode
PUBLIC STATIC METHOD resetForTest():
    _instance._config = null
    _instance._httpClient = null
```

---

## 流式与非流式方法对比

| 非流式方法 | 流式方法 | 返回值类型 | 使用场景 |
|-----------|---------|-----------|---------|
| generateFullChapterSummary() | generateFullChapterSummaryStream() | String? / Stream<String> | 需要实时反馈时使用流式 |
| generateBookSummary() | generateBookSummaryStream() | String? / Stream<String> | 需要实时反馈时使用流式 |
| generateBookSummaryFromPreface() | generateBookSummaryFromPrefaceStream() | String? / Stream<String> | 需要实时反馈时使用流式 |

**流式方法特点:**
1. 使用 `Stream<String>` 返回类型
2. 内部调用 `_callAIStream()` 而非 `_callAI()`
3. 支持 SSE (Server-Sent Events) 数据解析
4. 可以实时获取 AI 生成的内容片段
5. UI 可以通过 `await for` 循环接收内容更新

**SSE 数据格式:**
```
data: {"choices":[{"delta":{"content":"内容片段"},"index":0,"finish_reason":null}]}
data: [DONE]
```

### setMockClient() - 设置 Mock HTTP 客户端

```pseudocode
PUBLIC METHOD setMockClient(client: MockClient):
    _httpClient = client
```

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

- **2026-04-24**: 添加流式显示功能
  - 新增流式方法：generateFullChapterSummaryStream()
  - 新增流式方法：generateBookSummaryStream()
  - 新增流式方法：generateBookSummaryFromPrefaceStream()
  - 新增内部方法：_callAIStream() 支持 SSE 数据解析
  - 新增语言检测方法：_detectLanguageFromMetadataAndContentWithBookId()
  - 新增语言代码转换方法：convertLanguageCodeToStandard()
  - 所有生成方法支持 bookId 参数用于元数据语言检测