#!/usr/bin/env python3
"""Import local EPUB files into hongmeng_zhiyue database for HarmonyOS reader."""
import zipfile, xml.etree.ElementTree as ET, json, subprocess, os, re, pathlib, html as html_mod, sys

MYSQL_BIN = r"E:\FlyEnv-Data\app\mysql-5.7.44\mysql-5.7.44-winx64\bin\mysql.exe"
MYSQL = ["docker", "exec", "-i", "hongmeng-mysql", "mysql", "-u", "root", "-proot", "hongmeng_zhiyue"]
DB_OPTS = "--default-character-set=utf8mb4"

def mysql_exec(sql: str) -> str:
    """Execute SQL and return output. All SQL goes through stdin."""
    proc = subprocess.run(
        MYSQL + ["--default-character-set=utf8mb4"],
        input=sql.encode("utf-8"),
        capture_output=True,
        timeout=30,
    )
    if proc.returncode != 0 and "Duplicate" not in proc.stderr.decode("utf-8", errors="replace"):
        print(f"SQL ERROR: {proc.stderr.decode('utf-8', errors='replace')[:500]}")
    return proc.stdout.decode("utf-8", errors="replace")


def escape_sql(text: str) -> str:
    """Escape string for MySQL INSERT values."""
    if text is None:
        return "NULL"
    text = text.replace("\\", "\\\\")
    text = text.replace("'", "\\'")
    text = text.replace("\x00", "")
    return f"'{text}'"


