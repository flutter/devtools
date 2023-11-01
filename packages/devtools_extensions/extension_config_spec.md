The `config.yaml` file for a DevTools extension must follow the format below.

## Required fields

- `name` : the package name that this DevTools extension belongs to. The value of this field
will be used in the extension page title bar. This name should not contain spaces or special characters.
- `issueTracker`: the url for the extension's issue tracker. When a user clicks the “Report an 
issue” link in the DevTools UI, they will be directed to this url.
- `version`: the version of the DevTools extension. This version number should evolve over time 
as the extension is developed. The value of this field will be used in the extension page 
title bar.
- `materialIconCodePoint`: corresponds to the codepoint value of an icon from
[material/icons.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/icons.dart).
This icon will be used for the extension’s tab in the top-level DevTools tab bar.

## Example

```yaml
name: foo_package
issueTracker: <link_to_your_issue_tracker.com>
version: 0.0.1
materialIconCodePoint: '0xe0b1'
```
