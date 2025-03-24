#!/bin/bash

BASE_DIR="./file"
OUTPUT_FILE="Packages"
ARCHS=("arm" "arm64" "arm64e")

for ARCH in "${ARCHS[@]}"; do
    mkdir -p "$BASE_DIR/$ARCH"
done

for deb in ./*.deb; do
    [ -e "$deb" ] || continue

    name=$(dpkg-deb -f "$deb" Name | tr -d '[:space:]')
    version=$(dpkg-deb -f "$deb" Version | tr -d '[:space:]')
    arch=$(dpkg-deb -f "$deb" Architecture | sed 's/^iphoneos-//' | tr -d '[:space:]')

    new_name="${name}.${version}.${arch}.deb"
    new_path="$BASE_DIR/$arch/$new_name"

    if [ ! -f "$new_path" ]; then
        mv "$deb" "$new_path"
    fi
done

> "$OUTPUT_FILE"

for ARCH in "${ARCHS[@]}"; do
    ARCH_DIR="$BASE_DIR/$ARCH"
    if [ -d "$ARCH_DIR" ]; then
        apt-ftparchive packages "$ARCH_DIR" >> "$OUTPUT_FILE"
    fi
done