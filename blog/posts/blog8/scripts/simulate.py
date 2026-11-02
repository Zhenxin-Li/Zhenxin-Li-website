"""Frozen, entirely simulated household savings; no external requests.

Run from this post directory: python scripts/simulate.py
The small browser payload is built from the same saved draws as the figures.
"""
from pathlib import Path
import csv
import hashlib
import json
import platform
import time

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SEED = 20261101
MU, SIGMA = 3.0, 20.0
SIZES = (50, 200, 800)
LEVELS = (.90, .95, .99)
B_OBS, B_COVER, M, D = 9999, 999, 2000, 50000


def rng_for(n, role):
    return np.random.default_rng(np.random.SeedSequence([SEED, n, role]))


def bootstrap_means(sample, repeats, rng):
    """Ordinary nonparametric bootstrap: n draws WITH replacement, each time."""
    n = len(sample)
    result = np.empty(repeats)
    for first in range(0, repeats, 128):
        stop = min(first + 128, repeats)
        indices = rng.integers(0, n, size=(stop - first, n))
        result[first:stop] = sample[indices].mean(axis=1)
    return result


def interval(values, level):
    alpha = 1 - level
    return np.quantile(values, [alpha / 2, 1 - alpha / 2], method="linear")


def t_statistic(samples, axis=-1):
    n = samples.shape[axis]
    return samples.mean(axis=axis) / (samples.std(axis=axis, ddof=1) / np.sqrt(n))


def histogram(values, include=()):
    lo = min(float(values.min()), *include) if include else float(values.min())
    hi = max(float(values.max()), *include) if include else float(values.max())
    counts, edges = np.histogram(values, bins=np.linspace(lo - .01, hi + .01, 71))
    assert counts.sum() == len(values)
    return dict(x=((edges[1:] + edges[:-1]) / 2).tolist(),
                width=np.diff(edges).tolist(), count=counts.tolist(),
                density=(counts / (len(values) * np.diff(edges))).tolist(),
                edges=edges.tolist())


def save_csv(path, header, rows):
    with path.open("w", newline="", encoding="utf8") as stream:
        writer = csv.writer(stream)
        writer.writerow(header)
        writer.writerows(rows)


