import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/utils.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

// # Contains a path to this script, relative to the directory it was called from.
// RELATIVE_PATH_TO_SCRIPT="${BASH_SOURCE[0]}"

// # The directory that this script is located in.
// TOOL_DIR=`dirname "${RELATIVE_PATH_TO_SCRIPT}"`

// # The devtools root directory is assumed to be the parent of this directory.
// DEVTOOLS_DIR="${TOOL_DIR}/.."

class UpdatePerfettoCommand extends Command {
  UpdatePerfettoCommand() {
    argParser.addOption(
      'build',
      abbr: 'b',
      help: 'Builds perfetto using the given directory',
    );
  }
  @override
  // TODO(@CodeDake): Add a better description
  String get description => 'Updates perfetto assets';

  @override
  String get name => 'update-perfetto';

  @override
  FutureOr? run() async {
    final buildFlag = argResults!['build'];
    // pushd $DEVTOOLS_DIR/third_party/packages/perfetto_ui_compiled/lib

    // echo "UPDATE_PERFETTO: Moving DevTools-Perfetto integration files to a temp directory"
    // mkdir _tmp
    final tempPerfettoBuildDirectory =
        await Directory(pathFromRepoRoot('.')).createTemp();
    try {
      // mv dist/devtools/* _tmp/
      final existingPerfettoBuild = Directory(pathFromRepoRoot(path.join(
        'dist',
        'devtools',
      )));
      existingPerfettoBuild.rename(tempPerfettoBuildDirectory.path);

      // echo "UPDATE_PERFETTO: Deleting existing Perfetto build"
      // rm -rf dist/
      existingPerfettoBuild.deleteSync();

      // # Example usage: ./update_perfetto.sh -b /Users/me/path/to/perfetto/out/ui/ui/dist
      // if [[ $1 = '-b' ]]; then
      if (buildFlag != null) {
        //   echo "UPDATE_PERFETTO: Using Perfetto build from $2"
        //   cp -R $2 ./
        existingPerfettoBuild.createSync();
        copyPath(buildFlag, existingPerfettoBuild.path);
        // else
      } else {
        //   echo "UPDATE_PERFETTO: Cloning Perfetto from HEAD"
        //   mkdir _perfetto
        //   cd _perfetto
        //   git clone https://android.googlesource.com/platform/external/perfetto
        //   cd perfetto

        //   echo "UPDATE_PERFETTO: Installing build deps and building the Perfetto UI"
        //   tools/install-build-deps --ui
        //   ui/build
        //   cp -R out/ui/ui/dist ../../
        //   cd ../../
        // fi
      }

      // echo "UPDATE_PERFETTO: Deleting unnecessary js source map files"
      // find ./ -name '*.js.map' -exec rm {} \;

      // echo "UPDATE_PERFETTO: Deleting unnecessary Catapult files"
      // find ./ -name 'traceconv.wasm' -exec rm {} \;
      // find ./ -name 'traceconv_bundle.js' -exec rm {} \;
      // find ./ -name 'catapult_trace_viewer.*' -exec rm {} \;

      // echo "UPDATE_PERFETTO: Deleting unnecessary PNG files"
      // find ./ -name 'rec_*.png' -exec rm {} \;

      // echo "UPDATE_PERFETTO: Moving DevTools-Perfetto integration files back from _tmp/"
      // mkdir dist/devtools
      // mv _tmp/* dist/devtools/

      // echo "UPDATE_PERFETTO: Updating index.html headers to include DevTools-Perfetto integration files"
      // gsed -i "s/<\/head>/  <link id=\"devtools-style\" rel=\"stylesheet\" href=\"devtools\/devtools_dark.css\">\n<\/head>/g" dist/index.html
      // gsed -i "s/<\/head>/  <script src=\"devtools\/devtools_theme_handler.js\"><\/script>\n<\/head>/g" dist/index.html

      // echo "UPDATE_PERFETTO: Cleaning up temporary directories"
      // rm -rf _tmp
      // rm -rf _perfetto

      // # TODO(kenz): we should verify that every file name under dist/ is included in devtools_app/pubspec.yaml until
      // # https://github.com/flutter/flutter/issues/112019 is resolved.

      // popd

      // pushd $DEVTOOLS_DIR

      // # Verify that all the perfetto assets are included in the devtools_app pubspec.yaml, and that the assets
      // # paths are updated to the new version number.
      // dart ./tool/update_perfetto_assets.dart

      // popd
    } finally {
      tempDirectory.delete(recursive: true);
    }
  }
}
