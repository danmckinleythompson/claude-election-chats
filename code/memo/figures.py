#!/usr/bin/env python3
"""figures.py -- every figure for the politics memo and the Free Systems post.

    python3 code/memo/figures.py

Reads only the CSVs written by code/memo/01_memo_stats.R (R still owns the
estimation, tables and macros; Python owns every chart). Writes:

    output/memo/fig_*.pdf   plain, no title/logo -- \\includegraphics'd by
                            draft/politics_memo, whose LaTeX \\caption does the
                            titling.
    output/post/post_0N_*.png  Free Systems branded, header + footer + logo,
                            numbered in presentation order so the whole set can
                            be dragged into the Google Doc in sequence.

One builder per figure, so the memo and the post can never disagree about a
chart. Branding is a wrapper, never a second copy of the chart.

TITLES describe what is plotted; they never state the conclusion. Subtitles
carry only neutral orienting facts -- geography, month, and whatever the reader
needs in order not to misread the panels (what does not sum, what is not
comparable). The argument belongs in the post's prose, not stamped on the
chart. The memo drops both and titles via its LaTeX \caption.

Brand system: ~/freesystems/CLAUDE.md -- off-white #FAFAF7, ink #1A1A18, deep
teal #2B5B6C, warm copper #C4703E. FONT: the brand faces (Playfair Display,
DM Sans, JetBrains Mono) are not installed on this machine; Avenir Next is the
closest installed geometric sans. Install them and change FS["family"].
"""
from __future__ import annotations

import shutil
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import Rectangle

ROOT = Path(__file__).resolve().parents[2]
MEMO = ROOT / "output" / "memo"
POST = ROOT / "output" / "post"
LOGO = ROOT / "code" / "memo" / "assets" / "free_systems_logo.png"
AEI = (ROOT / "original_data" / "anthropic_economic_index" /
       "release_2026_06_26" / "aei_claude_ai_2026-06-26.csv")

URL = "freesystems.substack.com"
SOURCE = ("Source: Anthropic Economic Index, 2026-06-26 release. "
          "Shares are of classified conversations.")
DPI = 200
PAD, HEAD, FOOT = 0.34, 1.25, 0.72   # inches: margin, header band, footer band

# --- palettes ---------------------------------------------------------------
MEMO_PAL = dict(
    bar="#B2182B", accent="#B2182B", muted="#737373", flat="#B7B7B7",
    series3={"Information": "#B2182B", "Action": "#2166AC", "Document": "#E08214"},
    bg="white", ink="#404040", axis="#4D4D4D", grid="#EAEAEA",
    strip="#4D4D4D", rule="#8C8C8C", light="#E0A8AF", base=11,
    family="DejaVu Sans")

FS = dict(
    bar="#2B5B6C", accent="#2B5B6C", muted="#8C8C86", flat="#B9B8AE",
    # Teal and copper are the brand's own pair and carry the story (information
    # vs document); the minor Action series is deliberately neutral. The brand
    # teal sits below the dataviz chroma floor -- it is a muted teal by design
    # -- so every series is also directly labelled, the documented relief.
    series3={"Information": "#2B5B6C", "Action": "#8C8C86", "Document": "#C4703E"},
    bg="#FAFAF7", ink="#3D3D38", axis="#3D3D38", grid="#E3E2DA",
    strip="#6B6B63", rule="#C9C8BE", light="#9FBAC2", base=11,
    family="Avenir Next")


# --- shared chart furniture -------------------------------------------------
def style_axes(ax, pal, xgrid=True):
    """Recessive frame: one baseline, x gridlines only, no y spine or ticks."""
    ax.set_facecolor(pal["bg"])
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(pal["rule"])
    ax.spines["bottom"].set_linewidth(0.8)
    if xgrid:
        ax.grid(axis="x", color=pal["grid"], linewidth=0.7, zorder=0)
    ax.set_axisbelow(True)
    ax.tick_params(axis="y", length=0, colors=pal["axis"], labelsize=pal["base"])
    ax.tick_params(axis="x", length=3, colors=pal["axis"], labelsize=pal["base"] - 0.5,
                   color=pal["rule"])


def bar_panel(ax, labels, values, pal, fmt="{:.2f}%", color=None, pad=0.02):
    """Ranked horizontal bars with the value printed at each bar end."""
    y = np.arange(len(labels))
    ax.barh(y, values, height=0.68, color=color or pal["bar"], zorder=3)
    span = max(values) if len(values) else 1
    for yi, v in zip(y, values):
        ax.text(v + span * pad, yi, fmt.format(v), va="center", ha="left",
                fontsize=pal["base"] - 0.5, color=pal["ink"], zorder=4)
    ax.set_yticks(y)
    ax.set_yticklabels(labels)
    ax.set_ylim(len(labels) - 0.5, -0.5)
    ax.set_xlim(0, span * 1.18)
    style_axes(ax, pal)


