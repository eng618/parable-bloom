fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Deploy a new version to the Google Play Console (Internal Testing)

### android beta

```sh
[bundle exec] fastlane android beta
```

Deploy to Google Play Console Beta Track

### android promote_to_beta

```sh
[bundle exec] fastlane android promote_to_beta
```

Promote Internal to Beta

### android production

```sh
[bundle exec] fastlane android production
```

Deploy to Production

### android build_release

```sh
[bundle exec] fastlane android build_release
```

Build release bundle only (no upload)

### android validate

```sh
[bundle exec] fastlane android validate
```

Validate bundle before upload

### android screenshots

```sh
[bundle exec] fastlane android screenshots
```

Generate Play Store screenshots via Flutter integration test

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
