#!/usr/bin/env bash
# Publish one platform's build to the public downloads repo.
#
#     tools/publish-release.sh <platform> <version> <file> [file...]
#     tools/publish-release.sh windows 1.0.0 ~/dist/SusiConnect-1.0.0-setup.exe
#     tools/publish-release.sh linux 1.0.0 dist/pkg/*.deb dist/pkg/*.rpm dist/pkg/*.tar.gz dist/pkg/*.pkg.tar.zst
#
# Why this exists rather than a plain `gh release create`: the README and the
# TV install page link to `releases/latest/download/<stable name>`, and GitHub
# resolves `latest` to ONE release. A Windows release published on its own
# becomes the latest and takes the Android APK out of every link that points at
# it. So every release carries the current build of EVERY platform: the new
# files, plus the stable-named assets copied down from the previous latest.
# One URL per platform, stable forever, no README edit per release.
#
# The stable names are the contract with those links; the versioned copies are
# for people who want a specific build.
set -euo pipefail

REPO="suzzukin/susi-connect-downloads"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Every stable name there is, across platforms: what a release must carry.
STABLE_ALL="susi-connect-android.apk susi-connect-windows-setup.exe
susi-connect-linux-amd64.deb susi-connect-linux-arm64.deb
susi-connect-linux-x86_64.rpm susi-connect-linux-aarch64.rpm
susi-connect-linux-amd64.tar.gz susi-connect-linux-arm64.tar.gz
susi-connect-linux-amd64.pkg.tar.zst susi-connect-linux-arm64.pkg.tar.zst"

# stable_name is the stable name a file publishes under, by platform and, for
# Linux, by the architecture and format in its own name.
stable_name() {
  case "$PLATFORM" in
    android) echo "susi-connect-android.apk" ;;
    windows) echo "susi-connect-windows-setup.exe" ;;
    linux)
      local f; f="$(basename "$1")"
      case "$f" in
        *_amd64.deb) echo "susi-connect-linux-amd64.deb" ;;
        *_arm64.deb) echo "susi-connect-linux-arm64.deb" ;;
        *.x86_64.rpm) echo "susi-connect-linux-x86_64.rpm" ;;
        *.aarch64.rpm) echo "susi-connect-linux-aarch64.rpm" ;;
        *-linux-amd64.tar.gz) echo "susi-connect-linux-amd64.tar.gz" ;;
        *-linux-arm64.tar.gz) echo "susi-connect-linux-arm64.tar.gz" ;;
        *-x86_64.pkg.tar.zst) echo "susi-connect-linux-amd64.pkg.tar.zst" ;;
        *-aarch64.pkg.tar.zst) echo "susi-connect-linux-arm64.pkg.tar.zst" ;;
        *) echo "no stable name for $f" >&2; return 1 ;;
      esac ;;
  esac
}

case "${1:-}" in
  android | windows | linux) ;;
  *) echo "usage: $0 <android|windows|linux> <version> <file> [file...]" >&2; exit 2 ;;
esac
PLATFORM="$1"; VERSION="$2"; shift 2
[ $# -ge 1 ] || { echo "no files given" >&2; exit 2; }

TAG="$PLATFORM-v$VERSION"

# Every artefact is published twice: once under the stable name the links use,
# once under its version so an old build stays reachable.
PUBLISHED=""
for file in "$@"; do
  stable="$(stable_name "$file")"
  cp "$file" "$WORK/$stable"
  cp "$file" "$WORK/${stable/susi-connect-/susi-connect-$VERSION-}"
  PUBLISHED="$PUBLISHED $stable"
done

# Carry every other platform's stable asset over from the release that is
# currently latest, so this one does not become a gap.
previous="$(gh release view -R "$REPO" --json tagName --jq .tagName 2>/dev/null || true)"
if [ -n "$previous" ]; then
  for name in $STABLE_ALL; do
    case " $PUBLISHED " in *" $name "*) continue ;; esac
    if gh release download "$previous" -R "$REPO" -p "$name" -D "$WORK" 2>/dev/null; then
      echo "carried over from $previous: $name"
    fi
  done
fi

(cd "$WORK" && shasum -a 256 -- * > SHA256SUMS.txt)

echo "publishing $TAG with:"
ls -1sh "$WORK"
gh release create "$TAG" -R "$REPO" --title "$PLATFORM $VERSION" --notes-file - "$WORK"/* <<NOTES
| | |
|---|---|
| Версия / version | $VERSION |
| Дата / date | $(date +%Y-%m-%d) |

Прямые ссылки не меняются между релизами / the direct links never change:
\`releases/latest/download/susi-connect-android.apk\`,
\`releases/latest/download/susi-connect-windows-setup.exe\`,
\`releases/latest/download/susi-connect-linux-{amd64,arm64}.deb\`,
\`releases/latest/download/susi-connect-linux-{x86_64,aarch64}.rpm\`,
\`releases/latest/download/susi-connect-linux-{amd64,arm64}.tar.gz\`.
NOTES
