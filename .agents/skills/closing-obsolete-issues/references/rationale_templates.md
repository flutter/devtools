# Common Closing Rationales for DevTools

When investigating old issues in the Flutter DevTools repository, look for these common reasons they may be eligible for closing. Use these as templates for your closing comments.

## 1. Superseded by New DevTools Features
DevTools has evolved significantly. Many old requests for features are now solved by newer implementations or entire new screens.
- **Example**: Requests for specific memory allocation tracking features that are covered by the new Tracing or Diff panes.
- **Rationale**: Point to the new feature or screen that fulfills the need (e.g., "This is now supported in the Memory screen's Tracing pane.").

## 2. Observatory Deprecation
With the deprecation and removal of the Observatory UI in favor of DevTools, issues specifically requesting feature parity or fixing bugs in Observatory integration may be obsolete.
- **Rationale**: Note that Observatory is deprecated/removed and DevTools is the supported solution.

## 3. Tooling Daemon (DTD) and IDE Integration
Issues about IDE integration or multi-package support might be resolved by the introduction of the Dart Tooling Daemon (DTD).
- **Rationale**: Explain that DTD now handles this integration or that workspace support has improved.

## 4. UI Refactoring and Legacy Screens
Requests related to old UI patterns or legacy screens that have been completely rewritten or removed are obsolete.
- **Example**: The "Analysis" pane in the Memory screen no longer exists.
- **Rationale**: Note that the feature or screen has been refactored or removed.

## 5. Resolved by Flutter SDK Updates
Some issues are caused by or fixed by changes in the Flutter SDK rather than DevTools itself.
- **Rationale**: If a bug was fixed in a specific Flutter version, mention it.

## 6. Stale Feature Requests
Proposals or feature requests from several years ago with no recent activity or community interest may be closed if they no longer align with current priorities or have been superseded by general improvements.
- **Rationale**: Note that the issue is a stale feature request with no recent activity and that DevTools has evolved significantly since then.

## 7. Very Old DevTools Version
Issues reported on very old versions of DevTools (check current version in `packages/devtools_app/pubspec.yaml` for comparison) may be closed if they are likely fixed or no longer relevant.
- **Rationale**: "This issue looks like it occurred on an old version of DevTools. Are you still experiencing this issue with DevTools on the latest Flutter stable? If so, please reopen and we will take a look. Thanks."

## 8. Insufficient Information
Issues that lack clear descriptions, reproduction steps, or logs make it impossible to investigate.
- **Rationale**: "Without additional information, we cannot debug this issue. Please re-open if you can provide a description of your issue and repro steps. Thanks."

---
**Reminder**: Every closing comment MUST end with:
"If there is more work to do here, please let us know by filing a new issue with up to date information. Thanks!"
