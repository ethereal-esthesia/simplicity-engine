#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cache="$root/node_modules/.cache/simplicity-recording"
version=7.1.1
checksum=733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1
case "${TAURI_ENV_ARCH:-$(uname -m)}" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|x64) arch=x86_64 ;;
  *) echo "Unsupported macOS encoder architecture" >&2; exit 1 ;;
esac
mkdir -p "$cache"
archive="$cache/ffmpeg-$version.tar.xz"
if [ ! -f "$archive" ]; then
  curl --fail --location --silent --show-error \
    "https://ffmpeg.org/releases/ffmpeg-$version.tar.xz" -o "$archive.part"
  mv "$archive.part" "$archive"
fi
echo "$checksum  $archive" | shasum -a 256 -c
source="$cache/ffmpeg-$version"
if [ ! -d "$source" ]; then
  tar -xf "$archive" -C "$cache"
fi
build="$cache/build-$arch-macos15"
mkdir -p "$build"
cd "$build"
"$source/configure" \
  --arch="$arch" --target-os=darwin --enable-cross-compile \
  --cc="clang -arch $arch" --extra-cflags="-mmacosx-version-min=15.0" \
  --extra-ldflags="-arch $arch -mmacosx-version-min=15.0" \
  --disable-everything --disable-doc --disable-network --disable-autodetect \
  --disable-x86asm --disable-ffplay --disable-ffprobe --enable-ffmpeg \
  --enable-demuxer=mov --enable-muxer=mp4 --enable-decoder=alac \
  --enable-encoder=aac --enable-protocol=file \
  --enable-filter=aresample --enable-filter=aformat --enable-filter=anull
make -j 4 ffmpeg
cp ffmpeg "$cache/ffmpeg"
cp "$source/COPYING.LGPLv2.1" "$cache/ffmpeg-LICENSE"
