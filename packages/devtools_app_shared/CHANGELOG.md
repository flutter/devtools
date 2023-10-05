## 0.0.6
* Bump to `vm_service` version 12.0.0.

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
