#!/usr/bin/env bash
# Publish one platform's build to the public downloads repo.
#
#     tools/publish-release.sh <platform> <version> <file> [file...]
#     tools/publish-release.sh windows 1.0.0 ~/dist/SusiConnect-1.0.0-setup.exe
#     tools/publish-release.sh macos 1.13.0 build/direct/susi-connect-1.13.0-macos.dmg build/direct/appcast.xml
#     tools/publish-release.sh linux 1.0.0 dist/pkg/*.deb dist/pkg/*.rpm dist/pkg/*.tar.gz dist/pkg/*.pkg.tar.zst packaging/linux.sh
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
#
# The Mac update feed is the one thing not on `latest`: every installed copy asks its
# address for good, and any platform's release moves `latest`. It is the only asset of
# the macos-feed release, which only a Mac release touches.
set -euo pipefail

REPO="suzzukin/susi-connect-downloads"
FEED_TAG="macos-feed"
FEED_URL="https://github.com/$REPO/releases/download/$FEED_TAG/appcast.xml"
WORK="$(mktemp -d)"
# What is not to be uploaded: everything in WORK is.
STATE="$(mktemp -d)"
MOUNT=""
cleanup() {
  if [ -n "$MOUNT" ]; then
    hdiutil detach -quiet "$MOUNT" || true
    rmdir "$MOUNT" || true
  fi
  rm -rf "${WORK:?}" "${STATE:?}"
}
trap cleanup EXIT

die() { echo "$*" >&2; exit 1; }

# Whether a release exists. Anything but "not found" stops the script: a network
# failure read as "no such release" would skip what that release is checked for.
release_exists() {
  local out
  if out="$(gh release view "$1" -R "$REPO" --json tagName 2>&1)"; then return 0; fi
  case "$out" in
    *"release not found"*) return 1 ;;
    *) die "gh release view $1: $out" ;;
  esac
}

# Whether a URL answers, through the flakes a transatlantic TLS handshake has.
answers() {
  curl -fsIL -o /dev/null --retry 6 --retry-delay 10 --retry-all-errors "$1"
}

enclosure_url() { sed -n 's/.*<enclosure url="\([^"]*\)".*/\1/p' "$FEED"; }
feed_build() { sed -n 's/.*<sparkle:version>\([^<]*\)<.*/\1/p' "$1"; }

# Every stable name there is, across platforms: what a release must carry.
STABLE_ALL="susi-connect-android.apk susi-connect-windows-setup.exe
susi-connect-linux-amd64.deb susi-connect-linux-arm64.deb
susi-connect-linux-x86_64.rpm susi-connect-linux-aarch64.rpm
susi-connect-linux-amd64.tar.gz susi-connect-linux-arm64.tar.gz
susi-connect-linux-amd64.pkg.tar.zst susi-connect-linux-arm64.pkg.tar.zst
susi-connect-linux.sh
susi-connect-macos.dmg"

# stable_name is the stable name a file publishes under, by platform and, for
# Linux, by the architecture and format in its own name.
stable_name() {
  case "$PLATFORM" in
    android) echo "susi-connect-android.apk" ;;
    windows) echo "susi-connect-windows-setup.exe" ;;
    macos)
      local m; m="$(basename "$1")"
      case "$m" in
        *.dmg) echo "susi-connect-macos.dmg" ;;
        *) echo "no stable name for $m" >&2; return 1 ;;
      esac ;;
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
        linux.sh) echo "susi-connect-linux.sh" ;;
        *) echo "no stable name for $f" >&2; return 1 ;;
      esac ;;
  esac
}

# A Mac release is a DMG and its feed, checked here, at the last step before the
# public: a DMG asking a test feed strands every Mac that takes it, and a feed
# promising a file that is not there stops updates on all of them, with nothing to say so.
check_mac_release() {
  [ -n "$DMG" ] && [ -n "$FEED" ] || die "a Mac release is the DMG and appcast.xml"

  MOUNT="$(mktemp -d)"
  hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT" "$DMG"
  local info="$MOUNT/susi connect.app/Contents/Info.plist" feed_in_app local_ok short build
  feed_in_app="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$info")"
  local_ok="$(/usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity:NSAllowsLocalNetworking' "$info" 2>/dev/null || true)"
  short="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info")"
  build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info")"
  hdiutil detach -quiet "$MOUNT"
  rmdir "$MOUNT"
  MOUNT=""

  [ "$feed_in_app" = "$FEED_URL" ] || die "the app asks another feed: $feed_in_app"
  [ -z "$local_ok" ] || die "the app allows local networking: a test build"
  [ "$short" = "$VERSION" ] || die "the app is $short, this release $VERSION"
  case "$build" in ''|*[!0-9]*) die "build $build is a test build's" ;; esac

  local promised url length expected
  promised="$(feed_build "$FEED")"
  url="$(enclosure_url)"
  length="$(sed -n 's/.*<enclosure .*length="\([0-9]*\)".*/\1/p' "$FEED")"
  expected="https://github.com/$REPO/releases/download/$TAG/susi-connect-$VERSION-macos.dmg"
  [ "$promised" = "$build" ] || die "the feed says build $promised, the DMG holds $build"
  [ "$url" = "$expected" ] || die "the feed points at $url, not $expected"
  [ "$length" = "$(stat -f %z "$DMG")" ] || die "the feed's length is not the DMG's"
  grep -q 'sparkle-signatures' "$FEED" || die "the feed is not signed"

  xcrun stapler validate -q "$DMG"
  spctl --assess --type open --context context:primary-signature "$DMG"

  # The build must grow, or no Mac updates. This very feed being out already is a
  # rerun after a failure past that point.
  if release_exists "$FEED_TAG"; then
    local assets current
    assets="$(gh release view "$FEED_TAG" -R "$REPO" --json assets --jq '.assets[].name')"
    if printf '%s\n' "$assets" | grep -qx appcast.xml; then
      gh release download "$FEED_TAG" -R "$REPO" -p appcast.xml -O "$STATE/published.xml"
      if ! cmp -s "$STATE/published.xml" "$FEED"; then
        current="$(feed_build "$STATE/published.xml")"
        [ "$build" -gt "$current" ] || die "build $build does not exceed the published $current"
      fi
    fi
  fi
}

