#!/bin/zsh
set -euo pipefail

PROJECT="Neon Vision Editor.xcodeproj"
SCHEME="Neon Vision Editor"
CONFIGURATION="Release"
EXPORT_OPTIONS="release/ExportOptions-TestFlight.plist"
ARCHIVE_PATH="build/NeonVisionEditor.xcarchive"
EXPORT_PATH="build/TestFlightExport"

mkdir -p build

echo "==> Cleaning"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" clean

echo "==> Archiving"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination 'generic/platform=iOS' -archivePath "$ARCHIVE_PATH" archive

echo "==> Exporting IPA"
xcodebuild -allowProvisioningUpdates -exportArchive -archivePath "$ARCHIVE_PATH" -exportPath "$EXPORT_PATH" -exportOptionsPlist "$EXPORT_OPTIONS"

echo "==> Done"
echo "Archive: $ARCHIVE_PATH"
echo "Export:  $EXPORT_PATH"
echo "Next: Open Organizer in Xcode and distribute/upload to TestFlight, or use Transporter with the IPA from $EXPORT_PATH"
