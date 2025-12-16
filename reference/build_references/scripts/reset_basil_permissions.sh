#!/bin/bash
#
# Script to reset macOS TCC permissions for Basil application components.
# This is intended for development use to ensure a clean permission state before testing.
#

echo "INFO: Starting TCC permission reset for Basil components..."

# Bundle ID for the main Swift application (BasilClient.app)
# Found in BasilClient/Sources/Support/Info.plist
CLIENT_BUNDLE_ID="com.stratten.basil"

# Bundle ID for the outer launcher application (Basil.app)
# Defined in builds/common/scripts/build_app.sh
# IMPORTANT: If this placeholder changes in build_app.sh, update it here too!
LAUNCHER_BUNDLE_ID="com.stratten.basil.launcher"

echo "INFO: Target Bundle ID for BasilClient: $CLIENT_BUNDLE_ID"
echo "INFO: Target Bundle ID for Basil Launcher: $LAUNCHER_BUNDLE_ID"

# Services to reset:
# - ScreenCapture: For screen recording
# - Accessibility: For controlling UI elements, simulating input
# - AppleEvents: For sending AppleEvents to other applications (e.g., System Events)

services=("ScreenCapture" "Accessibility" "AppleEvents")
bundle_ids=("$CLIENT_BUNDLE_ID" "$LAUNCHER_BUNDLE_ID")

for service in "${services[@]}"; do
    for bundle_id in "${bundle_ids[@]}"; do
        if [ -z "$bundle_id" ]; then
            # Handle an empty bundle_id more gracefully if needed,
            # For now, we'll try to run tccutil which will likely just fail silently for a non-existent/placeholder ID.
            # Or, you could choose to skip if it matches the exact placeholder:
            echo "WARNING: Skipping tccutil for empty bundle_id for service $service."
            continue
        fi
        echo "INFO: Resetting $service permissions for $bundle_id..."
        if tccutil reset "$service" "$bundle_id"; then
            echo "SUCCESS: $service permissions reset for $bundle_id."
        else
            # tccutil might return a non-zero exit code if the bundle ID was never registered
            # or if there's another issue. This is often not a critical failure for a reset script.
            echo "NOTE: tccutil command for $service on $bundle_id completed (may indicate no prior entry or other issue)."
        fi
    done
done

echo "INFO: TCC permission reset process completed."
echo "INFO: You should be prompted for necessary permissions when Basil is next launched." 