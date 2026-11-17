#!/usr/bin/env python3
"""Generate clean SVG bar charts for the QN10 README. No dependencies."""
import html
import os

OUT = os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT, exist_ok=True)

# Palette: QN10 highlighted, references neutral.
QN10 = "#2f8f83"      # teal, the QN10 bar
REF = "#8a94a6"       # slate grey, reference bars
REF2 = "#c2c9d6"      # lighter slate, second series
INTG = "#6b8fc4"      # blue, other integrated GPUs
DISC = "#8a94a6"      # slate, discrete GPUs
TEXT = "#1b1f27"
GRID = "#e4e8ef"
AXIS = "#9aa3b2"


def esc(s):
    return html.escape(str(s))


def chart(path, title, bars, ymax, ylabel, source, grouped=None, note=None):
    """bars: list of (label, value, color) for a single series.
       grouped: optional (series_names, [(label, [v1, v2], highlight_bool)])."""
    W, H = 720, 460
    ml, mr, mt, mb = 70, 24, 70, 96
    pw, ph = W - ml - mr, H - mt - mb
    y0 = mt + ph

    def yv(v):
        return y0 - (v / ymax) * ph

    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" font-family="-apple-system,Segoe UI,Roboto,'
         f'Helvetica,Arial,sans-serif">']
    s.append(f'<rect width="{W}" height="{H}" fill="white"/>')
    s.append(f'<text x="{ml}" y="34" font-size="20" font-weight="700" '
             f'fill="{TEXT}">{esc(title)}</text>')
    # gridlines + y ticks
    ticks = 5
    for i in range(ticks + 1):
        v = ymax * i / ticks
        y = yv(v)
        s.append(f'<line x1="{ml}" y1="{y:.1f}" x2="{ml+pw}" y2="{y:.1f}" '
                 f'stroke="{GRID}" stroke-width="1"/>')
        lab = f'{v:.0f}' if ymax >= 10 else f'{v:.1f}'
        s.append(f'<text x="{ml-10}" y="{y+4:.1f}" font-size="12" '
                 f'text-anchor="end" fill="{AXIS}">{lab}</text>')
    s.append(f'<text x="18" y="{mt+ph/2:.0f}" font-size="12" fill="{AXIS}" '
             f'transform="rotate(-90 18 {mt+ph/2:.0f})" '
             f'text-anchor="middle">{esc(ylabel)}</text>')

    if grouped:
        series_names, rows = grouped
        n = len(rows)
        group_w = pw / n
        bw = min(42, group_w / (len(series_names) + 1))
        for gi, (label, vals, hi) in enumerate(rows):
            gx = ml + gi * group_w
            for si, v in enumerate(vals):
                col = (QN10 if si == 0 else "#7bb7ae") if hi else (REF if si == 0 else REF2)
                x = gx + group_w / 2 - (len(vals) * bw) / 2 + si * bw
                y = yv(v)
                s.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bw:.1f}" '
                         f'height="{y0-y:.1f}" rx="3" fill="{col}"/>')
                s.append(f'<text x="{x+bw/2:.1f}" y="{y-6:.1f}" font-size="11" '
                         f'text-anchor="middle" fill="{TEXT}">{esc(v)}</text>')
            s.append(f'<text x="{gx+group_w/2:.1f}" y="{y0+18:.0f}" '
                     f'font-size="12" text-anchor="middle" fill="{TEXT}" '
                     f'font-weight="{"700" if hi else "400"}">{esc(label)}</text>')
        # legend
        lx = ml
        for si, nm in enumerate(series_names):
            col = QN10 if si == 0 else "#7bb7ae"
            s.append(f'<rect x="{lx}" y="{mt-20}" width="12" height="12" rx="2" '
                     f'fill="{col}"/>')
            s.append(f'<text x="{lx+18}" y="{mt-9}" font-size="12" '
                     f'fill="{TEXT}">{esc(nm)}</text>')
            lx += 40 + len(nm) * 8
    else:
        n = len(bars)
        slot = pw / n
        bw = min(80, slot * 0.55)
        for i, bar in enumerate(bars):
            label, v, col = bar[0], bar[1], bar[2]
            vlabel = bar[3] if len(bar) > 3 else v
            x = ml + i * slot + slot / 2 - bw / 2
            y = yv(v)
            s.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bw:.1f}" '
                     f'height="{y0-y:.1f}" rx="3" fill="{col}"/>')
            s.append(f'<text x="{x+bw/2:.1f}" y="{y-6:.1f}" font-size="13" '
                     f'text-anchor="middle" fill="{TEXT}" '
                     f'font-weight="600">{esc(vlabel)}</text>')
            parts = str(label).split("\n")
            for li, part in enumerate(parts):
                s.append(f'<text x="{x+bw/2:.1f}" y="{y0+18+li*14:.0f}" '
                         f'font-size="12" text-anchor="middle" '
                         f'fill="{TEXT}">{esc(part)}</text>')
    s.append(f'<line x1="{ml}" y1="{y0}" x2="{ml+pw}" y2="{y0}" '
             f'stroke="{AXIS}" stroke-width="1.5"/>')
    yb = H - mb + 46
    if note:
        s.append(f'<text x="{ml}" y="{yb}" font-size="11" fill="{TEXT}">'
                 f'{esc(note)}</text>')
        yb += 16
    s.append(f'<text x="{ml}" y="{yb}" font-size="10.5" fill="{AXIS}">'
             f'{esc(source)}</text>')
    s.append('</svg>')
    open(os.path.join(OUT, path), "w").write("\n".join(s))
    print("wrote", path)


