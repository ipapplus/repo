#!/bin/bash

BASE_DIR="./debs"
OUTPUT_FILE="Packages"
ARCHS=("arm" "arm64" "arm64e")

for ARCH in "${ARCHS[@]}"; do
    mkdir -p "$BASE_DIR/$ARCH"
done

for deb in ./*.deb; do
    [ -e "$deb" ] || continue

    tmp=$(mktemp -d)

    dpkg-deb -e "$deb" "$tmp/DEBIAN"

    package=$(grep "^Package:" "$tmp/DEBIAN/control" | cut -d' ' -f2)
    version=$(grep "^Version:" "$tmp/DEBIAN/control" | cut -d' ' -f2)
    arch_raw=$(grep "^Architecture:" "$tmp/DEBIAN/control" | cut -d' ' -f2)

    arch_folder=$(echo "$arch_raw" | sed 's/^iphoneos-//' | tr -d '[:space:]')
    new_deb_name="${package}_${version}_${arch_raw}.deb"
    target_path="$BASE_DIR/$arch_folder/$new_deb_name"

    if [ -f "$target_path" ]; then
        rm -rf "$tmp"
        continue
    fi

    dpkg-deb -x "$deb" "$tmp"
    dpkg-deb -b "$tmp" "$new_deb_name"

    [ "$deb" != "./$new_deb_name" ] && rm "$deb"

    rm -rf "$tmp"

    case "$arch_folder" in
        arm|arm64|arm64e)
            mv "$new_deb_name" "$BASE_DIR/$arch_folder/"
            ;;
    esac
done

> "$OUTPUT_FILE"

for ARCH in "${ARCHS[@]}"; do
    ARCH_DIR="$BASE_DIR/$ARCH"
    [ -d "$ARCH_DIR" ] && apt-ftparchive packages "$ARCH_DIR" >> "$OUTPUT_FILE"
done

gzip -k -f "$OUTPUT_FILE"
bzip2 -k -f "$OUTPUT_FILE"
xz -k -f "$OUTPUT_FILE"
zstd -k -f "$OUTPUT_FILE"

git add --all
git commit -m "Init"
git push