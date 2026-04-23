# PdfParser - PDF格式解析器

## 概述

`PdfParser` 是PDF格式解析器的实现类，负责解析PDF电子书文件。PDF文件与EPUB不同，没有明确的章节结构，需要通过页面内容分析来识别章节边界。

## PDF文件特性

```
┌─────────────────────────────────────────────────────────────────┐
│                    PDF File Characteristics                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PDF Structure:                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  Page 1 (Cover)          ← May contain only images      │   │
│  │  ┌─────────────────┐                                    │   │
│  │  │ [Image]         │                                    │   │
│  │  │ Title           │                                    │   │
│  │  │ Author          │                                    │   │
│  │  └─────────────────┘                                    │   │
│  │                                                          │   │
│  │  Page 2 (Chapter 1)      ← Text content begins          │   │
│  │  ┌─────────────────┐                                    │   │
│  │  │ 第一章 引言      │ ← Chapter title pattern           │   │
│  │  │ 正文内容...      │                                    │   │
│  │  └─────────────────┘                                    │   │
│  │                                                          │   │
│  │  Page 3-5 (Chapter 1 continued)                         │   │
│  │  ┌─────────────────┐                                    │   │
│  │  │ 正文内容...      │                                    │   │
│  │  └─────────────────┘                                    │   │
│  │                                                          │   │
│  │  Page 6 (Chapter 2)      ← New chapter detected         │   │
│  │  ┌─────────────────┐                                    │   │
│  │  │ 第二章 方法      │ ← Chapter title pattern           │   │
│  │  │ 正文内容...      │                                    │   │
│  │  └─────────────────┘                                    │   │
│  │                                                          │   │
│  │  ...                                                     │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Key Differences from EPUB:                                     │
│  - No explicit chapter structure                                │
│  - No navigation file (NCX/NAV)                                 │
│  - Content is page-based, not file-based                        │
│  - Metadata often unreliable                                    │
│  - Cover is typically first page                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 核心解析流程

### parse() - 元数据解析

```
FUNCTION parse(filePath: String) -> Future<BookMetadata>
    LOG: 'parse 开始执行, filePath: $filePath'
    
    // Step 1: 文件存在性检查
    file = File(filePath)
    IF NOT await file.exists():
        LOG: '文件不存在: $filePath'
        THROW Exception('PDF file not found: $filePath')
    
    TRY:
        // Step 2: 打开PDF文档
        // pdfrx库提供PDF文档的加载和渲染能力
        document = await PdfDocument.openFile(filePath)
        
        // Step 3: 获取总页数
        totalPages = document.pages.length
        
        // Step 4: 释放文档资源（重要！避免内存泄漏）
        await document.dispose()
        
        // Step 5: 标题提取（从文件名）
        // PDF内部元数据通常不可靠，使用文件名作为标题
        fileName = p.basenameWithoutExtension(filePath)
        
        // Step 6: 文件名美化处理
        // 移除下划线和连字符，转换为空格
        // 例如: "my_book-title.pdf" → "my book title"
        title = fileName.replaceAll('_', ' ').replaceAll('-', ' ')
        
        LOG: '书名: $title'
        LOG: '总页数: $totalPages'
        
        // Step 7: 构建元数据对象
        RETURN BookMetadata(
            title: title,
            author: 'Unknown',  // PDF作者信息需要额外提取
            coverPath: null,    // PDF封面提取复杂，暂不支持
            totalChapters: totalPages > 0 ? 1 : 0,  // 默认作为单章节处理
            format: BookFormat.pdf
        )
    
    CATCH e, stackTrace:
        LOG: '解析PDF失败', e, stackTrace
        THROW Exception('Failed to parse PDF: $e')
