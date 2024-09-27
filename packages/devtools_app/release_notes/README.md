## Updating NEXT_RELEASE_NOTES.md

When you add a user-facing change to DevTools,
please add a release note entry to document this improvement.

This entry should be phrased in the past tense (e.g. "Added XYZ" instead of "Add XYZ").

### Release note entry

Use this format for the entry:

```markdown
* Created the best feature ever. -
[#10000000001](https://github.com/flutter/devtools/pull/10000000001),
[#10000000002](https://github.com/flutter/devtools/pull/10000000002),
[#10000000003](https://github.com/flutter/devtools/pull/10000000003)
```

Find other examples in [previous notes](https://github.com/flutter/website/tree/main/src/tools/devtools/release-notes).

### Adding images to a release note entry

Consider adding an image to the release note entry:

1. Add the image to the `release_notes/images` folder,
2. Reference it in the markdown, right after the release note entry:

    ```markdown

        ![Accessible image description](images/my_feature.png "Image hover description")

    ```

#### Image style
Please use DevTools in **dark mode** when taking screenshots for release
notes. We use a dark theme since this is the default theme for DevTools.

#### Image size
When adding images, be cognizant that the images will be rendered in a
relatively small window in DevTools, and they should be sized accordingly.
A wide aspect ratio is preferred so that the space of the release notes
viewer can be used efficiently.

## Generating release notes for the Flutter website

Release notes for DevTools are hosted on the Flutter website.
They are indexed at https://docs.flutter.dev/tools/devtools/release-notes.

### Prerequisite

Before continuing, ensure you have your local environment set up for
[contributing](https://github.com/flutter/website) to the `flutter/website` repo.

### Creating the release notes PR

Draft release notes on a local `flutter/website` branch using the following command:
```console
devtools_tool release-notes -w /Users/me/absolute/path/to/flutter/website
```

Clean up the drafted notes on your local `flutter/website` branch and open a PR.

### Testing the release notes in DevTools

Once you push up your branch to `flutter/website` and open your PR,
wait for the `github-actions` bot to stage your changes to Firebase.
Open the link it comments and navigate to the release notes you want to test.
Be sure to add `-src.md` to the url to get the raw json.
The url should look something like:

```
https://flutter-docs-prod--pr8928-dt-notes-links-b0b33er1.web.app/tools/devtools/release-notes/release-notes-2.24.0-src.md
```

- Copy this url and set `_debugReleaseNotesUrl` in
  `release_notes.dart` to this value.

- Run DevTools and the release notes viewer should open
  with the markdown at the url you provided.

- Verify the release notes viewer displays the new release notes as expected.
  Some issues to watch out for are broken images or 'include_relative' lines in
  the markdown that don't load properly.
