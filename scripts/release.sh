#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release.sh <version> [options]

Options:
  --build <num>       Set build number (defaults to current + 1)
  --skip-commit       Do not create a version bump commit
  --skip-tag          Do not create a git tag
  --build-app         Build and zip the macOS app
  --unsigned          Disable code signing for the build
  --push              Push commit and tag to origin
  --gh                Create a GitHub release (requires gh + --build-app)
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

VERSION=""
BUILD=""
SKIP_COMMIT=false
SKIP_TAG=false
BUILD_APP=false
UNSIGNED=false
DO_PUSH=false
DO_GH=false

VERSION="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)
      BUILD="${2:-}"
      shift 2
      ;;
    --skip-commit)
      SKIP_COMMIT=true
      shift
      ;;
    --skip-tag)
      SKIP_TAG=true
      shift
      ;;
    --build-app)
      BUILD_APP=true
      shift
      ;;
    --unsigned)
      UNSIGNED=true
      shift
      ;;
    --push)
      DO_PUSH=true
      shift
      ;;
    --gh)
      DO_GH=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$ROOT/gesture-control.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "Could not find project file at $PBXPROJ"
  exit 1
fi

if [[ -z "$BUILD" ]]; then
  current_build=$(rg -m1 "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | sed -E 's/.*= ([0-9]+);/\\1/')
  if [[ -z "$current_build" ]]; then
    current_build=0
  fi
  BUILD=$((current_build + 1))
fi

python3 - "$PBXPROJ" "$VERSION" "$BUILD" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
build = sys.argv[3]
data = path.read_text()
data, mv_count = re.subn(r"MARKETING_VERSION = [^;]+;", f"MARKETING_VERSION = {version};", data)
data, bv_count = re.subn(r"CURRENT_PROJECT_VERSION = [^;]+;", f"CURRENT_PROJECT_VERSION = {build};", data)
if mv_count == 0 or bv_count == 0:
    raise SystemExit("Failed to update version fields in project.pbxproj")
path.write_text(data)
print(f"Updated MARKETING_VERSION to {version} and CURRENT_PROJECT_VERSION to {build}")
PY

if ! $SKIP_COMMIT || ! $SKIP_TAG || $DO_PUSH; then
  if ! git diff --quiet; then
    git status --short
  fi
  if ! git diff --quiet && ! $SKIP_COMMIT; then
    git add "$PBXPROJ"
    git commit -m "Bump version to v$VERSION ($BUILD)"
  elif $SKIP_COMMIT; then
    echo "Skipping commit."
  fi

  if ! $SKIP_TAG; then
    git tag -a "v$VERSION" -m "v$VERSION"
  fi

  if $DO_PUSH; then
    git push origin "v$VERSION"
    if ! $SKIP_COMMIT; then
      git push
    fi
  fi
fi

if $BUILD_APP; then
  BUILD_DIR="$ROOT/build"
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  SIGNING_ARGS=()
  if $UNSIGNED; then
    SIGNING_ARGS+=(CODE_SIGNING_ALLOWED=NO)
  fi

  xcodebuild \
    -project "$ROOT/gesture-control.xcodeproj" \
    -scheme "gesture-control" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    "${SIGNING_ARGS[@]}" \
    build

  APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/gesture-control.app"
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Build succeeded but app not found at $APP_PATH"
    exit 1
  fi

  ZIP_NAME="Gesture-Control-macOS-v${VERSION}.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$BUILD_DIR/$ZIP_NAME"
  echo "Created $BUILD_DIR/$ZIP_NAME"

  if $DO_GH; then
    if ! command -v gh >/dev/null 2>&1; then
      echo "gh not found; install GitHub CLI or rerun without --gh."
      exit 1
    fi
    gh release create "v$VERSION" "$BUILD_DIR/$ZIP_NAME" -t "Gesture Control v$VERSION" --generate-notes
  fi
fi