END FUNCTION
```

### getChapters() - 章节列表提取

这是PDF解析器的核心算法，通过分析页面内容来识别章节边界。

```
FUNCTION getChapters(filePath: String) -> Future<List<Chapter>>
    LOG: 'getChapters 开始执行'
    
    // Step 1: 文件存在性检查
    file = File(filePath)
    IF NOT await file.exists():
        LOG: '文件不存在'
        RETURN []
    
    TRY:
        // Step 2: 打开PDF文档
        document = await PdfDocument.openFile(filePath)
        totalPages = document.pages.length
        
        IF totalPages == 0:
            await document.dispose()
            RETURN []
        
        // Step 3: 预先收集所有页面的文本内容
        // 一次性完成文档读取，避免多次打开
        pageContents = []
        FOR i = 0 TO totalPages - 1:
            page = document.pages[i]
            pageText = await page.loadText()
            pageContents.add(pageText.fullText)
        
        // Step 4: 释放文档资源
        await document.dispose()
        
        // Step 5: 封面检测逻辑
        // PDF首页可能是封面，通常包含图片而非大量文字
        // 检测策略：首页文字少于50字符，认为是封面
        startOffset = 0
        coverThreshold = 50  // 封面检测阈值
        
        IF pageContents.isNotEmpty AND pageContents[0].trim().length < coverThreshold:
            startOffset = 1  // 跳过第一页
            LOG: '首页文字少于50字符，识别为封面，跳过'
        
        // Step 6: 处理跳过封面后的情况
        effectivePages = totalPages - startOffset
        IF effectivePages <= 0:
            LOG: '跳过封面后无有效页面'
            RETURN []
        
        // Step 7: 定义章节标题正则表达式模式
        patterns = [
            r'^第[一二三四五六七八九十百零]+章[：:\s]',  // 中文数字章节
            r'^第\d+章[：:\s]',                          // 阿拉伯数字章节
            r'^Chapter\s+\d+[：:\s]',                    // 英文章节（首字母大写）
            r'^CHAPTER\s+\d+[：:\s]'                     // 英文章节（全大写）
        ]
        
        // Step 8: 章节边界检测
        chapterBoundaries = [startOffset]  // 初始包含第一个有效页面
        chapterTitles = ['全文']           // 默认标题
        lastChapterNum = -1                // 上一个章节号，用于防止重复
        
        // Step 9: 逐页检测章节标题
        FOR i = startOffset TO pageContents.length - 1:
            content = pageContents[i]
            
            // 只检查每页的前5行（章节标题通常出现在页面开头）
            firstLines = content.split('\n').take(5)
            
            FOR line IN firstLines:
                FOR pattern IN patterns:
                    // 创建正则表达式
                    // multiLine: true 允许^匹配每行开头
                    // caseSensitive: false 忽略大小写
                    regex = RegExp(pattern, multiLine: true, caseSensitive: false)
                    match = regex.firstMatch(line)
                    
                    IF match != null:
                        // 提取匹配到的标题文本
                        title = match.group(0)?.trim() ?? ''
                        
                        // Step 10: 提取章节号（用于去重）
                        numMatch = RegExp(r'\d+|[一二三四五六七八九十百零]+').firstMatch(title)
                        
                        IF numMatch != null:
                            chapterNum = numMatch.group(0)
                            
                            // Step 11: 验证并记录章节边界
                            // 条件：
                            // 1. i != startOffset: 不是第一个有效页面
                            // 2. chapterNum != null: 成功提取章节号
                            // 3. !chapterBoundaries.contains(i): 当前页未被记录过
                            // 4. lastChapterNum != int.tryParse(chapterNum): 章节号与上一个不同
                            IF i != startOffset AND
                               chapterNum != null AND
                               !chapterBoundaries.contains(i) AND
                               lastChapterNum != int.tryParse(chapterNum):
                                
                                chapterBoundaries.add(i)
                                chapterTitles.add(title)
                                lastChapterNum = int.tryParse(chapterNum) ?? -1
                                LOG: '检测到章节边界: 页$i, 标题: $title'
                        
                        BREAK  // 匹配成功，跳出模式循环
        
        // Step 12: 处理无法识别章节的情况
        IF chapterBoundaries.length == 1:
            LOG: '未检测到章节结构，将有效文档视为一个章节'
            RETURN [
                Chapter(
                    id: 'pdf_chapter_0',
                    index: 0,
                    title: '全文',
                    location: ChapterLocation(
                        startPage: startOffset + 1,  // 转换为1-based页码
                        endPage: totalPages
                    ),
                    level: 0
                )
            ]
        
        // Step 13: 添加最后一页作为边界
        IF chapterBoundaries.last != totalPages - 1:
            chapterBoundaries.add(totalPages - 1)
            chapterTitles.add('结束')  // 占位标题
        
        // Step 14: 创建章节对象
        chapters = []
        FOR i = 0 TO chapterBoundaries.length - 2:
            startIndex = chapterBoundaries[i]
            endIndex = chapterBoundaries[i + 1]
            title = i < chapterTitles.length ? chapterTitles[i] : '第${i + 1}章'
            
            chapters.add(Chapter(
                id: 'pdf_chapter_$i',
                index: i,
                title: title,
                location: ChapterLocation(
                    startPage: startIndex + 1,  // 转换为1-based
                    endPage: endIndex + 1       // 转换为1-based
                ),
                level: 0  // PDF不支持层级，统一为0
            ))
        
        LOG: '检测到 ${chapters.length} 个章节'
        RETURN chapters
    
    CATCH e, stackTrace:
        LOG: '获取章节列表失败', e, stackTrace
        RETURN []
