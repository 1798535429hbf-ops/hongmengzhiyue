package com.hakimi.smartread.service;

import com.hakimi.smartread.repository.SmartReadRepository;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

@Service
public class ImportBookService {
    private static final int MAX_CHAPTERS = 120;
    private static final int MAX_CHAPTER_CHARS = 60_000;

    private final SmartReadRepository repository;

    public ImportBookService(SmartReadRepository repository) {
        this.repository = repository;
    }

    public Map<String, Object> importBook(Map<String, Object> payload) {
        String fileName = textAny(payload, "file_name", "fileName");
        if (fileName.isBlank()) {
            fileName = "local-book-" + System.currentTimeMillis() + ".txt";
        }
        String sourceType = normalizeSourceType(textAny(payload, "source_type", "sourceType"), fileName);
        ParsedBook parsed = "local_epub".equals(sourceType)
                ? parseEpub(fileName, loadBytes(payload))
                : parseText(fileName, loadText(payload));
        if (parsed.chapters().isEmpty()) {
            throw SmartReadException.badRequest("未能从本地书籍中解析出可阅读章节");
        }

        String isbn = sourceType + "-" + sha256(fileName + "\n" + parsed.title()).substring(0, 20);
        Map<String, Object> book = new LinkedHashMap<>();
        book.put("isbn", isbn);
        book.put("title", parsed.title());
        book.put("author", parsed.author());
        book.put("tags", textAny(payload, "tags").isBlank() ? parsed.tags() : textAny(payload, "tags"));
        book.put("summary", parsed.summary());
        book.put("difficulty", textAny(payload, "difficulty").isBlank() ? "本地导入" : textAny(payload, "difficulty"));
        book.put("targetReader", textAny(payload, "target_reader", "targetReader").isBlank()
                ? "希望把本地资料纳入阅读计划和 AI 伴读的学生"
                : textAny(payload, "target_reader", "targetReader"));
        book.put("coverColor", parsed.coverColor());
        book.put("sourceType", sourceType);
        book.put("sourceNote", "local_epub".equals(sourceType)
                ? "从本地 EPUB 导入，章节与片段已写入数据库。"
                : "从本地 TXT/MD 导入，章节与片段已写入数据库。");
        book.put("fileName", fileName);

        long bookId = repository.importBook(book, parsed.chapters(), parsed.chunks());
        return Map.of(
                "book_id", bookId,
                "bookId", bookId,
                "status", "ready",
                "message", "本地书籍已入库，可在书城搜索、阅读器和 AI 推荐中使用。",
                "chapter_count", parsed.chapters().size(),
                "chapterCount", parsed.chapters().size(),
                "source_type", sourceType,
                "sourceType", sourceType
        );
    }

    ParsedBook parseText(String fileName, String rawText) {
        String text = normalizeWhitespace(rawText);
        if (text.isBlank()) {
            throw SmartReadException.badRequest("TXT/MD 内容为空，无法导入");
        }
        String title = titleFromText(fileName, text);
        List<TextSection> sections = readableSections(splitTextSections(title, text));
        List<Map<String, Object>> chapters = new ArrayList<>();
        List<Map<String, Object>> chunks = new ArrayList<>();
        for (int i = 0; i < sections.size() && i < MAX_CHAPTERS; i++) {
            TextSection section = sections.get(i);
            List<String> paragraphs = paragraphs(section.content());
            Map<String, Object> chapter = chapterMap("ch-" + (i + 1), section.title(), i + 1, section.content(), paragraphs);
            chapters.add(chapter);
            addChunks(chunks, title, section.title(), paragraphs);
        }
        return new ParsedBook(title, "本地导入", defaultTags(fileName, "TXT"), summaryOf(text), colorFor(title), chapters, chunks);
    }