def strip_label(fig, ax, text, pal):
    """Italic group label, flush with the page margin so it can never collide
    with the y tick labels however long a category name gets."""
    W = fig.get_size_inches()[0]
    box = ax.get_position()
    fig.text(PAD / W, (box.y0 + box.y1) / 2, text, ha="left", va="center",
             fontsize=pal["base"] - 1, color=pal["strip"], style="italic",
             linespacing=1.3)


def bottom_legend(fig, handles, labels, pal, ncol):
    """Legend in the gutter between the x axis label and the footer rule.

    Placed in figure coordinates, not axes coordinates: an axes-relative offset
    silently drifts into the footer as soon as a figure's panel height changes.
    """
    H = fig.get_size_inches()[1]
    fig.legend(handles, labels, loc="lower center",
               bbox_to_anchor=(0.5, (fig.fs_foot + 0.04) / H), ncol=ncol,
               frameon=False, fontsize=pal["base"], labelcolor=pal["ink"],
               columnspacing=1.6, handlelength=1.3)


# --- figure canvas ----------------------------------------------------------
def make_canvas(chart_w, chart_h, row_counts, pal, branded, left_in, bottom_in,
                head_in=None, gap=0.35):
    """Figure sized so the plotting area is exactly chart_w x chart_h inches.

    Panels stack with heights proportional to their row counts, so a three-row
    panel never gets the same height as a six-row one. Two reserves matter and
    are the thing that goes wrong if they are guessed:
      left_in   room for the y tick labels plus, when panelled, the strip column
      bottom_in room for the x tick labels, the axis title, and any legend --
                all of which matplotlib draws OUTSIDE the axes rectangle, so
                without this they render straight over the footer.
    """
    head = (head_in or HEAD) if branded else 0.12
    foot = FOOT if branded else 0.10
    W = chart_w + 2 * PAD
    H = chart_h + head + foot + bottom_in
    fig = plt.figure(figsize=(W, H), facecolor=pal["bg"])
    fig.fs_foot = foot
    usable = chart_h - gap * (len(row_counts) - 1)
    heights = [usable * c / sum(row_counts) for c in row_counts]

    axes, top = [], H - head
    for h in heights:
        ax = fig.add_axes([(PAD + left_in) / W, (top - h) / H,
                           (chart_w - left_in) / W, h / H])
        axes.append(ax)
        top -= h + gap
    return fig, axes, W, H


def finish(fig, W, H, pal, title, subtitle, branded):
    """Header rule + title + subtitle, footer hairline + logo + source + link."""
    if not branded:
        return
    x0 = PAD / W
    fig.add_artist(Rectangle((x0, 1 - 0.30 / H), 0.62 / W, 0.030 / H,
                             color=pal["accent"], transform=fig.transFigure,
                             clip_on=False))
    fig.text(x0, 1 - 0.56 / H, title, ha="left", va="top", fontsize=17,
             fontweight="bold", color="#1A1A18", family=pal["family"])
    fig.text(x0, 1 - 0.86 / H, subtitle, ha="left", va="top", fontsize=10.5,
             color="#6B6B63", family=pal["family"], linespacing=1.35)

    fig.add_artist(plt.Line2D([x0, 1 - x0], [(FOOT - 0.10) / H] * 2,
                              color=pal["rule"], linewidth=0.8,
                              transform=fig.transFigure, clip_on=False))
    img = plt.imread(LOGO)
    ar = img.shape[1] / img.shape[0]
    lh = 0.30
    ax = fig.add_axes([x0, 0.16 / H, lh * ar / W, lh / H])
    ax.imshow(img)
    ax.axis("off")
    fig.text(1 - x0, 0.40 / H, SOURCE, ha="right", va="center", fontsize=8.2,
             color="#8C8C86", family=pal["family"])
    fig.text(1 - x0, 0.19 / H, URL, ha="right", va="center", fontsize=9.2,
             fontweight="bold", color=pal["accent"], family=pal["family"])


# =============================================================================
# Builders. Each returns (title, subtitle) and draws into the axes it is given.
# =============================================================================

