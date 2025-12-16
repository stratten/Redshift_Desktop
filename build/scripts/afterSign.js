// afterSign hook for electron-builder
// Runs deep signing after electron-builder's initial signing
// This ensures all nested binaries are properly signed

const { execSync } = require('child_process');
const path = require('path');

exports.default = async function(context) {
  const { electronPlatformName, appOutDir } = context;
  
  // Only sign on macOS
  if (electronPlatformName !== 'darwin') {
    return;
  }

  const appPath = path.join(appOutDir, `${context.packager.appInfo.productFilename}.app`);
  const deepSignScript = path.join(__dirname, 'deep_sign_app.sh');
  const entitlementsPath = path.join(__dirname, '..', 'entitlements.mac.plist');

  console.log('\n🔐 Running deep code signing...');
  console.log(`   App: ${appPath}`);
  console.log(`   Script: ${deepSignScript}`);
  console.log(`   Entitlements: ${entitlementsPath}`);

  try {
    execSync(`"${deepSignScript}" "${appPath}" --entitlements "${entitlementsPath}"`, {
      stdio: 'inherit'
    });
    console.log('✅ Deep code signing completed\n');
  } catch (error) {
    console.error('❌ Deep code signing failed:', error.message);
    throw error;
  }
};