    ParsedBook parseEpub(String fileName, byte[] bytes) {
        if (bytes.length == 0) {
            throw SmartReadException.badRequest("EPUB 内容为空，无法导入");
        }
        Map<String, byte[]> entries = unzip(bytes);
        String container = decode(entries.get("META-INF/container.xml"));
        String opfPath = attr(firstTag(container, "rootfile"), "full-path");
        if (opfPath.isBlank() || !entries.containsKey(opfPath)) {
            throw SmartReadException.badRequest("EPUB 缺少 OPF 元数据文件，无法解析目录");
        }
        String opf = decode(entries.get(opfPath));
        String title = firstText(opf, "title");
        if (title.isBlank()) {
            title = baseTitle(fileName);
        }
        String author = firstText(opf, "creator");
        if (author.isBlank()) {
            author = "本地导入";
        }

        Map<String, ManifestItem> manifest = manifest(opf);
        List<String> spine = spine(opf);
        List<Map<String, Object>> chapters = new ArrayList<>();
        List<Map<String, Object>> chunks = new ArrayList<>();
        int order = 1;
        for (String idref : spine) {
            ManifestItem item = manifest.get(idref);
            if (item == null || (!item.mediaType().contains("html") && !item.mediaType().contains("xhtml"))) {
                continue;
            }
            String href = resolvePath(opfPath, item.href());
            byte[] htmlBytes = entries.get(href);
            if (htmlBytes == null) {
                continue;
            }
            String html = decode(htmlBytes);
            String plain = stripHtml(html);
            if (plain.length() < 20) {
                continue;
            }
            String chapterTitle = heading(html);
            if (isFrontMatterSection(chapterTitle, plain)) {
                continue;
            }
            if (chapterTitle.isBlank()) {
                chapterTitle = "第" + order + "章";
            }
            List<String> paragraphs = paragraphs(plain);
            chapters.add(chapterMap("ch-" + order, chapterTitle, order, plain, paragraphs));
            addChunks(chunks, title, chapterTitle, paragraphs);
            order++;
            if (chapters.size() >= MAX_CHAPTERS) {
                break;
            }
        }
        if (chapters.isEmpty()) {
            throw SmartReadException.badRequest("EPUB 未解析出正文章节，请确认文件未加密且包含 HTML/XHTML 内容");
        }
        return new ParsedBook(title, author, defaultTags(fileName, "EPUB"), summaryOf(string(chapters.get(0).get("content"))),
                colorFor(title), chapters, chunks);
    }