def _topic_ranking():
    """USA minor-topic ranking for F0, cached: the raw release is ~210MB."""
    cache = MEMO / "topic_ranking_usa_may.csv"
    if cache.exists():
        return pd.read_csv(cache)
    aei = pd.read_csv(AEI, usecols=["category_name", "metric_id", "geo_id",
                                    "date_start", "hierarchy_level",
                                    "node_name", "value"])
    # Minor topics are the level at which the outcome is defined, so the
    # ranking is like-for-like: never an aggregate against a leaf.
    m = aei[(aei.category_name == "request") & (aei.metric_id == "pct") &
            (aei.geo_id == "USA") & (aei.date_start == "2026-05-01") &
            (aei.hierarchy_level == 1)]
    out = (m[["node_name", "value"]].rename(columns={"node_name": "topic",
                                                     "value": "pct"})
           .sort_values("pct", ascending=False).reset_index(drop=True))
    out["rank"] = out.index + 1
    out.to_csv(cache, index=False)
    return out


ACRONYMS = ["API", "AI", "UI", "UX", "ML", "SQL", "HR", "IT", "SEO", "US", "PDF"]


def tidy_label(s: str) -> str:
    """Sentence-case: AEI's own capitalisation is inconsistent across topics and
    looks careless side by side. Acronyms must survive, or 'API debugging'
    becomes 'Api debugging'."""
    s = s.replace(" and ", " & ")
    s = s[:1].upper() + s[1:].lower()
    for a in ACRONYMS:
        for variant in (a.lower(), a.capitalize()):
            s = " ".join(a if w.strip(",.") == variant else w for w in s.split(" "))
    return s


def f0_context(axes, pal, fig):
    d = _topic_ranking()
    N_TOP, OUTCOME = 10, "Politics and public record"
    pol = d[d.topic == OUTCOME].iloc[0]
    n_topics = len(d)
    lo, hi = int(pol["rank"]) - 2, int(pol["rank"]) + 5
    n_gap_up = lo - N_TOP - 1
    n_gap_lo = n_topics - hi
    assert n_gap_up > 0 and n_gap_lo > 0 and lo > N_TOP

    head = d.head(N_TOP)
    neigh = d[(d["rank"] >= lo) & (d["rank"] <= hi)]
    ax = axes[0]
    rows = (list(head.itertuples()) + [None] + list(neigh.itertuples()) + [None])
    ys = np.arange(len(rows))
    xmax = head.pct.max()

    labels = []
    for y, r in zip(ys, rows):
        if r is None:
            labels.append("")
            continue
        is_pol = r.topic == OUTCOME
        ax.barh(y, r.pct, height=0.66, zorder=3,
                color=pal["accent"] if is_pol else pal["flat"])
        ax.text(r.pct + xmax * 0.015, y, f"{r.pct:.2f}%", va="center", ha="left",
                fontsize=pal["base"] - 0.5, fontweight="bold", zorder=4,
                color=pal["accent"] if is_pol else pal["ink"])
        labels.append(tidy_label(r.topic))

    # Both omitted stretches are stated, never silently dropped.
    for y, n in ((N_TOP, n_gap_up), (len(rows) - 1, n_gap_lo)):
        ax.plot([0, xmax * 1.02], [y, y], ls=":", lw=1.0, color=pal["rule"], zorder=2)
        ax.text(xmax * 0.02, y, f"{n} topics omitted", va="center", ha="left",
                fontsize=pal["base"] - 1, style="italic", color=pal["strip"],
                bbox=dict(fc=pal["bg"], ec="none", pad=1.6), zorder=5)

    ax.set_yticks(ys)
    ax.set_yticklabels(labels)
    ax.set_ylim(len(rows) - 0.4, -0.6)
    ax.set_xlim(0, xmax * 1.16)
    style_axes(ax, pal)
    ax.set_xlabel("Share of all conversations (%)", fontsize=pal["base"] + 1,
                  color=pal["axis"], labelpad=8)
    # Two lines, never three: the header band is fixed and a third line runs
    # straight into the top bar.
    return ("Share of US Claude Conversations, by Request Topic",
            f"Ten largest request topics, and the politics topic with its "
            f"immediate neighbours.\nPolitics ranks {int(pol['rank'])}th of "
            f"{n_topics}. United States, May 2026.")


def f1_topics(axes, pal, fig):
    d = pd.read_csv(MEMO / "topic_decomposition.csv").dropna(subset=["may"])
    names = ["Broad categories\n(level 1)", "Specific topics\n(level 0)"]
    for ax, lvl, nm in zip(axes, (1, 0), names):
        s = d[d.lvl == lvl].sort_values("may", ascending=False)
        bar_panel(ax, s.topic.tolist(), s.may.tolist(), pal)
        strip_label(fig, ax, nm, pal)
    for ax in axes[:-1]:
        ax.set_xticklabels([])
    axes[-1].set_xlabel("Share of all US conversations (%)",
                        fontsize=pal["base"] + 1, color=pal["axis"], labelpad=8)
    return ("Political and News Topic Shares, by Taxonomy Level",
            "United States, May 2026. The two panels are different levels of the "
            "topic taxonomy\nand overlap, so they do not sum.")


