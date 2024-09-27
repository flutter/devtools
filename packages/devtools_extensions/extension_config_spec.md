The `config.yaml` file for a DevTools extension must follow the format below.

## Required fields

- `name` : the package name that this DevTools extension belongs to. The value of this field
will be used in the extension page title bar. This name should contain only lowercase letters
and underscores (no spaces or special characters like `'` or `.`).
- `issueTracker`: the url for the extension's issue tracker. When a user clicks the “Report an 
issue” link in the DevTools UI, they will be directed to this url.
- `version`: the version of the DevTools extension. This version number should evolve over time 
as the extension is developed. The value of this field will be used in the extension page 
title bar.
- `materialIconCodePoint`: corresponds to the codepoint value of an icon from
[material/icons.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/icons.dart).
This icon will be used for the extension’s tab in the top-level DevTools tab bar.

## Optional fields
- `requiresConnection`: whether this DevTools extension requires a connected Dart or
Flutter application to run. If this is not specified, this value will default to `true`.

## Examples

An extension for `foo_package` that requires a connected app to use:
```yaml
name: foo_package
issueTracker: <link_to_your_issue_tracker.com>
version: 0.0.1
materialIconCodePoint: '0xe0b1'
```

An extension for `foo_package` that does not require a connected app to use:
```yaml
name: foo_package
issueTracker: <link_to_your_issue_tracker.com>
version: 0.0.1
materialIconCodePoint: '0xe0b1'
requiresConnection: false
```
