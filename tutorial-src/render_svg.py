# Runs inside the diagrams container: renders Mermaid sources (/in/*.mmd) to SVG (/out/*.svg) with headless Chromium.
import glob, html, json, os, re, subprocess
os.makedirs("/tmp/w", exist_ok=True)
srcs = sorted(glob.glob("/in/*.mmd"))
areas = "".join('<textarea class="src" data-id="%s">%s</textarea>' % (os.path.basename(p)[:-4], html.escape(open(p).read())) for p in srcs)
page = """<!DOCTYPE html><html><head><meta charset="utf-8"><script src="file:///opt/mermaid/mermaid.min.js"></script></head>
<body>%s<textarea id="out"></textarea><script>
(async function () {
  var out = document.getElementById("out"), res = {};
  mermaid.initialize({ startOnLoad: false, securityLevel: "strict", deterministicIds: true, theme: "default", flowchart: { htmlLabels: false } });
  for (const t of document.querySelectorAll("textarea.src")) {
    try { res[t.dataset.id] = (await mermaid.render("d-" + t.dataset.id, t.value)).svg; }
    catch (e) { res[t.dataset.id] = "ERROR:" + (e.message || e); }
  }
  out.textContent = JSON.stringify(res);
})();
</script></body></html>""" % areas
open("/tmp/w/page.html", "w").write(page)
dom = subprocess.run(["chromium-browser", "--headless", "--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage",
    "--user-data-dir=/tmp/w/c", "--virtual-time-budget=30000", "--dump-dom", "file:///tmp/w/page.html"],
    capture_output=True, text=True, timeout=180).stdout
m = re.search(r'<textarea id="out">(.*?)</textarea>', dom, re.S)
res = json.loads(html.unescape(m.group(1)))
for k, v in res.items():
    if v.startswith("ERROR:"): print(k, v)
    else: open("/out/%s.svg" % k, "w").write(v); print(k, len(v))
