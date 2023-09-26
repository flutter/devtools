# Example DevTools Extension

This is an end-to-end example of a DevTools extension, including
- the parent `package:foo` that provides the DevTools extension to end-user
applications (`foo/packages/foo`)
- the end-user application (`app_that_uses_foo`) that depends on `package:foo`,
which will trigger a load of the `package:foo` DevTools extension when debugging
this app with DevTools
- the `package:foo` DevTools extension (`foo/packages/foo_devtools_extension`),
which is a Flutter web app that will be embedded in DevTools when debugging an
app the uses `package:foo`


This example will show you how to:
1. Structure your package for optimal extension development and publishing
    ```
    foo/  # formerly the repository root of your pub package
        packages/
            foo/  # your pub package
            extension/
                devtools/
                build/
                    ...  # pre-compiled output of foo_devtools_extension
                config.yaml
            foo_devtools_extension/  # source code for your extension
    ```
2. Configure your extension using the `foo/extension/devtools/config.yaml` file
    ```yaml
    name: foo
    issue_tracker: <link_to_your_issue_tracker.com>
    version: 0.0.1
    material_icon_code_point: '0xe0b1'
    ```
3. Use `package:devtools_extensions` and `package:devtools_app_shared` to
develop your DevTools extension (see source code under `foo_devtools_extension`).
4. Ship your extension with your pub package by including the pre-built assets
in the `foo/extension/devtools/build` directory.
    - For this example, the pre-built assets for `foo_devtools_extension` were added
    to `foo/extension/devtools/build` by running the following command from the
    `foo_devtools_extension/` directory:
        ```sh
        flutter pub get &&
        dart run devtools_extensions build_and_copy \
            --source=. \
            --dest=../foo/extension/devtools 
        ```
