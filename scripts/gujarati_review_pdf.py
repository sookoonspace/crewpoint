#!/usr/bin/env python3
"""Builds docs/i18n/gujarati-review.pdf, a printable sheet for a native
speaker to review every Gujarati spelling and string (Spec #233 Req 59b).

Reads docs/i18n/gujarati_terms.json, lib/l10n/app_en.arb / app_gu.arb and
functions/src/mail/templates/en.json / gu.json, so rerun it after any change:

    python3 scripts/gujarati_review_pdf.py

Chrome renders the page, because it shapes Gujarati conjuncts correctly with
the app's own Noto Sans Gujarati font.
"""

import datetime
import html
import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/i18n/gujarati-review.pdf"
FONTS = ROOT / "assets/fonts/gujarati"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

PLACEHOLDERS = {
    "{{name}}": "the person's name",
    "{{word.group.one.lower}}": "the event's own word for a group, such as "
    "“group” or “household”, chosen by the organizer",
}


EMAIL_TITLES = {"deliveryCheck": "Test email (checks that email arrives)"}


def load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def esc(text: str) -> str:
    return html.escape(text).replace("\n", "<br>")


def review_cells() -> str:
    return '<td class="box"></td><td class="fix"></td>'


def terms_section() -> tuple[str, int]:
    terms = load("docs/i18n/gujarati_terms.json")["terms"]
    groups: dict[str, list] = {}
    for t in terms:
        groups.setdefault(t["group"], []).append(t)
    out, n = [], 0
    for group, rows in groups.items():
        out.append(f"<h3>{esc(group)}</h3>")
        out.append(
            "<table><thead><tr><th class='n'>#</th><th>English</th>"
            "<th>Gujarati</th><th>Known wrong spelling</th>"
            "<th class='box'>OK</th><th class='fix'>Correction / note</th>"
            "</tr></thead><tbody>"
        )
        for t in rows:
            n += 1
            wrong = ", ".join(t["wrong"]) or "—"
            out.append(
                f"<tr><td class='n'>{n}</td><td>{esc(t['en'])}</td>"
                f"<td class='gu'>{esc(t['gu'])}</td>"
                f"<td class='gu wrong'>{esc(wrong)}</td>{review_cells()}</tr>"
            )
        out.append("</tbody></table>")
    return "\n".join(out), n


def strings_section(start: int) -> tuple[str, int]:
    en, gu = load("lib/l10n/app_en.arb"), load("lib/l10n/app_gu.arb")
    rows, n = [], start
    for key, value in gu.items():
        if key.startswith("@"):
            continue
        n += 1
        rows.append(
            f"<tr><td class='n'>{n}</td><td>{esc(en.get(key, ''))}</td>"
            f"<td class='gu'>{esc(value)}</td>{review_cells()}</tr>"
        )
    table = (
        "<table><thead><tr><th class='n'>#</th><th>English</th>"
        "<th>Gujarati</th><th class='box'>OK</th>"
        "<th class='fix'>Correction / note</th></tr></thead><tbody>"
        + "".join(rows)
        + "</tbody></table>"
    )
    return table, n


def emails_section(start: int) -> tuple[str, int]:
    en = load("functions/src/mail/templates/en.json")
    gu = load("functions/src/mail/templates/gu.json")
    parts = {"subject": "Subject", "text": "Message", "push": "Phone notification"}
    out, n = [], start
    for name, message in gu.items():
        title = EMAIL_TITLES.get(name, name)
        out.append(f"<h3>Email: {esc(title)}</h3>")
        out.append(
            "<table><thead><tr><th class='n'>#</th><th class='part'>Part</th>"
            "<th>English</th><th>Gujarati</th><th class='box'>OK</th>"
            "<th class='fix'>Correction / note</th></tr></thead><tbody>"
        )
        for part, label in parts.items():
            if part not in message:
                continue
            n += 1
            out.append(
                f"<tr><td class='n'>{n}</td><td class='part'>{label}</td>"
                f"<td>{esc(en[name].get(part, ''))}</td>"
                f"<td class='gu'>{esc(message[part])}</td>{review_cells()}</tr>"
            )
        out.append("</tbody></table>")
    return "\n".join(out), n


