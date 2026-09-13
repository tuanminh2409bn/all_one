#!/bin/sh

# Prepare a clean Xcode Cloud checkout for Flutter before Xcode archives it.
set -e

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$SCRIPT_DIRECTORY/../.." && pwd)}
FLUTTER_VERSION=${FLUTTER_VERSION:-3.38.10}
FLUTTER_SDK_DIRECTORY=${FLUTTER_SDK_DIRECTORY:-"$HOME/flutter"}

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PATH="$FLUTTER_SDK_DIRECTORY/bin:$PATH"

if [ ! -x "$FLUTTER_SDK_DIRECTORY/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION for Xcode Cloud..."
  git clone \
    --branch "$FLUTTER_VERSION" \
    --depth 1 \
    https://github.com/flutter/flutter.git \
    "$FLUTTER_SDK_DIRECTORY"
fi

cd "$REPOSITORY_ROOT"

flutter config --no-analytics
flutter precache --ios
flutter pub get

if ! command -v pod >/dev/null 2>&1; then
  echo "Installing CocoaPods for Xcode Cloud..."
  export HOMEBREW_NO_AUTO_UPDATE=1
  brew install cocoapods
fi

cd "$REPOSITORY_ROOT/ios"
pod install

test -f "$REPOSITORY_ROOT/ios/Flutter/Generated.xcconfig"
test -f "$REPOSITORY_ROOT/ios/Flutter/flutter_export_environment.sh"
test -f "$REPOSITORY_ROOT/ios/Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"

echo "Flutter and CocoaPods dependencies are ready for Xcode Cloud."
