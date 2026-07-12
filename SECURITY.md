# Security Policy

## Supported versions

Only the **latest release line** receives security maintenance. On a relevant
Qt CVE (high/critical affecting the pinned Qt version) we bump Qt, rebuild,
and publish a patch tag (e.g. `v2026.2.1`). Older tags stay downloadable but
are explicitly unmaintained.

## Web Runtime specifics

The Clayground Web Runtime (`clayground.wasm` + starter bundle) statically
bundles Qt. Two automated checks watch it:

- **Release gate**: every release build checks the pinned Qt version against
  published CVEs (NVD). An unwaived high/critical finding fails the runtime
  upload. To consciously accept a finding, add its CVE id to the
  `QT_CVE_WAIVE` repository variable (comma-separated) - that acceptance is
  visible and auditable.
- **Monthly watch** (`security-watch.yml`): checks the Qt version recorded in
  the latest release's `RUNTIME-MANIFEST.json` and opens a tracker issue on
  findings.

**Deployed games are static files.** A runtime security fix does not reach
already-deployed games automatically - creators must re-copy the runtime
bundle into their site. The browser sandbox (plus the cross-origin isolation
the runtime requires) contains most memory-safety CVE classes, but treat
that as mitigation, not policy.

JavaScript dependencies (`coi-serviceworker.js`, docs-site scripts) are
covered by Dependabot alerts.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting on this repository
(Security tab → "Report a vulnerability"). Expect an initial response within
two weeks - this is a solo-maintained project.
