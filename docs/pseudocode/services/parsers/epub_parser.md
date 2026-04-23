# EpubParser - EPUB格式解析器

## 概述

`EpubParser` 是EPUB格式解析器的实现类，负责解析EPUB电子书文件。EPUB本质上是一个ZIP压缩包，包含HTML内容文件、CSS样式、图片资源和元数据文件。

## EPUB文件结构

```
┌─────────────────────────────────────────────────────────────────┐
│                    EPUB File Structure                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  book.epub (ZIP archive)                                        │
│  │                                                               │
│  ├── META-INF/                                                  │
│  │   └── container.xml    ← 入口文件，指向OPF                   │
│  │                                                               │
│  ├── OEBPS/ (或 OPS/ 或 content/)                               │
│  │   ├── content.opf     ← 包文件，元数据和manifest              │
│  │   ├── toc.ncx         ← 导航文件（EPUB2）                     │
│  │   ├── nav.xhtml       ← 导航文件（EPUB3）                     │
│  │   │                                                           │
│  │   ├── Text/                                                   │
│  │   │   ├── chapter1.xhtml                                     │
│  │   │   ├── chapter2.xhtml                                     │
│  │   │   └── ...                                                │
│  │   │                                                           │
│  │   ├── Images/                                                │
│  │   │   ├── cover.jpg                                          │
│  │   │   ├── image1.png                                         │
│  │   │   └── ...                                                │
│  │   │                                                           │
│  │   └── Styles/                                                │
│  │       ├── stylesheet.css                                     │
│  │       └── ...                                                │
│  │                                                               │
│  └─────────────────────────────────────────────────────────────┘
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
        THROW Exception('EPUB file not found: $filePath')
    
    // Step 2: 读取文件字节
    bytes = await file.readAsBytes()
    LOG: '文件大小: ${bytes.length} bytes'
    
    // Step 3: 初始化变量
    title = null
    author = null
    chapterTitles = []
    
    // Step 4: 首选方案 - 使用EpubReader解析
    TRY:
        epubBook = await EpubReader.readBook(bytes)
        LOG: 'EPUB解析成功'
        
        // 提取标题
        title = epubBook.title
        
        // 提取作者（多个作者用逗号连接）
        IF epubBook.authors?.isNotEmpty:
            author = epubBook.authors!.join(', ')
        
        // 提取章节标题
        IF epubBook.chapters?.isNotEmpty:
            chapterTitles = _extractChapterTitles(epubBook.chapters!)
    
    CATCH e:
        LOG: '使用EpubReader解析失败'
        LOG: '尝试使用archive直接解析EPUB...'
        
        // Step 5: 回退方案 - 使用archive直接解析ZIP结构
        archive = ZipDecoder().decodeBytes(bytes)
        
        // 解析container.xml获取OPF路径
        containerInfo = _parseContainerXml(archive)
        IF containerInfo != null:
            title = containerInfo['title']
            author = containerInfo['author']
        
        // 解析OPF文件获取元数据
        opfInfo = _parseOpfFile(archive)
        IF opfInfo != null:
            title ??= opfInfo['title']  // 空值合并赋值
            author ??= opfInfo['author']
        
        // 解析导航文件获取章节列表
        chapterTitles = _parseNavigationFile(archive)
    
    // Step 6: 最终回退 - 从文件路径提取书名
    IF title == null OR title.isEmpty:
        title = _extractTitleFromPath(filePath)
    
    IF author == null OR author.isEmpty:
        author = '未知作者'
    
    // Step 7: 提取封面图片
    TRY:
        coverPath = await extractCover(filePath)
    CATCH e:
        LOG: '封面提取失败'
        coverPath = null
    
    LOG: '最终书名: $title'
    LOG: '最终作者: $author'
    LOG: '章节数: ${chapterTitles.length}'
    
    // Step 8: 返回元数据对象
    RETURN BookMetadata(
        title: title,
        author: author,
        coverPath: coverPath,
        totalChapters: chapterTitles.length,
        format: BookFormat.epub
    )
END FUNCTION
```

### getChapters() - 章节列表提取