END FUNCTION
```

### 章节检测算法流程图

```
┌─────────────────────────────────────────────────────────────────┐
│              PDF Chapter Detection Algorithm                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Phase 1: Cover Detection                                 │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │                                                          │   │
│  │  Page 0 text length < 50 characters?                    │   │
│  │         │                                                │   │
│  │         │ YES                                            │   │
│  │         ▼                                                │   │
│  │  startOffset = 1 (skip cover)                           │   │
│  │         │                                                │   │
│  │         │ NO                                             │   │
│  │         ▼                                                │   │
│  │  startOffset = 0 (include first page)                   │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Phase 2: Pattern Matching                                │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │                                                          │   │
│  │  FOR each page from startOffset:                         │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  Extract first 5 lines                                   │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  FOR each line:                                          │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  Match against patterns:                                 │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ Pattern 1: 第[一二三四五六七八九十百零]+章        │    │   │
│  │  │ Pattern 2: 第\d+章                              │    │   │
│  │  │ Pattern 3: Chapter\s+\d+                        │    │   │
│  │  │ Pattern 4: CHAPTER\s+\d+                        │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │      │                                                   │   │
│  │      │ IF MATCH                                          │   │
│  │      ▼                                                   │   │
│  │  Extract chapter number                                  │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  Check duplicate prevention                             │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Phase 3: Boundary Recording                              │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │                                                          │   │
│  │  IF chapter number != last chapter number:              │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  Add page index to chapterBoundaries                    │   │
│  │  Add title to chapterTitles                             │   │
│  │  Update lastChapterNum                                  │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Phase 4: Chapter Creation                                │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │                                                          │   │
│  │  IF only 1 boundary detected:                           │   │
│  │      RETURN single chapter (entire document)            │   │
│  │                                                          │   │
│  │  ELSE:                                                   │   │
│  │      Add last page as final boundary                    │   │
│  │      Create Chapter objects for each boundary pair      │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 章节标题模式详解

