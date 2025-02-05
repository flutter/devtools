<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
# Contributing to DevTools

![GitHub contributors](https://img.shields.io/github/contributors/flutter/devtools.svg)

_tl;dr: join [Discord](https://github.com/flutter/flutter/blob/master/docs/contributing/Chat.md), be
[courteous](https://github.com/flutter/flutter/blob/master/CODE_OF_CONDUCT.md), follow the steps below
to set up a development environment; if you stick around and contribute, you can
[join the team](https://github.com/flutter/flutter/blob/master/docs/contributing/Contributor-access.md) and get commit access._

> If you are here because you just want to test the bleeding-edge (unreleased) DevTools functionality,
follow our [beta testing guidance](https://github.com/flutter/devtools/blob/master/BETA_TESTING.md).

## Welcome

We gladly accept contributions via GitHub pull requests! We encourage you to read the
[Welcome](https://github.com/flutter/flutter/blob/master/CONTRIBUTING.md#welcome) remarks in the Flutter
framework's contributing guide, as all of that information applies to contributing to the `flutter/devtools`
repo as well.

We communicate primarily over GitHub and [Discord](https://github.com/flutter/flutter/blob/master/docs/contributing/Chat.md) on the
[#hackers-devtools](https://discord.com/channels/608014603317936148/1106667330093723668) channel.

Before contributing code:

1. Complete the
[Contributor License Agreement](https://cla.developers.google.com/clas).
You can do this online, and it only takes a minute.

2. Review the [DevTools style guide](STYLE.md), which uses a combination of Dart and Flutter best practices.

## Table of contents
1. [Developing for DevTools](#developing-for-devtools)
	- [Set up your DevTools environment](#set-up-your-devtools-environment)
	- [Workflow for making changes](#workflow-for-making-changes)
	- [Keeping your fork in sync](#keeping-your-fork-in-sync)
2. [Running and debugging DevTools](#running-and-debugging-devtools)
    - [Frontend only (most common)](#frontend-only-most-common)
    - [Frontend + DevTools server](#frontend--devtools-server)
    - [DevTools + VS Code integration](#devtools--vs-code-integration-ide-embedded-devtools-experience)
3. [Testing for DevTools](#testing-for-devtools)
4. [Appendix](#appendix)

## Developing for DevTools

### Set up your DevTools environment

**Before setting up your DevTools environment**, please make sure you have
[cloned the Flutter SDK from GitHub](https://github.com/flutter/flutter/blob/main/docs/contributing/Setting-up-the-Framework-development-environment.md)
and added the included `flutter` and `dart` executables to your `PATH` environment variable (see Flutter
instructions for how to [update your PATH](https://flutter.dev/to/update-macos-path)).

Typing `which flutter` and `which dart` (or `where.exe flutter` and `where.exe dart` for Windows)
into your terminal should print the path to the binaries from the Flutter SDK you cloned from GitHub.

Be sure to run `flutter doctor -v` to ensure your Flutter environment is set up correctly.
If you plan to develop on macOS or run a test app on an iOS simulator, you will need
to ensure CocoaPods is setup correctly.

1. [Fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) the DevTools repo to your
own Github account, and then clone it using SSH.
	- If you haven't already, you may need to
[generate a new SSH key](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)
to connect to Github with SSH.
	- Make sure to [configure Git to keep your fork in sync](https://docs.github.com/en/get-started/quickstart/fork-a-repo#configuring-git-to-sync-your-fork-with-the-upstream-repository)
with the upstream DevTools repo.

2. Ensure that you have access to the DevTools repo management tool exectuable, `dt`:
	- Run `flutter pub get` on the `devtools/tool` directory
	- Add the `devtools/tool/bin` folder to your `PATH` environment variable:
	  - **MacOS Users**
	    - add the following to your `~/.zshrc` file (or `~/.bashrc`, `~/.bash_profile` if you use Bash),
		replacing `<DEVTOOLS_DIR>` with the absolute path to your DevTools repo:

			```
			export PATH=$PATH:<DEVTOOLS_DIR>/tool/bin
			```
	  - **Windows Users**
		- Open "Edit environment variables for your account" from Control Panel
		- Locate the `Path` variable and click **Edit**
		- Click the **New** button and paste in `<DEVTOOLS_DIR>/tool/bin`, replacing `<DEVTOOLS_DIR>`
		with the absolute path to your DevTools repo.

	Explore the commands and helpers that `dt` provides by running `dt -h`.

3. **Optional:** enable and activate DCM (Dart Code Metrics) - see the [DCM section below](#enable-and-activate-dcm-dart-code-metrics)

#### Set up your IDE

We recommend using VS Code for your DevTools development environment because this gives you
access to some advanced development and configuration features. When you open DevTools in VS Code,
open the top-level `devtools/` directory in your VS Code workspace. This will give you access to a set
of launch configurations for running and debugging DevTools:

![VS Code launch configurations](_markdown_images/vs_code_launch_configurations.png)

### Workflow for making changes

1. Change your local Flutter SDK to the latest flutter candidate branch:
	```sh
	dt update-flutter-sdk --update-on-path
	```
	> Warning: this will delete any local changes in your Flutter SDK you checked out from git.

2. Create a branch from your cloned DevTools repo:
	```sh
	git checkout -b myBranch
	```

3. Ensure your branch, dependencies, and generated code are up-to-date:
	```sh
	dt sync
	```

4. Implement your changes, and commit to your branch:
	```sh
	git commit -m “description”
	```
	If your improvement is user-facing, [document it](packages/devtools_app/release_notes/README.md) in the same PR.

5. Push to your branch to GitHub:
	```sh
	git push origin myBranch
	```

6. Navigate to the [Pull Requests](https://github.com/flutter/devtools/pulls) tab in the main
[DevTools repo](https://github.com/flutter/devtools). You should see a popup to create a pull
request from the branch in your cloned repo to the DevTools `master` branch. Create a pull request.

### Keeping your fork in-sync

- If at any time you need to re-sync your branch, run:
	```
	dt sync
	```
	This will pull the latest code from the upstream DevTools, upgrade dependencies, and perform code generation.

- If you want to upgrade dependencies and re-generate code (like mocks), but do not want to merge `upstream/master`, instead run
	```
	dt generate-code --upgrade
	```

 - To update DCM to the same version as on GitHub bots with apt-get or brew:

    1. Locate, copy and run the `apt-get` command searching by searching for
	"install dcm" in [build.yaml](https://github.com/flutter/devtools/blob/master/.github/workflows/build.yaml).

    2. Using the DCM version you just copied in the previous step (without the `-1` suffix), install
	`dcm` using homebrew: `brew install cqlabs/dcm/dcm@<version on bots without -1>`

    You can check your local version to verify it matches the version in
	[build.yaml](https://github.com/flutter/devtools/blob/master/.github/workflows/build.yaml): `dcm --version`.

    If the version of DCM used on the bots is outdated, consider contributing a
	PR to update the version on the bots to the latest.

## Running and debugging DevTools

There are a few different environments that you may need to run DevTools in. After running DevTools
in one of the environments below, connect to a test application to debug DevTools runtime tooling
(the majority of DevTools tools). See the
[Connect DevTools to a test application](#connect-devtools-to-a-test-application) section below.

### Frontend only (most common)

Most of the time, you will not need to run DevTools with the DevTools server to test your changes.
You can run DevTools in debug mode as either a Flutter web or Flutter desktop app.

> Note: though DevTools is shipped as a Flutter Web app, we recommend developing as a Flutter
Desktop app whenever possible for a more efficient development workflow. Please see the
[running on Flutter desktop](#running-devtools-on-flutter-desktop) section below for instructions.

- To run DevTools as a Flutter web app **from VS Code**, run with the **devtools** configuration and the "Chrome" device
	- To run with experiments enabled, run from VS Code with the **devtools + experiments** configuration
- To run DevTools as a Flutter web app **from the command line**, run `flutter run -d chrome`
	- To run with experiments enabled, add the flag `--dart-define=enable_experiments=true`

### Frontend + DevTools server

To develop with a workflow that exercises the DevTools server <==> DevTools client connection,
you will need to perform the following set up steps (first time only).

1. Clone the [Dart SDK](https://github.com/dart-lang/sdk) fron GitHub.
2. The `LOCAL_DART_SDK` environment variable needs to point to this path: `export LOCAL_DART_SDK=/path/to/dart/sdk`

If you are also developing server side code (e.g. the `devtools_shared` package), you will need to add a
dependency override to `sdk/pkg/dds/pubspec.yaml`.

```yaml
dependency_overrides:
  devtools_shared:
    path: relative/path/to/devtools/packages/devtools_shared
```

Then you can run DevTools with the server by running the following from anywhere under the `devtools/` directory:
1. To run the DevTools web app in release mode, served with the DevTools server (this emulates the production environment):
	```
	dt serve
	```
2. To run the DevTools web app in debug mode, with full debugging support, and with a connection to a live DevTools server:
	```sh
	dt run
	```

Option 2 is useful for a quicker development cycle. The DevTools build time will be faster, and you will be
able to connect the DevTools web app to an IDE or another DevTools instance for debugging purposes.

To see the full list of arguments available for either command, please pass the `-h` flag.

### DevTools + VS Code integration (IDE-embedded DevTools experience)

To test the integration with VS Code, you can set up the Dart VS Code extension to run DevTools
and the server from your local source code. Follow the
[Frontend + DevTools server](#frontend--devtools-server) setup instructions above, and make sure
you have version v3.47 or newer of the Dart extension for VS Code.

Open your VS Code settings (Run the **Preferences: Open User Settings (JSON)** command from the
command palette (`F1`)) and add the following to your settings:

```js
"dart.customDevTools": {
	"path": "/absolute/path/to/devtools",
	"env": {
		"LOCAL_DART_SDK": "/absolute/path/to/sdk"
		// Path to the Flutter SDK that will be used to build DevTools. This may
		// be the path to the included Flutter SDK under the tool/ directory or
		// the path to your local Flutter SDK git checkout.
		"FLUTTER_ROOT": "/absolute/path/to/devtools/tool/flutter-sdk"
	},
	"args": [
		// Arguments that will be passed along to the `dt serve` command.
    ],
},
```

This instructs VS Code to run the `dt serve` command instead of running `dart devtools`.
You must set the `LOCAL_DART_SDK` and `FLUTTER_ROOT` env variables correctly for the script to work.

Next, restart VS Code (or run the **Developer: Reload Window** command from the command palette (`F1`))
and DevTools will be run from your local source code. After making any code changes to DevTools or the
server, you will need to re-run the **Developer: Reload Window** command to rebuild and restart the server.

## Testing for DevTools

Please see [TESTING.md](TESTING.md) for guidance on running and writing tests.

## Appendix

### Connect DevTools to a test application

For working on most DevTools tools, a connection to a running Dart or Flutter app is required. Run any Dart or Flutter app of your choice to
connect it to DevTools. Consider running [veggieseasons](https://github.com/flutter/samples/tree/main/veggieseasons) or another Flutter sample since those apps have plenty of interesting
code to debug.
1. Run your Dart or Flutter app.
	> Note: some DevTools features may be unavailable depending on the test app platform (Flutter native, Flutter web, Dart CLI, etc.) or run mode
	(debug, profile) you choose.
2. Copy the URI printed to the command line (you will use this URI to connect to DevTools).

	```
	"A Dart VM Service on iPhone 14 Pro Max is available at: <copy-this-uri>"
	```
3. Paste this URI into the connect dialog in DevTools and click "Connect".

	![Connect dialog example](_markdown_images/connect_dialog_example.png)

### Running DevTools on Flutter Desktop

For a faster development cycle with hot reload, you can run DevTools on Flutter desktop. Some DevTools
features only work on the web, like the embedded Perfetto trace viewer, DevTools extensions, or WASM support,
but the limitations on the desktop app are few.

To run DevTools with the desktop embedder, you can run `flutter run -d macos` from `devtools/packages/devtools_app`,
or you can run DevTools from your IDE with the `macOS` device selected.

If this fails, you may need to run `flutter create .` from `devtools/packages/devtools_app` to generate
the updated files for your platform. If you want to run DevTools on Flutter desktop for Windows or Linux,
you will need to generate the files for this platform using the `flutter create .` command, and then run using
`flutter run -d <windows or linux>`.

### Enable and activate DCM (Dart Code Metrics)

Enabling and activating DCM is optional. When you open a PR, the CI bots will show you any DCM warnings introduced
by your change which should be fixed before submitting.

- **Contributors who work at Google:** you can use the Google-purchased license key to activate DCM.
See [go/dash-devexp-dcm-keys](http://goto.google.com/dash-devexp-dcm-keys).

- **All other contributors:** please follow instructions at <https://dcm.dev/pricing/>. You can either use the free tier of DCM, or purchase a team license. Note that the free tier doesn't support all the rules of the paid tier, so you will also need to consult the output of the [Dart Code Metrics workflow on Github](#running-the-dart-code-metrics-github-workflow) when you open your PR.

To enable DCM:

1. Install the executable for your target platform. You can refer to [this guide](https://dcm.dev/docs/teams/getting-started/#installation).
2. [Get the license key](http://goto.google.com/dash-devexp-dcm-keys) and activate DCM. To do so, run `dcm activate --license-key=YOUR_KEY` from the console.
3. Install the extension for your IDE. If you use VS Code, you can get it from [the marketplace](https://marketplace.visualstudio.com/items?itemName=dcmdev.dcm-vscode-extension). If you use IntelliJ IDEA or Android Studio, you can find the plugin [here](https://plugins.jetbrains.com/plugin/20856-dcm).
4. Reload the IDE.

>Note:  DCM issues can be distinguished from the Dart analyzer issues by their name: DCM rule names contain
dashes `-` instead of underscores `_`. Some of the issues can be fixed via CLI; to do so, run `dcm fix` for
any directory. To apply `dcm fix` on a file save in the IDE, refer to
[this guide](https://dcm.dev/docs/teams/ide-integrations/vscode/#extension-capabilities).

### third_party dependencies

All content not authored by the Flutter team (which includes both sponsored and open-source contributors)
must go in the `third_party` directory. As an expedient to make the `third_party` code works well with our
build scripts, code in `third_party` should be given a stub `pubspec.yaml` file so that you can reference
the resources from the packages directory from `packages/devtools_app/web/index.html`.