# 1. CPU: Geekbench 6 single + multi (published reference numbers)
chart(
    "cpu-geekbench.svg",
    "CPU: Geekbench 6 (higher is better)",
    [], 26000, "score",
    "Published reviewer figures for the Snapdragon X2 family and competitors "
    "(XDA, cpu-monkey, Windows Central). Not measured on this unit.",
    grouped=(["Single-core", "Multi-core"], [
        ("Snapdragon\nX2 Elite Extreme", [4080, 23400], True),
        ("Apple\nM4 Max", [3900, 25000], False),
        ("Ryzen AI 9\nHX 375", [2842, 15030], False),
        ("Core Ultra 7\n258V", [2724, 11003], False),
    ]),
    note="QN10 uses this Snapdragon X2 silicon. It wins single-core, trails "
         "the M4 Max in multi-core, and leads Intel and AMD in both.",
)

# multi-line x labels are not supported by tspan above; fall back to short
# labels by regenerating with single-line names.
chart(
    "cpu-geekbench.svg",
    "CPU: Geekbench 6 (higher is better)",
    [], 26000, "score",
    "Published reviewer figures (XDA, cpu-monkey, Windows Central); "
    "not measured on this unit.",
    grouped=(["Single-core", "Multi-core"], [
        ("X2 Elite Extreme", [4080, 23400], True),
        ("Apple M4 Max", [3900, 25000], False),
        ("Ryzen AI 9 375", [2842, 15030], False),
        ("Core Ultra 258V", [2724, 11003], False),
    ]),
    note="QN10 uses this Snapdragon X2 silicon: wins single-core, trails M4 "
         "Max multi-core, leads Intel and AMD in both.",
)

# 2. NPU INT8 TOPS
chart(
    "npu-tops.svg",
    "NPU / tensor: INT8 TOPS (dense)",
    [("QN10 Hexagon NPU", 80, QN10),
     ("RTX 3090 tensor", 284, REF),
     ("RTX 5090 tensor", 838, REF)],
    950, "TOPS (INT8, dense)",
    "NPU: Qualcomm spec (80 TOPS). RTX: club386 / bestgpusforai.",
    note="Same axis, very different power: the NPU is part of a ~15-50 W SoC; "
         "the RTX cards draw 350-575 W.",
)

# 3. GPU FP32, parity class plus flagships for scale
chart(
    "gpu-fp32.svg",
    "GPU: FP32 TFLOPS (parity class, with flagships for scale)",
    [("Adreno X2-85\n(QN10)", 6.0, QN10, "~6.0"),
     ("Radeon\n890M", 5.94, INTG),
     ("Arc 140V", 4.1, INTG),
     ("RTX 3050\n(discrete)", 6.77, DISC),
     ("RTX 3090", 35.6, DISC),
     ("RTX 5090", 104.8, DISC)],
    115, "TFLOPS (FP32)",
    "FP32 sources: nanoreview, cpu-monkey, TechPowerUp, club386. Details in "
    "BENCHMARKS.md.",
    note="On par with the Radeon 890M and an entry RTX 3050; the flagships "
         "are a different league.",
)

chart(
    "gpu-perf-per-watt.svg",
    "GPU: compute per watt (FP32 TFLOPS / W)",
    [("Adreno X2-85\n(QN10)", 0.40, QN10, "0.40"),
     ("Radeon\n890M", 0.40, INTG, "0.40"),
     ("Arc 140V", 0.27, INTG),
     ("RTX 5090", 0.182, DISC, "0.18"),
     ("RTX 3090", 0.102, DISC, "0.10"),
     ("RTX 3050", 0.097, DISC, "0.10")],
    0.48, "TFLOPS per watt",
    "Power: integrated at 15 W configurable TDP; discrete at board TDP. "
    "FP32 and sources in BENCHMARKS.md.",
    note="Integrated GPUs (incl. the Adreno) lead on compute per watt; the "
         "5090 is the most efficient discrete card.",
)

# 6. CPU compute per watt (Geekbench 6 multi / power at the multi-core load)
chart(
    "cpu-perf-per-watt.svg",
    "CPU: multi-core score per watt (at load)",
    [("X2 Elite\nExtreme", 296, QN10, "296"),
     ("Apple\nM4 Max", 446, DISC),
     ("Ryzen AI 9\n375", 320, DISC),
     ("Core Ultra\n258V", 367, DISC)],
    520, "Geekbench 6 multi / watt",
    "Power at the multi-core load (approx): X2 ~79 W (notebookcheck "
    "measured); M4 Max ~56 W, Ryzen ~47 W, 258V ~30 W (representative).",
    note="The X2 posts top-tier scores but draws the most power, so the M4 "
         "Max leads efficiency here. Approximate, not an iso-power test.",
)

print("done")
