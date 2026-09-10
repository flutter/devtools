---
name: debugging-devtools-extensions
description: Guidelines and step-by-step workflow for debugging DevTools extensions locally, including stub mode, real extension hosting with DevTools server, target app connection, force reload validation, fixed-port launching, and browser navigation. Use when debugging or testing DevTools extension behavior.
---

# Debugging DevTools Extensions

Follow this workflow to test and debug DevTools extensions locally.

## 1. Local Stub Extensions Mode (No Server Needed)

When running DevTools in standalone web mode (`flutter run -d chrome`), DevTools does not run the `devtools_server` backend by default. To test extensions without a running server backend:

1. Open [`packages/devtools_app/lib/src/shared/development_helpers.dart`](file:///Users/ryjohn/code/github/flutter/devtools/packages/devtools_app/lib/src/shared/development_helpers.dart#L57).
2. Set `const _debugDevToolsExtensions = true;`.

> [!WARNING]
> Never commit `_debugDevToolsExtensions = true;` to git. A repository unit test (`development_helpers_test.dart`) enforces that this flag remains `false`.

Activating stub mode registers the following mock extensions:
- `foo_ext` (`package:foo`)
- `bar_ext` (`package:bar`)
- `provider_ext` (`package:provider`)

Launch DevTools and navigate directly:
```bash
flutter run -d chrome --web-port=52941
```
- **macOS**: `open "http://localhost:52941/foo_ext"`
- **Linux**: `xdg-open "http://localhost:52941/foo_ext"`
- **Windows**: `start "http://localhost:52941/foo_ext"`

## 2. Testing with Real Extensions (DevTools Server + Target App)

To test real pre-compiled DevTools extensions (such as `package:foo`, `package:dart_foo`, or `package:standalone_extension`):

### Step 2a: Start the DevTools Server
In a terminal, start a standalone DevTools server instance to discover and serve extension assets:
```bash
dart devtools --no-launch-browser --disable-cors
```
Take note of the server address printed in the console (e.g. `http://127.0.0.1:9101`).

### Step 2b: Run the Target App
Run the example application that provides the extensions:
```bash
cd packages/devtools_extensions/example/app_that_uses_foo
dart run --observe bin/script.dart
```
*(Or run `flutter run -d chrome` from the `app_that_uses_foo` directory).*
Copy the VM Service URI from the output (e.g. `http://127.0.0.1:8181/xxxx=/`).

### Step 2c: Launch DevTools Connected to the DevTools Server
In `packages/devtools_app`, launch DevTools pointing to the local DevTools server:
```bash
cd packages/devtools_app
flutter run -d chrome --web-port=52941 --dart-define=debug_devtools_server=<DEVTOOLS_SERVER_ADDRESS>/
```

### Step 2d: Open Browser to Target URL Automatically
Use the system OS open command to launch Chrome directly to DevTools connected to the target app's VM service:
- **macOS**: `open "http://localhost:52941/?uri=<VM_SERVICE_URI>"` (or `open "http://localhost:52941/foo_ext?uri=<VM_SERVICE_URI>"`)
- **Linux**: `xdg-open "http://localhost:52941/?uri=<VM_SERVICE_URI>"`
- **Windows**: `start "http://localhost:52941/?uri=<VM_SERVICE_URI>"`

## 3. Validating Extension Force Reload

To validate the extension force reload feature:

1. Navigate to the extension screen (e.g. `foo` or `dart_foo`) in DevTools.
2. Click **"Enable"** if the extension enable prompt appears.
3. In the top-right header of the extension view, click the context menu button (**`⋮`** / three vertical dots).
4. Click **"Force reload extension"** (refresh icon 🔄).
5. **Verify**:
   - The embedded extension iframe reloads cleanly without becoming blank or hanging.
   - Open Chrome Developer Tools (**`Cmd + Option + I`**) and verify in the **Console** tab that there are no iframe sandbox errors (e.g. `DOMException`, origin mismatches, or permissions policy blocks).

## 4. Human Interaction & User Prompting Steps

When an AI agent is performing this workflow:

- **Obtaining VM Service URI**: When connecting to a target app, obtain the VM Service URI from the background task output or ask the user for it.
- **Automated Browser Opening**: Launch DevTools and execute the appropriate OS command (`open`, `xdg-open`, or `start`) to navigate the browser automatically.
- **Manual Visual Verification**: Ask the user to inspect the opened browser window and confirm whether the expected extension UI or reload behavior succeeded without console errors.
