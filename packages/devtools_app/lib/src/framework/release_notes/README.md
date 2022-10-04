## Writing DevTools release notes
- Release notes for DevTools are hosted on the flutter website (see [archive](https://docs.flutter.dev/development/tools/devtools/release-notes)).
- To add release notes for the latest release, create a PR with the appropriate changes for your release
    - The [release notes template](release-notes-template.md) can be used as a starting point
    - see example [PR](https://github.com/flutter/website/pull/6791).

- Test these changes locally before creating the PR.
    - See [README.md](https://github.com/flutter/website/blob/main/README.md)
for getting setup to run the Flutter website locally.
    - Release notes can be found at [http://localhost:4002/development/tools/devtools/release-notes/](http://localhost:4002/development/tools/devtools/release-notes/)

- Once you are satisfied with the release notes
    - stage the Flutter website on Firebase
    - point the DevTools release notes logic to this staged url.

### Staging your changes on Firebase
- In the flutter/website directory,
    - open [_config.yml](https://github.com/flutter/website/blob/main/_config.yml#L2)
    - replace `https://docs.flutter.dev` with `https://flutter-website-dt-staging.web.app` (line 2).

- Then run the following rom the `website/` directory:
    ```shell
    make setup && \
    DISABLE_TESTS=1 make build && \
    firebase deploy --project devtools-staging --only hosting;
    ```

- If the firebase command gives an authentication error or just says it cannot access a URL,
    - try running
        ```shell
        firebase logout && \
        firebase login;
        ```
    - then retry
        ```shell
        firebase deploy --project devtools-staging --only hosting
        ```

- Once you see this message, the deployment was successful and now you can move on to the next step.
    ```
    ...

    ✔  Deploy complete!

    Project Console: https://console.firebase.google.com/project/flutter-website-dt-staging/overview
    Hosting URL: https://flutter-website-dt-staging.web.app
    ```

### Testing the release notes in DevTools
- In `release_notes.dart` flip the `debugTestReleaseNotes` flag to true. 

- from the main `devtools/` directory, run the following:
    ```dart
    dart ./tool/build_e2e.dart
    ```

- Once DevTools has been successfully built and served, you should see the following the CLI output:
```
...

Serving DevTools with a local devtools server...
Serving DevTools at http://127.0.0.1:57336.
```

- Visit the DevTools link
- verify the release notes viewer displays the new release notes as expected.