```
FUNCTION getChapters(filePath: String) -> Future<List<Chapter>>
    LOG: 'getChapters 开始执行'
    
    // Step 1: 文件存在性检查
    file = File(filePath)
    IF NOT await file.exists():
        LOG: '文件不存在'
        RETURN []
    
    // Step 2: 读取文件字节
    bytes = await file.readAsBytes()
    chapterInfos = []
    
    TRY:
        epubBook = await EpubReader.readBook(bytes)
        
        // Step 3: 优先从toc.ncx (navigation)提取 - 最准确，包含层级结构
        IF epubBook.schema?.navigation?.navMap != null AND
           epubBook.schema!.navigation!.navMap!.points.isNotEmpty:
            LOG: '从navigation提取章节列表'
            chapterInfos = _extractChapterInfosFromNavigation(
                epubBook.schema!.navigation!.navMap!.points
            )
            IF chapterInfos.isNotEmpty:
                RETURN _convertToChapters(chapterInfos)
        
        // Step 4: 从chapters提取 - epub_plus库解析的章节列表
        IF epubBook.chapters.isNotEmpty:
            LOG: '从epubBook.chapters提取章节列表'
            chapterInfos = _extractChapterInfos(epubBook.chapters)
            IF chapterInfos.isNotEmpty:
                RETURN _convertToChapters(chapterInfos)
        
        // Step 5: 从content.html提取 - 按spine顺序排列的HTML文件
        IF epubBook.content?.html?.isNotEmpty:
            LOG: '从content.html提取章节列表'
            chapterInfos = _extractChapterInfosFromContent(
                epubBook.content!.html!,
                epubBook.schema?.package?.spine?.items
            )
            IF chapterInfos.isNotEmpty:
                RETURN _convertToChapters(chapterInfos)
    
    CATCH e:
        LOG: 'EpubReader解析失败，使用archive回退方案'
    
    // Step 6: 回退方案 - 使用archive解析ZIP结构
    archive = ZipDecoder().decodeBytes(bytes)
    
    // 尝试从NCX文件提取
    chaptersFromNcx = _extractChapterInfosFromNcxArchive(archive)
    IF chaptersFromNcx.isNotEmpty:
        RETURN _convertToChapters(chaptersFromNcx)
    
    // 最终回退 - 从HTML文件列表提取
    flatChapters = _extractChapterInfosFromArchive(archive)
    RETURN _convertToChapters(flatChapters)
END FUNCTION
```

### 章节提取优先级流程图

