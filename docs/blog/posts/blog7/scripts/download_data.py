"""Explicit refresh of the public World Bank snapshot; ordinary builds are offline."""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
URL = ('https://api.worldbank.org/v2/country/CAN;FRA;DEU;ITA;JPN;GBR;USA/'
       'indicator/SP.DYN.LE00.IN?date=2015:2023&format=json&per_page=1000')


def validate(payload):
    obj = json.loads(payload)
    assert isinstance(obj, list) and len(obj) == 2, 'Unexpected API response'
    assert obj[0]['pages'] == 1 and obj[0]['total'] == 63, 'Incomplete response'
    records = obj[1]
    keys = {(r['countryiso3code'], int(r['date'])) for r in records}
    expected = {(c, y) for c in ['CAN', 'FRA', 'DEU', 'ITA', 'JPN', 'GBR', 'USA']
                for y in range(2015, 2024)}
    assert keys == expected and len(records) == len(keys), 'Missing/duplicate records'
    assert all(r['indicator']['id'] == 'SP.DYN.LE00.IN' and
               isinstance(r['value'], (float, int)) and 50 < r['value'] < 100
               for r in records), 'Invalid indicator or values'
    return obj


def save_manifest(payload):
    obj = validate(payload)
    manifest = {
        'url': URL, 'retrieved_utc': datetime.now(timezone.utc).isoformat(),
        'api_last_updated': obj[0]['lastupdated'], 'sha256': hashlib.sha256(payload).hexdigest(),
        'indicator': 'SP.DYN.LE00.IN', 'source': 'World Development Indicators, source 2',
        'records': len(obj[1]), 'analysis_years': [2019, 2020, 2021, 2022, 2023],
        'metadata_url': 'https://databank.worldbank.org/metadataglossary/health-nutrition-and-population-statistics/series/SP.DYN.LE00.IN',
        'note': 'Public API response retained verbatim. No imputation or interpolation.'
    }
    (ROOT / 'data/raw/manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh', action='store_true', help='Download and replace the snapshot explicitly')
    args = parser.parse_args()
    path = ROOT / 'data/raw/wdi_life_expectancy.json'
    if not args.refresh:
        validate(path.read_bytes())
        print('Saved snapshot validated; use --refresh to download a new vintage.')
    else:
        request = Request(URL, headers={'User-Agent': 'Blog7 reproducible coursework analysis'})
        with urlopen(request, timeout=60) as response:
            payload = response.read()
        validate(payload)  # Never replace a good snapshot with an error page.
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
        save_manifest(payload)
        print('Downloaded and validated 63 official observations.')
