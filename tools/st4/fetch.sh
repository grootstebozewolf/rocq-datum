#!/usr/bin/env bash
# Fetch StringTemplate 4 and its ANTLR 3 runtime from Maven Central into
# tools/st4/lib/, verifying pinned SHA-256 checksums.
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)/lib
mkdir -p "$dir"
fetch() {  # group-path artifact version sha256
  local jar="$2-$3.jar"
  if [ ! -f "$dir/$jar" ]; then
    curl -sSfL -o "$dir/$jar.part" \
      "https://repo1.maven.org/maven2/$1/$2/$3/$jar"
    mv "$dir/$jar.part" "$dir/$jar"
  fi
  echo "$4  $dir/$jar" | sha256sum -c --quiet - || {
    rm -f "$dir/$jar"; echo "checksum mismatch: $jar" >&2; exit 1; }
}
fetch org/antlr ST4           4.3.4 f927ac384c46d749f8b5ec68972a53aed21e00313509299616edb73bfa15ff33
fetch org/antlr antlr-runtime 3.5.3 68bf9f5a33dfcb34033495c587e6236bef4e37aa6612919f5b1e843b90669fb9
