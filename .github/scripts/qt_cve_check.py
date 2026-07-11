#!/usr/bin/env python3
"""Check the pinned Qt version against published CVEs (NVD).

Used by the monthly security watch and as a release quality gate for the
Clayground Web Runtime (see SECURITY.md).

Usage:
    qt_cve_check.py --qt 6.10.1 [--fail-on high|critical] [--waive CVE-a,CVE-b]

Waived CVE ids (also read from env QT_CVE_WAIVE, comma-separated) are
reported but do not fail the check - that is the explicit "I looked at this
and accept it for this release" mechanism.

Exit codes: 0 = clean (or all findings waived), 2 = unwaived findings,
1 = error (treat as failure - the check could not run).
"""
import argparse
import json
import os
import sys
import urllib.parse
import urllib.request

NVD_API = "https://services.nvd.nist.gov/rest/json/cves/2.0"
SEVERITY_RANK = {"LOW": 0, "MEDIUM": 1, "HIGH": 2, "CRITICAL": 3}


def fetch_cves(qt_version):
    cpe = f"cpe:2.3:a:qt:qt:{qt_version}"
    url = NVD_API + "?" + urllib.parse.urlencode({"virtualMatchString": cpe})
    req = urllib.request.Request(url, headers={"User-Agent": "clayground-cve-check"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def severity_of(cve):
    metrics = cve.get("metrics", {})
    for key in ("cvssMetricV31", "cvssMetricV30", "cvssMetricV2"):
        for m in metrics.get(key, []):
            sev = m.get("cvssData", {}).get("baseSeverity") or m.get("baseSeverity")
            if sev:
                return sev.upper()
    return "UNKNOWN"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--qt", required=True, help="Qt version, e.g. 6.10.1")
    ap.add_argument("--fail-on", default="high", choices=["high", "critical"])
    ap.add_argument("--waive", default="")
    args = ap.parse_args()

    waived = {c.strip() for c in
              (args.waive + "," + os.environ.get("QT_CVE_WAIVE", "")).split(",")
              if c.strip()}
    threshold = SEVERITY_RANK["HIGH" if args.fail_on == "high" else "CRITICAL"]

    try:
        data = fetch_cves(args.qt)
    except Exception as e:
        print(f"ERROR: NVD query failed: {e}", file=sys.stderr)
        return 1

    findings = []
    for item in data.get("vulnerabilities", []):
        cve = item.get("cve", {})
        sev = severity_of(cve)
        if SEVERITY_RANK.get(sev, 0) >= threshold:
            findings.append((cve.get("id", "?"), sev))

    print(f"## Qt {args.qt} CVE check")
    print()
    total = data.get("totalResults", 0)
    print(f"NVD lists {total} CVE(s) matching Qt {args.qt}; "
          f"{len(findings)} at {args.fail_on}+ severity.")
    unwaived = []
    for cve_id, sev in findings:
        mark = " (waived)" if cve_id in waived else ""
        print(f"- **{cve_id}** [{sev}]{mark} - "
              f"https://nvd.nist.gov/vuln/detail/{cve_id}")
        if cve_id not in waived:
            unwaived.append(cve_id)

    if unwaived:
        print()
        print(f"{len(unwaived)} unwaived finding(s). Bump Qt or waive "
              f"explicitly via the QT_CVE_WAIVE repository variable.")
        return 2
    print()
    print("Clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
