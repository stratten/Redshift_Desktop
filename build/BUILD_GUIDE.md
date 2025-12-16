# Redshift Desktop - Build & Packaging Guide

## Prerequisites

1. **Node.js & npm** installed
2. **Relocatable Python** configured (see PYTHON_SETUP.md)
3. **Developer ID Application certificate** (for distribution outside Mac App Store)

## Initial Setup

### 1. Install Dependencies

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
npm install
```

### 2. Setup Bundled Python

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
./scripts/setup-python.sh
```

This downloads and configures the relocatable Python runtime and pymobiledevice3.

### 3. Verify Python Setup

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
ls -la resources/python/python/bin/python3
ls -la resources/python-deps/
```

Both directories should exist and be populated.

## Development Build

Run the app in development mode:

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
npm run dev
```

Or without HTML rebuild:

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
npm start
```

## Packaging for Distribution

### Option 1: Automated Build with Deep Signing (Recommended)

Use the master build script that handles the complete workflow in **one command**:

```bash
./build/scripts/build_and_sign.sh
```

This single command will:
1. Verify Python runtime is bundled
2. Build the Electron app (unsigned via `npm run pack`)
3. **Deep sign all nested binaries** (Python, Node modules, frameworks)
4. Sign the main app bundle with your Developer ID
5. Verify code signatures
6. **Create DMG file(s)** for distribution
7. Sign the DMG(s)
8. Notarize both app and DMG with Apple (if credentials configured)
9. Staple notarization tickets

**Build Options:**
```bash
# Build without notarization (faster, for testing)
./build/scripts/build_and_sign.sh --skip-notarize

# Build only ARM64 (Apple Silicon)
./build/scripts/build_and_sign.sh --arm64-only

# Build only x64 (Intel)
./build/scripts/build_and_sign.sh --x64-only

# Skip DMG creation (only create signed .app)
./build/scripts/build_and_sign.sh --skip-dmg

# Use existing build (skip npm build step, only sign/package)
./build/scripts/build_and_sign.sh --skip-build

# Combine options (common for testing)
./build/scripts/build_and_sign.sh --arm64-only --skip-notarize
```

### Option 2: Manual Build Process

#### Build the App

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
npm run build
```

This will:
1. Build the HTML templates (`build-html.js`)
2. Package the Electron app with electron-builder
3. **Automatically run deep signing** via afterSign hook
4. Bundle Python runtime and dependencies
5. Create distributable `.app`, DMG, and ZIP in `dist/`

#### Build for Testing (Unpacked)

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
npm run pack
```

Creates an unpacked app in `dist/mac/` for local testing.

## Code Signing & Notarization

### Deep Signing Architecture

Redshift uses a comprehensive deep signing process (adapted from Basil) to ensure all nested binaries are properly signed for notarization:

**Signing Order:**
1. Python runtime binaries (`.dylib`, `.so` files)
2. Python dependencies (pymobiledevice3, etc.)
3. Node.js native modules (`sqlite3.node`, `usb.node`)
4. Electron Helper apps
5. Electron Framework
6. Main app bundle

**Scripts:**
- `build/scripts/deep_sign_app.sh` - Deep signs all nested binaries
- `build/scripts/afterSign.js` - electron-builder hook that runs deep signing
- `build/scripts/test_signing.sh` - Verifies signing on a built app
- `build/scripts/notarize_app.sh` - Submits to Apple for notarization
- `build/scripts/build_and_sign.sh` - Master script orchestrating everything

### Automatic Signing

The build process automatically signs everything via the `afterSign` hook:

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
npm run build
# afterSign hook runs automatically after electron-builder packages the app
```

### Manual Deep Signing (if needed)

To manually deep sign an already-packaged app:

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
./build/scripts/deep_sign_app.sh "dist/mac/Redshift.app" --entitlements build/entitlements.mac.plist
```

### Test Signing

Test the complete signing process:

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
./build/scripts/test_signing.sh "dist/mac/Redshift.app"
```

### Verify Signing

```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"

# Verify code signature
codesign --verify --deep --strict --verbose=2 "dist/mac/Redshift.app"

# Check Gatekeeper assessment
spctl -a -t exec -vv "dist/mac/Redshift.app"

# List all signed binaries
codesign -dv --verbose=4 "dist/mac/Redshift.app"
```

### Notarization (Required for Gatekeeper)

#### One-Time Setup: Store Apple Credentials

1. **Generate an app-specific password:**
   - Go to https://appleid.apple.com
   - Sign in with your Apple Developer account
   - Navigate to **Security** → **App-Specific Passwords**
   - Click **Generate an app-specific password**
   - Name it "Redshift Notarization"
   - Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

