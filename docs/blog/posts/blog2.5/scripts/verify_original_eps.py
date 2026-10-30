from pathlib import Path
import re
from pypdf import PdfReader
post = Path(__file__).resolve().parents[1]
pdf = post / 'data/private/full_html/ALLY_2023_original.pdf'
if not pdf.exists():
    raise SystemExit('Optional private original not supplied. Analysis reproduces from the sourced EPS ledger.')
text = PdfReader(pdf).pages[2].extract_text()
m = re.search(r'net income attributable to common shareholders\)\s*\$\s*([\d.]+)', text)
assert m and float(m.group(1)) == 2.98
print('Original Ally FY2023 GAAP diluted EPS: 2.98, PDF page 3')
