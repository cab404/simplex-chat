#!/bin/sh

set -e

langs=( en bg cs de es fi fr it ja nl pl ru th uk zh-Hans )

for lang in "${langs[@]}"; do
  echo "***"
  echo "***"
  echo "***"
  echo "*** Importing $lang"
  xcodebuild -importLocalizations \
            -project ./apps/ios/SimpleX.xcodeproj \
            -localizationPath ./apps/ios/SimpleX\ Localizations/$lang.xcloc \
            -disableAutomaticPackageResolution \
            -skipPackageUpdates
  sleep 10
done