```
┌─────────────────────────────────────────────────────────────────┐
│                    Chapter Title Patterns                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Pattern 1: Chinese Number Chapters                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Regex: ^第[一二三四五六七八九十百零]+章[：:\s]           │   │
│  │                                                          │   │
│  │ Matches:                                                  │   │
│  │ - 第一章 引言                                            │   │
│  │ - 第十二章 方法论                                        │   │
│  │ - 第二十章 总结                                          │   │
│  │ - 第一百章 附录                                          │   │
│  │                                                          │   │
│  │ Character Set:                                            │   │
│  │ [一二三四五六七八九十百零]                               │   │
│  │ - 一二三四五六七八九十: Basic numbers                    │   │
│  │ - 百: Hundred                                            │   │
│  │ - 零: Zero                                               │   │
│  │                                                          │   │
│  │ Separator:                                                │   │
│  │ [：:\s] - Chinese colon, English colon, or whitespace    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Pattern 2: Arabic Number Chapters                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Regex: ^第\d+章[：:\s]                                   │   │
│  │                                                          │   │
│  │ Matches:                                                  │   │
│  │ - 第1章 引言                                            │   │
│  │ - 第12章 方法论                                          │   │
│  │ - 第100章 附录                                           │   │
│  │                                                          │   │
│  │ \d+: One or more digits                                  │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Pattern 3: English Chapters (Capitalized)                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Regex: ^Chapter\s+\d+[：:\s]                             │   │
│  │                                                          │   │
│  │ Matches:                                                  │   │
│  │ - Chapter 1: Introduction                                │   │
│  │ - Chapter 12: Methods                                    │   │
│  │                                                          │   │
│  │ \s+: One or more whitespace                             │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Pattern 4: English Chapters (All Caps)                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Regex: ^CHAPTER\s+\d+[：:\s]                             │   │
│  │                                                          │   │
│  │ Matches:                                                  │   │
│  │ - CHAPTER 1: INTRODUCTION                                │   │
│  │ - CHAPTER 12: METHODS                                    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Note: All patterns use caseSensitive: false                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### getChapterContent() - 章节内容提取

```
FUNCTION getChapterContent(filePath: String, chapter: Chapter) -> Future<ChapterContent>
    LOG: 'getChapterContent 开始执行'
    
    // Step 1: 文件存在性检查
    file = File(filePath)
    IF NOT await file.exists():
        THROW Exception('PDF file not found: $filePath')
    
    TRY:
        // Step 2: 打开PDF文档
        document = await PdfDocument.openFile(filePath)
        
        // Step 3: 获取章节的页面范围
        // startPage和endPage都是1-based（从1开始计数）
        startPage = chapter.location.startPage
        endPage = chapter.location.endPage
        
        // Step 4: 验证页面范围是否存在
        IF startPage == null OR endPage == null:
            await document.dispose()
            LOG: '章节缺少页面范围信息'
            RETURN ChapterContent(plainText: '', htmlContent: '')
        
        LOG: '提取页面范围: $startPage - $endPage'
        
        // Step 5: 提取页面范围内的所有文本
        buffer = StringBuffer()
        
        FOR pageNum = startPage TO endPage AND pageNum <= document.pages.length:
            // 转换为0-based索引
            page = document.pages[pageNum - 1]
            pageText = await page.loadText()
            
            // 页面之间用双换行分隔
            IF buffer.isNotEmpty:
                buffer.write('\n\n')
            
            buffer.write(pageText.fullText)
        
        // Step 6: 释放文档资源
        await document.dispose()
        
        // Step 7: 处理提取结果
        plainText = buffer.toString().trim()
        LOG: '章节内容提取成功，长度: ${plainText.length}'
        
        IF plainText.isEmpty:
            LOG: '章节内容为空'
            RETURN ChapterContent(plainText: '', htmlContent: '')
        
        // Step 8: 将纯文本转换为HTML格式
        // PDF文本提取是纯文本，需要转换为HTML以便渲染
        // 转换规则：
        // 1. 按换行符分割为段落
        // 2. 过滤空段落
        // 3. 用<p>标签包裹每个段落
        paragraphs = plainText.split('\n').where(p => p.trim().isNotEmpty)
        htmlContent = paragraphs.map(p => '<p>${p.trim()}</p>').join('\n')
        
        RETURN ChapterContent(
            plainText: plainText,
            htmlContent: htmlContent
        )
    
    CATCH e, stackTrace:
        LOG: '获取章节内容失败', e, stackTrace
        RETURN ChapterContent(plainText: '', htmlContent: '')
