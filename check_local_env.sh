#!/bin/bash

# --- 请确保你在正确的项目目录下运行此脚本 ---
# --- 或者修改下面的 CD 命令指向你的项目目录 ---
# cd /path/to/your/brisk-norman

echo "--- Flutter Version --- "
flutter --version --verbose

echo ""
echo "--- Dart Version --- "
dart --version

echo ""
echo "--- macOS Version --- "
sw_vers

echo ""
echo "--- Xcode Version --- "
xcodebuild -version

echo ""
echo "--- Xcode SDKs --- "
xcodebuild -showsdks

echo ""
echo "--- CocoaPods Version --- "
pod --version

echo ""
echo "--- Node Version --- "
node --version

echo ""
echo "--- npm Version --- "
npm --version

echo ""
echo "--- Ruby Version --- "
ruby --version

echo ""
echo "--- RubyGems Version --- "
gem --version

echo ""
echo "--- System Info --- "
uname -a

echo ""
echo "--- pubspec.lock loader_overlay --- "
if [ -f pubspec.lock ]; then
  grep loader_overlay pubspec.lock | cat
else
  echo "pubspec.lock not found in current directory."
fi

echo ""
echo "--- Flutter Pub Deps --- "
flutter pub deps