#!/bin/bash
set -euo pipefail
opus_package=$(cd "$(dirname "$0")/.." && pwd)
opus_work=$(mktemp -d /tmp/nexus-opus-build.XXXXXX)
curl --fail --location --silent --show-error https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz -o "$opus_work/opus.tar.gz"
test "$(shasum -a 256 "$opus_work/opus.tar.gz" | cut -d ' ' -f 1)" = 65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1
tar -xzf "$opus_work/opus.tar.gz" -C "$opus_work"
for opus_arch in arm64 x86_64; do
  cmake -S "$opus_work/opus-1.5.2" -B "$opus_work/$opus_arch" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$opus_arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15 -DBUILD_SHARED_LIBS=ON \
    -DOPUS_BUILD_PROGRAMS=OFF -DOPUS_BUILD_TESTING=OFF
  cmake --build "$opus_work/$opus_arch" --parallel 6
done
opus_framework="$opus_work/opus.framework"
mkdir -p "$opus_framework/Versions/A/Headers" "$opus_framework/Versions/A/Resources" "$opus_framework/Versions/A/Modules"
lipo -create "$opus_work/arm64/libopus.dylib" "$opus_work/x86_64/libopus.dylib" -output "$opus_framework/Versions/A/opus"
install_name_tool -id '@rpath/opus.framework/Versions/A/opus' "$opus_framework/Versions/A/opus"
cp "$opus_work/opus-1.5.2/include/"*.h "$opus_framework/Versions/A/Headers/"
cp "$opus_work/opus-1.5.2/COPYING" "$opus_package/LICENSE"
cp "$opus_package/tool/Info.plist" "$opus_framework/Versions/A/Resources/Info.plist"
cp "$opus_package/tool/module.modulemap" "$opus_framework/Versions/A/Modules/module.modulemap"
ln -s A "$opus_framework/Versions/Current"
for opus_item in Headers Resources Modules opus; do
  ln -s "Versions/Current/$opus_item" "$opus_framework/$opus_item"
done
xcodebuild -create-xcframework -framework "$opus_framework" -output "$opus_work/opus.xcframework"
# Fail rather than overwrite an existing distribution; review and move it first.
test ! -e "$opus_package/macos/nx_opus_macos/opus.xcframework"
cp -R "$opus_work/opus.xcframework" "$opus_package/macos/nx_opus_macos/"
echo "Built universal framework; build workspace retained at $opus_work"
