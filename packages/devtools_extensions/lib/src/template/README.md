The code in this directory is for the DevTools extension template that package
authors will use to build DevTools extensions. Files in this directory are
exported through the `lib/devtools_extensions.dart` file.

This code is not intended to be imported into DevTools itself. Anything that
should be shared between DevTools and DevTools extensions will be under the
`src/api` directory and exported through `lib/api.dart`.