END FUNCTION
```

### extractCover() - 封面提取

```
FUNCTION extractCover(filePath: String) -> Future<String?>
    LOG: 'extractCover 开始执行'
    
    // Step 1: 文件存在性检查
    file = File(filePath)
    IF NOT await file.exists():
        RETURN null
    
    // Step 2: PDF封面提取说明
    // PDF文件通常没有像EPUB那样的独立封面图片
    // 第一页通常包含内容而非专门的封面设计
    // 因此返回null，让UI层使用默认封面占位图
    
    LOG: 'PDF不支持封面提取，返回null'
    RETURN null
    
    // 可能的增强方案（未来实现）：
    // 1. 渲染第一页为图片并保存为封面
    // 2. 使用PDF内嵌的缩略图（如果有）
    // 3. 使用AI识别封面页并渲染
END FUNCTION
```

## 封面检测算法详解

```
┌─────────────────────────────────────────────────────────────────┐
│                    Cover Detection Algorithm                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Rationale:                                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ PDF first page often contains:                          │   │
│  │ - Book cover image                                      │   │
│  │ - Title and author name                                 │   │
│  │ - Publisher information                                 │   │
│  │ - Minimal text content                                  │   │
│  │                                                          │   │
│  │ Detection Strategy:                                      │   │
│  │ - If first page text < 50 characters → Likely cover     │   │
│  │ - Skip this page for chapter detection                   │   │
│  │                                                          │   │
│  │ Threshold: 50 characters                                 │   │
│  │ - Based on empirical observation                        │   │
│  │ - Covers typically have < 50 chars of text              │   │
│  │ - Content pages have > 50 chars                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Algorithm:                                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  pageContents[0].trim().length                          │   │
│  │         │                                                │   │
│  │         │ < 50                                           │   │
│  │         │                                                │   │
│  │         ▼                                                │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ startOffset = 1                                 │    │   │
│  │  │ LOG: '首页文字少于50字符，识别为封面，跳过'      │    │   │
│  │  │                                                  │    │   │
│  │  │ Result:                                          │    │   │
│  │  │ - Chapter detection starts from page 1           │    │   │
│  │  │ - Page 0 excluded from chapter boundaries        │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │         │ >= 50                                          │   │
│  │         │                                                │   │
│  │         ▼                                                │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ startOffset = 0                                 │    │   │
│  │  │                                                  │    │   │
│  │  │ Result:                                          │    │   │
│  │  │ - Chapter detection starts from page 0           │    │   │
│  │  │ - First page included in chapter boundaries      │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Edge Cases:                                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 1. Empty PDF (totalPages = 0)                           │   │
│  │    → Return empty chapter list                         │   │
│  │                                                          │   │
│  │ 2. All pages are covers (effectivePages <= 0)           │   │
│  │    → Return empty chapter list                         │   │
│  │                                                          │   │
│  │ 3. Cover with more than 50 chars                        │   │
│  │    → May be incorrectly included                       │   │
│  │    → User can manually adjust                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 重复章节号防止机制

