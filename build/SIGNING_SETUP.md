# Code Signing & Notarization Setup

## Current Status

✅ **Icon**: Generated from `Assets/Redshift Logo - Trimmed - 1024.png`  
✅ **Certificate**: Developer ID Application: Baobab Group LLC (D4X8TSBQJC)  
✅ **Entitlements**: Configured for USB, network, and file access  
⚠️ **Notarization**: Requires Apple ID credentials

## Code Signing (Already Configured)

Your app will be automatically signed with:
- **Identity**: `Developer ID Application: Baobab Group LLC (D4X8TSBQJC)`
- **Hardened Runtime**: Enabled
- **Entitlements**: USB device access, network access, file access

## Notarization Setup (Required for Distribution)

Notarization is required for macOS 10.15+ users to run your app without warnings.

### 1. Create App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in with your Apple Developer account
3. Go to "Security" → "App-Specific Passwords"
4. Click "Generate an app-specific password"
5. Name it: "Redshift Notarization"
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

### 2. Set Environment Variables

Add these to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
# Redshift notarization credentials
export APPLE_ID="your-apple-id@example.com"
export APPLE_ID_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password
export APPLE_TEAM_ID="D4X8TSBQJC"
```

Then reload your shell:
```bash
source ~/.zshrc
```

### 3. Verify Setup

```bash
echo $APPLE_ID
echo $APPLE_ID_PASSWORD
echo $APPLE_TEAM_ID
```

All three should output values.

## Building & Notarizing

### Full Build with Notarization

```bash
npm run build
```

This will:
1. Build the app
2. Sign it with your Developer ID
3. Create a DMG
4. **Automatically notarize** if credentials are set
5. Staple the notarization ticket

### Build Without Notarization (Testing)

```bash
npm run pack
```

Creates an unsigned/non-notarized `.app` for local testing.

## What Gets Created

After `npm run build`, you'll have in `dist/`:

```
dist/
├── mac/
│   └── Redshift.app                    # The signed application
├── mac-arm64/
│   └── Redshift.app                    # ARM64 build
├── mac-x64/  
│   └── Redshift.app                    # Intel build
├── Redshift-1.0.0-arm64-mac.zip       # ARM64 ZIP
├── Redshift-1.0.0-x64-mac.zip         # Intel ZIP  
├── Redshift-1.0.0-arm64.dmg           # ARM64 DMG (signed & notarized)
└── Redshift-1.0.0-x64.dmg             # Intel DMG (signed & notarized)
```

## Verification

### Check Code Signature

```bash
codesign --verify --deep --strict --verbose=2 "dist/mac/Redshift.app"
```

Expected output:
```
dist/mac/Redshift.app: valid on disk
dist/mac/Redshift.app: satisfies its Designated Requirement
```

### Check Hardened Runtime

```bash
codesign -d --entitlements - "dist/mac/Redshift.app"
```

Should show your entitlements (USB device, network, etc.)

### Check Notarization

```bash
spctl -a -t exec -vv "dist/mac/Redshift.app"
```

Expected output (after notarization):
```
dist/mac/Redshift.app: accepted
source=Notarized Developer ID
```

### Check DMG Notarization

```bash
spctl -a -t open --context context:primary-signature -v "dist/Redshift-1.0.0-arm64.dmg"
```

Should show `accepted` if notarized.

## Troubleshooting

### "App is damaged and can't be opened"

**Cause**: App not signed or signature broken.

**Fix**: Rebuild with signing enabled.

### "Apple cannot check it for malicious software"

**Cause**: App not notarized.

**Fix**: Set environment variables and rebuild.

### Notarization fails

**Check credentials**:
```bash
xcrun notarytool history --apple-id "$APPLE_ID" --password "$APPLE_ID_PASSWORD" --team-id "$APPLE_TEAM_ID"
```

**Common issues**:
- Wrong Apple ID or password
- Team ID mismatch
- 2FA not set up properly
- Not enrolled in Apple Developer Program

### "Developer ID Application not found"

Your certificate is correctly installed. If this error appears:

1. Check certificate is not expired:
   ```bash
   security find-identity -v -p codesigning
   ```

2. Verify certificate name matches package.json

## Distribution Checklist

Before distributing to users:

- [ ] Icon is set (`build/icon.icns` exists)
- [ ] App is code signed
- [ ] Hardened runtime enabled
- [ ] Entitlements configured
- [ ] App is notarized (no warnings on first launch)
- [ ] DMG is stapled with notarization ticket
- [ ] Tested on a Mac that isn't your development machine
- [ ] USB device detection works
- [ ] All features work in signed/notarized build

## CI/CD Integration (Future)

For automated builds in CI:

```yaml
# GitHub Actions example
env:
  APPLE_ID: ${{ secrets.APPLE_ID }}
  APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
  APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
  CSC_LINK: ${{ secrets.MAC_CERT_P12_BASE64 }}
  CSC_KEY_PASSWORD: ${{ secrets.MAC_CERT_PASSWORD }}
```

Store your certificate as base64:
```bash
base64 -i certificate.p12 | pbcopy
```

## Resources

- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [electron-builder Signing Docs](https://www.electron.build/code-signing)

