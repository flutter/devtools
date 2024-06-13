## 0.2.0
* Add `navigateToCode` utility method for jumping to code in IDEs.
* Add `FlutterEvent` and `DeveloperServiceEvent` constants.
* Add `connectedAppPackageRoot`, `rootPackageDirectoryForMainIsolate`, and
`mainIsolateRootLibraryUriAsString` methods to the `ServiceManager` class.
* Bump minimum Dart SDK version to Dart stable `3.4.3` and minimum Flutter SDK
version to Flutter stable `3.22.2`.

## 0.2.0-dev.0
* Add `tooltipWaitExtraLong` to `utils.dart`.
* Bump `devtools_shared` dependency to `^10.0.0`.
* Bump `vm_service` dependency to `^14.2.1`.
* Add a `DTDManager.dispose` method.
* Fix a race condition during service manager disconnect.
* Add `IdeThemeQueryParams` extension type for parsing query params.
* Add `EmbedMode` to enumerate the possible DevTools embedded states.
* Add `IsolateManager.waitForMainIsolateState` method.
* Add `LinkTextSpan` and `Link` classes.
* Add `launchUrl` utility method that has platform agnostic handling for
launching a URL in the browser, and includes special handling for launching
URLs when in an embedded VS Code view.

## 0.1.1
* Update `package:dtd` to `^2.1.0`
* Add `DTDManager.projectRoots` method.
* Bump the minimum Dart and Flutter SDK versions to `3.4.0-282.1.beta` and
`3.22.0-0.1.pre` respectively.
* Bump `devtools_shared` to ^8.1.1-dev.0

## 0.1.0
* Remove deprecated `background` and `onBackground` values for `lightColorScheme`
and `darkColorScheme`.
* Rename `Split` to `SplitPane`.
* Add `ServiceManager.serviceUri` field to store the connected VM service URI.
* Update readme to use `pub add` instead of explicit package version.
* Update `package:dtd` to `^2.0.0`
* Update `package:devtools_shared` to `^8.1.0`
* Add `DTDManager.workspaceRoots` method.

## 0.0.10
* Add `DTDManager` class and export from `service.dart`.
* Add `showDevToolsDialog` helper method.
* Add `FlexSplitColumn` and `BlankHeader` common widgets.
* Bump `package:vm_service` dependency to ^14.0.0.

## 0.0.9
* Bump `package:web` to `^0.4.1`.
* Densify overall UI.
* Add public members: `PaddedDivider.noPadding`, `singleLineDialogTextFieldDecoration`, `extraLargeSpacing`, `regularTextStyleWithColor`.
* Remove public members: `areaPaneHeaderHeight`, `defaultSwitchHeight`,`
`dialogTextFieldDecoration`
* Automatically show tooltips for `DevToolsButton` whose labels have been hidden due to
hitting a narrow screen threshold, specified by `minScreenWidthForTextBeforeScaling`.
* Add an optional parameter `borderColor` to `DevToolsToggleButtonGroup`.
* Add a strict type on `DialogApplyButton.onPressed` and `ToggleableServiceExtension`.
* Change default styling of `regularTextStyle` to inherit from `TextTheme.bodySmall`.
* Change default styling of `TextTheme.bodySmall`, `TextTheme.bodyMedium`,
`TextTheme.titleSmall` in the base theme.

## 0.0.8
* Add `ServiceManager.resolvedUriManager` for looking up package and file uris from
a VM service connection.
* Migrate from `dart:html` to `package:web`.

## 0.0.7
* Bump minimum Dart SDK version to `3.3.0-91.0.dev` and minimum Flutter SDK version to `3.17.0-0.0.pre`.
* Bump `package:vm_service` dependency to ^13.0.0.
* Bump the `package:devtools_shared` dependency to ^6.0.1.
* Remove public getter `libraryRef`, and public methods `getLibrary` and `retrieveFullValueAsString` from `EvalOnDartLibrary`.
* Change `toString` output for `UnknownEvalException`, `EvalSentinelException`, and `EvalErrorException`.
* Remove public getters `flutterVersionSummary`, `frameworkVersionSummary`, and `engineVersionSummary` from `FlutterVersion`.
* Remove public getters `onIsolateCreated` and `onIsolateExited` from `IsolateManager`.
* Remove public getter `firstFrameReceived` from `ServiceExtensionManager`.
* Add `RoundedButtonGroup` common widget.

## 0.0.6
* Add `profilePlatformChannels` to known service extensions.
* Fix a bug where service extension states were not getting cleared on app disconnect.
* Add optional parameter `id` to `DisposerMixin.addAutoDisposeListener` and
`AutoDisposeMixin.addAutoDisposeListener` that allows for tagging a listener
with a specific id.
* Add optional parameter `excludeIds` to `DisposerMixin.cancelListeners` and
`AutoDisposeMixin.cancelListeners` that allows for excluding listeners with
a specific id from the cancel operation.

## 0.0.5
* Fix bug where registered services were not getting cleared on app disconnect.
* Fix a bug with the logic to wait for a service extension's availability.
* Fixed an exception on hot restart.

## 0.0.4
* Add `useDarkThemeAsDefault` constant for defining the default theme behavior.

## 0.0.3
* Bump `package:vm_service` dependency to ^11.10.0

## 0.0.2
* Remove public `hasService` getter from `ServiceManager`.
* Add optional `timeout` parameter to the `whenValueNonNull` utility.
* Rename `includeText` utility to `isScreenWiderThan`.
* Move `ideTheme` getter from `devtools_app_shared/utils.dart` to `devtools_app_shared/ui.dart`.

## 0.0.1

* Add README.md with usage examples.
* Seal all possible classes for safeguarding against breaking changes.
* Trim shared theme features down to only what is needed.

## 0.0.1-dev.0

* Initial commit. This package is under construction.
