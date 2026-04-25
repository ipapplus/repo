#!/bin/bash
set -euo pipefail

BASE_DIR="./debs"
OUTPUT_FILE="Packages"
ARCHS=("arm" "arm64" "arm64e")
GIT_COMMIT_MSG="Update repository packages - $(date +'%Y-%m-%d %H:%M')"

mkdir -p "${ARCHS[@]/#/$BASE_DIR/}"

for deb in ./*.deb; do
    [ -e "$deb" ] || continue

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    dpkg-deb -e "$deb" "$tmp/DEBIAN"

    package=$(awk '/^Package:/ {print $2}' "$tmp/DEBIAN/control")
    version=$(awk '/^Version:/ {print $2}' "$tmp/DEBIAN/control")
    arch_raw=$(awk '/^Architecture:/ {print $2}' "$tmp/DEBIAN/control")

    arch_folder=$(echo "$arch_raw" | sed 's/^iphoneos-//' | tr -d '[:space:]')
    new_deb_name="${package}_${version}_${arch_raw}.deb"
    target_path="$BASE_DIR/$arch_folder/$new_deb_name"

    if [ -f "$target_path" ]; then
        echo "Skipping existing package: $new_deb_name"
        rm -rf "$tmp"
        trap - EXIT
        continue
    fi

    if [[ ! " ${ARCHS[*]} " =~ " ${arch_folder} " ]]; then
        echo "Skipping unsupported architecture: $arch_folder for $deb"
        rm -rf "$tmp"
        trap - EXIT
        continue
    fi

    dpkg-deb -x "$deb" "$tmp"
    dpkg-deb -b "$tmp" "$new_deb_name"

    [ "$deb" != "./$new_deb_name" ] && rm -f "$deb"

    mv "$new_deb_name" "$target_path"

    rm -rf "$tmp"
    trap - EXIT
done

> "$OUTPUT_FILE"

for ARCH in "${ARCHS[@]}"; do
    ARCH_DIR="$BASE_DIR/$ARCH"
    if [ -d "$ARCH_DIR" ] && [ -n "$(ls -A "$ARCH_DIR")" ]; then
        apt-ftparchive packages "$ARCH_DIR" >> "$OUTPUT_FILE"
    fi
done

gzip -k -f "$OUTPUT_FILE"
bzip2 -k -f "$OUTPUT_FILE"
xz -k -f "$OUTPUT_FILE"
zstd -k -f "$OUTPUT_FILE"

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    git add --all
    git commit -m "$GIT_COMMIT_MSG" || echo "No changes to commit"
    git push
else
    echo "Warning: Current directory is not a Git repository"
fi