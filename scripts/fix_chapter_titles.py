#!/usr/bin/env python3
"""Fix chapter titles for Capital (book 51) by extracting real headings from content."""
import subprocess, re, json

MYSQL = ['docker', 'exec', '-i', 'hongmeng-mysql', 'mysql', '-u', 'root', '-proot',
         'hongmeng_zhiyue', '--default-character-set=utf8mb4']

def mysql_exec(sql: str) -> str:
    proc = subprocess.run(MYSQL, input=sql.encode('utf-8'), capture_output=True, timeout=15)
    return proc.stdout.decode('utf-8', errors='replace')

def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace("'", "\\'")

def extract_heading(content: str) -> str:
    """Extract real chapter heading from content body."""
    if not content:
        return ""
    # Remove the book title prefix pattern
    text = content
    # Remove leading "资本论(1-3)(套装共3册)" and whitespace
    text = re.sub(r'^资本论\(1-3\)\(套装共3册\)[\s\\n]*', '', text)
    # Remove leading blank lines
    text = re.sub(r'^[\s\\n]+', '', text)

    # Get first non-empty, meaningful line
    lines = [l.strip() for l in text.split('\n') if l.strip() and len(l.strip()) > 2]
    if not lines:
        return ""

    first = lines[0]
    # If it's an English name or very short preface, combine with second line if available
    if first.startswith('(1)') and len(lines) > 1:
        first = lines[1]

    # Limit to 160 chars (DB constraint)
    return first[:160]

# Get all chapters
proc = subprocess.run(MYSQL, input='SELECT id, chapter_id, title, content FROM book_chapter WHERE book_id=51 ORDER BY chapter_order ASC;'.encode('utf-8'),
                      capture_output=True, timeout=30)
output = proc.stdout.decode('utf-8')

lines = output.strip().split('\n')
print(f'Processing {len(lines) - 1} chapters...')

updated = 0
for line in lines[1:]:
    parts = line.split('\t', 3)
    if len(parts) < 4:
        continue
    db_id = parts[0]
    old_title = parts[2]
    content = parts[3]

    new_title = extract_heading(content)
    if new_title and new_title != old_title and len(new_title) >= 2:
        sql = f"UPDATE book_chapter SET title = '{escape(new_title)}' WHERE id = {db_id};"
        mysql_exec(sql)
        updated += 1
        if updated <= 20:
            print(f"  {parts[1]}: '{old_title[:40]}' -> '{new_title[:60]}'")

print(f"Updated {updated} chapter titles")

# Show final result
proc = subprocess.run(MYSQL, input='SELECT chapter_id, title FROM book_chapter WHERE book_id=51 ORDER BY chapter_order LIMIT 20;'.encode('utf-8'),
                      capture_output=True, timeout=10)
print("\nFinal chapter list (first 20):")
for line in proc.stdout.decode('utf-8').strip().split('\n')[1:]:
    print(f"  {line}")
