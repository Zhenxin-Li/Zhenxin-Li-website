"""Extract the eleven leading rows; map quoted listed parents, excluding TD's unlisted US subsidiary."""
from pathlib import Path
import argparse,csv,re
from pypdf import PdfReader
parser=argparse.ArgumentParser()
parser.add_argument('--pdf',default='data/private/full_html/NYFed_2023Q4.pdf')
parser.add_argument('--out',default='data/raw/nyfed_universe.csv')
args=parser.parse_args()
text=PdfReader(args.pdf).pages[37].extract_text()
assert '2023Q4' in text
mapping={1:'JPM',2:'BAC',3:'C',4:'WFC',5:'GS',6:'MS',7:'USB',8:'PNC',9:'TFC',10:'',11:'COF'}
url='https://www.newyorkfed.org/medialibrary/media/research/banking_research/QuarterlyTrends2023Q4.pdf?hash=085DF7EB1CAEE14D2FCC011A20B37FD7&sc_lang=en'
rows=[]
for line in text.splitlines():
 m=re.match(r'^(\d+) (.+?) (\d+\.\d+)\s',line.strip())
 if not m or int(m[1]) not in mapping:continue
 rank=int(m[1]);ticker=mapping[rank]
 rows.append(dict(source_rank=rank,source_name=m[2],ticker=ticker,assets_bn=float(m[3]),us_listed_parent=bool(ticker),source_url=url))
assert [r['source_rank'] for r in rows]==list(range(1,12))
assert sum(r['us_listed_parent'] for r in rows)==10
target=Path(args.out);target.parent.mkdir(parents=True,exist_ok=True)
with target.open('w',newline='',encoding='utf8') as f:
 writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
print('Extracted 11 ranked entities; 10 directly listed U.S. parents.')