def page() -> str:
    terms, n = terms_section()
    strings, n2 = strings_section(n)
    emails, n3 = emails_section(n2)
    placeholders = "".join(
        f"<li><code>{esc(k)}</code>: {esc(v)}</li>" for k, v in PLACEHOLDERS.items()
    )
    today = datetime.date.today().strftime("%-d %B %Y")
    regular = (FONTS / "NotoSansGujarati-Regular.ttf").as_uri()
    bold = (FONTS / "NotoSansGujarati-Bold.ttf").as_uri()
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>CrewPoint Gujarati review</title>
<style>
@font-face {{ font-family: Guj; src: url('{regular}'); font-weight: 400; }}
@font-face {{ font-family: Guj; src: url('{bold}'); font-weight: 700; }}
@page {{ size: A4; margin: 16mm 14mm 18mm; }}
body {{ font-family: -apple-system, 'Helvetica Neue', Arial, Guj, sans-serif;
  font-size: 10.5pt; color: #1b1b1f; line-height: 1.45; }}
h1 {{ font-size: 20pt; margin: 0 0 2pt; }}
h2 {{ font-size: 14pt; margin: 18pt 0 4pt; border-bottom: 1.5pt solid #1b1b1f;
  padding-bottom: 2pt; break-after: avoid; }}
h3 {{ font-size: 11pt; margin: 12pt 0 4pt; break-after: avoid; }}
.meta {{ color: #555; margin-bottom: 10pt; }}
.intro {{ background: #f3f3f6; padding: 8pt 10pt; border-radius: 4pt; }}
.intro p {{ margin: 0 0 5pt; }} .intro ul {{ margin: 0 0 5pt 14pt; padding: 0; }}
table {{ width: 100%; border-collapse: collapse; margin-bottom: 6pt; }}
thead {{ display: table-header-group; }}
tr {{ break-inside: avoid; }}
th, td {{ border: 0.6pt solid #9a9aa3; padding: 4pt 5pt; vertical-align: top;
  text-align: left; }}
th {{ background: #e6e6ec; font-size: 9pt; }}
td.gu {{ font-family: Guj, sans-serif; font-size: 13pt; line-height: 1.6; }}
td.wrong {{ color: #8a1c1c; font-size: 11pt; }}
.n {{ width: 18pt; color: #666; font-size: 9pt; }}
.part {{ width: 58pt; }}
.box {{ width: 24pt; }} .fix {{ width: 30%; }}
.sign {{ margin-top: 22pt; }} .sign td {{ border: none; padding: 14pt 6pt 2pt 0; }}
.line {{ border-bottom: 0.6pt solid #1b1b1f !important; width: 40%; }}
code {{ font-size: 9pt; background: #e6e6ec; padding: 0 2pt; border-radius: 2pt; }}
</style></head><body>
<h1>CrewPoint: Gujarati review</h1>
<div class="meta">{n3} items · generated {today} from the app's own files</div>
<div class="intro">
<p><b>Thank you for reviewing.</b> CrewPoint is an event app. Everything below
appears in Gujarati on its screens and in its emails. Please check each line
for spelling, the natural everyday word, and grammar.</p>
<ul>
<li>Tick <b>OK</b> if the Gujarati is right as written.</li>
<li>Otherwise write the correct spelling, or a note, under
<b>Correction / note</b>.</li>
<li>Part 1 is the list of key words; every screen must use these spellings.
The “Known wrong spelling” column shows spellings the app must never use;
please add any other common misspellings you know.</li>
<li>Days and months must match how Gujarati speakers write dates.</li>
</ul>
<p>Some messages contain placeholders in curly brackets, which the app fills
in. They stay as they are, but please check the words around them still read
correctly once filled in:</p>
<ul>{placeholders}</ul>
</div>

<h2>Part 1: Key words ({n})</h2>
{terms}

<h2>Part 2: Screen text ({n2 - n})</h2>
{strings}

<h2>Part 3: Emails ({n3 - n2})</h2>
{emails}

<table class="sign"><tr><td>Reviewed by</td><td class="line"></td>
<td>Date</td><td class="line"></td></tr></table>
</body></html>"""


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        src = pathlib.Path(tmp) / "review.html"
        src.write_text(page(), encoding="utf-8")
        subprocess.run(
            [
                CHROME,
                "--headless",
                "--disable-gpu",
                "--no-pdf-header-footer",
                "--allow-file-access-from-files",
                f"--print-to-pdf={OUT}",
                src.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
    print(f"Wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
