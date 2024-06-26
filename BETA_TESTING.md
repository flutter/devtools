# Build DevTools

This page describes the fastest way to build DevTools with the goal to use it. Do not mix this setup with development environment. If you want to make code changes, follow [contributing guidance](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md).

You may want to build DevTools locally to:

1. Try experimental features

2. Run DevTools on Flutter Desktop instead of Flutter Web. This will eliminate issues like the browser memory limit, for example, to be able to analyze heap snapshots of large applications.

These steps are tested for Mac and may require adjustments for other platforms. Contributions
to make these instructions more platform-agnostic are welcome.

## Prerequisites (first time only)

### Set up Dart & Flutter

[Configure](https://docs.flutter.dev/get-started/install) Dart & Flutter on your local machine.

After doing so, typing `which flutter` and `which dart` (or `where.exe flutter` and `where.exe dart` for Windows)
into your terminal should print the path to your Flutter and Dart executables.

### Set up your DevTools environment

1. Ensure you have a clone of the DevTools repository on your machine. This can be a clone of
`flutter/devtools` or a clone of a DevTools
[fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) from your own Github
account. You may want to fork Devtools to your own Github account if you plan to contribute
to the project.

    In your terminal, navigate to a directory where you want to clone DevTools: `cd some/directory`.
    This folder must not already contain a folder named 'devtools'.
 
    **To clone flutter/devtools**:
    - Clone the DevTools repo: `git clone git@github.com:flutter/devtools.git` 
        - If you haven't already, you may need to
    [generate a new SSH key](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)
    to connect to Github with SSH.

    **To clone your fork of flutter/devtools**:
    - [Fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) the DevTools repo to your
    own Github account.
    - Clone your fork of the DevTools repo: `git clone git@github.com:your_github_account/devtools.git` 
        - If you haven't already, you may need to
    [generate a new SSH key](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)
    to connect to Github with SSH.
    - Make sure to [configure Git to keep your fork in sync](https://docs.github.com/en/get-started/quickstart/fork-a-repo#configuring-git-to-sync-your-fork-with-the-upstream-repository)
    with the upstream DevTools repo.

2. Ensure that you have access to the `devtools_tool` executable by:
	- Running `flutter pub get` on the `devtools/tool` directory
	- Adding the `devtools/tool/bin` folder to your `PATH` environment variable:
	  - **MacOS Users**
	    - add the following to your `~/.zshrc` file (or `~/.bashrc`, `~/.bash_profile` if you use Bash),
		replacing `<DEVTOOLS_DIR>` with the local path to your DevTools repo:

			```
			export PATH=$PATH:<DEVTOOLS_DIR>/tool/bin
			```
	  - **Windows Users**
		- Open "Edit environment variables for your account" from Control Panel
		- Locate the `Path` variable and click **Edit**
		- Click the **New** button and paste in `<DEVTOOLS_DIR>/tool/bin`, replacing `<DEVTOOLS_DIR>`
		with the local path to your DevTools repo.
	
	Explore the commands and helpers that the `devtools_tool` provides by running `devtools_tool -h`. 

## Prepare to build DevTools

To ensure your DevTools repository is up to date and ready to build, run the following from the
`devtools` directory (this will delete any local changes you have made to your DevTools clone):
```bash
git checkout master
git reset --hard origin/master

devtools_tool update-flutter-sdk
devtools_tool pub-get --only-main --upgrade
```

## Start DevTools and connect to an app

1. From the main `devtools/packages/devtools_app` directory, run the following, where
`<platform>` is one of `chrome`, `macos`, or `windows` depending on which platform you
are targeting:
    ```bash
    ../../tool/flutter-sdk/bin/flutter run --release -d <platform>
    ```

    - Add `--dart-define=enable_experiments=true` to enable experimental features.

2. Run the application that you want to debug or profile with DevTools. 
3. Paste the VM Service URL of your application into the DevTools connect dialog. See this
[example](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#connect-devtools-to-a-test-application).
