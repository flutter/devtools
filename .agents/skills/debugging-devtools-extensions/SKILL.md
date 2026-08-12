---
name: debugging-devtools-extensions
description: Guidelines and step-by-step workflow for debugging DevTools extensions locally, including stub mode, fixed-port launching, browser auto-opening, URL query parameters, target app connection, and human-in-the-loop interaction. Use when debugging or testing DevTools extension behavior.
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

## 2. Automated Launch & Browser Navigation

The agent can automate running DevTools AND launching the browser directly to the target URL:

### Step 2a: Launch DevTools on a Fixed Port
In `packages/devtools_app`, launch DevTools specifying a fixed `--web-port`:
```bash
flutter run -d chrome --web-port=52941
```

### Step 2b: Open Browser to Target URL Automatically
Use the system OS open command to launch Chrome/browser directly to the desired test URL:

- **macOS**: `open "http://localhost:52941/foo_ext?embedMode=one"`
- **Linux**: `xdg-open "http://localhost:52941/foo_ext?embedMode=one"`
- **Windows**: `start "http://localhost:52941/foo_ext?embedMode=one"`

## 3. Connecting to an End-User Target App

To test against real pub package extensions:

1. Run the sample app in `packages/devtools_extensions/example/app_that_uses_foo`:
   ```bash
   cd packages/devtools_extensions/example/app_that_uses_foo
   flutter run -d chrome
   ```
2. Ask the user to copy/paste the VM Service URI from the terminal output (e.g. `ws://127.0.0.1:8181/xxx=/ws`).
3. Open the browser automatically with the `uri` parameter using the appropriate OS command (as described in Step 2b):
   - **macOS**: `open "http://localhost:52941/foo_ext?embedMode=one&uri=<VM_SERVICE_URI>"`
   - **Linux**: `xdg-open "http://localhost:52941/foo_ext?embedMode=one&uri=<VM_SERVICE_URI>"`
   - **Windows**: `start "http://localhost:52941/foo_ext?embedMode=one&uri=<VM_SERVICE_URI>"`

## 4. Human Interaction & User Prompting Steps

When an AI agent is performing this workflow:

- **Obtaining VM Service URI**: When connecting to a target app, ask the user to provide the VM Service URI printed in the target app's console output (using `ask_question` or a direct prompt).
- **Automated Browser Opening**: The agent should launch DevTools and execute the appropriate OS command (`open`, `xdg-open`, or `start` as described in Step 2b) to launch the browser automatically.
- **Manual Visual Verification**: Ask the user to inspect the opened browser window and confirm whether the expected extension UI or behavior is visible.
