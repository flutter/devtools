# Dart & Flutter DevTools Extensions

Extend Dart & Flutter's developer tool suite,
[Dart DevTools](https://docs.flutter.dev/tools/devtools/overview), with your own custom tool.
DevTools' extension framework allows you to build tools that can leverage existing frameworks
and utilities from DevTools (VM service connection, theming, shared widgets, utilities, etc.).

You can add a DevTools extension to an existing pub package, or you can create a new package
that provides a DevTools extension only. In both these scenarios, the end-user must list a
dependency on the package providing the DevTools extension in order to see the extension
in DevTools.

When an app that depends on your package is connected to DevTools, your extension will
show up in its own DevTools tab:

![Example devtools extension](_readme_images/example_devtools_extension.png)

Follow the instructions below to get started, and use the
[end-to-end example](https://github.com/flutter/devtools/tree/master/packages/devtools_extensions/example/)
for reference.

# Table of contents
1. [Setup your package hierarchy](#setup-your-package-hierarchy)
2. [Create a DevTools extension](#create-a-devtools-extension)
    - [Where to put your source code](#where-to-put-your-source-code)
    - [Development](#create-the-extension-web-app)
    - [Debugging](#debug-the-extension-web-app)
3. [Publish your package with a DevTools extension](#publish-your-package-with-a-DevTools-extension)
4. [Resources and support](#resources-and-support)

## Setup your package hierarchy

### Standalone extensions

If you are adding a DevTools extension to an existing Dart package, proceed to the
instructions for [configuring your extension](#configure-your-extension).

If you are creating a standalone DevTools extension as a new package (i.e. not
part of an existing pub package), then you can build your extension in the same
package that it will be published with. Since the extension must be built as a
Flutter web app, you can use the following `flutter create` template:

```
flutter create --template app --platforms web my_new_tool
```

Now use the `my_new_tool` package to [configure your extension](#configure-your-extension)
in the next step.

### Configure your extension

In the Dart package that will provide the DevTools extension to users,
add a top-level `extension` directory:
```
some_pkg
  extension/
  lib/
  ...
```

Under this directory, create the following structure:
```
extension
  devtools/
    build/
    config.yaml
```

The `config.yaml` file contains metadata that DevTools needs to load the extension.

```yaml
name: some_pkg
issueTracker: <link_to_your_issue_tracker.com>
version: 0.0.1
materialIconCodePoint: '0xe0b1'
```

Copy the `config.yaml` file content above and paste it into the `config.yaml` file you just 
created in your package. **It is important that you use the exact file name and field names
as shown, or else your extension may fail to load in DevTools.**

For each key, fill in the appropriate value for your package. 
* `name`: the package name that this DevTools extension belongs to. The value of this field 
will be used in the extension page title bar. **(required)**
* `issueTracker`: the url for your issue tracker. When a user clicks the “Report an issue” 
link in the DevTools UI, they will be directed to this url. **(required)**
* `version`: the version of your DevTools extension. This version number should evolve over 
time as you ship new features for your extension. The value of this field will be used in the 
extension page title bar. **(required)**

  ![Extension title bar components](_readme_images/extension_title_bar.png)

* `materialIconCodePoint`: corresponds to the codepoint value of an icon from
[material/icons.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/icons.dart).
This icon will be used for the extension’s tab in the top-level DevTools tab bar. **(required)**

  ![Extension tab icon](_readme_images/extension_tab_icon.png)

For the most up-to-date documentation on the `config.yaml` spec, see
[extension_config_spec.md](https://github.com/flutter/devtools/blob/master/packages/devtools_extensions/extension_config_spec.md)

Now it is time to build your extension.

## Create a DevTools extension

DevTools extensions must be written as Flutter web apps. This is because DevTools embeds
extensions in an iFrame to display them dynamically in DevTools.

### Where to put your source code

Only the pre-compiled output of your extension needs to be shipped with your pub package
in order for DevTools to load it. 

#### Standalone extensions

For a standalone extension (an extension that is not being shipped as part of an existing
pub package), it is acceptable to include your source code in the same package that the
extension is shipped with. This will simplify development, and since users of your
package will add a dependency on your package as a `dev_dependency`, the size of your
package will not affect the user's app size.

```
my_new_tool
  extension/
    devtools/
      build/
        ...  # pre-compiled output of the Flutter web app under lib/
      config.yaml
  lib/  # source code for your extension Flutter web app
    src/
      ...
```

#### Extensions that are part of an existing package

To keep the size of your pub package small, we recommend that
you develop your DevTools extension outside of your pub package. Here is the recommended package structure:

```
some_pkg/  # formerly the repository root of your pub package
  packages/
    some_pkg/  # your pub package
      extension/
        devtools/
          build/
            ...  # pre-compiled output of some_pkg_devtools_extension/lib
          config.yaml
    some_pkg_devtools_extension/
      lib/  # source code for your extension Flutter web app
```

### Create the extension web app

1. Create the Flutter web app 
    - **Skip this step if you are building a standalone extension, since you already did
  this when you set up your package hierarchy.**

    From the directory where you want your extension source code to live, run the following
    command, replacing `some_pkg_devtools_extension` with 
    `<your_package_name>_devtools_extension``:
    ```sh
    flutter create --template app --platforms web some_pkg_devtools_extension
    ```

2. Add the `devtools_extensions` dependency to your Flutter web app.

    In `pubspec.yaml`, add the following:
    ```yaml
    devtools_extensions: ^0.0.14
    ```

3. Add the `DevToolsExtension` widget at the root of your Fluter web app.

    In `lib/main.dart`, add the following:
    ```dart
    import 'package:devtools_extensions/devtools_extensions.dart';
    import 'package:flutter/material.dart';

    void main() {
      runApp(const SomePkgDevToolsExtension());
    }

    class SomePkgDevToolsExtension extends StatelessWidget {
      const SomePkgDevToolsExtension({super.key});

      @override
      Widget build(BuildContext context) {
        return const DevToolsExtension(
          child: Placeholder(), // Build your extension here
        );
      }
    }
    ```

    The `DevToolsExtension` widget automatically performs all extension initialization required
    to interact with DevTools. From anywhere in your extension web app, you can access the globals:
      - `extensionManager`: a manager for interacting with DevTools or the extensions framework
      - `serviceManager`: a manager for interacting with the connected vm service, if present
      - `dtdManager`: a manager for interacting with the Dart Tooling Daemon, if present

#### Utilize helper packages

Use [package:devtools_app_shared](https://pub.dev/packages/devtools_app_shared) for access to
service managers, common widgets, DevTools theming, utilities, and more. See
[devtools_app_shared/example](https://github.com/flutter/devtools/tree/master/packages/devtools_app_shared/example)
for sample usages.

### Debug the extension web app

#### Use the Simulated DevTools Environment (recommended for development)

For debugging purposes, you will likely want to use the "simulated DevTools environment". This
is a simulated environment that allows you to build your extension without having to develop it
as an embedded iFrame in DevTools. Running your extension this way will wrap your extension
with an environment that simulates the DevTools-to-extension connection. It also
gives you access to hot restart and a faster development cycle.

![Simulated devtools environment](_readme_images/simulated_devtools_environment.png)
1. Your DevTools extension.
2. The VM service URI for a test app that your DevTools extension will interact with. This app
should depend on your extension’s parent package.
3. Buttons to perform actions that a user may trigger from DevTools.
4. Logs showing the messages that will be sent between your extension and DevTools.

The simulated environment is enabled by an environment parameter `use_simulated_environment`.
To run your extension web app with this flag enabled, add a configuration to your `launch.json`
file in VS code:
```json
{
    ...
    "configurations": [
        ...
        {
            "name": "some_pkg_devtools_extension + simulated environment",
            "cwd": "packages/some_pkg_devtools_extension",
            "request": "launch",
            "type": "dart",
            "args": [
                "--dart-define=use_simulated_environment=true"
            ],
        },
    ]
}
```

or launch your app from the command line with the added flag:
```sh
flutter run -d chrome --dart-define=use_simulated_environment=true
```

#### Use a real DevTools Environment

To use a real DevTools environment, you will need to perform a series of setup steps:

1. Develop your extension to a point where you are ready to test your changes in a
real DevTools environment. Build your flutter web app and copy the built assets from
`your_extension_web_app/build/web` to your pub package's `extension/devtools/build` directory.

    Use the `build_and_copy` command from `package:devtools_extensions` to help with this step.
    ```sh
    cd your_extension_web_app;
    flutter pub get;
    dart run devtools_extensions build_and_copy --source=. --dest=../some_pkg/extension/devtools
    ```

    To ensure that your extension is setup properly for loading in DevTools, run the
    `validate` command from `package:devtools_extensions`. The `--package` argument
    should point to the root of the Dart package that this extension will be published
    with.
    ```sh
    cd your_extension_web_app;
    flutter pub get;
    dart run devtools_extensions validate --package=../some_pkg
    ```

2. Prepare and run a test application that depends on your pub package that is providing the
extension. You'll need to change the `pubspec.yaml` dependency to be a
[path](https://dart.dev/tools/pub/dependencies#path-packages) dependency that points to your
local pub package source code. Once you have done this, run `pub get` on the test app, and
then run the application.

3. Start DevTools:
    * As long as you are using **Dart SDK >= todo or Flutter SDK >= todo**,
    you can launch the DevTools instance that was just started by running your app (either from
    a url printed to command line or from the IDE where you ran your test app). You can also run
    `dart devtools` from the command line.
    * **If you need local or unreleased changes from DevTools**, you'll need to build and run 
    DevTools from source. See the DevTools [CONTRIBUTING.md]() for a guide on how to do this.
    You'll need to build DevTools with the server and the front end to test extensions - see
    [instructions](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#development-devtools-server--devtools-flutter-web-app).

4. Connect your test app to DevTools if it is not connected already, and you should see a tab
in the DevTools app bar for your extension. The enabled or disabled state of your extension is
managed by DevTools, which is exposed from an "Extensions" menu in DevTools, available from the
action buttons in the upper right corner of the screen.

## Publish your package with a DevTools extension

In order for a package to provide a DevTools extension to its users, it must be published with the
expected content in the `your_package/extension/devtools/` directory (see the
[setup instructions](#setup-your-package-hierarchy) above).

1. Ensure the `extension/devtools/config.yaml` file exists and is configured per the
[specifications above](#setup-your-package-hierarchy).
2. Use the `build_and_copy` command provided by `package:devtools_extensions` to build
your extension and copy the output to the `extension/devtools` directory:
```sh
cd your_extension_web_app;
flutter pub get;
dart run devtools_extensions build_and_copy --source=. --dest=../some_pkg/extension/devtools
```

Then publish your package. When running `pub publish`, you will see a warning if you
do not have the `config.yaml` file and a non-empty `build` directory as required.

### What if I don't want the `extension/devtools/build/` contents checked into source control?

As a package author, the content that you check into your git repository is completely up to you.
If you want the contents of `extension/devtools/build/` to be git ignored, then you'll just need
to ensure that the extension web app is always built and included in `extension/devtools/build/`
when you publish your package. To do so, add the following to a `.pubignore` file in the
`extension/devtools/` directory:

```
!build
```

This will ensure that, even if the `extension/devtools/build` directory has been been git
ignored, the directory will still be included when publishing the package on pub.

To verify the published extension contents are always up to date, consider adding a tool
script to your repo that looks something like this:

**publish.sh**
```sh
pushd your_extension_web_app

flutter pub get
dart run devtools_extensions build_and_copy --source=. --dest=../your_pub_package/extension/devtools

popd

pushd your_pub_package
flutter pub publish
popd
```

## Resources and support

Please join the [Flutter Discord server](https://github.com/flutter/flutter/wiki/Chat) and then check out
the [#devtools-extension-authors](https://discord.com/channels/608014603317936148/1159561514072690739)
channel to connect with other DevTools extension authors and the DevTools team.

For feature requests or bugs, please [file an issue](https://github.com/flutter/devtools/issues/new)
on the DevTools Github repository.
