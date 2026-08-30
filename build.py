#!/usr/bin/env python3
"""Reads data.json (written by collect.sh) and emits a self-contained index.html."""
import json, os, re, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
raw = json.load(open(os.path.join(HERE, "data.json")))

STAGE_ORDER = ["changes", "cosine_similarity", "similarity", "tier1", "review",
               "ava_review", "deep_review", "adversarial_review", "qc_eval",
               "qc_exec", "qc_gate", "validation", "ratelimit", "pass2",
               "pass2_suggestion", "trials", "gate", "claude-cost-report"]

def stage_key(name):
    short = name.split("/")[-1].strip()
    return (STAGE_ORDER.index(short) if short in STAGE_ORDER else 99, short)

def state_of(c):
    if c.get("status") != "COMPLETED":
        return "running"
    return {"SUCCESS": "pass", "FAILURE": "fail", "SKIPPED": "skip",
            "CANCELLED": "skip", "TIMED_OUT": "fail", "NEUTRAL": "skip",
            "ACTION_REQUIRED": "fail"}.get(c.get("conclusion") or "", "skip")

rows = []
for r in raw["repos"]:
    slug = r["repo"].split("/")[-1]
    m = re.match(r"dynamo-([0-9a-f]+)-(.+)", slug)
    tid, cat = (m.group(1), m.group(2).replace("-", " ")) if m else (slug, "")
    prs = sorted(r["prs"], key=lambda p: p["number"], reverse=True)
    if not prs:
        rows.append({"id": tid, "cat": cat, "repo": r["repo"], "url": r["url"],
                     "status": "nopr", "pr": None, "stages": [], "others": [],
                     "foreign": r.get("foreign", [])})
        continue
    pr = prs[0]
    checks = sorted(pr.get("statusCheckRollup") or [], key=lambda c: stage_key(c["name"]))
    stages = [{"n": c["name"].split("/")[-1].strip(), "s": state_of(c),
               "u": c.get("detailsUrl", "")} for c in checks]
    if any(s["s"] == "fail" for s in stages):
        status = "fail"
    elif any(s["s"] == "running" for s in stages):
        status = "running"
    elif stages:
        status = "pass"
    else:
        status = "nochecks"
    gate = next((s["s"] for s in stages if s["n"] == "gate"), None)
    rows.append({
        "id": tid, "cat": cat, "repo": r["repo"], "url": r["url"], "status": status,
        "gate": gate,
        "pr": {"n": pr["number"], "t": pr["title"], "state": pr["state"],
               "url": pr["url"], "branch": pr["headRefName"],
               "updated": pr["updatedAt"], "draft": pr.get("isDraft", False)},
        "stages": stages,
        "others": [{"n": p["number"], "state": p["state"], "url": p["url"],
                    "t": p["title"]} for p in prs[1:]],
        "foreign": r.get("foreign", []),
    })

# newest activity first; repos with no PR of yours sink to the bottom
rows.sort(key=lambda r: (r["pr"] is None, r["pr"]["updated"] if r["pr"] else ""),
          reverse=False)
rows.sort(key=lambda r: r["pr"]["updated"] if r["pr"] else "", reverse=True)
rows.sort(key=lambda r: r["pr"] is None)

payload = json.dumps({"generated": raw["generated"], "rows": rows},
                     separators=(",", ":"))

TPL = open(os.path.join(HERE, "template.html")).read()
open(os.path.join(HERE, "index.html"), "w").write(TPL.replace("/*__DATA__*/null", payload))
print("wrote index.html  (%d repos)" % len(rows))
