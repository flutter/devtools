# leaking_counter_1

This is memory leaking application to test memory debugging tools.

## Leak debugging lab

Users report that the app consumes more and more memory with every button click.
Your task is to fix the leak using the tab Memory > Diff, assuming the application is too large to find the issue by
simply reviewing the code of the button handler.

Setup the lab:

1. Run the app in profile mode (`flutter run -d macos --profile`) and copy the Observatory URL displayed in the console.
2. Follow [the steps](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#manual-testing) to connect DevTools to the app.
3. Open Memory > Diff.