def f2_countries(axes, pal, fig):
    c = pd.read_csv(MEMO / "country_politics_shares.csv")
    sel = (pd.concat([c.nlargest(12, "pct"), c.nsmallest(12, "pct")])
           .drop_duplicates("geo_id").sort_values("pct"))
    ax = axes[0]
    y = np.arange(len(sel))
    colors = [pal["accent"] if g == "USA" else pal["flat"] for g in sel.geo_id]
    ax.barh(y, sel.pct, height=0.72, color=colors, zorder=3)
    ax.set_yticks(y)
    ax.set_yticklabels(sel.geo_id)
    ax.set_ylim(-0.7, len(sel) - 0.3)
    ax.set_xlim(0, sel.pct.max() * 1.08)
    style_axes(ax, pal)
    ax.set_xlabel("Politics-topic share of conversations (%)",
                  fontsize=pal["base"] + 1, color=pal["axis"], labelpad=8)
    handles = [Rectangle((0, 0), 1, 1, color=pal["accent"]),
               Rectangle((0, 0), 1, 1, color=pal["flat"])]
    bottom_legend(fig, handles, ["United States", "Other countries"], pal, 2)
    return ("Politics-Topic Share of Conversations, by Country",
            "Twelve highest and twelve lowest countries, May 2026.")


def f3_artifacts(axes, pal, fig):
    a = pd.read_csv(MEMO / "artifacts.csv")
    a = a[(a.politics >= 0.5) | (a.all_convos >= 3)].copy()
    a["label"] = a.artifact.str.replace("_", " ").str.capitalize()
    a = a.sort_values("politics")
    ax = axes[0]
    y = np.arange(len(a))
    ax.hlines(y, a.all_convos, a.politics, color=pal["flat"], lw=2.2, zorder=2)
    ax.scatter(a.all_convos, y, s=62, color=pal["muted"], zorder=3,
               label="All conversations")
    ax.scatter(a.politics, y, s=62, color=pal["accent"], zorder=3,
               label="Politics topic")
    ax.set_yticks(y)
    ax.set_yticklabels(a.label)
    ax.set_ylim(-0.7, len(a) - 0.3)
    style_axes(ax, pal)
    ax.set_xlabel("Share of conversations producing this artifact (%)",
                  fontsize=pal["base"] + 1, color=pal["axis"], labelpad=8)
    bottom_legend(fig, *ax.get_legend_handles_labels(), pal, 2)
    return ("Artifacts Produced: Politics Topic vs. All Conversations",
            "Worldwide, May 2026. Artifact = the conversation's main concrete output.")


def f4_info_action(axes, pal, fig):
    p = pd.read_csv(MEMO / "info_action_profile.csv").sort_values("info")
    ax = axes[0]
    y = np.arange(len(p))
    kinds = [("info", "Information"), ("action", "Action"), ("doc", "Document")]
    h = 0.24
    for i, (col, name) in enumerate(kinds):
        # i=0 drawn highest within each group, so the legend order matches the
        # visual order top-to-bottom.
        off = (1 - i) * h
        ax.barh(y + off, p[col], height=h, color=pal["series3"][name],
                label=name, zorder=3)
        for yi, v in zip(y, p[col]):
            ax.text(v + p["info"].max() * 0.012, yi + off, f"{v:.1f}",
                    va="center", ha="left", fontsize=pal["base"] - 1.5,
                    color=pal["ink"], zorder=4)
    ax.set_yticks(y)
    ax.set_yticklabels(p.topic)
    ax.set_ylim(-0.6, len(p) - 0.4)
    ax.set_xlim(0, p["info"].max() * 1.15)
    style_axes(ax, pal)
    ax.set_xlabel("Share of the topic's conversations producing this output (%)",
                  fontsize=pal["base"] + 1, color=pal["axis"], labelpad=8)
    bottom_legend(fig, *ax.get_legend_handles_labels(), pal, 3)
    return ("Conversation Outputs, by Political Topic",
            "Worldwide, May 2026. Each output kind groups several artifact "
            "types,\nso the three do not sum to 100.")


