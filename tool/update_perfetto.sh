#!/bin/bash
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

pushd $DEVTOOLS_DIR/packages/devtools_app/assets/perfetto

echo "UPDATE_PERFETTO: Moving DevTools-Perfetto integration files to a temp directory"
mkdir _tmp
mv dist/devtools_dark.css _tmp/
mv dist/devtools_light.css _tmp/
mv dist/devtools_shared.css _tmp/
mv dist/devtools_theme_handler.js _tmp/

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

echo "UPDATE_PERFETTO: Moving DevTools-Perfetto integration files back from _tmp/"
mv _tmp/devtools_dark.css dist/
mv _tmp/devtools_light.css dist/
mv _tmp/devtools_shared.css dist/
mv _tmp/devtools_theme_handler.js dist/

echo "UPDATE_PERFETTO: Updating index.html headers to include DevTools-Perfetto integration files"
gsed -i "s/<\/head>/  <link id=\"devtools-style\" rel=\"stylesheet\" href=\"devtools_dark.css\">\n<\/head>/g" dist/index.html
gsed -i "s/<\/head>/  <script src=\"devtools_theme_handler.js\"><\/script>\n<\/head>/g" dist/index.html

echo "UPDATE_PERFETTO: Cleaning up temporary directories"
rm -rf _tmp
rm -rf _perfetto

popd