def parse_epub(filepath: str):
    """Parse EPUB and return (metadata, list_of_chapters).
    Each chapter: {title, content, plain_text, paragraphs}"""
    zf = zipfile.ZipFile(filepath, "r")

    # Read OPF for metadata and spine
    container = ET.fromstring(zf.read("META-INF/container.xml"))
    ns = {"c": "urn:oasis:names:tc:opendocument:xmlns:container"}
    rootfile = container.find(".//c:rootfile", ns)
    opf_path = rootfile.get("full-path")
    opf_xml = zf.read(opf_path).decode("utf-8", errors="replace")

    # Parse OPF - register namespaces
    opf_ns = {
        "opf": "http://www.idpf.org/2007/opf",
        "dc": "http://purl.org/dc/elements/1.1/",
    }
    opf = ET.fromstring(opf_xml)

    # Extract metadata
    title = author = publisher = language = ""
    for el in opf.findall(".//{http://purl.org/dc/elements/1.1/}title"):
        title = (el.text or "").strip()
    if not title:
        # fallback: try without namespace prefix
        for el in opf.iter():
            if el.tag.endswith("}title") or el.tag == "title":
                title = (el.text or "").strip()
                if title:
                    break
    for el in opf.findall(".//{http://purl.org/dc/elements/1.1/}creator"):
        author = (el.text or "").strip()
        if author:
            break
    for el in opf.findall(".//{http://purl.org/dc/elements/1.1/}publisher"):
        publisher = (el.text or "").strip()
    for el in opf.findall(".//{http://purl.org/dc/elements/1.1/}language"):
        language = (el.text or "").strip()

    if not title:
        title = os.path.splitext(os.path.basename(filepath))[0]
    if not author:
        author = "佚名"

    # Get spine (reading order)
    spine_items = []
    manifest = {}
    for item in opf.findall(".//{http://www.idpf.org/2007/opf}item"):
        item_id = item.get("id", "")
        href = item.get("href", "")
        media_type = item.get("media-type", "")
        manifest[item_id] = (href, media_type)

    spine = opf.find(".//{http://www.idpf.org/2007/opf}spine")
    if spine is not None:
        for itemref in spine.findall("{http://www.idpf.org/2007/opf}itemref"):
            idref = itemref.get("idref", "")
            if idref in manifest:
                href, mime = manifest[idref]
                if "xhtml" in mime or "html" in mime:
                    spine_items.append(href)

    # Resolve paths relative to OPF
    opf_dir = os.path.dirname(opf_path)
    if opf_dir:
        spine_items_full = [os.path.normpath(os.path.join(opf_dir, h)).replace("\\", "/") for h in spine_items]
    else:
        spine_items_full = spine_items

    # Extract chapters from spine items
    chapters = []
    chapter_idx = 0
    for href in spine_items_full:
        if href not in zf.namelist():
            continue
        chapter_idx += 1
        html_bytes = zf.read(href)
        # Try to decode; some EPUBs use different encodings
        html_text = ""
        for encoding in ["utf-8", "gbk", "gb2312", "gb18030"]:
            try:
                html_text = html_bytes.decode(encoding)
                break
            except UnicodeDecodeError:
                continue
        if not html_text:
            html_text = html_bytes.decode("utf-8", errors="replace")

        # Extract text from HTML
        text = strip_html(html_text)
        if not text or len(text) < 20:
            continue  # skip empty/trivial pages

        # Try to extract heading/title
        heading = extract_heading(html_text)
        if not heading:
            heading = f"第{chapter_idx}节"

        # Build paragraphs
        paragraphs = [p.strip() for p in text.split("\n") if p.strip() and len(p.strip()) > 5]
        if not paragraphs:
            paragraphs = [text[:500]]

        chapters.append({
            "chapter_id": f"ch-{chapter_idx}",
            "title": heading[:160],
            "order": chapter_idx,
            "summary": text[:200].replace("\n", " ")[:200],
            "content": text[:60000],
            "paragraphs": paragraphs[:200],
            "page_count": max(1, len(text) // 2000),
        })

    zf.close()
    return {
        "title": title,
        "author": author,
        "publisher": publisher,
        "language": language,
        "source_type": "local_epub",
        "source_note": f"从本地 EPUB 导入: {os.path.basename(filepath)}",
        "file_name": os.path.basename(filepath),
        "chapters": chapters,
    }


def strip_html(html_text: str) -> str:
    """Extract plain text from HTML, preserving paragraph breaks."""
    # Remove scripts and styles
    text = re.sub(r'<(script|style)[^>]*>.*?</\1>', '', html_text, flags=re.DOTALL | re.IGNORECASE)
    # Replace block-level tags with newlines
    text = re.sub(r'</?(p|div|h[1-6]|br|li|tr|section|article)[^>]*>', '\n', text, flags=re.IGNORECASE)
    # Remove all remaining tags
    text = re.sub(r'<[^>]+>', '', text)
    # Decode HTML entities
    text = html_mod.unescape(text)
    # Normalize whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]+', ' ', text)
    return text.strip()


def extract_heading(html_text: str) -> str:
    """Try to find a heading/title from HTML."""
    for tag in ["h1", "h2", "h3", "h4"]:
        m = re.search(f'<{tag}[^>]*>(.+?)</{tag}>', html_text, re.IGNORECASE)
        if m:
            return html_mod.unescape(re.sub(r'<[^>]+>', '', m.group(1))).strip()
    # Try title tag
    m = re.search(r'<title>(.+?)</title>', html_text, re.IGNORECASE)
    if m:
        return html_mod.unescape(re.sub(r'<[^>]+>', '', m.group(1))).strip()
    return ""


def import_to_db(book_data: dict):
    """Insert book + chapters + import_record into MySQL."""
    title = escape_sql(book_data["title"])
    author = escape_sql(book_data["author"])
    source_type = escape_sql(book_data["source_type"])
    source_note = escape_sql(book_data["source_note"])
    file_name = escape_sql(book_data["file_name"])

    # Generate unique ISBN-like identifier
    import hashlib
    isbn = "epub-" + hashlib.md5(book_data["title"].encode()).hexdigest()[:20]

    # Tags from title analysis
    tags = "经济学,政治经济学,马克思主义,经典著作"

    # Summary - take first chapter text or generate
    summary = escape_sql(book_data["chapters"][0]["summary"][:500] if book_data["chapters"] else "经典经济学著作")
    difficulty = "进阶"
    target_reader = "经济学研究者,社会科学爱好者"

    # 1. INSERT book
    sql = f"""INSERT INTO book (isbn, title, author, tags, summary, difficulty, target_reader,
        cover_color, source_type, readable, import_status, source_note)
    VALUES ({escape_sql(isbn)}, {title}, {author}, {escape_sql(tags)}, {summary},
        {escape_sql(difficulty)}, {escape_sql(target_reader)}, '#8B0000',
        {source_type}, 1, 'ready', {source_note})
    ON DUPLICATE KEY UPDATE
      title = VALUES(title),
      author = VALUES(author),
      source_type = VALUES(source_type),
      readable = 1,
      import_status = 'ready',
      source_note = VALUES(source_note);
    """
    mysql_exec(sql)

    # 2. Get book_id
    result = mysql_exec(f"SELECT id FROM book WHERE isbn = {escape_sql(isbn)};")
    book_id = None
    for line in result.strip().split("\n"):
        if line.strip() and line.strip() != "id":
            book_id = int(line.strip())
            break
    if not book_id:
        print("ERROR: Could not get book_id after INSERT")
        return None

    print(f"  Book ID: {book_id}, title: {book_data['title']}")

    # 3. INSERT chapters
    chapter_count = 0
    for ch in book_data["chapters"]:
        paragraphs_json = json.dumps(ch["paragraphs"], ensure_ascii=False)
        sql = f"""INSERT INTO book_chapter (book_id, chapter_id, title, chapter_order, summary, content, paragraphs_json, page_count)
        VALUES ({book_id}, {escape_sql(ch['chapter_id'])}, {escape_sql(ch['title'][:160])},
        {ch['order']}, {escape_sql(ch['summary'][:500])},
        {escape_sql(ch['content'][:60000])},
        CAST({escape_sql(paragraphs_json)} AS JSON),
        {ch['page_count']})
        ON DUPLICATE KEY UPDATE
          title = VALUES(title),
          content = VALUES(content),
          paragraphs_json = VALUES(paragraphs_json);
        """
        mysql_exec(sql)
        chapter_count += 1

    print(f"  Inserted {chapter_count} chapters")

    # 4. INSERT import record
    sql = f"""INSERT INTO book_import_record (book_id, source_type, file_name, status, message)
    VALUES ({book_id}, {source_type}, {file_name}, 'ready', 'EPUB 导入成功，{chapter_count} 章')
    ON DUPLICATE KEY UPDATE
      status = VALUES(status),
      message = VALUES(message);
    """
    mysql_exec(sql)

    # 5. Add some book_chunks for AI companion RAG
    for ch in book_data["chapters"][:5]:
        for i, p in enumerate(ch["paragraphs"][:3]):
            chunk_text = escape_sql(p[:500])
            sql = f"""INSERT IGNORE INTO book_chunk (book_id, source, chunk_text, chunk_index)
            VALUES ({book_id}, {escape_sql(f'{book_data["title"]}·{ch["title"]}')},
            {chunk_text}, {ch['order'] * 10 + i});
            """
            mysql_exec(sql)

    return book_id


def main():
    filepath = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\kong\Downloads\资本论(1-3)(套装共3册) (中共中央马克思恩格斯列宁斯大林著作编译局) (z-library.sk, 1lib.sk, z-lib.sk).epub"

    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        sys.exit(1)

    print(f"Parsing: {filepath}")
    book = parse_epub(filepath)
    print(f"  Title: {book['title']}")
    print(f"  Author: {book['author']}")
    print(f"  Chapters: {len(book['chapters'])}")

    print("Importing to database...")
    book_id = import_to_db(book)
    if book_id:
        print(f"\nDone! Book '{book['title']}' imported as ID #{book_id}")
        print("Frontend can now access it via search or direct URL.")


if __name__ == "__main__":
    main()