```
┌─────────────────────────────────────────────────────────────────┐
│              Chapter Extraction Priority Flow                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Priority 1: toc.ncx (Navigation)                        │   │
│  │ - Most accurate                                         │   │
│  │ - Contains hierarchical structure                       │   │
│  │ - Includes navPoints with level info                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          │ IF EMPTY                               │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Priority 2: epubBook.chapters                           │   │
│  │ - Medium accuracy                                        │   │
│  │ - Library-parsed chapter list                           │   │
│  │ - May miss some chapters                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          │ IF EMPTY                               │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Priority 3: content.html (Spine order)                  │   │
│  │ - Lower accuracy                                         │   │
│  │ - Based on OPF spine ordering                            │   │
│  │ - May include non-chapter files                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          │ IF EMPTY                               │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Priority 4: Archive NCX direct parse                    │   │
│  │ - Fallback parsing                                       │   │
│  │ - Direct XML parsing of .ncx file                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                       │
│                          │ IF EMPTY                               │
│                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Priority 5: Archive HTML file list                      │   │
│  │ - Final fallback                                         │   │
│  │ - List all .html/.xhtml files                            │   │
│  │ - No hierarchy, flat structure                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### getChapterContent() - 章节内容提取

```
FUNCTION getChapterContent(filePath: String, chapter: Chapter) -> Future<ChapterContent>
    LOG: 'getChapterContent 开始执行'
    LOG: '章节信息：title=${chapter.title}, href=${chapter.location.href}'
    
    // Step 1: 文件存在性检查
    file = File(filePath)
    IF NOT await file.exists():
        THROW Exception('EPUB file not found: $filePath')
    
    // Step 2: 读取文件字节
    bytes = await file.readAsBytes()
    href = chapter.location.href
    
    // Step 3: 验证href
    IF href == null OR href.isEmpty:
        LOG: '章节没有 href'
        RETURN ChapterContent(plainText: '')
    
    LOG: '准备提取章节内容，href: $href'
    
    // Step 4: 首选方案 - 从archive根据href提取HTML文件内容
    TRY:
        LOG: '尝试从 archive 提取章节内容...'
        htmlContent = await _getChapterHtmlFromArchive(bytes, href)
        
        IF htmlContent != null AND htmlContent.isNotEmpty:
            LOG: '成功从 archive 提取章节内容'
            plainText = _extractTextFromHtml(htmlContent)
            RETURN ChapterContent(
                plainText: plainText,
                htmlContent: htmlContent
            )
        ELSE:
            LOG: '从 archive 提取的内容为空'
    
    CATCH e:
        LOG: '从 archive 提取章节内容失败'
    
    // Step 5: 回退方案 - 使用EpubReader查找章节内容
    TRY:
        LOG: '尝试使用 EpubReader 提取章节内容...'
        epubBook = await EpubReader.readBook(bytes)
        
        // 通过章节索引查找
        IF chapter.index >= 0 AND chapter.index < epubBook.chapters.length:
            epubChapter = epubBook.chapters[chapter.index]
            htmlContent = epubChapter.htmlContent ?? ''
            
            IF htmlContent.isNotEmpty:
                LOG: '使用 EpubReader 获取章节内容'
                plainText = _extractTextFromHtml(htmlContent)
                RETURN ChapterContent(
                    plainText: plainText,
                    htmlContent: htmlContent
                )
    
    CATCH e:
        LOG: '使用 EpubReader 获取章节内容失败'
    
    // Step 6: 无法获取内容
    LOG: '无法获取章节内容'
    RETURN ChapterContent(plainText: '')
END FUNCTION
```

### 锚点处理算法

EPUB文件中，多个章节可能共享同一个HTML文件，通过锚点（如 `#nav_point_1`）区分。

```
FUNCTION _getChapterHtmlFromArchive(bytes: Uint8List, href: String) -> Future<String?>
    archive = ZipDecoder().decodeBytes(bytes)
    
    // Step 1: 分离文件路径和锚点
    hrefParts = href.split('#')
    hrefWithoutAnchor = hrefParts[0]
    anchor = hrefParts.length > 1 ? hrefParts[1] : null
    
    LOG: '从 archive 提取章节：href=$href, anchor=$anchor'
    
    // Step 2: 多种匹配方式尝试查找文件
    FOR archiveFile IN archive.files:
        archiveName = archiveFile.name
        
        // 匹配条件（大小写不敏感）
        isMatch = 
            archiveName == hrefWithoutAnchor OR
            archiveName.endsWith('/$hrefWithoutAnchor') OR
            archiveName.toLowerCase() == hrefWithoutAnchor.toLowerCase() OR
            archiveName.toLowerCase().endsWith('/${hrefWithoutAnchor.toLowerCase()}') OR
            archiveName.endsWith(hrefWithoutAnchor) OR
            // 处理路径中的文件名匹配
            hrefWithoutAnchor.contains('/') AND 
            archiveName.endsWith(hrefWithoutAnchor.split('/').last)
        
        IF isMatch:
            fullHtml = utf8.decode(archiveFile.content)
            
            // Step 3: 如果没有锚点，返回整个文件内容
            IF anchor == null OR anchor.isEmpty:
                RETURN fullHtml
            
            // Step 4: 有锚点时，提取锚点对应的章节片段
            chapterHtml = _extractChapterByAnchor(fullHtml, anchor)
            
            IF chapterHtml != null:
                RETURN chapterHtml
            ELSE:
                // 未找到锚点，返回整个文件
                RETURN fullHtml
    
    LOG: '未找到文件：$hrefWithoutAnchor'
    RETURN null
END FUNCTION
```

