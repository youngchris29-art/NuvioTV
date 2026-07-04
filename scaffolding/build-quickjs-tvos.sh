#!/bin/bash
# Builds quickjs-kt 1.0.5 with tvOS targets and publishes it to ~/.m2 (mavenLocal) as
# io.github.dokar3:quickjs-kt:1.0.5-tvos. Run once on the Mac; :shared then resolves the
# tvosArm64/tvosSimulatorArm64 klibs from mavenLocal.
#
# Requirements: Xcode (appletvos SDK), CMake (brew install cmake), JDK 17+.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH="$SCRIPT_DIR/quickjs-kt-tvos.patch"
WORK_DIR="${1:-$HOME/quickjs-kt-tvos}"

if [ ! -d "$WORK_DIR/.git" ]; then
  git clone --branch v1.0.5 --depth 1 https://github.com/dokar3/quickjs-kt "$WORK_DIR"
fi

cd "$WORK_DIR"
# QuickJS C sources (bellard/quickjs) + c-vector are git submodules.
git submodule update --init --depth 1
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Work tree already modified — assuming the patch is applied. (git checkout . to reset)"
else
  git apply --check "$PATCH"
  git apply "$PATCH"
  echo "Patch applied."
fi

# Publish only what tvOS needs: the common metadata module + the two tvOS targets.
# The patch strips non-Apple native targets (their static libs need zig cross-toolchains);
# quickjs.skipJni=true skips desktop JNI libs (need per-OS JDKs). Apple static libs build
# with plain Xcode + CMake.
./gradlew \
  :quickjs:publishKotlinMultiplatformPublicationToMavenLocal \
  :quickjs:publishTvosArm64PublicationToMavenLocal \
  :quickjs:publishTvosSimulatorArm64PublicationToMavenLocal \
  -Pquickjs.skipJni=true \
  -PRELEASE_SIGNING_ENABLED=false

echo
echo "Done. Published io.github.dokar3:quickjs-kt:1.0.5-tvos to ~/.m2/repository."
ls ~/.m2/repository/io/github/dokar3/ | grep tvos || true