```
┌─────────────────────────────────────────────────────────────────┐
│                    Duplicate Prevention                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Problem:                                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Some PDFs have chapter numbers in:                      │   │
│  │ - Page headers                                          │   │
│  │ - Page footers                                          │   │
│  │ - Table of contents                                     │   │
│  │                                                          │   │
│  │ Example:                                                 │   │
│  │ Page 5:                                                  │   │
│  │   Header: "第一章 引言"  ← Actual chapter title         │   │
│  │   Content: "正文内容..."                                │   │
│  │   Footer: "第一章"       ← Duplicate in footer          │   │
│  │                                                          │   │
│  │ Without prevention, both would be recorded              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Solution:                                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  lastChapterNum = -1  // Initialize                     │   │
│  │                                                          │   │
│  │  FOR each detected chapter:                             │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  Extract chapter number from title                      │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  chapterNum = int.tryParse(extractedNumber)             │   │
│  │      │                                                   │   │
│  │      │                                                   │   │
│  │      ▼                                                   │   │
│  │  IF chapterNum != lastChapterNum:                       │   │
│  │      │                                                   │   │
│  │      │ YES                                               │   │
│  │      ▼                                                   │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ Record as new chapter boundary                   │    │   │
│  │  │ Update lastChapterNum = chapterNum               │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │      │                                                   │   │
│  │      │ NO (duplicate)                                    │   │
│  │      ▼                                                   │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ Skip this detection                              │    │   │
│  │  │ Do not add to boundaries                         │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Example Flow:                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Page 5: "第一章 引言" → chapterNum = 1 → Record         │   │
│  │ Page 5: "第一章" (footer) → chapterNum = 1 → Skip       │   │
│  │ Page 10: "第二章 方法" → chapterNum = 2 → Record        │   │
│  │ Page 10: "第二章" (footer) → chapterNum = 2 → Skip      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 页码转换说明

```
┌─────────────────────────────────────────────────────────────────┐
│                    Page Number Conversion                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Two Page Number Systems:                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  1-based (User Perspective):                             │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ Page 1, Page 2, Page 3, ...                      │    │   │
│  │  │ Used in:                                          │    │   │
│  │  │ - ChapterLocation.startPage                       │    │   │
│  │  │ - ChapterLocation.endPage                         │    │   │
│  │  │ - UI display                                      │    │   │
│  │  │ - User input                                      │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │  0-based (Internal Index):                               │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ Index 0, Index 1, Index 2, ...                   │    │   │
│  │  │ Used in:                                          │    │   │
│  │  │ - document.pages[i]                               │    │   │
│  │  │ - pageContents[i]                                 │    │   │
│  │  │ - chapterBoundaries[i]                            │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Conversion Rules:                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  0-based → 1-based:                                      │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ startIndex + 1 = startPage                       │    │   │
│  │  │ endIndex + 1 = endPage                           │    │   │
│  │  │                                                  │    │   │
│  │  │ Example:                                         │    │   │
│  │  │ startIndex = 0 → startPage = 1                   │    │   │
│  │  │ endIndex = 5 → endPage = 6                       │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │  1-based → 0-based:                                      │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ pageNum - 1 = pageIndex                          │    │   │
│  │  │                                                  │    │   │
│  │  │ Example:                                         │    │   │
│  │  │ startPage = 1 → pages[0]                         │    │   │
│  │  │ startPage = 6 → pages[5]                         │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Code Examples:                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ // Creating Chapter (0-based to 1-based)                │   │
│  │ Chapter(                                                  │   │
│  │     location: ChapterLocation(                           │   │
│  │         startPage: startIndex + 1,  // Convert          │   │
│  │         endPage: endIndex + 1,      // Convert          │   │
│  │     )                                                    │   │
│  │ )                                                        │   │
│  │                                                          │   │
│  │ // Accessing Page (1-based to 0-based)                   │   │
│  │ FOR pageNum = startPage TO endPage:                     │   │
│  │     page = document.pages[pageNum - 1]  // Convert       │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## HTML转换算法