```
FUNCTION _extractChapterByAnchor(fullHtml: String, anchor: String) -> String?
    LOG: '开始提取锚点内容：anchor=$anchor'
    
    // Step 1: 查找包含 id="anchor" 或 name="anchor" 的元素
    anchorPattern = RegExp('(id|name)\\s*=\\s*["\']?$anchor["\']?', caseSensitive: false)
    anchorMatch = anchorPattern.firstMatch(fullHtml)
    
    IF anchorMatch == null:
        LOG: '未找到锚点：$anchor'
        RETURN null
    
    startPos = anchorMatch.start
    
    // Step 2: 向前查找最近的 '<'（元素开始标签）
    elementStart = startPos
    searchCount = 0
    WHILE elementStart > 0 AND fullHtml[elementStart - 1] != '<' AND searchCount < 500:
        elementStart--
        searchCount++
    
    // Step 3: 向后查找该元素的结束标签 '>'
    elementEnd = startPos
    searchCount = 0
    WHILE elementEnd < fullHtml.length AND fullHtml[elementEnd] != '>' AND searchCount < 500:
        elementEnd++
        searchCount++
    elementEnd++  // 包含 '>'
    
    // Step 4: 判断是否是自闭合标签
    tagContent = fullHtml.substring(elementStart, elementEnd)
    isSelfClosing = tagContent.endsWith('/>')
    
    IF isSelfClosing:
        RETURN tagContent
    
    // Step 5: 提取标签名
    tagNameMatch = RegExp(r'<(\w+)').firstMatch(tagContent)
    IF tagNameMatch == null:
        RETURN null
    
    tagName = tagNameMatch.group(1)
    
    // Step 6: 查找对应的结束标签
    endTagPattern = RegExp('</$tagName\\s*>', caseSensitive: false)
    endTagMatch = endTagPattern.firstMatch(fullHtml.substring(elementEnd))
    
    IF endTagMatch != null:
        // 找到结束标签，返回整个元素
        RETURN fullHtml.substring(elementStart, elementEnd + endTagMatch.end)
    ELSE:
        // 没有找到结束标签，返回从锚点到文件末尾
        RETURN fullHtml.substring(elementStart)
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
    
    bytes = await file.readAsBytes()
    
    TRY:
        // Step 2: 首选方案 - 使用EpubReader提取封面
        epubBook = await EpubReader.readBook(bytes)
        
        IF epubBook.content?.images?.isNotEmpty:
            coverImage = null
            
            // Step 3: 查找包含cover或title的图片
            FOR entry IN epubBook.content!.images!.entries:
                name = entry.key.toLowerCase()
                IF name.contains('cover') OR name.contains('title'):
                    coverImage = entry.value
                    LOG: '找到封面图片: ${entry.key}'
                    BREAK
            
            // Step 4: 若未找到，使用第一张图片
            IF coverImage == null:
                coverImage = epubBook.content!.images!.values.first
                LOG: '使用第一张图片作为封面'
            
            IF coverImage != null AND coverImage.content != null:
                RETURN await _saveCoverImage(
                    coverImage.content!,
                    coverImage.contentMimeType
                )
    
    CATCH e:
        LOG: '使用EpubReader提取封面失败'
    
    // Step 5: 回退方案 - 从archive查找
    RETURN await _extractCoverFromArchive(bytes)
END FUNCTION
```

```
FUNCTION _extractCoverFromArchive(bytes: Uint8List) -> Future<String?>
    archive = ZipDecoder().decodeBytes(bytes)
    
    // Step 1: 定义封面文件名模式
    coverPatterns = [
        'cover.jpg', 'cover.jpeg', 'cover.png',
        'Cover.jpg', 'Cover.jpeg', 'Cover.png'
    ]
    
    coverFile = null
    
    // Step 2: 按文件名模式查找
    FOR pattern IN coverPatterns:
        FOR file IN archive.files:
            IF file.name.toLowerCase().endsWith(pattern.toLowerCase()):
                coverFile = file
                BREAK
        IF coverFile != null:
            BREAK
    
    // Step 3: 若未找到，查找包含cover或image的图片文件
    IF coverFile == null:
        FOR file IN archive.files:
            name = file.name.toLowerCase()
            IF (name.contains('cover') OR name.contains('image')) AND
               (name.endsWith('.jpg') OR name.endsWith('.jpeg') OR name.endsWith('.png')):
                coverFile = file
                BREAK
    
    // Step 4: 保存封面图片
    IF coverFile != null:
        imageBytes = coverFile.content
        mimeType = coverFile.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg'
        RETURN await _saveCoverImage(imageBytes, mimeType)
    
    RETURN null
END FUNCTION
```

