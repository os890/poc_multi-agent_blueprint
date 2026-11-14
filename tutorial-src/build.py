"""Builds multi-agent-workflow-tutorial.html: template + inline SVG diagrams + open points from open-points.md."""
import html
import re
import sys

template, svg_dir, open_points_md, out = sys.argv[1:5]


def svg(name):
    s = open(f"{svg_dir}/{name}.svg", encoding="utf-8").read()
    s = re.sub(r"^<\?xml[^>]*>\s*", "", s)
    return s


def inline(text):
    t = html.escape(text, quote=False)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![*\w])\*([^*\s][^*]*?)\*(?![*\w])", r"<em>\1</em>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', t)
    return t


def open_points(md):
    out, item, in_list = [], None, False

    def flush():
        nonlocal item
        if item:
            num, text = item
            out.append(f'<li value="{num}" id="open-{num}">{inline(text)}</li>')
            item = None

    for line in md.splitlines():
        if line.startswith("# "):
            continue
        m_h = re.match(r"^## (.+)$", line)
        m_i = re.match(r"^(\d+)\. (.+)$", line)
        if m_h:
            flush()
            if in_list:
                out.append("</ol>")
                in_list = False
            out.append(f"<h3>{inline(m_h.group(1))}</h3>")
        elif m_i:
            flush()
            if not in_list:
                out.append("<ol>")
                in_list = True
            item = [m_i.group(1), m_i.group(2)]
        elif item and line.startswith("  ") and line.strip():
            item[1] += " " + line.strip()
        elif line.strip() and not item and not in_list:
            out.append(f"<p>{inline(line.strip())}</p>")
    flush()
    if in_list:
        out.append("</ol>")
    return "\n".join(out)


page = open(template, encoding="utf-8").read()
md = open(open_points_md, encoding="utf-8").read()
# the intro paragraph of open-points.md refers to the Markdown docs; the tutorial has its own intro
md = re.sub(r"^Open decisions.*?\n\n", "", md, flags=re.S | re.M)
page = (page.replace("{{SVG_WORKFLOW}}", svg("workflow"))
            .replace("{{SVG_BRANCHES}}", svg("branches"))
            .replace("{{SVG_AGENTS}}", svg("agents"))
            .replace("{{OPEN_POINTS}}", open_points(md)))
page = re.sub(r'<span class="tag open">OPEN #(\d+)</span>', r'<a class="tag open" href="#open-\1">OPEN #\1</a>', page)
assert "{{" not in page
open(out, "w", encoding="utf-8").write(page)
print("items:", page.count('<li value="'), "bytes:", len(page.encode()))
