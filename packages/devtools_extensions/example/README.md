# DevTools extension examples

## Run this example

1. Start app_that_uses_foo on any platform
2. Open DevTools in release mode connected to app_that_uses_foo
3. Find there is the custom tab 'Foo' in DevTools

## Example structure

This directory contains end-to-end examples of DevTools extensions. Each
end-to-end example is made up of three components:
1. **Parent package**: Dart package that provides the extension
2. **DevTools extension**: the tool itself
3. **End-user application**: the app that the extension is used on

## Parent package

This is the Dart package that provides a DevTools extension for end-user
applications to use in DevTools. There are multiple extension-providing pacakges
in the `example` directory.

- `package:foo` from `packages_with_extensions/foo/packages/foo`: a package for Flutter apps

- `package:dart_foo` from `packages_with_extensions/dart_foo/packages/dart_foo`: a
pure Dart package for Dart or Flutter apps

<!-- TODO(kenz): build this example. -->
<!-- - `package:standalone_tool` from `packages_with_extensions/dart_foo/packages/stanalone_tool`, which is a package that is strictly meant to provide a tool
as a DevTools extension. This is different from the other packages in that it
is not an extension shipped with an existing Dart package. It is a package
published solely to provide a DevTools extension. -->

<!-- TODO(kenz): build this example, or pull in Khan's extension. -->
<!-- - `package:gemini_ai_tool` from `packages_with_extensions/dart_foo/packages/gemini_ai_tool`, which is a standalone tool (like `package:standalone_tool`)
that provides an example of using the Gemini SDK to build an AI powered tool
as a DevTools extension. -->

## DevTools extension

These are Flutter web apps that will be embedded in DevTools when connected to an app
that depends on the [parent package](#parent-package).

- `packages_with_extensions/foo/packages/foo_devtools_extension`: this
is the Flutter web app whose built assets are included in `package:foo`'s
`extension/devtools/build` directory.

- `packages_with_extensions/dart_foo/packages/dart_foo_devtools_extension`: this
is the Flutter web app whose built assets are included in `package:dart_foo`'s
`extension/devtools/build` directory.

## End-user application

These are the applications that depend on the [parent package](#parent-package) and
can connect to the [DevTools extension](#devtools-extension) provided by the parent package.

### `app_that_uses_foo`

This Flutter app depends on `package:foo` and `package:dart_foo`. When debugging
`app_that_uses_foo`, or one if its `bin/` or `test/` libraries, the provided
DevTools extensions will load in their own tab in DevTools.

- `flutter run` the `app_that_uses_foo` app and open DevTools to see both the
`package:foo` and `package:dart_foo` extensions in DevTools connected to a
Flutter app.

- Run `dart run --observe bin/script.dart` and open DevTools to see the
`package_dart_foo` extension in DevTools connected to a Dart CLI app.

<!-- TODO(kenz): uncomment once https://github.com/flutter/devtools/issues/7183 is resolved. -->
<!-- - Run `dart test test/nested/simple_test.dart --pause-after-load` and open
DevTools to see the `package:dart_foo` extension connected to a Dart test.

- Run `flutter test test/app_that_uses_foo_test.dart --start-paused` and open
DevTools to see both the `package:foo` and `package:dart_foo` extensions
connected to a Flutter test. -->

## Learn how to structure your Dart package

The examples will show you how to structure your package for optimal extension
development and publishing.

1. If you are adding a DevTools extension to an existing Dart package, this is
the recommended structure:
    ```
    foo/  # formerly the repository root of your pub package
        packages/
            foo/  # your pub package
            extension/
                devtools/
                build/
                    ...  # pre-compiled build output of foo_devtools_extension
                config.yaml
            foo_devtools_extension/  # source code for your extension
    ```
    `package:foo` and `package:dart_foo` provide an example of this structure.

2. If you are creating a DevTools extension as a standalone package, this is
the recommended structure:
    ```
    standalone_tool/ # your new pub package
        extension/
            devtools/
            build/
                ...  # pre-compiled build output of standalone_tool
            config.yaml
        lib/  # source code for your extension
    ```
    <!-- TODO(kenz): uncomment once these examples are provided. -->
    <!-- `package:standalone_tool` and `package:gemini_ai_tool` provide an example of this structure. -->

The pre-compiled build output included in the example packages'
`extension/devtools/build` directories were included using the `build_and_copy`
command provided by `package:devtools_extensions`.
  - For example, `package:foo`'s `extension/devtools/build` directory was populated
  by running the following command from the `foo_devtools_extension/` directory:

    ```sh
    flutter pub get &&
    dart run devtools_extensions build_and_copy \
        --source=. \
        --dest=../foo/extension/devtools
    ```
## Learn how to configure your extension's `config.yaml` file

In these examples, you will also learn how to properly configure your extension's
`config.yaml` file. DevTools reads this file in order to embed your extension in its
own tab. This file must be configured as shown.

```yaml
name: foo
issueTracker: <link_to_your_issue_tracker.com>
version: 0.0.1
materialIconCodePoint: '0xe0b1'
```

For the most up-to-date documentation on the `config.yaml` spec, see
[extension_config_spec.md](https://github.com/flutter/devtools/blob/master/packages/devtools_extensions/extension_config_spec.md)

## Learn how to use shared packages from DevTools

To learn how to use the shared packages from Devtools (`package:devtools_extensions`
and `package:devtools_app_shared`), see the source for the `package:foo` extension.

`packages_with_extensions/foo/packages/foo_devtools_extension` provides in-depth
examples of how to do things like interact with the connected app's VM service,
read / write to the user's project files over the Dart Tooling Daemon, interact
with the DevTools extension framework APIs, etc.
