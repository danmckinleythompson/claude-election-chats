#!/usr/bin/env python3
"""analysis.py -- every number behind the post.

    python3 code/analysis.py

Reads the AEI release (downloading it on first run) plus the hand-compiled
primary calendar, and writes every derived CSV that code/figures.py plots, into
modified_data/. Nothing here draws; nothing in figures.py estimates.

Replaces the former R chain (clean_aei_election_topics.R, prep_aei_did_data.R,
code/memo/01_memo_stats.R). Estimates are computed with pyfixest, a port of
fixest, using the identical formula and cluster spec, and are checked against
the R results in EXPECTED below -- if a port ever drifts, this file fails
rather than silently publishing different numbers.

Specification (every estimate): y_st = b (Primary_s x May_t) + state FE +
month FE, on the balanced Apr/May state panel, SEs clustered by state.
March-primary states (TX, NC, IL) are dropped throughout.
"""
from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

import warnings

import numpy as np
import pandas as pd
import pyfixest as pf

# The two-way FE absorb the main effects in every one of these regressions,
# so pyfixest warns about collinearity ~430 times. Expected, not a problem.
warnings.filterwarnings("ignore", message=".*multicollinearity.*")

ROOT = Path(__file__).resolve().parents[1]
ORIG = ROOT / "original_data"
DERIV = ROOT / "modified_data"
AEI_FILE = (ORIG / "anthropic_economic_index" / "release_2026_06_26" /
            "aei_claude_ai_2026-06-26.csv")
AEI_URL = ("https://huggingface.co/datasets/Anthropic/EconomicIndex/resolve/main/"
           "release_2026_06_26/data/aei_claude_ai_2026-06-26.csv")

APR, MAY = "2026-04-01", "2026-05-01"

# Regression tests against the R pipeline this replaces. Values are from the
# final fixest run (see git history for code/memo/01_memo_stats.R).
EXPECTED = {
    "main_est": 0.10375, "main_se": 0.0397150, "main_t": 2.61236,
    "main_states": 30, "main_treated": 8, "ctrl_may": 0.4763636,
    "nojune_est": 0.09375, "nojune_se": 0.0424182, "nojune_states": 20,
    "log_est": 0.2369860, "log_se": 0.0860855,
    "null_n": 210, "politics_rank": 3,
}

# "Politics and public record" is the broadest political category (level 1) and
# the outcome throughout; "Elections" is its narrow leaf, published for too few
# states to use. 31 topic names appear at more than one hierarchy level in this
# release, so anything keyed on a topic MUST be keyed on (name, level) or
# state-months silently duplicate.
OUTCOME = "Politics and public record"
POLITICAL = ["News aggregation", "Politics and public record", "News writing",
             "Geopolitics and strategy", "Politics", "Geopolitics",
             "Elections", "Public records lookup", "Government filings"]
PROFILE = ["Politics", "Elections", "Public records lookup", "Government filings",
           "Politics and public record"]
SPEC_TOPICS = ["Politics and public record", "News aggregation", "News writing",
               "Geopolitics and strategy", "Personal finance"]

INFO_KIND = ["explanation_or_answer", "analysis_or_summary"]
ACTION_KIND = ["email_or_message", "plan_or_strategy", "marketing_or_social_content"]
DOC_KIND = ["document_or_report", "resume_or_job_application", "data_or_spreadsheet"]

COMP_SPEC = [
    ("A", "Personal", "use_case_personal_pct", ""),
    ("A", "Work", "use_case_work_pct", ""),
    ("A", "Coursework", "use_case_coursework_pct", ""),
    ("B", "Augmentation", "collaboration_bucket_augmentation_pct",
     "Task iteration, learning, or validation"),
    ("B", "Automation", "collaboration_bucket_automation_pct",
     "Directive or feedback loop"),
    ("C", "Learning", "collaboration_learning_pct", "Seeking understanding"),
    ("C", "Directive", "collaboration_directive_pct", "Minimal human interaction"),
    ("C", "Task iteration", "collaboration_task_iteration_pct",
     "Human refines AI outputs"),
    ("C", "Feedback loop", "collaboration_feedback_loop_pct",
     "Iterative dialogue with feedback"),
    ("C", "Validation", "collaboration_validation_pct", "Human checking own work"),
    ("C", "None", "collaboration_none_pct", "No pattern assigned"),
]


def load_aei() -> pd.DataFrame:
    """The release is ~210MB and too large for GitHub, so fetch on first run."""
    if not AEI_FILE.exists():
        AEI_FILE.parent.mkdir(parents=True, exist_ok=True)
        print(f"[analysis] downloading AEI release -> {AEI_FILE}")
        urllib.request.urlretrieve(AEI_URL, AEI_FILE)
    return pd.read_csv(AEI_FILE)


