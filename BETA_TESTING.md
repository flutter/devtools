# Build DevTools

This page describes the fastest way to build DevTools with the goal to use it. Do not mix this setup with development environment. If you want to make code changes, follow [contributing guidance](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md).

You may want to build DevTools to:

1. Try experimental features
2. Run desktop version to get away from browser memory limit. For example, if
heap snapshots of your application casues aout of memory crash of the Chrome tab.

The steps were tested for Mac. They may require adjustments for other platforms. Contributions,
that make the steps more platform agnostic, are welcome.

## Prerequisites

1. [Configure](https://docs.flutter.dev/get-started/install) Dart or Flutter.

## Setup DevTools

If it is initial setup:

1. In your terminal `cd` to a folder where you want to clone devtools, and that does not have subfolder `devtools` yet.

2. Clone the repo and get needed Flutter version to local folder:

```bash
git clone https://github.com/flutter/devtools.git

bash devtools/tool/update_flutter_sdk.sh
cd devtools
```

## Or refresh DevTools

If you are refreting previously configured version:

1. `cd` to the `devtools` directory created in the [Setup and start](#setup-and-start) section.

2. Refresh DevTools (it will delete all your local changes!):

```bash
git checkout master
git reset --hard origin/master

bash tool/update_flutter_sdk.sh
bash tool/upgrade.sh
```

If some steps failed, remove the directory and redo to [Setup](#setup).

## Start DevTools


```
cd devtools/packages/devtools_app
../../tool/flutter-sdk/bin/flutter run -d chrome --dart-define=enable_experiments=true
```

3. Paste the URL of your application (for example [Gallery](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-to-application)) to the connection textbox.