# After the release, so the feed never promises a DMG that is not there yet.
publish_mac_feed() {
  answers "$(enclosure_url)" || die "the feed's DMG is not reachable"
  release_exists "$FEED_TAG" ||
    gh release create "$FEED_TAG" -R "$REPO" --title "macos feed" --prerelease --latest=false --notes \
      "Лента обновлений приложения для Mac, её адрес вшит в приложение. · The Mac app's update feed, whose address is built into the app."
  # --clobber deletes the old asset before it uploads the new one, so a failure here
  # leaves no feed at all. It is retried, and a rerun of the script gets past it.
  local tries=0
  until gh release upload "$FEED_TAG" -R "$REPO" --clobber "$FEED"; do
    tries=$((tries + 1))
    [ "$tries" -lt 3 ] || die "the feed did not upload, and the old one may be gone: rerun this script"
    sleep 10
  done
  curl -fsSL --retry 6 --retry-delay 10 --retry-all-errors "$FEED_URL" | cmp - "$FEED" || die "$FEED_URL does not serve what was uploaded"
  echo "feed: $FEED_URL"
}

case "${1:-}" in
  android | windows | linux | macos) ;;
  *) echo "usage: $0 <android|windows|linux|macos> <version> <file> [file...]" >&2; exit 2 ;;
esac
PLATFORM="$1"; VERSION="$2"; shift 2
[ $# -ge 1 ] || { echo "no files given" >&2; exit 2; }

TAG="$PLATFORM-v$VERSION"

# Every artefact is published twice: once under the stable name the links use,
# once under its version so an old build stays reachable.
PUBLISHED=""
DMG=""
FEED=""
for file in "$@"; do
  case "$PLATFORM:$(basename "$file")" in
    macos:appcast.xml) FEED="$file"; continue ;;
    macos:*.dmg) DMG="$file" ;;
  esac
  stable="$(stable_name "$file")"
  cp "$file" "$WORK/$stable"
  cp "$file" "$WORK/${stable/susi-connect-/susi-connect-$VERSION-}"
  PUBLISHED="$PUBLISHED $stable"
done

[ "$PLATFORM" != macos ] || check_mac_release

# Carry every other platform's stable asset over from the release that is
# currently latest, so this one does not become a gap. Anything failing here stops
# the release: an asset that went missing would stay missing for every release after,
# with a 404 behind its link. One the last release does not have is a platform that
# has not released yet.
previous="$(gh release view -R "$REPO" --json tagName --jq .tagName)"
previous_assets="$(gh release view "$previous" -R "$REPO" --json assets --jq '.assets[].name')"
for name in $STABLE_ALL; do
  case " $PUBLISHED " in *" $name "*) continue ;; esac
  printf '%s\n' "$previous_assets" | grep -qx "$name" || continue
  gh release download "$previous" -R "$REPO" -p "$name" -D "$WORK"
  echo "carried over from $previous: $name"
done

(cd "$WORK" && shasum -a 256 -- * > SHA256SUMS.txt)

echo "publishing $TAG with:"
ls -1sh "$WORK"
# A rerun after a failure past this point goes on from here.
if release_exists "$TAG"; then
  gh release download "$TAG" -R "$REPO" -p SHA256SUMS.txt -O - | cmp - "$WORK/SHA256SUMS.txt" ||
    die "$TAG is already out with other files"
  echo "$TAG is already out with these files"
else
gh release create "$TAG" -R "$REPO" --latest --title "$PLATFORM $VERSION" --notes-file - "$WORK"/* <<NOTES
| | |
|---|---|
| Версия / version | $VERSION |
| Дата / date | $(date +%Y-%m-%d) |

Прямые ссылки не меняются между релизами / the direct links never change:
\`releases/latest/download/susi-connect-android.apk\`,
\`releases/latest/download/susi-connect-windows-setup.exe\`,
\`releases/latest/download/susi-connect-macos.dmg\`,
\`releases/latest/download/susi-connect-linux-{amd64,arm64}.deb\`,
\`releases/latest/download/susi-connect-linux-{x86_64,aarch64}.rpm\`,
\`releases/latest/download/susi-connect-linux-{amd64,arm64}.tar.gz\`.
NOTES
fi

# What the links promise, as anyone sees them now.
for file in "$WORK"/*; do
  name="$(basename "$file")"
  answers "https://github.com/$REPO/releases/latest/download/$name" || die "$name is not on latest"
done
echo "every asset answers on latest"

[ "$PLATFORM" != macos ] || publish_mac_feed