def f5_composition(axes, pal, fig):
    # keep_default_na: the "None" collaboration pattern is a CATEGORY NAME;
    # the default reader turns it into NaN and the bar loses its label.
    c = pd.read_csv(MEMO / "composition.csv", keep_default_na=False)
    c["may"] = c["may"].astype(float)
    # ASCII only, and never lower-case the definitions or "AI outputs" becomes
    # "ai outputs".
    c["lab"] = [l if d == "" else f"{l} ({d})"
                for l, d in zip(c.label, c.defn)]
    names = ["Use case", "Collaboration\nbucket", "Collaboration\npattern"]
    for ax, g, nm in zip(axes, ("A", "B", "C"), names):
        s = c[c.grp == g].sort_values("may", ascending=False)
        bar_panel(ax, s.lab.tolist(), s.may.tolist(), pal, fmt="{:.1f}")
        ax.set_xlim(0, c.may.max() * 1.15)
        strip_label(fig, ax, nm, pal)
    for ax in axes[:-1]:
        ax.set_xticklabels([])
    axes[-1].set_xlabel("Share of political conversations (%)",
                        fontsize=pal["base"] + 1, color=pal["axis"], labelpad=8)
    return ("Composition of Political Conversations",
            "Worldwide, May 2026. Each panel is a separate classification of the "
            "same\nconversations and sums to 100.")


def f6_did(axes, pal, fig):
    # One axis, in percentage points, so every interval is comparable. The log
    # specification is deliberately absent: it is not in pp and cannot share
    # this axis; it is reported in the memo instead.
    sp = pd.read_csv(MEMO / "did_specs.csv")
    sp = sp[sp.units == "pp"].rename(columns={"spec": "label"})
    cm = pd.read_csv(MEMO / "specificity.csv")
    cm = cm[cm.topic != "Politics and public record"].rename(columns={"topic": "label"})
    groups = [(sp, "Politics and\npublic record", pal["accent"]),
              (cm, "Other topics,\nsame design", pal["muted"])]
    lo = min((d.est - 1.96 * d.se).min() for d, _, _ in groups)
    hi = max((d.est + 1.96 * d.se).max() for d, _, _ in groups)
    span = hi - lo
    for ax, (d, nm, col) in zip(axes, groups):
        d = d.sort_values("est", ascending=False)
        y = np.arange(len(d))
        ax.axvline(0, ls="--", lw=1.0, color=pal["rule"], zorder=2)
        ax.hlines(y, d.est - 1.96 * d.se, d.est + 1.96 * d.se, color=col,
                  lw=2.0, zorder=3)
        ax.scatter(d.est, y, s=70, color=col, zorder=4)
        ax.set_yticks(y)
        ax.set_yticklabels(d.label)
        ax.set_ylim(len(d) - 0.5, -0.5)
        ax.set_xlim(lo - span * 0.08, hi + span * 0.08)
        style_axes(ax, pal)
        strip_label(fig, ax, nm, pal)
    axes[0].set_xticklabels([])
    axes[-1].set_xlabel("Effect of a May primary on topic share (pp), with 95% CI",
                        fontsize=pal["base"] + 1, color=pal["axis"], labelpad=8)
    return ("Estimated Effect of a May Primary, by Topic and Specification",
            "Difference-in-differences across US states, April to May 2026.\n"
            "State and month fixed effects; SEs clustered by state.")


def f7_null(axes, pal, fig):
    nd = pd.read_csv(MEMO / "null_distribution.csv")
    pol_t = float(nd.t[nd.topic == "Politics and public record"].iloc[0])
    rank = int((nd.t >= pol_t).sum())
    ax = axes[0]
    bw = 0.25
    edges = np.arange(np.floor(nd.t.min() / bw) * bw,
                      np.ceil(nd.t.max() / bw) * bw + bw, bw)
    counts, _, _ = ax.hist(nd.t, bins=edges, color=pal["flat"],
                           edgecolor=pal["bg"], linewidth=0.6, zorder=3)
    top = counts.max()

    # A segment, not a full rule: it must stop below the callout or it strikes
    # through the label it belongs to.
    ax.plot([pol_t, pol_t], [0, top * 0.80], color=pal["accent"], lw=2.4, zorder=4)
    ax.text(pol_t, top * 1.02,
            f"Politics and public record\nt = {pol_t:.2f} (rank {rank} of {len(nd)})",
            ha="center", va="top", fontsize=pal["base"], color=pal["accent"],
            linespacing=1.35, zorder=6,
            bbox=dict(fc=pal["bg"], ec="none", pad=2.5))

    # Name the topics that outrank politics so the figure carries the whole
    # ranking finding and needs no companion table. Heights are fractions of
    # the tallest bar, so they track the histogram rather than today's counts.
    above = nd[nd.t > pol_t].sort_values("t", ascending=False)
    for i, r in enumerate(above.itertuples()):
        y = top * (1.02 - 0.23 * (i + 1))
        ax.plot([r.t, r.t], [0.8, y - 0.6], color=pal["strip"], lw=0.8, zorder=4)
        ax.text(r.t, y, f"  {r.topic} ({r.t:.2f})" if i else f"{r.topic} ({r.t:.2f})  ",
                ha="left" if i else "right", va="center",
                fontsize=pal["base"] - 1.5, color=pal["strip"], zorder=5)

    style_axes(ax, pal, xgrid=False)
    ax.grid(axis="y", color=pal["grid"], linewidth=0.7, zorder=0)
    ax.tick_params(axis="y", length=3)
    ax.set_xlabel("$t$-statistic on Primary × May", fontsize=pal["base"] + 1,
                  color=pal["axis"], labelpad=8)
    ax.set_ylabel(f"Number of topics (of {len(nd)})", fontsize=pal["base"] + 1,
                  color=pal["axis"], labelpad=8)
    return ("Distribution of t-Statistics Across All Estimable Topics",
            f"The same difference-in-differences run on all {len(nd)} topic "
            f"series.\nUS states, April to May 2026.")