## XML解析辅助方法

### _parseContainerXml() - 解析container.xml

```
FUNCTION _parseContainerXml(archive: Archive) -> Map<String, String>?
    TRY:
        // Step 1: 查找container.xml文件
        containerFile = null
        FOR file IN archive.files:
            IF file.name.toLowerCase() == 'meta-inf/container.xml' OR
               file.name == 'META-INF/container.xml':
                containerFile = file
                BREAK
        
        IF containerFile == null:
            RETURN null
        
        // Step 2: 解析XML内容
        content = utf8.decode(containerFile.content)
        document = XmlDocument.parse(content)
        
        // Step 3: 查找rootfile元素
        rootfileElement = document.findAllElements('rootfile').firstOrNull
        
        IF rootfileElement == null:
            RETURN null
        
        // Step 4: 提取OPF路径
        opfPath = rootfileElement.getAttribute('full-path')
        
        IF opfPath == null:
            RETURN null
        
        RETURN {'opfPath': opfPath}
    
    CATCH e:
        LOG: '解析container.xml失败'
        RETURN null
END FUNCTION
```

### _parseOpfFile() - 解析OPF文件

```
FUNCTION _parseOpfFile(archive: Archive) -> Map<String, String?>?
    TRY:
        // Step 1: 获取OPF文件路径
        opfPath = null
        opfFile = null
        
        containerInfo = _parseContainerXml(archive)
        IF containerInfo != null AND containerInfo['opfPath'] != null:
            opfPath = containerInfo['opfPath']
            FOR file IN archive.files:
                IF file.name == opfPath:
                    opfFile = file
                    BREAK
        
        // Step 2: 若未找到，搜索所有.opf文件
        IF opfFile == null:
            FOR file IN archive.files:
                IF file.name.toLowerCase().endsWith('.opf'):
                    opfFile = file
                    BREAK
        
        IF opfFile == null:
            RETURN null
        
        // Step 3: 解析XML内容
        content = utf8.decode(opfFile.content)
        document = XmlDocument.parse(content)
        
        // Step 4: 提取dc:title
        title = null
        titleElements = document.findAllElements('dc:title')
        IF titleElements.isNotEmpty:
            title = titleElements.first.innerText.trim()
        
        // Step 5: 提取dc:creator（作者）
        author = null
        creatorElements = document.findAllElements('dc:creator')
        IF creatorElements.isNotEmpty:
            author = creatorElements.map(e => e.innerText.trim()).join(', ')
        
        RETURN {'title': title, 'author': author}
    
    CATCH e:
        LOG: '解析OPF文件失败'
        RETURN null
END FUNCTION
```

### _parseNavigationFile() - 解析导航文件

```
FUNCTION _parseNavigationFile(archive: Archive) -> List<String>
    TRY:
        navFile = null
        navFileType = null
        
        // Step 1: 查找NCX文件（EPUB2）
        FOR file IN archive.files:
            IF file.name.toLowerCase().endsWith('.ncx'):
                navFile = file
                navFileType = 'ncx'
                BREAK
        
        // Step 2: 若无NCX，查找NAV文件（EPUB3）
        IF navFile == null:
            FOR file IN archive.files:
                name = file.name.toLowerCase()
                IF (name.contains('nav.') AND name.endsWith('.html')) OR
                   name.endsWith('.xhtml'):
                    IF name.contains('nav'):
                        navFile = file
                        navFileType = 'nav'
                        BREAK
        
        IF navFile == null:
            RETURN []
        
        content = utf8.decode(navFile.content)
        chapters = []
        
        // Step 3: 解析NCX文件
        IF navFileType == 'ncx':
            document = XmlDocument.parse(content)
            navPoints = document.findAllElements('navPoint')
            
            FOR navPoint IN navPoints:
                textElements = navPoint.findElements('text')
                IF textElements.isNotEmpty:
                    text = textElements.first.innerText.trim()
                    IF text.isNotEmpty:
                        chapters.add(text)
        
        // Step 4: 解析NAV文件（HTML链接）
        ELSE:
            aPattern = RegExp(r'<a[^>]*>(.*?)</a>', caseSensitive: false)
            matches = aPattern.allMatches(content)
            
            FOR match IN matches:
                text = _extractTextFromHtml(match.group(1) ?? '').trim()
                IF text.isNotEmpty:
                    chapters.add(text)
        
        RETURN chapters
    
    CATCH e:
        LOG: '解析导航文件失败'
        RETURN []
END FUNCTION
```

