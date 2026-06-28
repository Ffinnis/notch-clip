# Notch Clip

Notch Clip is a macOS menu-bar clipboard history app that appears from the notch area, keeps recent clipboard items locally, and supports pinned history.

## Development

Open `notch-clip.xcodeproj` in Xcode or run the unit tests from the command line:

```sh
rtk xcodebuild test -project notch-clip.xcodeproj -scheme notch-clip -destination 'platform=macOS' -only-testing:notch-clipTests
```

The full scheme currently includes UI tests that may fail to bootstrap on local macOS runners. CI runs the unit test target only.

## Updates

The app uses Sparkle 2 for GitHub-hosted auto-updates.

- Feed URL: `https://ffinnis.github.io/notch-clip/appcast.xml`
- Release archives: GitHub Releases in `Ffinnis/notch-clip`
- App menu action: `Check for Updates...`

Sparkle update archives are signed with an EdDSA key. The public key is stored in the app target settings. The private key must stay out of git and is expected in GitHub Actions as `SPARKLE_PRIVATE_KEY`.

## Release Secrets

The release workflow expects these repository secrets:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `KEYCHAIN_PASSWORD`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_KEY_P8_BASE64`
- `SPARKLE_PRIVATE_KEY`

Create a release by pushing a version tag:

```sh
git tag v1.0.1
git push origin v1.0.1
```