def _did_panel():
    """The estimation sample Dan's two blog figures use: the balanced Apr/May
    state panel with March-primary states dropped."""
    d = pd.read_csv(ROOT / "modified_data" / "aei_did_data.csv")
    return d[~d.march_primary]


def f6_arrows(axes, pal, fig):
    """Ported from code/make_politics_arrows.R (D. Thompson) into the post's
    palette, with the group averages split into their own panel.

    Why two panels: on a levels axis the later-primary average (0.48, flat) sits
    INSIDE the May-primary arrow's span (0.40 -> 0.51), so the eye compares
    where the groups ended up and reads them as much the same. The question is
    how far each MOVED, and a zero-length arrow has no visual weight at all.
    The lower panel puts both changes on a change axis against a zero line,
    where +0.10 against nothing is unmissable.
    """
    d = _did_panel()
    w = (d.pivot_table(index=["state_po", "treat_may"], columns="post",
                       values="politics_broad").reset_index()
         .rename(columns={False: "apr", True: "may"}))
    avg = w.groupby("treat_may")[["apr", "may"]].mean()
    n = w.groupby("treat_may").state_po.count()
    w = w.sort_values("apr", ascending=False)

    # --- panel 1: every state, in levels ------------------------------------
    ax = axes[0]
    for y, r in enumerate(w.itertuples()):
        col = pal["accent"] if r.treat_may else pal["light"]
        ax.annotate("", xy=(r.may, y), xytext=(r.apr, y),
                    arrowprops=dict(arrowstyle="-|>", color=col, linewidth=1.2,
                                    mutation_scale=11, shrinkA=0, shrinkB=0),
                    zorder=3)
        ax.scatter(r.apr, y, s=26, color=col, zorder=4)
    ax.set_yticks(range(len(w)))
    ax.set_yticklabels(w.state_po)
    ax.set_ylim(len(w) - 0.4, -0.6)
    ax.set_xlim(0.28, 1.14)
    style_axes(ax, pal)
    ax.text(0.80, 2.4, "Dot = April share\nArrow tip = May share", ha="left",
            va="center", fontsize=pal["base"], color=pal["strip"], linespacing=1.4)
    ax.text(0.80, 6.6, "Teal states held\nMay 2026 primaries", ha="left",
            va="center", fontsize=pal["base"], color=pal["accent"],
            fontweight="bold", linespacing=1.4)
    ax.set_xlabel("% of the state's Claude conversations about politics",
                  fontsize=pal["base"] + 1, color=pal["axis"], labelpad=8)

    # --- panel 2: the two group averages, as change -------------------------
    ax2 = axes[1]
    groups = [(True, pal["accent"], f"May-primary states ({n[True]})"),
              (False, pal["muted"], f"Later-primary states ({n[False]})")]
    ax2.axvline(0, color=pal["axis"], lw=1.0, zorder=2)
    for y, (treated, col, lab) in enumerate(groups):
        chg = avg.may[treated] - avg.apr[treated]
        ax2.barh(y, chg, height=0.5, color=col, zorder=3)
        # A marker at zero as well as the bar: the later-primary change is
        # exactly 0.00, so without it that row would be blank.
        ax2.scatter(0, y, s=34, color=col, zorder=4)
        txt = "no change" if abs(chg) < 0.005 else f"{chg:+.2f} pp"
        ax2.text(max(chg, 0) + 0.006, y, txt, va="center", ha="left",
                 fontsize=pal["base"], fontweight="bold", color=col, zorder=5)
    ax2.set_yticks(range(len(groups)))
    ax2.set_yticklabels([g[2] for g in groups])
    ax2.set_ylim(len(groups) - 0.4, -0.6)
    ax2.set_xlim(-0.022, 0.172)
    ax2.set_xticks([0, 0.05, 0.10, 0.15])
    ax2.set_xticklabels(["0", "+0.05", "+0.10", "+0.15"])
    style_axes(ax2, pal)
    ax2.set_title("The two group averages, compared", loc="left",
                  fontsize=pal["base"] + 1, fontweight="bold", color="#1A1A18",
                  pad=7)
    ax2.set_xlabel("Change in the group's unweighted average, April to May (pp)",
                   fontsize=pal["base"] + 1, color=pal["axis"], labelpad=8)

    return ("Change in Politics-Topic Share, by State",
            "April to May 2026. States ordered by April share. March-primary "
            "states (TX, NC, IL)\nexcluded, as are states below the AEI privacy "
            "threshold in either month.")


