#!/usr/bin/env python3
"""Clean up Capital chapter titles - remove newlines and trim to proper length."""
import subprocess, re

MYSQL = ["docker", "exec", "-i", "hongmeng-mysql", "mysql", "-u", "root", "-proot",
         "hongmeng_zhiyue", "--default-character-set=utf8mb4"]

def mysql_exec(sql):
    proc = subprocess.run(MYSQL, input=sql.encode("utf-8"), capture_output=True, timeout=15)
    return proc.stdout.decode("utf-8", errors="replace")

def escape(text):
    return text.replace("\\", "\\\\").replace("'", "\\'")

# 1. Fix titles with newlines
proc = subprocess.run(MYSQL,
    input="SELECT id, chapter_id, title FROM book_chapter WHERE book_id=51 AND title LIKE '%\\\\\\\\n%';".encode("utf-8"),
    capture_output=True, timeout=10)
output = proc.stdout.decode("utf-8")
lines = output.strip().split("\n")
print(f"Found {len(lines)-1} chapters with newlines in title")

for line in lines[1:]:
    parts = line.split("\t", 2)
    if len(parts) < 3:
        continue
    db_id = parts[0]
    title = parts[2]
    first_line = title.split("\\n")[0].strip()
    first_line = re.sub(r'^资本论.*?册\)\s*', '', first_line).strip()
    first_line = ' '.join(first_line.split())[:80]
    if first_line:
        sql = f"UPDATE book_chapter SET title = '{escape(first_line)}' WHERE id = {db_id};"
        mysql_exec(sql)

# 2. Fix summaries - use first 200 chars of content
mysql_exec("UPDATE book_chapter SET summary = LEFT(content, 200) WHERE book_id=51;")

# 3. Show result
proc = subprocess.run(MYSQL,
    input="SELECT chapter_id, title, LEFT(summary,50) FROM book_chapter WHERE book_id=51 ORDER BY chapter_order LIMIT 30;".encode("utf-8"),
    capture_output=True, timeout=10)
print("\nCleaned chapters:")
for line in proc.stdout.decode("utf-8").strip().split("\n")[1:]:
    print(f"  {line[:130]}")

# Count total
proc = subprocess.run(MYSQL,
    input="SELECT COUNT(*) FROM book_chapter WHERE book_id=51;".encode("utf-8"),
    capture_output=True, timeout=5)
count = proc.stdout.decode("utf-8").strip().split("\n")[1]
print(f"\nTotal chapters: {count}")
