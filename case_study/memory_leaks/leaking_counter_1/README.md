# leaking_counter_1

This is memory leaking application to test memory debugging tools.

## Leak debugging lab

Users report that the app consumes more and more memory with every button click.
Your task is to fix the leak using the tab Memory > Diff, assuming the application is too large to find the issue by
simply reviewing the code of the button handler.

Setup the lab:

1. Clone DevTools: `git clone git@github.com:flutter/devtools.git`

2. Navigate to the DevTools directory (`cd devtools`) in two console tabs

3. In the first console tab:

    a. Start the app:

    ```
    cd case_study/memory_leaks/leaking_counter_1
    flutter run -d macos --profile
    ```

    b. Copy the Observatory URL displayed in the console

4. In the second console tab:

    a. Start DevTools with experimental features enabled:

    ```
    cd packages/devtools_app
    flutter run -d chrome --dart-define=enable_experiments=true
    ```

    b. Paste the copyed URL to the connection box

    c. Open Memory > Diff