2. **Store credentials in your keychain (one-time):**

```bash
xcrun notarytool store-credentials "notarytool-password"
```

When prompted, enter:
- **Apple ID**: Your Apple Developer email
- **Team ID**: `D4X8TSBQJC`
- **Password**: `sngj-vltx-lsgu-xdyf`

This securely stores your credentials in macOS Keychain. You only need to do this once.

#### Automatic Notarization

Once credentials are stored, the build script **automatically notarizes** for you:

```bash
./build/scripts/build_and_sign.sh --arm64-only
```

The script will:
1. Build and sign the app
2. Create DMG
3. Submit for notarization
4. Wait for Apple's approval
5. Staple the notarization ticket

#### Manual Notarization (if needed)

If you need to manually notarize a specific file:

```bash
./build/scripts/notarize_app.sh "path/to/Redshift.dmg"
```

## What Gets Packaged

The final `.app` bundle includes:

```
Redshift.app/
├── Contents/
│   ├── MacOS/
│   │   └── Redshift              # Electron executable
│   ├── Resources/
│   │   ├── app.asar              # Your app code (packed)
│   │   ├── app.asar.unpacked/    # Unpacked resources
│   │   │   └── resources/
│   │   │       ├── python/       # Bundled Python runtime
│   │   │       └── python-deps/  # pymobiledevice3 & deps
│   │   └── python/               # Extra resources copy
│   │       └── python-deps/
│   └── Info.plist
```

## File Sizes

Expected sizes:
- **Python runtime:** ~50-70 MB
- **Python dependencies:** ~30-50 MB  
- **App code:** ~10-20 MB
- **Total .app size:** ~100-150 MB
- **DMG size:** ~80-120 MB (compressed)

## Platform-Specific Builds

### Building for macOS Intel (x86_64)

Download the x86_64 Python build:

```bash
# In setup-python.sh, change the download URL to:
PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.11.10%2B20241016-x86_64-apple-darwin-install_only.tar.gz"
```

### Building for Windows (Future)

1. Download Windows Python build
2. Update `PythonBridge.js` to handle `.exe` executables
3. Add Windows-specific build config to `package.json`

### Building for Linux (Future)

1. Download Linux Python build  
2. Ensure USB permissions are handled correctly
3. Add Linux-specific build config

## Troubleshooting

### "Python not found" in packaged app

**Cause:** Python resources weren't included in the build.

**Fix:** 
```bash
cd "/Users/strattenwaldt/Desktop/Projects/Personal Projects/Redshift/RedShift_Desktop"
./scripts/setup-python.sh
npm run build
```

### Code signing fails

**Cause:** Certificate not found or expired.

**Fix:** 
```bash
# List available certificates
security find-identity -v -p codesigning

# Make sure you have "Developer ID Application: Your Name"
```

### App crashes on launch (packaged)

**Check logs:**
```bash
# macOS
Console.app → Filter by "Redshift"

# Or terminal
log stream --predicate 'process == "Redshift"'

# Or check crash reports
ls -lt ~/Library/Logs/DiagnosticReports/ | grep Redshift | head -5
```

### USB device not detected

**Cause:** Entitlements not properly signed.

**Fix:** Ensure `com.apple.security.device.usb` is in your entitlements and app is properly signed.

## Distribution Checklist

Before distributing:

- [ ] Python runtime is bundled (`resources/python/`)
- [ ] Python deps are bundled (`resources/python-deps/`)
- [ ] App is code signed with Developer ID
- [ ] App is notarized (if distributing outside App Store)
- [ ] DMG is created and stapled
- [ ] Tested on a clean Mac (not your dev machine)
- [ ] USB device detection works
- [ ] WebSocket sync works
- [ ] All database operations work

## Required macOS Permissions

When running the packaged app for the first time, you'll need to grant certain permissions:

### Accessibility Permission (Required for USB Device Access)

The app needs **Accessibility** permission to properly communicate with iOS devices via USB.

**To grant the permission:**
1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button to add an app
3. Navigate to and select `Redshift.app`
4. Ensure the checkbox next to Redshift is **enabled**

**Note:** Without this permission, the app won't be able to detect or communicate with connected iOS devices. The Python scripts that handle device communication require elevated permissions.

## CI/CD Notes (Future)

For automated builds:

1. Store Python runtime in a secure location (S3, GitHub releases)
2. Download and extract during CI build
3. Use GitHub Secrets for Apple ID credentials
4. Automate notarization with `notarytool`
5. Upload signed DMG to distribution platform

## Resources

- [electron-builder docs](https://www.electron.build/)
- [python-build-standalone](https://github.com/indygreg/python-build-standalone)
- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

