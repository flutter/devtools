# 10.0.0-dev.3
* Added helper `deserialize` and `deserializeNullable`
* Extended serialization for `HeapSample` and `ExtensionEvents`
* Added mixin `Serializable`

# 10.0.0-dev.2
* Support detecting package roots for nested Dart projects in the
`packageRootFromFileUriString` utility method.

# 10.0.0-dev.1
* Export `DTDConnectionInfo` from the `devtools_shared.dart` library instead
of the `devtools_server.dart` library.

# 10.0.0-dev.0
* **Breaking change:** rename `DevToolsExtensionConfig.path` to
`DevToolsExtensionConfig.extensionAssetsPath` and update class documentation.
* **Breaking change:** rename `ExtensionsApi.extensionRootPathPropertyName`
to `ExtensionsApi.packageRootUriPropertyName`, and modify the String value
for the parameter from 'rootPath' to 'packageRootUri'.
* **Breaking change:** add new required JSON fields "devtoolsOptionsUri" and
"detectedFromStaticContext" in the `DevToolsExtensionConfig.parse` factory constructor.
* **Breaking change:** remove `DevToolsOptions.optionsFileName` constant in favor of
new constant `devtoolsOptionsFileName`.
* **Breaking change:** modify the `ExtensionsApi.apiExtensionEnabledState`
API to expect a query parameter "devtoolsOptionsUri" instead of "rootPath".
* **Breaking change:** replace the `rootUri` parameter in the
`DevToolsOptions.lookupExtensionEnabledState` and
`DevToolsOptions.setExtensionEnabledState` methods with new parameter
`devtoolsOptionsUri`. Modify logic to expect a full file URI to the
options file instead of expecting the package root in which it is contained.
* Add new fields `requiresConnection`, `devtoolsOptionsUri`, and `detectedFromStaticContext`
to `DevToolsExtensionConfig`.
* Add `ExtensionsApi.devtoolsOptionsUriPropertyName` field.
* Return valid extensions from the `apiServeAvailableExtensions` endpoint even when
an exception is thrown.
* Add utility extension methods on `Completer`: `safeComplete` and `safeCompleteError`.

# 9.0.1
* Restructure `devtools_extensions.dart` and `devtools_extensions_io.dart` libraries.

# 9.0.0
* **Breaking change:** remove parameter `analytics` from `ServerApi.handle` in favor
of DTD implementation.
* **Breaking change:** remove DevTools server APIs `apiMarkConsentMessageAsShown` and `apiGetConsentMessage`
* **Breaking change:** remove parameter `buildDir` from `ExtensionsManager`.
in favor of DTD implementation.
* Stop copying DevTools extensions assets to the DevTools build directory.
* Bump `package:dtd` to `2.2.0`
* Remove `package:unified_analytics` dependency.
* Use DTD in the `packageRootFromFileUriString` utility to detect the package root.
* Add `runWithRetry` utility method.

# 8.1.1
* Bump `package:dtd` to `2.1.0`.
* Bump the minimum Dart SDK version to `3.4.0-282.1.beta`.

# 8.1.0
* Bump `package:dtd` to `2.0.0`.
* Bump `package:unified_analytics` to `5.8.8`.

# 8.0.1
* **Breaking change:** rename `ServerApi.getCompleted` to `ServerApi.success` and make the
`value` parameter optional.
* **Breaking change:** remove the `String? dtdUri` parameter from `ServerApi.handle` and replace
it with a parameter `DTDConnectionInfo? dtd`.
* Introduce a new typedef `DTDConnectionInfo`.
* Add a new API `apiNotifyForVmServiceConnection` that DevTools will call when a
VM service connection is connected or disconnected from the client.
* Add a helper method `packageRootFromFileUriString`.
* Refactor yaml extension methods.
* Add intent filters checking functionality for deep link validation.

# 7.0.0
* **Breaking change:** remove the `ServerApi.setCompleted` method that was a
duplicate of `ServerApi.getCompleted`.
* **Breaking change:** add required parameter `analytics` to `ServerApi.handle`, which accepts
an instance of `Analytics` from `package:unified_analytics`.
* Add the ability to send debug logs in DevTools server request responses.
* Add an optional positional parameter `logs` to the `ServerApi.serverError` method.
* Include debug logs with the `ExtensionsApi.apiServeAvailableExtensions` API response.
* Devtools server API `apiGetConsentMessage` added to fetch the consent message from
  `package:unified_analytics`.
* Devtools server API `apiMarkConsentMessageAsShown` added to mark the consent message for
  `package:unified_analytics` as shown to enable telemetry.

# 6.0.4
* Add `apiGetDtdUri` to the server api.
* Add a description and link to documentation to the `devtools_options.yaml` file that
is created in a user's project.

# 6.0.3
* `CompareMixin` is now generic, implementing `Comparable<T>` instead of
  `Comparable<dynamic>`, and it's operators each therefore accept a `T`
  argument.
* `SemanticVersion` now mixes in `CompareMixin<SemanticVersion>`, and it's
  `compareTo` method therefore now accepts a `SemanticVersion`.
* Fix an issue parsing file paths that could prevent extensions from being detected.
* Bump `package:vm_service` dependency to `>=13.0.0 <15.0.0`.

# 6.0.2
* Fix an issue parsing file paths on Windows that could prevent extensions from being detected.

# 6.0.1
* Bump minimum Dart SDK version to `3.3.0-91.0.dev` and minimum Flutter SDK version to `3.17.0-0.0.pre`.
* Add field `isPublic` to `DevToolsExtensionConfig`.
* Add validation for `DevToolsExtensionConfig.name` field to ensure it is a valid
Dart package name.
* Pass warnings and errors for DevTools extension APIs from the DevTools server to
DevTools app.

# 6.0.0
* Bump `package:vm_service` dependency to ^13.0.0.
* Remove `ServiceCreator` typedef and replace usages with `VmServiceFactory` typedef from `package:vm_service`.

# 5.0.0
* Split deeplink exports into `devtools_deeplink_io.dart` and `devtools_deeplink.dart`.
* Bump `package:vm_service` to ^12.0.0.
* Adds `DeeplinkApi.androidAppLinkSettings`, `DeeplinkApi.iosBuildOptions`, and
  `DeeplinkApi.iosUniversalLinkSettings` endpoints to ServerApi.
* Add shared integration test utilities to `package:devtools_shared`. These test
utilities are exported as part of the existing `devtools_test_utils.dart` library.

# 4.0.1
* Override equality operator and hashCode for `DevToolsExtensionConfig`
to be based on the values of its fields.

# 4.0.0
* Bump `package:extension_discovery` version to ^2.0.0
* Adds a `DeeplinkApi.androidBuildVariants` endpoint to ServerApi.
* **BREAKING CHANGE**:
  - `ServerApi.handle` parameters `extensionsManager` and `api` were converted to named
    parameters
  - Adds a new required named parameter `deeplinkManager` to `ServerApi.handle`.

# 3.0.1
* Bump `package:extension_discovery` version to ^1.0.1

# 3.0.0
* Separate extension-related libraries into those that require `dart:io` (exported as
`devtools_extensions_io.dart`) and those that do not (exported as `devtools_extensions.dart`).

Prior to version 3.0.0, `package:devtools_shared` was versioned in lockstep with
`package:devtools_app`. Both of these packages are developed as part of the broader
[DevTools project](https://github.com/flutter/devtools). To see changes and commits
for `package:devtools_shared`, prior to version 3.0.0 please view the git log
[here](https://github.com/flutter/devtools/commits/master/packages/devtools_shared).
