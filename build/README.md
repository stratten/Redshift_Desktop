# Redshift Build Resources

This directory contains all resources needed for building and signing Redshift.

## Structure

```
build/
├── icon.icns                      # Application icon (generated)
├── entitlements.mac.plist         # macOS entitlements (USB, network, etc.)
├── scripts/                       # Build and signing scripts
│   ├── build_and_sign.sh         # Master build orchestrator
│   ├── deep_sign_app.sh          # Deep signs all nested binaries
│   ├── afterSign.js              # electron-builder hook
│   ├── notarize_app.sh           # Submits to Apple for notarization
│   └── test_signing.sh           # Verifies signing process
└── README.md                      # This file
```

## Quick Start

### Full Build with Signing

```bash
./build/scripts/build_and_sign.sh
```

### Build Without Notarization (faster)

```bash
./build/scripts/build_and_sign.sh --skip-notarize
```

### Test Signing on Existing Build

```bash
./build/scripts/test_signing.sh dist/mac/Redshift.app
```

## Scripts Reference

### `build_and_sign.sh`
Master script that orchestrates the complete build process.

**Usage:**
```bash
./build_and_sign.sh [options]

Options:
  --skip-build       Use existing build (only sign/notarize)
  --skip-notarize    Skip notarization (for testing)
  --arm64-only       Build only for Apple Silicon
  --x64-only         Build only for Intel
```

**What it does:**
1. Verifies Python runtime is bundled
2. Builds the Electron app
3. Deep signs all binaries
4. Creates DMG and ZIP distributables
5. Notarizes with Apple (optional)
6. Staples notarization tickets

### `deep_sign_app.sh`
Signs all nested binaries within the app bundle in the correct order.

**Usage:**
```bash
./deep_sign_app.sh <app_path> [--entitlements <path>]
```

**What it signs:**
- Python runtime binaries (.dylib, .so)
- Python dependencies (pymobiledevice3, etc.)
- Node.js native modules (.node files)
- Electron Helper apps
- Electron Framework
- Main app bundle

### `afterSign.js`
electron-builder hook that automatically runs deep signing during the build.

Called automatically by electron-builder. No manual invocation needed.

### `notarize_app.sh`
Submits the signed app to Apple for notarization.

**Usage:**
```bash
./notarize_app.sh <app_path> [--dmg <dmg_path>]
```

**Requirements:**
- App must be signed with Developer ID
- Hardened runtime enabled
- Credentials stored via:
  ```bash
  xcrun notarytool store-credentials "notarytool-password" \
    --apple-id "your-email" \
    --team-id "D4X8TSBQJC" \
    --password "app-specific-password"
  ```

### `test_signing.sh`
Tests the complete signing process on a built app.

**Usage:**
```bash
./test_signing.sh <app_path>
```

**What it tests:**
1. Deep signing of all binaries
2. Final app bundle signing
3. Signature verification
4. Gatekeeper assessment

## Signing Certificate

**Identity:** `Developer ID Application: Baobab Group LLC (D4X8TSBQJC)`

Verify it's in your keychain:
```bash
security find-identity -v -p codesigning
```

## Entitlements

The `entitlements.mac.plist` file grants:
- USB device access (for iOS devices)
- Network client/server (for WebSocket sync)
- File system access (user-selected files)
- Hardened runtime exceptions (for JIT, unsigned memory)

## Icon Generation

To regenerate the app icon:

```bash
cd ..
./scripts/create-icon.sh
```

Source: `Assets/Redshift Logo - Trimmed - 1024.png`

## Troubleshooting

### "No handler registered" errors during build

The native module rebuild is failing. This is expected - we skip rebuilds and use the existing modules.

### Signing fails for Python binaries

Ensure you're using the relocatable Python from `resources/python/`, not system Python.

### Notarization fails

Check credentials:
```bash
xcrun notarytool history --keychain-profile "notarytool-password"
```

### DMG not created

Check the electron-builder output in `dist/` directory. DMG creation may fail if disk space is low.

## Related Documentation

- `/BUILD_GUIDE.md` - Complete build documentation
- `/SIGNING_SETUP.md` - Code signing and notarization setup
- `/PYTHON_SETUP.md` - Bundled Python configuration

