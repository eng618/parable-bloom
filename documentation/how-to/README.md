# 🛠️ How-To Guides

How-To Guides are **task-oriented** recipes that guide you step-by-step through solving specific, real-world development and operational problems in Parable Bloom.

They assume you already understand the basics and want to achieve a concrete goal.

---

## Available Guides

### 1. [Automated Release Process](release-process.md)

Step-by-step procedure for preparing and releasing new versions across platforms:

- Version bumping via Conventional Commits and Nx Release.
- Automated changelog generation.
- Fastlane execution and CI/CD pipelines.
- Bitwarden Secrets Manager (`bws`) credential injection.

### 2. [Store Onboarding Checklist](store-onboarding.md)

Step-by-step instructions for App Store Connect and Google Play Console release preparation:

- Data safety, privacy policy, and content rating questionnaires.
- Category selection and store listing prerequisites.

### 3. [Level Generation and Resilience Management](level-generation.md)

How to generate, render, validate, and repair puzzle levels:

- Running batch module generation via Go CLI.
- Handling generator resilience, backtracking, and circuit breakers.
- Recovering and repairing corrupted level JSON files.

### 4. [App Store Listings & Marketing](app-store-listings/README.md)

Guides for preparing store listings, marketing copy, and screenshots:

- [Best Practices](app-store-listings/best-practices.md)
- [Compliance](app-store-listings/compliance.md)
- [Marketing](app-store-listings/marketing.md)
- [Visual Assets](app-store-listings/visual-assets.md)

---

## Diátaxis Navigation

- **[Tutorials](../tutorials/README.md)** — Hands-on learning
- **[How-To Guides](../how-to/README.md)** (You are here) — Practical problem-solving recipes
- **[Reference](../reference/README.md)** — Technical specifications & schemas
- **[Explanation](../explanation/README.md)** — Architecture & design discussions