```
┌─────────────────────────────────────────────────────────────────┐
│                    HTML Conversion Algorithm                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Input: plainText (extracted from PDF pages)                    │
│                                                                  │
│  Output: htmlContent (wrapped in <p> tags)                      │
│                                                                  │
│  Algorithm:                                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  plainText = "第一章 引言\n\n这是第一段内容。\n这是第二段内容。\n\n第三章 方法\n这是第三段内容。" │   │
│  │                                                          │   │
│  │  Step 1: Split by newline                               │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ ["第一章 引言", "", "", "这是第一段内容。",      │    │   │
│  │  │  "这是第二段内容。", "", "第三章 方法",          │    │   │
│  │  │  "这是第三段内容。"]                             │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │  Step 2: Filter empty paragraphs                        │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ ["第一章 引言", "这是第一段内容。",              │    │   │
│  │  │  "这是第二段内容。", "第三章 方法",              │    │   │
│  │  │  "这是第三段内容。"]                             │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │  Step 3: Wrap each paragraph in <p> tag                 │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ <p>第一章 引言</p>                               │    │   │
│  │  │ <p>这是第一段内容。</p>                          │    │   │
│  │  │ <p>这是第二段内容。</p>                          │    │   │
│  │  │ <p>第三章 方法</p>                               │    │   │
│  │  │ <p>这是第三段内容。</p>                          │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  │  Step 4: Join with newline                              │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ <p>第一章 引言</p>\n<p>这是第一段内容。</p>\n... │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Code:                                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ paragraphs = plainText                                   │   │
│  │     .split('\n')                                         │   │
│  │     .where((p) => p.trim().isNotEmpty)                   │   │
│  │                                                          │   │
│  │ htmlContent = paragraphs                                 │   │
│  │     .map((p) => '<p>${p.trim()}</p>')                    │   │
│  │     .join('\n')                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 资源管理

```
┌─────────────────────────────────────────────────────────────────┐
│                    Resource Management                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PDF Document Lifecycle:                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  ┌───────────────┐                                       │   │
│  │  │ Open Document │                                       │   │
│  │  │ PdfDocument   │                                       │   │
│  │  │ .openFile()   │                                       │   │
│  │  └───────────────┘                                       │   │
│  │         │                                                │   │
│  │         ▼                                                │   │
│  │  ┌───────────────┐                                       │   │
│  │  │ Use Document  │                                       │   │
│  │  │ - Read pages  │                                       │   │
│  │  │ - Load text   │                                       │   │
│  │  └───────────────┘                                       │   │
│  │         │                                                │   │
│  │         ▼                                                │   │
│  │  ┌───────────────┐                                       │   │
│  │  │ Dispose       │  ← CRITICAL!                          │   │
│  │  │ document      │                                       │   │
│  │  │ .dispose()    │                                       │   │
│  │  └───────────────┘                                       │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Why dispose() is Critical:                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  pdfrx uses native PDF libraries (pdfium)               │   │
│  │                                                          │   │
│  │  Native resources:                                       │   │
│  │  - Memory buffers                                        │   │
│  │  - File handles                                          │   │
│  │  - Rendering contexts                                    │   │
│  │                                                          │   │
│  │  Without dispose():                                      │   │
│  │  - Memory leaks                                          │   │
│  │  - File handle exhaustion                                │   │
│  │  - Performance degradation                               │   │
│  │                                                          │   │
│  │  Best Practice:                                          │   │
│  │  - Call dispose() immediately after use                  │   │
│  │  - Use try/finally to ensure cleanup                     │   │
│  │  - Don't keep document open across async operations      │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Correct Pattern:                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ TRY:                                                      │   │
│  │     document = await PdfDocument.openFile(filePath)      │   │
│  │     // ... use document ...                              │   │
│  │ FINALLY:                                                  │   │
│  │     await document.dispose()                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 边界情况处理

| 边界情况 | 处理方式 |
|----------|----------|
| 文件不存在 | 抛出异常 |
| 空PDF（0页） | 返回空章节列表 |
| 无章节结构 | 整个文档作为一个章节 |
| 封面后无有效页面 | 返回空章节列表 |
| 页面范围缺失 | 返回空内容 |
| 内容为空 | 返回空ChapterContent |
| 无法提取封面 | 返回null |

## 性能优化

1. **批量文本提取**: 预先收集所有页面文本，避免多次打开文档
2. **限制检测范围**: 只检查每页前5行，提高检测效率
3. **及时资源释放**: 使用完立即调用dispose()
4. **去重机制**: 防止重复章节号导致的冗余处理

## 与EPUB解析器的对比

| 特性 | EPUB | PDF |
|------|------|-----|
| 文件结构 | ZIP + XML | 页面序列 |
| 章节来源 | NCX/NAV导航文件 | 页面内容分析 |
| 层级支持 | 多层级目录 | 无层级（level=0） |
| 内容格式 | HTML | 纯文本 |
| 封面提取 | 图片文件 | 不支持 |
| 元数据来源 | OPF文件 | 文件名 |
| 锚点处理 | 支持 | 不适用 |
| 页码系统 | 不适用 | 1-based/0-based转换 |