### _extractChapterInfosFromNcxArchive() - 从NCX提取章节信息

```
FUNCTION _extractChapterInfosFromNcxArchive(archive: Archive) -> List<_ChapterInfoInternal>
    TRY:
        // Step 1: 查找NCX文件
        ncxFile = null
        FOR file IN archive.files:
            IF file.name.toLowerCase().endsWith('.ncx'):
                ncxFile = file
                BREAK
        
        IF ncxFile == null:
            RETURN []
        
        // Step 2: 解析XML
        content = utf8.decode(ncxFile.content)
        document = XmlDocument.parse(content)
        navMap = document.findAllElements('navMap').firstOrNull
        
        IF navMap == null:
            RETURN []
        
        // Step 3: 递归解析navPoint元素
        FUNCTION parseNavPoints(points: Iterable<XmlElement>, level: int) -> List<_ChapterInfoInternal>
            result = []
            
            FOR navPoint IN points:
                // 提取标题
                textElements = navPoint.findElements('navLabel').firstOrNull?.findElements('text') ?? []
                contentElements = navPoint.findElements('content')
                
                IF textElements.isNotEmpty:
                    title = textElements.first.innerText.trim()
                    href = contentElements.isNotEmpty ? contentElements.first.getAttribute('src') : null
                    
                    IF title.isNotEmpty:
                        result.add(_ChapterInfoInternal(
                            title: title,
                            href: href,
                            level: level
                        ))
                        
                        // 递归处理子导航点
                        childNavPoints = navPoint.findElements('navPoint')
                        IF childNavPoints.isNotEmpty:
                            result.addAll(parseNavPoints(childNavPoints, level + 1))
            
            RETURN result
        
        navPoints = navMap.findElements('navPoint')
        RETURN parseNavPoints(navPoints, 0)
    
    CATCH e:
        LOG: '从archive解析toc.ncx失败'
        RETURN []
END FUNCTION
```

## HTML文本提取

### _extractTextFromHtml() - 从HTML提取纯文本

```
FUNCTION _extractTextFromHtml(html: String) -> String
    // Step 1: 移除script标签及其内容
    result = html.replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
        ''
    )
    
    // Step 2: 移除style标签及其内容
    result = result.replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
        ''
    )
    
    // Step 3: 移除所有HTML标签
    result = result.replaceAll(RegExp(r'<[^>]+>'), ' ')
    
    // Step 4: 合并多个空白字符为单个空格
    result = result.replaceAll(RegExp(r'\s+'), ' ')
    
    // Step 5: 替换HTML实体
    result = result.replaceAll(RegExp(r'&nbsp;'), ' ')
    result = result.replaceAll(RegExp(r'&[a-z]+;'), '')
    
    // Step 6: 去除首尾空白
    RETURN result.trim()
END FUNCTION
```

### _extractTitleFromHtmlContent() - 从HTML提取章节标题

```
FUNCTION _extractTitleFromHtmlContent(html: String) -> String
    // Step 1: 尝试提取<title>标签内容
    titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false).firstMatch(html)
    IF titleMatch != null:
        title = titleMatch.group(1)?.trim()
        IF title?.isNotEmpty:
            RETURN title
    
    // Step 2: 尝试提取<h1>标签内容
    h1Match = RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false).firstMatch(html)
    IF h1Match != null:
        title = _extractTextFromHtml(h1Match.group(1) ?? '').trim()
        IF title.isNotEmpty:
            RETURN title
    
    // Step 3: 尝试提取<h2>标签内容
    h2Match = RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false).firstMatch(html)
    IF h2Match != null:
        title = _extractTextFromHtml(h2Match.group(1) ?? '').trim()
        IF title.isNotEmpty:
            RETURN title
    
    // Step 4: 无法提取，返回默认值
    RETURN '未知章节'
END FUNCTION
```

