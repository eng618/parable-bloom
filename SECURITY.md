# Security Policy

## Supported Versions

Only the latest release (tag `v*`) and the `main` branch are supported.
`develop` and feature branches receive fixes by merging forward into `main`;
no security patches are backported to older tags.

| Version              | Supported          |
| -------------------- | ------------------ |
| latest `v*` / `main` | :white_check_mark: |
| older tags           | :x:                |

## Scope

In scope for reports:

- `apps/parable-bloom` — Flutter game (auth, Firestore access, local storage, OTA config handling)
- `apps/parable-bloom-site` — Next.js marketing/legal site (privacy, terms, support, account-deletion flows)
- `tools/level-builder` — level generation/validation tooling
- `apps/parable-bloom/firestore.rules` — Firestore security rules
- `.github/workflows/` — CI/CD pipelines and secret handling
- Supply chain: `pubspec.yaml` / `package.json` / `go.mod` dependencies

Out of scope: Firebase/GCP platform issues (report to Google), third-party
store infrastructure (Play Console, App Store Connect), and social-engineering
or physical-security reports.

## Reporting a Vulnerability

**Do not open a public issue.** Instead:

1. Email [security@garciaericn.com](mailto:security@garciaericn.com) with:
   - Affected component and version/commit
   - Steps to reproduce or proof of concept
   - Impact assessment (what data or users are at risk)
   - Any relevant logs (redact credentials and PII)
2. Alternatively, use **GitHub Security Advisories** (Report a vulnerability)
   for private disclosure with credit.

### Response SLA

Solo-maintainer project; best-effort targets:

- Acknowledgment within **3 business days**
- Triage and severity assessment within **7 days**
- Fix for **critical** issues (auth bypass, data exposure, RCE) within **14 days**,
  shipped to `main` and released; reporters are notified before public disclosure
- We ask for **90 days** coordinated disclosure for non-critical issues

There is no bug bounty program. Good-faith researchers who follow this policy
will be credited in release notes on request.

## Store & Data-Deletion Contacts

For Play/App Store review or user-data matters (not vulnerabilities), use:

- Support: [parablebloom.support@garciaericn.com](mailto:parablebloom.support@garciaericn.com)
  / [support page](https://parable-bloom.pages.dev/support)
- Account deletion: in-app Settings → Delete Account, or
  [delete-account page](https://parable-bloom.pages.dev/delete-account)
- Privacy questions: see the [privacy policy](https://parable-bloom.pages.dev/privacy)

## Secrets Hygiene

Committed Firebase client configs (`google-services.json`,
`GoogleService-Info.plist`) are public-by-design client identifiers, not
server secrets. Release signing keys, Play service-account JSON, and the
Firebase service-account key live in Bitwarden / GitHub Secrets and must never
be committed. If you suspect a secret leaked, report it as a vulnerability
immediately so it can be rotated.
