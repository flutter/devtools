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

1. Ensure your local Flutter SDK, DevTools dependencies, and generated code are up-to-date:
	```sh
	dt sync --update-on-path
	```
	> Warning: this will delete any local changes in your Flutter SDK you checked out from git.

2. Create a branch from your cloned DevTools repo:
	```sh
	git checkout -b myBranch
	```

3. Implement your changes, and commit to your branch:
	```sh
	git commit -m “description”
	```
	If your improvement is user-facing, [document it](packages/devtools_app/release_notes/README.md) in the same PR.

4. Push to your branch to GitHub:
	```sh
	git push origin myBranch
	```

5. Navigate to the [Pull Requests](https://github.com/flutter/devtools/pulls) tab in the main
[DevTools repo](https://github.com/flutter/devtools). You should see a popup to create a pull
request from the branch in your cloned repo to the DevTools `master` branch. Create a pull request.

### Keeping your fork in-sync

- If at any time you need to re-sync your branch, run:
	```
	dt sync
	```
	This command will:
	- pull the latest code from the upstream DevTools master branch
	- update `tool/flutter-sdk`	to the Flutter version DevTools is built and tested
	with on the CI
	- upgrade dependencies
	- perform code generation

	Optionally, pass the `--update-on-path` flag to also update your local Flutter SDK
	git checkout along with the `tool/flutter-sdk`. 

- If you want to upgrade dependencies and re-generate code (like mocks), but do
not want to merge `upstream/master` or update your Flutter SDK version, instead run
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

Please see [DEBUGGING.md][] for guidance on running and debugging DevTools.

## Testing for DevTools

Please see [TESTING.md][] for guidance on running and writing tests.

## Appendix

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
