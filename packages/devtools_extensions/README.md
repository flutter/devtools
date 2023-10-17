# Dart & Flutter DevTools Extensions

Extend Dart & Flutter's developer tool suite,
[Dart DevTools](https://docs.flutter.dev/tools/devtools/overview), with a custom tool for
your package. DevTools' extension framework allows you to build a tool for your Dart package
that can leverage existing frameworks and utilities from DevTools (VM service connection, theming,
shared widgets, utilities, etc.). When an app is connected to DevTools that depends on your
package, your extension will show up in its own DevTools tab:

![Example devtools extension](_readme_images/example_devtools_extension.png)

Follow the instructions below to get started, and use the
[end-to-end example](https://github.com/flutter/devtools/tree/master/packages/devtools_extensions/example/)
for reference.

# Table of contents
1. [Setup your package to provide a DevTools extension](#setup-your-package-to-provide-a-DevTools-extension)
2. [Create a DevTools extension](#create-a-devtools-extension)
    - [Where to put your source code](#where-to-put-your-source-code)
    - [Development](#create-the-extension-web-app)
    - [Debugging](#debug-the-extension-web-app)
3. [Publish your package with a DevTools extension](#publish-your-package-with-a-DevTools-extension)
4. [Resources and support](#resources-and-support)

## Setup your package to provide a DevTools extension

DevTools extensions must be written as Flutter web apps. This is because DevTools embeds
extensions in an iFrame to display them dynamically in DevTools.

To add an extension to your Dart package, add a top-level `extension` directory:
```
foo_package
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

The `config.yaml` file contains metadata that DevTools needs in order to load the
extension. Copy the `config.yaml` file below and fill in the approproate value for each key.
The `materialIconCodePoint` field should correspond to the codepoint value of an icon from
[material/icons.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/icons.dart).
```yaml
name: foo_package
issueTracker: <link_to_your_issue_tracker.com>
version: 0.0.1
materialIconCodePoint: '0xe0b1'
```

Now it is time to build your extension.

## Create a DevTools extension

### Where to put your source code

Only the pre-compiled output of your extension needs to be shipped with your pub package
in order for DevTools to load it. To keep the size of your pub package small, we recommend that
you develop your DevTools extension outside of your pub package. Here is the recommended package structure:

```
foo_package/  # formerly the repository root of your pub package
  packages/
    foo_package/  # your pub package
      extension/
        devtools/
          build/
            ...  # pre-compiled output of foo_package_devtools_extension
          config.yaml
    foo_package_devtools_extension/  # source code for your extension
```

### Create the extension web app

From the directory where you want your extension source code to live, run the following command,
replacing `foo_package_devtools_extension` with `<your_package_name>_devtools_extension``:
```sh
flutter create --template app --platforms web foo_package_devtools_extension
```

In `foo_package_devtools_extension/pubspec.yaml`, add a dependency on `devtools_extensions`:
```yaml
devtools_extensions: ^0.0.9
```

In `lib/main.dart`, place a `DevToolsExtension` widget at the root of your app:
```dart
import 'package:devtools_extensions/devtools_extensions.dart';

void main() {
  runApp(const FooPackageDevToolsExtension());
}

class FooPackageDevToolsExtension extends StatelessWidget {
  const FooPackageDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: FooDevToolsExtension(),
    );
  }
}
```

The `DevToolsExtension` widget automatically performs all extension initialization required
to interact with DevTools. From anywhere your extension web app, you can access the globals
`extensionManager` and `serviceManager` to send messages and interact with the connected app.

#### Utilize helper packages

Use [package:devtools_app_shared](https://pub.dev/packages/devtools_app_shared) for access to
service managers, common widgets, DevTools theming, utilities, and more. See
[devtools_app_shared/example](https://github.com/flutter/devtools/tree/master/packages/devtools_app_shared/example)
for sample usages.

### Debug the extension web app

#### Use the Simulated DevTools Environment (recommended for development)

For debugging purposes, you will likely want to use the "simulated DevTools environment". This
is a simulated environment that allows you to build your extension without having to develop it
as an embedded iFrame in DevTools. The simulated environment is enabled by an environment
parameter `use_simulated_environment`.

![Simulated devtools environment](_readme_images/simulated_devtools_environment.png)

To run your extension web app with this flag enabled, add a configuration to your `launch.json`
file in VS code:
```json
{
    ...
    "configurations": [
        ...
        {
            "name": "foo_devtools_extension + simulated environment",
            "program": "foo_package/extension/foo_devtools_extension/lib/main.dart",
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
`your_extension_web_app/build` to your pub package's `extension/devtools/build` directory.

Use the `build_extension` command from `package:devtools_extensions` to help with this step.
```sh
cd your_extension_web_app &&
flutter pub get &&
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=path/to/your_pub_package/extension/devtools 
```

2. Prepare and run a test application that depends on your pub package. You'll need to change the
`pubspec.yaml` dependency to be a `path` dependency that points to your local pub package
source code. Once you have done this, run `pub get`, and run the application.

3. Start DevTools:
    * **If you need local or unreleased changes from DevTools**, you'll need to build and run DevTools
    from source. See the DevTools [CONTRIBUTING.md]() for a guide on how to do this.
        > Note: you'll need to build DevTools with the server and the front end to test extensions - see
        [instructions](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#development-devtools-server--devtools-flutter-web-app).
    * **If not, and if your local Dart or Flutter SDK version is >= `<TODO: insert version>`**,
    you can launch the DevTools instance that was just started by running your app (either from
    a url printed to command line or from the IDE where you ran your test app). You can also run
    `dart devtools` from the command line.

4. Connect your test app to DevTools if it is not connected already, and you should see a tab
in the DevTools app bar for your extension. The enabled or disabled state of your extension is
managed by DevTools, which is exposed from an "Extensions" menu in DevTools, available from the
action buttons in the upper right corner of the screen.

## Publish your package with a DevTools extension

In order for a package to provide a DevTools extension to its users, it must be published with the
expected content in the `your_package/extension/devtools/` directory (see the
[setup instructions](#setup-your-package-to-provide-a-DevTools-extension) above).

1. Ensure the `extension/devtools/config.yaml` file exists and is configured per the
[specifications above](#setup-your-package-to-provide-a-DevTools-extension).
2. Use the `build_and_copy` command provided by `package:devtools_extensions` to build
your extension and copy the output to the `extension/devtools` directory:
```sh
cd your_extension_web_app &&
flutter pub get &&
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=path/to/your_pub_package/extension/devtools 
```

Then publish your package.

### What if I don't want the `extension/devtools/build/` contents checked into source control?

As a package author, the content that you check into your git repository is completely up to you.
If you want the contents of `extension/devtools/build/` to be git ignored, then you'll just need
to ensure that the extension web app is always built and included in `extension/devtools/build/`
when you publish your package. To do so, add the following to a `.pubignore` file in the
`extension/devtools/` directory:

```
!./build
```

This will ensure that, even if the `extension/devtools/build` directory has been been git
ignored, the directory will still be included when publishing the package on pub.

To verify the published extension contents are always up to date, consider adding a tool
script to your repo that looks something like this:

**publish.sh**
```sh
pushd your_extension_web_app

flutter pub get &&
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=path/to/your_pub_package/extension/devtools 

popd

pushd your_pub_package
flutter pub publish
popd
```

## Resources and support

Check out the [#devtools-extension-authors](https://discord.com/channels/608014603317936148/1159561514072690739)
Discord channel to connect with other DevTools extension authors and the DevTools team.

For feature requests or bugs, please [file an issue](https://github.com/flutter/devtools/issues/new)
on the DevTools Github repository.