    private String loadText(Map<String, Object> payload) {
        String content = textAny(payload, "content", "text");
        if (!content.isBlank()) {
            return content;
        }
        byte[] bytes = loadBytes(payload);
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private byte[] loadBytes(Map<String, Object> payload) {
        String base64 = textAny(payload, "base64", "content_base64", "contentBase64");
        if (!base64.isBlank()) {
            return Base64.getDecoder().decode(base64);
        }
        String filePath = textAny(payload, "file_path", "filePath");
        if (!filePath.isBlank()) {
            try {
                return Files.readAllBytes(Path.of(filePath));
            } catch (IOException exc) {
                throw SmartReadException.badRequest("读取服务端文件失败：" + exc.getMessage());
            }
        }
        String content = textAny(payload, "content", "text");
        return content.getBytes(StandardCharsets.UTF_8);
    }

    private String normalizeSourceType(String sourceType, String fileName) {
        String normalized = sourceType == null ? "" : sourceType.trim().toLowerCase(Locale.ROOT);
        String extension = extension(fileName);
        if (normalized.isBlank()) {
            normalized = "epub".equals(extension) ? "local_epub" : "local_txt";
        }
        if ("txt".equals(normalized) || "md".equals(normalized) || "markdown".equals(normalized)) {
            return "local_txt";
        }
        if ("epub".equals(normalized)) {
            return "local_epub";
        }
        if (!"local_txt".equals(normalized) && !"local_epub".equals(normalized)) {
            throw SmartReadException.badRequest("暂不支持的本地书籍类型：" + normalized);
        }
        if ("local_txt".equals(normalized) && !List.of("txt", "md", "markdown", "").contains(extension)) {
            throw SmartReadException.badRequest("当前仅支持 TXT/MD 和 EPUB 入库解析");
        }
        return normalized;
    }

    private Map<String, Object> chapterMap(String chapterId, String title, int order, String content, List<String> paragraphs) {
        Map<String, Object> chapter = new LinkedHashMap<>();
        String safeContent = content.length() > MAX_CHAPTER_CHARS ? content.substring(0, MAX_CHAPTER_CHARS) : content;
        chapter.put("chapterId", chapterId);
        chapter.put("title", title.length() > 150 ? title.substring(0, 150) : title);
        chapter.put("order", order);
        chapter.put("summary", summaryOf(safeContent));
        chapter.put("content", safeContent);
        chapter.put("paragraphs", paragraphs);
        chapter.put("pageCount", Math.max(1, safeContent.length() / 900 + 1));
        return chapter;
    }

    private void addChunks(List<Map<String, Object>> chunks, String bookTitle, String chapterTitle, List<String> paragraphs) {
        for (String paragraph : paragraphs) {
            if (paragraph.length() < 18) {
                continue;
            }
            Map<String, Object> chunk = new LinkedHashMap<>();
            chunk.put("source", bookTitle + " · " + chapterTitle);
            chunk.put("text", paragraph.length() > 500 ? paragraph.substring(0, 500) : paragraph);
            chunks.add(chunk);
            if (chunks.size() >= 40) {
                return;
            }
        }
    }

    private List<TextSection> splitTextSections(String title, String text) {
        List<TextSection> sections = new ArrayList<>();
        Pattern headingPattern = Pattern.compile("(?m)^(#{1,6}\\s+.+|第[一二三四五六七八九十百千万0-9]+[章节回部].*)$");
        Matcher matcher = headingPattern.matcher(text);
        int currentStart = 0;
        String currentTitle = title;
        while (matcher.find()) {
            if (matcher.start() > currentStart) {
                String content = text.substring(currentStart, matcher.start()).trim();
                if (!content.isBlank()) {
                    sections.add(new TextSection(cleanHeading(currentTitle), content));
                }
            }
            currentTitle = matcher.group(1);
            currentStart = matcher.end();
        }
        String tail = text.substring(currentStart).trim();
        if (!tail.isBlank()) {
            sections.add(new TextSection(cleanHeading(currentTitle), tail));
        }
        if (sections.isEmpty()) {
            List<String> blocks = paragraphs(text);
            if (blocks.size() <= 1) {
                sections.add(new TextSection(title, text));
                return sections;
            }
            StringBuilder current = new StringBuilder();
            int chapterIndex = 1;
            for (String block : blocks) {
                if (current.length() > 0 && current.length() + block.length() > 2800) {
                    sections.add(new TextSection(cleanHeading(chapterLabel(title, chapterIndex++)), current.toString().trim()));
                    current.setLength(0);
                }
                if (current.length() > 0) {
                    current.append("\n\n");
                }
                current.append(block);
            }
            if (current.length() > 0) {
                sections.add(new TextSection(cleanHeading(chapterLabel(title, chapterIndex)), current.toString().trim()));
            }
        }
        return sections;
    }

    private List<TextSection> readableSections(List<TextSection> sections) {
        List<TextSection> filtered = new ArrayList<>();
        for (TextSection section : sections) {
            if (!isFrontMatterSection(section.title(), section.content())) {
                filtered.add(section);
            }
        }
        return filtered.isEmpty() ? sections : filtered;
    }

    private boolean isFrontMatterSection(String title, String content) {
        String cleanTitle = compact(title).toLowerCase(Locale.ROOT);
        String sample = compact((title == null ? "" : title) + "\n"
                + (content == null ? "" : content.substring(0, Math.min(content.length(), 2400)))).toLowerCase(Locale.ROOT);
        if (cleanTitle.matches("(cover|titlepage|contents|tableofcontents|copyright|toc|nav)")
                || cleanTitle.matches("(\u5c01\u9762|\u4e66\u540d\u9875|\u6249\u9875|\u76ee\u5f55|\u76ee\u9304|\u76ee\u6b21|\u7248\u6743|\u7248\u6743\u9875|\u7248\u6743\u4fe1\u606f|\u5236\u4f5c\u4fe1\u606f)")) {
            return true;
        }
        if (sample.startsWith("copyright") || sample.startsWith("\u7248\u6743") || sample.startsWith("\u51fa\u7248\u8bf4\u660e")) {
            return true;
        }
        if (sample.startsWith("contents") || sample.startsWith("tableofcontents")
                || sample.startsWith("\u76ee\u5f55") || sample.startsWith("\u76ee\u9304") || sample.startsWith("\u76ee\u6b21")) {
            return true;
        }
        return looksLikeCatalog(content);
    }

    private boolean looksLikeCatalog(String content) {
        if (content == null || content.isBlank()) {
            return false;
        }
        String[] lines = normalizeWhitespace(content).split("\\n");
        int catalogLines = 0;
        int readableLines = 0;
        Pattern chapterRef = Pattern.compile("^(?:\u7b2c[\u4e00-\u9fa5\\d]+[\u7ae0\u8282\u56de\u90e8\u5377\u7bc7]|chapter\\s*\\d+|\\d+[.、]\\s*).*$",
                Pattern.CASE_INSENSITIVE);
        for (String rawLine : lines) {
            String line = rawLine.trim();
            if (line.isBlank()) {
                continue;
            }
            readableLines++;
            if (line.length() <= 120 && (chapterRef.matcher(line).matches()
                    || line.matches(".*[.。·\\s]{2,}\\d{1,4}$"))) {
                catalogLines++;
            }
            if (readableLines >= 24) {
                break;
            }
        }
        return catalogLines >= 3 && catalogLines * 2 >= Math.max(1, readableLines);
    }

    private String compact(String value) {
        return value == null ? "" : value.replaceAll("[\\s\\p{Punct}\u3000-\u303f]+", "").trim();
    }

    private List<String> paragraphs(String content) {
        String[] parts = normalizeWhitespace(content).split("\\n\\s*\\n");
        List<String> paragraphs = new ArrayList<>();
        for (String part : parts) {
            String text = part.trim();
            if (!text.isBlank()) {
                paragraphs.add(text.length() > 1200 ? text.substring(0, 1200) : text);
            }
        }
        if (paragraphs.isEmpty() && !content.isBlank()) {
            paragraphs.add(content.substring(0, Math.min(content.length(), 1200)));
        }
        return paragraphs;
    }

    private Map<String, byte[]> unzip(byte[] bytes) {
        Map<String, byte[]> entries = new LinkedHashMap<>();
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(bytes))) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                if (!entry.isDirectory()) {
                    entries.put(entry.getName(), zip.readAllBytes());
                }
            }
        } catch (IOException exc) {
            throw SmartReadException.badRequest("EPUB 解压失败：" + exc.getMessage());
        }
        return entries;
    }

    private Map<String, ManifestItem> manifest(String opf) {
        Map<String, ManifestItem> items = new LinkedHashMap<>();
        Matcher matcher = Pattern.compile("<item\\s+([^>]+)>", Pattern.CASE_INSENSITIVE).matcher(opf);
        while (matcher.find()) {
            String attrs = matcher.group(1);
            String id = attr(attrs, "id");
            String href = attr(attrs, "href");
            String mediaType = attr(attrs, "media-type");
            if (!id.isBlank() && !href.isBlank()) {
                items.put(id, new ManifestItem(href, mediaType));
            }
        }
        return items;
    }

    private List<String> spine(String opf) {
        List<String> refs = new ArrayList<>();
        Matcher matcher = Pattern.compile("<itemref\\s+([^>]+)>", Pattern.CASE_INSENSITIVE).matcher(opf);
        while (matcher.find()) {
            String idref = attr(matcher.group(1), "idref");
            if (!idref.isBlank()) {
                refs.add(idref);
            }
        }
        return refs;
    }

    private String resolvePath(String opfPath, String href) {
        String base = "";
        int slash = opfPath.lastIndexOf('/');
        if (slash >= 0) {
            base = opfPath.substring(0, slash + 1);
        }
        return Path.of(base).resolve(href).normalize().toString().replace('\\', '/');
    }

    private String stripHtml(String html) {
        String text = html.replaceAll("(?is)<(script|style)[^>]*>.*?</\\1>", "")
                .replaceAll("(?i)</?(p|div|br|li|h[1-6]|section|article|tr)[^>]*>", "\n")
                .replaceAll("<[^>]+>", "")
                .replace("&nbsp;", " ")
                .replace("&amp;", "&")
                .replace("&lt;", "<")
                .replace("&gt;", ">")
                .replace("&quot;", "\"");
        return normalizeWhitespace(text);
    }

    private String heading(String html) {
        for (String tag : List.of("h1", "h2", "h3", "h4", "title")) {
            String text = firstText(html, tag);
            if (!text.isBlank()) {
                return text;
            }
        }
        return "";
    }

    private String firstText(String xml, String tag) {
        Matcher matcher = Pattern.compile("<(?:[^:>]+:)?" + tag + "\\b[^>]*>(.*?)</(?:[^:>]+:)?" + tag + ">",
                Pattern.CASE_INSENSITIVE | Pattern.DOTALL).matcher(xml);
        if (!matcher.find()) {
            return "";
        }
        return stripHtml(matcher.group(1)).trim();
    }

    private String firstTag(String xml, String tag) {
        Matcher matcher = Pattern.compile("<(?:[^:>]+:)?" + tag + "\\b([^>]*)/?>", Pattern.CASE_INSENSITIVE).matcher(xml);
        return matcher.find() ? matcher.group(1) : "";
    }

    private String attr(String attrs, String name) {
        Matcher matcher = Pattern.compile(name + "\\s*=\\s*['\"]([^'\"]+)['\"]", Pattern.CASE_INSENSITIVE).matcher(attrs);
        return matcher.find() ? matcher.group(1).trim() : "";
    }

    private String titleFromText(String fileName, String text) {
        for (String line : text.split("\\n")) {
            String clean = cleanHeading(line);
            if (!clean.isBlank() && clean.length() <= 80) {
                return clean;
            }
        }
        return baseTitle(fileName);
    }

    private String cleanHeading(String value) {
        return value == null ? "" : value.replaceFirst("^#{1,6}\\s*", "").trim();
    }

    private String chapterLabel(String title, int index) {
        if (index <= 1) {
            return title;
        }
        return title + " " + index;
    }

    private String summaryOf(String text) {
        String compact = text == null ? "" : text.replaceAll("\\s+", " ").trim();
        if (compact.length() <= 180) {
            return compact;
        }
        return compact.substring(0, 180);
    }

    private String normalizeWhitespace(String text) {
        return text == null ? "" : text.replace("\r\n", "\n")
                .replace('\r', '\n')
                .replaceAll("[\\t ]+", " ")
                .replaceAll("\\n{3,}", "\n\n")
                .trim();
    }

    private String defaultTags(String fileName, String kind) {
        return "本地导入," + kind + ",可读,AI伴读";
    }

    private String colorFor(String title) {
        String[] colors = {"#243044", "#2F3A2D", "#3A2B35", "#263748", "#3A3328", "#2B3542"};
        return colors[Math.abs(title.hashCode()) % colors.length];
    }

    private String extension(String fileName) {
        int dot = fileName.lastIndexOf('.');
        return dot < 0 ? "" : fileName.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private String baseTitle(String fileName) {
        int slash = Math.max(fileName.lastIndexOf('/'), fileName.lastIndexOf('\\'));
        String name = slash >= 0 ? fileName.substring(slash + 1) : fileName;
        int dot = name.lastIndexOf('.');
        return dot > 0 ? name.substring(0, dot) : name;
    }

    private String decode(byte[] bytes) {
        return bytes == null ? "" : new String(bytes, StandardCharsets.UTF_8);
    }

    private String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder builder = new StringBuilder();
            for (byte b : hash) {
                builder.append(String.format("%02x", b));
            }
            return builder.toString();
        } catch (NoSuchAlgorithmException exc) {
            throw new IllegalStateException(exc);
        }
    }

    private static String textAny(Map<String, Object> payload, String... keys) {
        for (String key : keys) {
            Object value = payload.get(key);
            if (value != null && !value.toString().isBlank()) {
                return value.toString().trim();
            }
        }
        return "";
    }

    private static String string(Object value) {
        return value == null ? "" : value.toString();
    }

    record ParsedBook(String title, String author, String tags, String summary, String coverColor,
                      List<Map<String, Object>> chapters, List<Map<String, Object>> chunks) {
    }

    record TextSection(String title, String content) {
    }

    record ManifestItem(String href, String mediaType) {
    }
}
