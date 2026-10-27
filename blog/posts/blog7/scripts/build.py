"""Offline state rent-burden analysis, approximate ACS MOEs, and Plotly chart."""

import csv, json, math, platform, zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
import plotly
import plotly.graph_objects as go
from download_data import ROOT, validate_saved

GROUPS = {
    "Northeast": "CT ME MA NH RI VT NJ NY PA".split(),
    "Midwest": "IN IL MI OH WI IA KS MN MO NE ND SD".split(),
    "South": "DE FL GA MD NC SC VA WV AL KY MS TN AR LA OK TX".split(),
    "West": "AZ CO ID MT NV NM UT WY AK CA HI OR WA".split(),
}
COLORS = ["#0072B2", "#009E73", "#D55E00", "#7B3294"]
SYMBOLS = ["circle", "diamond", "square", "triangle-up"]


def write_csv(path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def definitions():
    raw = ROOT / "data/raw"
    with (raw / "acs2019_table_shells.csv").open(encoding="latin-1", newline="") as f:
        old = [r for r in csv.DictReader(f) if r["Table ID"] == "B25070"]
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    new = []
    with zipfile.ZipFile(raw / "acs2024_table_shells.xlsx") as z:
        strings = [
            "".join(t.text or "" for t in item.findall(".//m:t", ns))
            for item in ET.fromstring(z.read("xl/sharedStrings.xml"))
        ]
        for row in ET.fromstring(z.read("xl/worksheets/sheet1.xml")).findall(".//m:row", ns):
            cells = {}
            for c in row.findall("m:c", ns):
                v = c.find("m:v", ns)
                text = (v.text or "") if v is not None else ""
                cells["".join(t for t in c.attrib["r"] if t.isalpha())] = (
                    strings[int(text)] if c.get("t") == "s" and text else text
                )
            if cells.get("A") == "B25070":
                new.append(dict(line=cells.get("B", ""), label=cells.get("D", "")))
    a = {r["Line"].strip(): r["Stub"].strip().lower() for r in old if r["Line"].strip().isdigit()}
    b = {r["line"]: r["label"].strip().lower() for r in new if r["line"].isdigit()}
    assert a == b and len(b) == 11, "Categories changed"
    universe = "universe:  renter-occupied housing units"
    assert any(r["Stub"].strip().lower() == universe for r in old)
    assert any(r["label"].strip().lower() == universe for r in new)
    write_csv(
        ROOT / "results/variable_definitions.csv",
        [dict(cell=f"B25070_{i:03d}", label=b[str(i)]) for i in range(1, 12)],
    )


def derive(row):
    e = {i: int(row[f"B25070_E{i:03d}"]) for i in range(1, 12)}
    m = {i: int(row[f"B25070_M{i:03d}"]) for i in range(1, 12)}
    assert all(v >= 0 for v in list(e.values()) + list(m.values())), "Missing/sentinel state count"
    assert e[1] == sum(e[i] for i in range(2, 12)), "Categories do not sum to total"
    num = sum(e[i] for i in range(7, 11))
    den = e[1] - e[11]
    assert 0 < num < den
    p = num / den
    mn = math.sqrt(sum(m[i] ** 2 for i in range(7, 11)))
    md = math.hypot(m[1], m[11])
    rad = mn**2 - p**2 * md**2
    fallback = rad < 0
    if fallback:
        rad = mn**2 + p**2 * md**2
    return dict(
        total=e[1],
        excluded=e[11],
        eligible=den,
        burdened=num,
        share=100 * p,
        moe90_pp=100 * math.sqrt(rad) / den,
        ratio_fallback=fallback,
    )


def chart(rows):
    fig = go.Figure()
    for region, color, symbol in zip(GROUPS, COLORS, SYMBOLS):
        s = [r for r in rows if r["region"] == region]
        fig.add_trace(
            go.Scatter(
                x=[r["share_2019"] for r in s],
                y=[r["share_2024"] for r in s],
                mode="markers",
                name=region,
                text=[r["abbr"] for r in s],
                textposition="top center",
                marker=dict(color=color, symbol=symbol, size=11, line=dict(color="white", width=1)),
                error_x=dict(
                    type="data",
                    array=[r["moe90_2019"] for r in s],
                    visible=False,
                    thickness=1,
                    width=2,
                ),
                error_y=dict(
                    type="data",
                    array=[r["moe90_2024"] for r in s],
                    visible=False,
                    thickness=1,
                    width=2,
                ),
                customdata=[
                    [
                        r["state"],
                        r["change_pp"],
                        r["change_low90"],
                        r["change_high90"],
                        r["eligible_2019"],
                        r["eligible_2024"],
                    ]
                    for r in s
                ],
                hovertemplate="<b>%{customdata[0]}</b><br>2019: %{x:.1f}%<br>2024: %{y:.1f}%<br>Change: %{customdata[1]:+.2f} percentage points<br>Approx. 90% change interval: [%{customdata[2]:+.2f}, %{customdata[3]:+.2f}] pp<br>Eligible households: %{customdata[4]:,.0f} (2019), %{customdata[5]:,.0f} (2024)<extra>%{fullData.name}</extra>",
            )
        )
    fig.update_layout(
        template="plotly_white",
        height=570,
        autosize=True,
        font=dict(family="Arial, sans-serif", size=13, color="#23374a"),
        margin=dict(l=65, r=20, t=45, b=110),
        hovermode="closest",
        dragmode=False,
        xaxis=dict(
            title="2019: eligible renters with gross rent at least 30% of income (%)",
            range=[30, 66],
            tickformat=".0f",
            ticksuffix="%",
            fixedrange=True,
            dtick=5,
            automargin=True,
        ),
        yaxis=dict(
            title="2024: same measure (%)",
            range=[30, 66],
            tickformat=".0f",
            ticksuffix="%",
            fixedrange=True,
            dtick=5,
            automargin=True,
        ),
        legend=dict(orientation="h", y=-0.22, x=0, itemclick=False, itemdoubleclick=False),
        shapes=[
            dict(
                type="line",
                x0=30,
                x1=66,
                y0=30,
                y1=66,
                line=dict(color="#6b7a86", width=1.5, dash="dash"),
                layer="below",
            )
        ],
        annotations=[
            dict(
                x=0.02,
                y=1.08,
                xref="paper",
                yref="paper",
                showarrow=False,
                text="Above the dashed line: a higher share in 2024",
                font=dict(size=12, color="#526575"),
            )
        ],
    )
    figure = fig.to_html(
        full_html=False,
        include_plotlyjs=True,
        div_id="rent-chart",
        config=dict(responsive=True, displayModeBar=False, displaylogo=False, scrollZoom=False),
    )
    options = "".join(f'<option value="{r["fips"]}">{r["state"]}</option>' for r in rows)
    html = (
        (ROOT / "scripts/chart_template.html.txt")
        .read_text(encoding="utf-8")
        .replace("%%FIGURE%%", figure)
        .replace("%%OPTIONS%%", options)
        .replace("%%RECORDS%%", json.dumps(rows))
        .replace("%%REGIONS%%", json.dumps(list(GROUPS)))
    )
    (ROOT / "figures/rent_burden.html").write_text(html, encoding="utf-8")
    (ROOT / "figures/figure_spec.json").write_text(fig.to_json(), encoding="utf-8")
    return fig


def build():
    validate_saved()
    for folder in ["results", "data/processed", "figures"]:
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
    definitions()
    with (ROOT / "data/raw/geos2019_1yr.csv").open(encoding="latin-1", newline="") as f:
        geos = {
            r["DADSID"]: r
            for r in csv.DictReader(f)
            if r["SUMLEVEL"] == "040" and r["COMPONENT"] == "00"
        }
    tables = {}
    for year in [2019, 2024]:
        with (ROOT / f"data/raw/acsdt1y{year}-b25070.dat").open(
            encoding="utf-8-sig", newline=""
        ) as f:
            tables[year] = {
                r["GEO_ID"]: r
                for r in csv.DictReader(f, delimiter="|")
                if r["GEO_ID"].startswith("0400000US") and len(r["GEO_ID"]) == 11
            }
    region_of = {abbr: region for region, abbrs in GROUPS.items() for abbr in abbrs}
    assert (
        len(region_of) == 50 and set(tables[2019]) == set(tables[2024]) and len(tables[2019]) == 52
    )
    rows = []
    annual = []
    for key in sorted(tables[2019]):
        if key[-2:] in ["11", "72"]:
            continue
        geo = geos[key]
        abbr = geo["STUSAB"].upper()
        name = geo["NAME"]
        a = derive(tables[2019][key])
        b = derive(tables[2024][key])
        change = b["share"] - a["share"]
        moe = math.hypot(a["moe90_pp"], b["moe90_pp"])
        rows.append(
            dict(
                fips=key[-2:],
                state=name,
                abbr=abbr,
                region=region_of[abbr],
                share_2019=a["share"],
                share_2024=b["share"],
                change_pp=change,
                moe90_2019=a["moe90_pp"],
                moe90_2024=b["moe90_pp"],
                change_moe90_pp=moe,
                change_low90=change - moe,
                change_high90=change + moe,
                eligible_2019=a["eligible"],
                eligible_2024=b["eligible"],
                excluded_2019=a["excluded"],
                excluded_2024=b["excluded"],
                total_2019=a["total"],
                total_2024=b["total"],
            )
        )
        for year, result in [(2019, a), (2024, b)]:
            annual.append(dict(fips=key[-2:], state=name, year=year, **result))
    rows.sort(key=lambda r: r["state"])
    ranked = sorted(rows, key=lambda r: -r["change_pp"])
    for i, r in enumerate(ranked, 1):
        r["estimated_change_rank"] = i
    write_csv(ROOT / "data/processed/state_comparison.csv", rows)
    write_csv(ROOT / "data/processed/annual_measures.csv", annual)
    write_csv(ROOT / "results/ranked_changes.csv", ranked)
    write_csv(ROOT / "results/top_five.csv", ranked[:5])
    facts = dict(
        n_states=len(rows),
        n_estimated_increases=sum(r["change_pp"] > 0 for r in rows),
        largest_increase_state=ranked[0]["state"],
        largest_share_state=max(rows, key=lambda r: r["share_2024"])["state"],
        n_proportion_fallbacks=sum(r["ratio_fallback"] for r in annual),
        years=[2019, 2024],
        interval_level=0.90,
        python=platform.python_version(),
        plotly=plotly.__version__,
    )
    (ROOT / "results/facts.json").write_text(json.dumps(facts, indent=2) + "\n", encoding="utf-8")
    fig = chart(rows)
    checks = [
        dict(check="Official-file hashes and schemas validated", passed=True),
        dict(check="Both table shells: all 11 categories and universe agree", passed=True),
        dict(
            check="50 unique states; DC and PR excluded",
            passed=len(rows) == len({r["fips"] for r in rows}) == 50,
        ),
        dict(
            check="100 annual measures: no sentinel values; cells sum to total",
            passed=len(annual) == 100,
        ),
        dict(
            check="Every burden numerator is below its computable denominator",
            passed=all(0 < r["burdened"] < r["eligible"] for r in annual),
        ),
        dict(
            check="Every change equals 2024 minus 2019",
            passed=all(
                abs(r["change_pp"] - (r["share_2024"] - r["share_2019"])) < 1e-10 for r in rows
            ),
        ),
        dict(
            check="Intervals contain point estimates",
            passed=all(r["change_low90"] < r["change_pp"] < r["change_high90"] for r in rows),
        ),
        dict(
            check="Four plotted regions partition exactly 50 observations",
            passed=len(fig.data) == 4 and sum(len(t.x) for t in fig.data) == 50,
        ),
        dict(
            check="Top five estimated increases span four regions",
            passed=len({r["region"] for r in ranked[:5]}) == 4,
        ),
    ]
    write_csv(ROOT / "results/validation.csv", checks)
    assert all(c["passed"] for c in checks)
    print(
        "Built 50 states, 100 annual measures and self-contained Plotly chart; nine checks passed."
    )
    print("Largest estimated increases:", ", ".join(r["state"] for r in ranked[:5]))


if __name__ == "__main__":
    build()