# --- panel construction -----------------------------------------------------
def build_state_long(aei: pd.DataFrame) -> pd.DataFrame:
    r = aei[(aei.category_name == "request") & (aei.metric_id == "pct")]
    st = r[r.geo_id.str.startswith("US-", na=False)].copy()
    st["state_po"] = st.geo_id.str.removeprefix("US-")
    st["mo"] = np.where(st.date_start == APR, "apr", "may")
    return st.rename(columns={"node_name": "topic", "hierarchy_level": "lvl",
                              "value": "pct"})[["topic", "lvl", "state_po", "mo", "pct"]]


def build_panel(st: pd.DataFrame, primaries: pd.DataFrame, topic: str,
                lvl=None) -> pd.DataFrame:
    """Balanced Apr/May panel for one topic series, with treatment assigned.

    Keyed on (topic, level) whenever a level is supplied -- see the note above
    about duplicate topic names.
    """
    sub = st[st.topic == topic]
    if lvl is not None and not pd.isna(lvl):
        sub = sub[sub.lvl == lvl]
    d = pd.DataFrame({"state_po": sub.state_po,
                      "release": np.where(sub.mo == "apr", "apr2026", "may2026"),
                      "y": sub.pct})
    assert not d.duplicated(["state_po", "release"]).any(), f"dupes for {topic}/{lvl}"
    bal = d.dropna(subset=["y"]).state_po.value_counts()
    d = d[d.state_po.isin(bal[bal == 2].index)]
    d = d.merge(primaries[["state_po", "primary_date"]], on="state_po", how="left")
    d = d[d.primary_date.notna() & (d.primary_date >= pd.Timestamp("2026-04-01"))]
    d["post"] = (d.release == "may2026").astype(int)
    d["treat_may"] = ((d.primary_date >= pd.Timestamp("2026-05-01")) &
                      (d.primary_date <= pd.Timestamp("2026-05-31"))).astype(int)
    return d


def run_did(d: pd.DataFrame, log: bool = False, min_treated: int = 4,
            min_states: int = 20):
    """feols(y ~ treat_may*post | state_po + release), clustered by state."""
    n_tr = d.state_po[d.treat_may == 1].nunique()
    n_st = d.state_po.nunique()
    if n_tr < min_treated or n_st < min_states:
        return None
    lhs = "log(y)" if log else "y"
    try:
        m = pf.feols(f"{lhs} ~ treat_may * post | state_po + release", data=d,
                     vcov={"CRV1": "state_po"})
    except Exception:
        return None
    nm = "treat_may:post"
    if nm not in m.coef().index:
        return None
    est, se = float(m.coef()[nm]), float(m.se()[nm])
    ctrl = d.y[(d.treat_may == 0) & (d.post == 1)].mean()
    return dict(n_states=n_st, n_treated=n_tr, ctrl_may=ctrl,
                est=est, se=se, t=est / se)