## 章节转换

### _convertToChapters() - 转换为Chapter模型

```
FUNCTION _convertToChapters(chapterInfos: List<_ChapterInfoInternal>) -> List<Chapter>
    chapters = []
    topLevelIndex = 0
    
    FOR info IN chapterInfos:
        IF info.title.isNotEmpty AND info.href != null AND info.href.isNotEmpty:
            // 顶层章节分配递增index，子章节index设为-1
            chapterIndex = info.level == 0 ? topLevelIndex++ : -1
            
            chapters.add(Chapter(
                id: _uuid.v4(),  // 生成UUID
                index: chapterIndex,
                title: info.title,
                location: ChapterLocation(href: info.href),
                level: info.level
            ))
    
    RETURN chapters
END FUNCTION
```

## 内部数据结构

### _ChapterInfoInternal

```
CLASS _ChapterInfoInternal
    PROPERTIES:
        title: String       // 章节标题
        href: String?       // 章节文件路径（HTML/XHTML文件的相对路径）
        level: int          // 层级深度（0=顶层章节，用于UI显示缩进）
    
    CONSTRUCTOR(title, href, level)
END CLASS
```

## 错误处理与回退策略

```
┌─────────────────────────────────────────────────────────────────┐
│                    Fallback Strategy Matrix                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ parse() Fallback Chain                                    │ │
│  ├───────────────────────────────────────────────────────────┤ │
│  │ 1. EpubReader.readBook() → Primary                        │ │
│  │ 2. _parseContainerXml() → Get OPF path                    │ │
│  │ 3. _parseOpfFile() → Extract metadata                     │ │
│  │ 4. _parseNavigationFile() → Get chapter titles            │ │
│  │ 5. _extractTitleFromPath() → Final fallback               │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ getChapters() Fallback Chain                              │ │
│  ├───────────────────────────────────────────────────────────┤ │
│  │ 1. navigation.navMap → Most accurate                      │ │
│  │ 2. epubBook.chapters → Medium accuracy                    │ │
│  │ 3. content.html + spine → Lower accuracy                  │ │
│  │ 4. _extractChapterInfosFromNcxArchive() → Direct XML      │ │
│  │ 5. _extractChapterInfosFromArchive() → File list          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ getChapterContent() Fallback Chain                        │ │
│  ├───────────────────────────────────────────────────────────┤ │
│  │ 1. _getChapterHtmlFromArchive() → Direct href lookup      │ │
│  │ 2. EpubReader.chapters[index] → Index-based lookup        │ │
│  │ 3. Return empty content → Final fallback                  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ extractCover() Fallback Chain                             │ │
│  ├───────────────────────────────────────────────────────────┤ │
│  │ 1. EpubReader.content.images → Find cover/title image     │ │
│  │ 2. First image → If no cover found                        │ │
│  │ 3. _extractCoverFromArchive() → Direct file search        │ │
│  │ 4. Return null → No cover available                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 性能优化

1. **按需解析**: 只解析用户请求的章节，避免全量解析
2. **锚点处理**: 支持同一HTML文件中的多个章节（通过锚点区分）
3. **大小写不敏感**: 文件路径匹配忽略大小写，提高兼容性
4. **搜索限制**: 锚点查找限制500字符，防止无限循环
5. **资源复用**: 解析器实例可复用（无状态设计）

## 边界情况处理

| 边界情况 | 处理方式 |
|----------|----------|
| 文件不存在 | 抛出异常 |
| 无元数据 | 从文件名提取标题，作者设为"未知作者" |
| 无章节结构 | 返回空列表或按HTML文件列表生成章节 |
| href为空 | 返回空内容 |
| 锚点未找到 | 返回整个HTML文件内容 |
| 无封面图片 | 返回null |
| 编码问题 | 使用UTF-8解码，失败时记录日志 |