def main():
    started = time.monotonic()
    for folder in ("data/simulated", "results", "assets"):
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
    # The observed samples are nested prefixes; coverage experiments are NEW samples.
    master = np.random.default_rng(SEED).normal(MU, SIGMA, max(SIZES))
    save_csv(ROOT / "data/simulated/households.csv", ["household_id", "saving_usd"],
             enumerate(master, 1))
    payload = dict(seed=SEED, mu=MU, sigma=SIGMA, sizes=list(SIZES),
                   levels=list(LEVELS), default_n=200, default_level="95",
                   B_observed=B_OBS, B_coverage=B_COVER, M=M, D=D, cases={})
    coverage_rows, summary_rows, checks = [], [], []
    for n in SIZES:
        sample = master[:n]
        boots = bootstrap_means(sample, B_OBS, rng_for(n, 1))
        save_csv(ROOT / f"data/simulated/bootstrap_n{n}.csv", ["resample", "mean_saving"],
                 enumerate(boots, 1))
        # Fresh households in EACH outer experiment, not repeated bootstrapping
        # of the one observed sample. A new bootstrap interval for each dataset.
        sampling_rng, boot_rng = rng_for(n, 2), rng_for(n, 3)
        endpoints = np.empty((M, len(LEVELS), 2))
        means = np.empty(M)
        for experiment in range(M):
            new_sample = sampling_rng.normal(MU, SIGMA, n)
            means[experiment] = new_sample.mean()
            new_boots = bootstrap_means(new_sample, B_COVER, boot_rng)
            for j, level in enumerate(LEVELS):
                endpoints[experiment, j] = interval(new_boots, level)
            if (experiment + 1) % 500 == 0:
                print(f"n={n}: {experiment+1}/{M} independent coverage experiments", flush=True)
        null_rng = rng_for(n, 4)
        null_t = np.empty(D)
        for start in range(0, D, 500):
            stop = min(start + 500, D)
            null_samples = null_rng.normal(0, SIGMA, (stop-start, n))
            null_t[start:stop] = t_statistic(null_samples, axis=1)
        observed_t = float(t_statistic(sample))
        tail_count = int(np.sum(np.abs(null_t) >= abs(observed_t)))
        # A simulated p-value is never reported as zero.
        p_value = (tail_count + 1) / (D + 1)
        save_csv(ROOT / f"data/simulated/null_n{n}.csv", ["simulation", "t_statistic"],
                 enumerate(null_t, 1))
        case = dict(n=n, mean=float(sample.mean()), sd=float(sample.std(ddof=1)),
                    t=observed_t, tail_count=tail_count, p=p_value,
                    bootstrap_hist=histogram(boots, (0, MU)),
                    null_hist=histogram(null_t, (-abs(observed_t), abs(observed_t))),
                    levels={})
        for j, level in enumerate(LEVELS):
            key = str(round(100*level))
            low, high = interval(boots, level)
            hit = (endpoints[:, j, 0] <= MU) & (MU <= endpoints[:, j, 1])
            rate = float(hit.mean())
            critical = float(np.quantile(np.abs(null_t), level))
            null_reject_rate = float(np.mean(np.abs(null_t) >= critical))
            case["levels"][key] = dict(
                low=float(low), high=float(high), covered=int(hit.sum()),
                coverage=rate, coverage_mcse=float(np.sqrt(rate*(1-rate)/M)),
                average_width=float(np.diff(endpoints[:, j], axis=1).mean()),
                critical=critical, null_reject_rate=null_reject_rate,
                show=[dict(run=k+1, low=float(endpoints[k,j,0]),
                           high=float(endpoints[k,j,1]), hit=bool(hit[k])) for k in range(100)])
            for k in range(M):
                coverage_rows.append([n, level, k+1, means[k], *endpoints[k,j], bool(hit[k])])
            summary_rows.append([n, level, float(sample.mean()), low, high, int(hit.sum()),
                                 M, rate, observed_t, tail_count, D, p_value, critical])
            checks.append(dict(check=f"n{n}_level{key}_ordered_endpoints", passed=bool(low<=high and np.all(endpoints[:,j,0]<=endpoints[:,j,1]))))
            checks.append(dict(check=f"n{n}_level{key}_null_tail_size", passed=abs(null_reject_rate-(1-level))<2/D))
        checks.append(dict(check=f"n{n}_valid_pvalue",passed=0<p_value<=1))
        checks.append(dict(check=f"n{n}_wider_intervals_at_higher_confidence",
                           passed=bool(np.all(endpoints[:,0,0]>=endpoints[:,1,0]) and np.all(endpoints[:,1,0]>=endpoints[:,2,0]) and np.all(endpoints[:,0,1]<=endpoints[:,1,1]) and np.all(endpoints[:,1,1]<=endpoints[:,2,1]))))
        payload["cases"][str(n)] = case
        print(f"n={n} mean={sample.mean():.4f}, p={p_value:.5f}, 95% coverage={case['levels']['95']['coverage']:.3f}",flush=True)
    save_csv(ROOT / "results/coverage_intervals.csv",
             ["n","confidence","experiment","sample_mean","lower","upper","covers_true_mu"],coverage_rows)
    save_csv(ROOT / "results/summary.csv",
             ["n","confidence","sample_mean","lower","upper","covered","experiments","coverage","observed_t","tail_count","null_simulations","p_value","critical_abs_t"],summary_rows)
    (ROOT / "results/explorer.json").write_text(json.dumps(payload,separators=(",",":"),allow_nan=False),encoding="utf8")
    (ROOT / "assets/simulation-data.js").write_text("window.BLOG8_DATA="+json.dumps(payload,separators=(",",":"),allow_nan=False)+";",encoding="utf8")
    summary = {**{k:v for k,v in payload.items() if k!='cases'},
               "default":payload['cases']['200'],"versions":{"python":platform.python_version(),"numpy":np.__version__}}
    (ROOT / "results/facts.json").write_text(json.dumps(summary,indent=2),encoding="utf8")
    save_csv(ROOT / "results/validation.csv",["check","passed"],[(r['check'],r['passed']) for r in checks])
    assert all(r['passed'] for r in checks)
    files=[p for folder in ['data/simulated','results'] for p in (ROOT/folder).glob('*') if p.name!='manifest.json']
    manifest={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (ROOT/'results/manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    print(f"All {len(checks)} checks passed; elapsed {time.monotonic()-started:.1f}s",flush=True)


if __name__ == "__main__":
    main()