def f7_spaghetti(axes, pal, fig):
    """Ported from code/make_did_spaghetti.R (D. Thompson) into the post's
    palette. Same data, same three panels, same y range."""
    d = _did_panel().assign(x=lambda t: np.where(t.post, 2, 1))
    means = d.groupby(["treat_may", "x"]).politics_broad.mean().reset_index()
    n = d.groupby("treat_may").state_po.nunique()

    def panel(ax, treated, light, dark, title, ylab):
        for st, g in d[d.treat_may == treated].groupby("state_po"):
            g = g.sort_values("x")
            ax.plot(g.x, g.politics_broad, color=light, lw=1.1, zorder=2)
        m = means[means.treat_may == treated].sort_values("x")
        ax.plot(m.x, m.politics_broad, color=dark, lw=2.8, zorder=4)
        ax.scatter(m.x, m.politics_broad, color=dark, s=52, zorder=5)
        ax.text(2.08, m.politics_broad.iloc[-1], "Average", color=dark,
                fontsize=pal["base"], fontweight="bold", va="center", zorder=5)
        ax.set_title(title, loc="left", fontsize=pal["base"] + 1,
                     fontweight="bold", color="#1A1A18", pad=7)
        if ylab:
            ax.set_ylabel(ylab, fontsize=pal["base"], color=pal["axis"], labelpad=8)

    panel(axes[0], True, pal["light"], pal["accent"],
          f"States with May 2026 primaries ({n[True]})", None)
    panel(axes[1], False, "#D6D5CC", pal["muted"],
          f"States with June-September primaries ({n[False]})",
          "% of the state's Claude conversations about politics")

    ax = axes[2]
    for treated, col, ls, lab, dy in ((True, pal["accent"], "-", "May primary", 0.028),
                                      (False, pal["muted"], (0, (4, 2)),
                                       "Later primary", -0.001)):
        m = means[means.treat_may == treated].sort_values("x")
        ax.plot(m.x, m.politics_broad, color=col, lw=2.8, ls=ls, zorder=4)
        ax.scatter(m.x, m.politics_broad, color=col, s=52, zorder=5)
        ax.text(2.08, m.politics_broad.iloc[-1] + dy, lab, color=col,
                fontsize=pal["base"], fontweight="bold", va="center")
    ax.set_title("The averages, compared", loc="left", fontsize=pal["base"] + 1,
                 fontweight="bold", color="#1A1A18", pad=7)

    for i, ax in enumerate(axes):
        style_axes(ax, pal, xgrid=False)
        ax.grid(axis="y", color=pal["grid"], linewidth=0.7, zorder=0)
        ax.tick_params(axis="y", length=3)
        ax.set_xticks([1, 2])
        # All three panels share one x axis; labelling each would collide with
        # the next panel's title.
        ax.set_xticklabels(["April 2026", "May 2026"] if i == len(axes) - 1
                           else ["", ""])
        ax.set_xlim(0.85, 2.75)
        ax.set_ylim(0.30, 0.75)
    return ("Politics-Topic Share Before and After a State's Primary",
            "Each thin line is one state; the bold line is the unweighted group "
            "average.\nMarch-primary states excluded; DC (1.0-1.1%) is above the "
            "plotted range.")


