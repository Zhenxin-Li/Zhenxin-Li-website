"""Validate saved Census data; public downloads occur only with --refresh."""

import argparse, csv, hashlib, io, json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://www2.census.gov/programs-surveys/acs/summary_file/"
SOURCES = {
    "acsdt1y2019-b25070.dat": BASE + "2019/prototype/1YRData/acsdt1y2019-b25070.dat",
    "acsdt1y2024-b25070.dat": BASE + "2024/table-based-SF/data/1YRData/acsdt1y2024-b25070.dat",
    "geos2019_1yr.csv": BASE + "2019/prototype/Geos20191YR.csv",
    "acs2019_table_shells.csv": BASE + "2019/prototype/ACS2019_Table_Shells.csv",
    "acs2024_table_shells.xlsx": BASE
    + "2024/table-based-SF/documentation/ACS2024_Table_Shells.xlsx",
    "b25070_2019_metadata.json": "https://api.census.gov/data/2019/acs/acs1/groups/B25070.json",
}


def validate_payload(name, data):
    if name.endswith(".dat"):
        rows = list(csv.DictReader(io.StringIO(data.decode("utf-8-sig")), delimiter="|"))
        assert rows and {"GEO_ID", "B25070_E001", "B25070_E011", "B25070_M010"} <= rows[0].keys()
        states = [r for r in rows if r["GEO_ID"].startswith("0400000US") and len(r["GEO_ID"]) == 11]
        assert len(states) == len({r["GEO_ID"] for r in states}) == 52
    elif name.endswith(".xlsx"):
        assert data.startswith(b"PK")
    elif name.endswith(".json"):
        assert "B25070_007E" in json.loads(data)["variables"]
    elif name.startswith("geos"):
        assert data.startswith(b"FILEID,STUSAB,SUMLEVEL")
    else:
        assert data.startswith(b"Table ID,Line,UniqueID,Stub")


def record_manifest():
    files = []
    for name, url in SOURCES.items():
        data = (ROOT / "data/raw" / name).read_bytes()
        validate_payload(name, data)
        files.append(
            dict(file=name, url=url, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        )
    m = dict(
        recorded_utc=datetime.now(timezone.utc).isoformat(),
        source="Census ACS 1-year B25070",
        years=[2019, 2024],
        files=files,
        note="Public bulk files saved verbatim. The 2019 prototype folder denotes table-based packaging, not experimental estimates.",
    )
    (ROOT / "data/raw/manifest.json").write_text(json.dumps(m, indent=2) + "\n", encoding="utf-8")


def validate_saved():
    m = json.loads((ROOT / "data/raw/manifest.json").read_text(encoding="utf-8"))
    assert {r["file"] for r in m["files"]} == set(SOURCES)
    for r in m["files"]:
        data = (ROOT / "data/raw" / r["file"]).read_bytes()
        assert hashlib.sha256(data).hexdigest() == r["sha256"], r["file"] + ": checksum mismatch"
        validate_payload(r["file"], data)
    return m


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--refresh", action="store_true")
    a = p.parse_args()
    if a.refresh:
        payloads = {}
        for name, url in SOURCES.items():
            with urlopen(url, timeout=60) as r:
                data = r.read()
            validate_payload(name, data)
            payloads[name] = data
        for name, data in payloads.items():
            (ROOT / "data/raw" / name).write_bytes(data)
        record_manifest()
        print("Official files refreshed and validated.")
    else:
        validate_saved()
        print("Saved snapshots validated; no network requests.")
