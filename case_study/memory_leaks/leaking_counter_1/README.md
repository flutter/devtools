<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
# leaking_counter_1

This is memory leaking application to test memory debugging tools.

## Leak debugging lab

1. Setup the lab:

    a. Start the latest version of DevTools by following [BETA_TESTING.md](https://github.com/polina-c/devtools/blob/master/BETA_TESTING.md)

    b. in another console tabs navigate to the DevTools directory (`cd devtools`) and start the app:

        cd case_study/memory_leaks/leaking_counter_1
        flutter run -d macos --profile
        

    c. Copy the Observatory URL displayed in the console to the connection box in DevTools

2. Solve the puzzle:

Users report the app consumes more and more memory with every button click.
Your task is to fix the leak using the tab Memory > Diff, assuming the application is too large to find the issue by
simply reviewing the code of the button handler.
