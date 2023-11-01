#!/bin/bash

# TODO(kenz): delete this script once we can confirm it is not used in the
# Dart SDK or in infra tooling.

# This script requires the use of `gsed`. If you do not have this installed, please run
# `brew install gnu-sed` from your Mac. This script will take several minutes to complete,
# and for that reason it should be ran once per quarter instead of once per montly release.
# We can update the Perfetto UI code as needed as critical commits or bug fixes are landed.

# Contains a path to this script, relative to the directory it was called from.
RELATIVE_PATH_TO_SCRIPT="${BASH_SOURCE[0]}"

# The directory that this script is located in.
TOOL_DIR=`dirname "${RELATIVE_PATH_TO_SCRIPT}"`

# The devtools root directory is assumed to be the parent of this directory.
DEVTOOLS_DIR="${TOOL_DIR}/.."

pushd $DEVTOOLS_DIR/third_party/packages/perfetto_ui_compiled/lib

echo "UPDATE_PERFETTO: Moving DevTools-Perfetto integration files to a temp directory"
mkdir _tmp
mv dist/devtools/* _tmp/

echo "UPDATE_PERFETTO: Deleting existing Perfetto build"
rm -rf dist/

# Example usage: ./update_perfetto.sh -b /Users/me/path/to/perfetto/out/ui/ui/dist
if [[ $1 = '-b' ]]; then
  echo "UPDATE_PERFETTO: Using Perfetto build from $2"
  cp -R $2 ./
else
  echo "UPDATE_PERFETTO: Cloning Perfetto from HEAD"
  mkdir _perfetto
  cd _perfetto
  git clone https://android.googlesource.com/platform/external/perfetto
  cd perfetto

  echo "UPDATE_PERFETTO: Installing build deps and building the Perfetto UI"
  tools/install-build-deps --ui
  ui/build
  cp -R out/ui/ui/dist ../../
  cd ../../
fi

echo "UPDATE_PERFETTO: Deleting unnecessary js source map files"
find ./ -name '*.js.map' -exec rm {} \;

echo "UPDATE_PERFETTO: Deleting unnecessary Catapult files"
find ./ -name 'traceconv.wasm' -exec rm {} \;
find ./ -name 'traceconv_bundle.js' -exec rm {} \;
find ./ -name 'catapult_trace_viewer.*' -exec rm {} \;

echo "UPDATE_PERFETTO: Deleting unnecessary PNG files"
find ./ -name 'rec_*.png' -exec rm {} \;

echo "UPDATE_PERFETTO: Moving DevTools-Perfetto integration files back from _tmp/"
mkdir dist/devtools
mv _tmp/* dist/devtools/

echo "UPDATE_PERFETTO: Updating index.html headers to include DevTools-Perfetto integration files"
gsed -i "s/<\/head>/  <link id=\"devtools-style\" rel=\"stylesheet\" href=\"devtools\/devtools_dark.css\">\n<\/head>/g" dist/index.html
gsed -i "s/<\/head>/  <script src=\"devtools\/devtools_theme_handler.js\"><\/script>\n<\/head>/g" dist/index.html

echo "UPDATE_PERFETTO: Cleaning up temporary directories"
rm -rf _tmp
rm -rf _perfetto

# TODO(kenz): we should verify that every file name under dist/ is included in devtools_app/pubspec.yaml until
# https://github.com/flutter/flutter/issues/112019 is resolved.

popd

pushd $DEVTOOLS_DIR

# Verify that all the perfetto assets are included in the devtools_app pubspec.yaml, and that the assets
# paths are updated to the new version number.
dart ./tool/update_perfetto_assets.dart

popd