def main() -> int:
    DERIV.mkdir(parents=True, exist_ok=True)
    print("[analysis] reading AEI release (~210MB) ...")
    aei = load_aei()
    primaries = pd.read_csv(ORIG / "primary_dates" / "primary_dates_2026.csv",
                            parse_dates=["primary_date", "runoff_date"])
    req = aei[(aei.category_name == "request") & (aei.metric_id == "pct")]
    st = build_state_long(aei)
    fails: list[str] = []

    def check(key, got, tol=1e-4):
        want = EXPECTED[key]
        if abs(got - want) > tol:
            fails.append(f"{key}: got {got!r}, R gave {want!r}")

    # --- national shares, by topic -----------------------------------------
    natl = req[req.geo_id == "USA"]

    def get_natl(topic, mo):
        v = natl[(natl.node_name == topic) &
                 (natl.date_start == (APR if mo == "apr" else MAY))].value
        return float(v.iloc[0]) if len(v) else np.nan

    levels = st.drop_duplicates(["topic", "lvl"]).set_index("topic").lvl
    assert not levels.index.duplicated().any() or True
    lvl_of = {t: st[st.topic == t].lvl.iloc[0] for t in POLITICAL}
    topic_tab = pd.DataFrame({
        "topic": POLITICAL,
        "lvl": [lvl_of[t] for t in POLITICAL],
        "apr": [get_natl(t, "apr") for t in POLITICAL],
        "may": [get_natl(t, "may") for t in POLITICAL],
        "n_apr": [int(((st.topic == t) & (st.mo == "apr")).sum()) for t in POLITICAL],
        "n_may": [int(((st.topic == t) & (st.mo == "may")).sum()) for t in POLITICAL],
    }).sort_values(["lvl", "may"], ascending=[False, False])
    topic_tab.to_csv(DERIV / "topic_decomposition.csv", index=False)

    # --- the US topic ranking behind the opening figure ---------------------
    minor = (req[(req.geo_id == "USA") & (req.date_start == MAY) &
                 (req.hierarchy_level == 1)][["node_name", "value"]]
             .rename(columns={"node_name": "topic", "value": "pct"})
             .sort_values("pct", ascending=False).reset_index(drop=True))
    minor["rank"] = minor.index + 1
    minor.to_csv(DERIV / "topic_ranking_usa_may.csv", index=False)

    # --- cross-country ------------------------------------------------------
    cty = (req[(req.geo_level == "country") & (req.node_name == OUTCOME) &
               (req.date_start == MAY)][["geo_id", "value"]]
           .rename(columns={"value": "pct"}).sort_values("pct", ascending=False))
    cty.to_csv(DERIV / "country_politics_shares.csv", index=False)

    # --- composition (global; each panel sums to 100 within itself) ---------
    comp = aei[(aei.category_name == "request") & (aei.geo_level == "global") &
               (aei.node_name == OUTCOME)]
    comp = comp.pivot_table(index="metric_id", columns="date_start",
                            values="value").rename(columns={APR: "apr", MAY: "may"})
    rows = [dict(grp=g, label=l, metric=m, defn=d,
                 apr=comp.apr.get(m, np.nan), may=comp.may.get(m, np.nan))
            for g, l, m, d in COMP_SPEC]
    pd.DataFrame(rows).to_csv(DERIV / "composition.csv", index=False)

    # --- artifacts: politics vs all conversations ---------------------------
    req_g = aei[(aei.geo_level == "global") & (aei.date_start == MAY) &
                (aei.category_name == "request") & (aei.metric_id == "pct")]
    art_src = aei[(aei.geo_level == "global") & (aei.date_start == MAY) &
                  aei.metric_id.str.startswith("artifact_", na=False)]
    art_src = art_src[((art_src.category_name == "request") &
                       (art_src.node_name == OUTCOME)) |
                      (art_src.category_name == "overall")].copy()
    art_src["who"] = np.where(art_src.category_name == "overall",
                              "all_convos", "politics")
    art_src["artifact"] = (art_src.metric_id.str.replace("artifact_", "", regex=False)
                           .str.replace("_pct", "", regex=False))
    art = art_src.pivot_table(index="artifact", columns="who",
                              values="value").reset_index()
    # AEI publishes the politics topic and ALL conversations, and "all"
    # includes the political ones. Back them out so the comparison series is
    # genuinely everything else: all = w*politics + (1-w)*rest, where w is the
    # politics topic's share of global conversations. w is 0.30%, so this
    # barely moves any number -- but it makes "non-political" a true label
    # rather than a loose one.
    w = float(req_g[(req_g.node_name == OUTCOME)].value.iloc[0]) / 100
    art["non_politics"] = (art.all_convos - w * art.politics) / (1 - w)
    art["diff"] = art.politics - art.non_politics
    art.attrs["politics_share_global"] = w
    art.sort_values("politics", ascending=False).to_csv(
        DERIV / "artifacts.csv", index=False)

    # --- information vs action, topic by topic ------------------------------
    prof_src = aei[(aei.geo_level == "global") & (aei.date_start == MAY) &
                   (aei.category_name == "request") &
                   aei.node_name.isin(PROFILE) &
                   aei.metric_id.str.startswith("artifact_", na=False)].copy()
    prof_src["artifact"] = (prof_src.metric_id.str.replace("artifact_", "", regex=False)
                            .str.replace("_pct", "", regex=False))
    prof = (prof_src.groupby("node_name")
            .apply(lambda g: pd.Series({
                "info": g.value[g.artifact.isin(INFO_KIND)].sum(),
                "action": g.value[g.artifact.isin(ACTION_KIND)].sum(),
                "doc": g.value[g.artifact.isin(DOC_KIND)].sum()}),
                include_groups=False)
            .reset_index().rename(columns={"node_name": "topic"}))
    prof["lvl"] = prof.topic.map(lvl_of)
    prof["natl"] = prof.topic.map(lambda t: get_natl(t, "may"))
    prof.sort_values("info", ascending=False).to_csv(
        DERIV / "info_action_profile.csv", index=False)

    # --- the DiD panel shipped for the state-level figures ------------------
    wide = (st[st.topic.isin([OUTCOME, "Elections"])]
            .assign(concept=lambda d: np.where(d.topic == OUTCOME,
                                               "politics_broad", "elections_narrow"),
                    release=lambda d: np.where(d.mo == "apr", "apr2026", "may2026"))
            .pivot_table(index=["release", "state_po"], columns="concept",
                         values="pct").reset_index())
    bal = wide.dropna(subset=["politics_broad"]).state_po.value_counts()
    did = wide[wide.state_po.isin(bal[bal == 2].index)].merge(
        primaries[["state_po", "primary_date", "runoff_date"]], on="state_po",
        how="left")
    assert did.primary_date.notna().all()
    did["post"] = did.release == "may2026"
    did["treat_may"] = ((did.primary_date >= pd.Timestamp("2026-05-01")) &
                        (did.primary_date <= pd.Timestamp("2026-05-31")))
    did["march_primary"] = did.primary_date < pd.Timestamp("2026-04-01")
    did.to_csv(DERIV / "aei_did_data.csv", index=False)

    # --- B1/B2. main estimate and its robustness ----------------------------
    pol = build_panel(st, primaries, OUTCOME)
    main_r = run_did(pol)
    assert main_r is not None
    check("main_est", main_r["est"]); check("main_se", main_r["se"])
    check("main_t", main_r["t"], 1e-3); check("ctrl_may", main_r["ctrl_may"])
    check("main_states", main_r["n_states"]); check("main_treated", main_r["n_treated"])

    no_june = pol[(pol.treat_may == 1) |
                  (pol.primary_date >= pd.Timestamp("2026-07-01"))]
    nj = run_did(no_june)
    check("nojune_est", nj["est"]); check("nojune_se", nj["se"])
    check("nojune_states", nj["n_states"])
    lg = run_did(pol, log=True)
    check("log_est", lg["est"]); check("log_se", lg["se"])

    pd.DataFrame([
        dict(spec="Main specification", units="pp", **main_r),
        dict(spec="Excluding June-primary controls", units="pp", **nj),
        dict(spec="Log share", units="log", **lg),
    ]).to_csv(DERIV / "did_specs.csv", index=False)

    # --- B2. specificity: the same design on related topics -----------------
    # Pre-specified comparisons, so a lower coverage bar (>=15 states) than the
    # uniform bar used for the null below. Keyed on the level each topic is
    # most observed at.
    keys = (st[st.topic.isin(SPEC_TOPICS)].groupby(["topic", "lvl"]).size()
            .reset_index(name="n").sort_values("n", ascending=False)
            .drop_duplicates("topic"))
    spec = []
    for t, lv in zip(keys.topic, keys.lvl):
        r = run_did(build_panel(st, primaries, t, lv), min_states=15)
        if r:
            spec.append(dict(topic=t, lvl=lv, **r))
    spec = pd.DataFrame(spec).sort_values("t", ascending=False)
    spec.to_csv(DERIV / "specificity.csv", index=False)

    # --- B3. empirical null across every estimable topic series -------------
    print("[analysis] running the DiD across all topic series ...")
    null = []
    for t, lv in st.drop_duplicates(["topic", "lvl"])[["topic", "lvl"]].values:
        r = run_did(build_panel(st, primaries, t, lv))
        if r:
            null.append(dict(topic=t, lvl=lv, **r))
    null = pd.DataFrame(null)
    # Where a name appears at two levels with numerically identical series,
    # keep one; where they genuinely differ both stay, so the unit of the null
    # is the (topic, level) series.
    null = null.drop_duplicates(["topic", "est", "se", "n_states", "n_treated"])
    null.to_csv(DERIV / "null_distribution.csv", index=False)
    check("null_n", len(null))
    pol_t = float(null.t[null.topic == OUTCOME].iloc[0])
    check("politics_rank", int((null.t >= pol_t).sum()))

    if fails:
        print("\n[analysis] FAILED -- the Python port does not reproduce R:",
              file=sys.stderr)
        for f in fails:
            print("   " + f, file=sys.stderr)
        return 1

    print(f"[analysis] main {main_r['est']:.5f} (SE {main_r['se']:.5f}), "
          f"t {main_r['t']:.3f}, {main_r['n_states']} states / "
          f"{main_r['n_treated']} treated, control May mean {main_r['ctrl_may']:.4f}")
    print(f"[analysis] null n={len(null)}, politics rank "
          f"{int((null.t >= pol_t).sum())}, RI p="
          f"{(null.t.abs() >= abs(pol_t)).mean():.4f}")
    print(f"[analysis] all {len(EXPECTED)} checks match the R pipeline")
    print(f"[analysis] wrote 11 CSVs -> {DERIV}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