# --- registry ---------------------------------------------------------------
# rows: relative panel heights (number of bars). left: inches reserved for the
# y tick labels, plus the strip column where there is one.
FIGS = [
    dict(key="politics_in_context", fn=f0_context, out="post_01_F0_politics_in_context",
         w=9.6, h=7.6, rows=[1], left=2.2, bottom=0.66, memo=False),
    dict(key="topic_decomposition", fn=f1_topics, out="post_02_F1_topic_breakdown",
         w=9.4, h=5.4, rows=[3, 6], left=3.5, bottom=0.66, memo=True),
    dict(key="country_shares", fn=f2_countries, out="post_03_F2_country_shares",
         w=7.2, h=6.6, rows=[1], left=0.9, bottom=1.1, memo=True),
    dict(key="artifacts", fn=f3_artifacts, out="post_04_F3_artifacts",
         w=8.4, h=5.6, rows=[1], left=2.4, bottom=1.1, memo=True),
    dict(key="info_action", fn=f4_info_action, out="post_05_F4_info_vs_action",
         w=9.6, h=5.2, rows=[1], left=2.2, bottom=1.1, memo=False),
    dict(key="composition", fn=f5_composition, out="post_06_F5_how_conducted",
         w=10.6, h=5.8, rows=[3, 2, 6], left=4.6, bottom=0.66, memo=False),
    dict(key="politics_arrows", fn=f6_arrows, out="post_07_F6_politics_arrows",
         w=8.2, h=9.4, rows=[30, 2], left=2.6, bottom=0.66, memo=False,
         gap=1.15),   # room for panel 1's axis title above panel 2
    dict(key="did_spaghetti", fn=f7_spaghetti, out="post_08_F7_did_spaghetti",
         w=7.6, h=8.0, rows=[1, 1, 1], left=1.5, bottom=0.66, memo=False,
         head=1.72, gap=0.62),   # room for the per-panel titles
    dict(key="did_estimates", fn=f6_did, out="post_09_F8_did_estimates",
         w=9.8, h=4.6, rows=[2, 4], left=3.4, bottom=0.66, memo=False),
    dict(key="null_distribution", fn=f7_null, out="post_10_F9_null_distribution",
         w=8.4, h=5.0, rows=[1], left=1.0, bottom=0.66, memo=True),
]


def render(spec, pal, branded, path):
    plt.rcParams["font.family"] = pal["family"]
    # Keep the mathtext $t$ in the figure face; the default fontset is a
    # serif and shows up as an obvious mismatch in titles and axis labels.
    plt.rcParams["mathtext.fontset"] = "custom"
    plt.rcParams["mathtext.rm"] = pal["family"]
    plt.rcParams["mathtext.it"] = f"{pal['family']}:italic"
    fig, axes, W, H = make_canvas(spec["w"], spec["h"], spec["rows"], pal,
                                  branded, spec["left"], spec["bottom"],
                                  spec.get("head"), spec.get("gap", 0.35))
    title, subtitle = spec["fn"](axes, pal, fig)
    finish(fig, W, H, pal, title, subtitle, branded)
    fig.savefig(path, dpi=DPI, facecolor=pal["bg"])
    plt.close(fig)


def main():
    POST.mkdir(parents=True, exist_ok=True)
    assert LOGO.exists(), f"missing logo: {LOGO}"

    # Retire the assets of the earlier table-based layout, which used a
    # different numbering and would otherwise be dragged into the doc beside
    # their replacements. Deleting by an EXPLICIT list, never by exclusion:
    # output/post/ also holds figures owned by other scripts (e.g.
    # 05_cross_release_series.R) and a delete-what-I-do-not-recognise rule
    # destroys them.
    stale = [
        "post_01_T1_topics.png", "post_02_F1_topic_decomposition.png",
        "post_04_T2_composition.png", "post_05_F3_artifacts.png",
        "post_06_T3_artifacts.png", "post_07_T4_info_action_by_topic.png",
        "post_08_T5_did.png", "post_09_T6_specificity.png",
        "post_10_F4_null_distribution.png", "post_11_T7_null_top.png",
        "fig_politics_in_context.pdf", "_tex",
        # superseded when Dan's two figures were slotted in ahead of these
        "post_07_F6_did_estimates.png", "post_08_F7_null_distribution.png",
    ]
    for name in stale:
        p = POST / name
        if p.exists():
            shutil.rmtree(p) if p.is_dir() else p.unlink()
            print(f"[fig] retired {name}")

    for spec in FIGS:
        render(spec, FS, True, POST / f"{spec['out']}.png")
        if spec["memo"]:
            render(spec, MEMO_PAL, False, MEMO / f"fig_{spec['key']}.pdf")

    n_memo = sum(s["memo"] for s in FIGS)
    print(f"[fig] {len(FIGS)} branded PNGs -> {POST}")
    print(f"[fig] {n_memo} plain PDFs -> {MEMO}")
    for s in FIGS:
        kb = (POST / f"{s['out']}.png").stat().st_size // 1024
        print(f"      {s['out']}.png  {kb} KB")


if __name__ == "__main__":
    main()
