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

To add release notes for the latest release, create a PR with the appropriate
changes for your release:

  1. Copy the markdown from [NEXT_RELEASE_NOTES.md](NEXT_RELEASE_NOTES.md) over
  to the Flutter website. This file contains the running release notes for
  the current DevTools version.
      - See this [PR](https://github.com/flutter/website/pull/10113) for
        an example of how to add these notes to the Flutter website.
  2. Copy any images from the `images/` directory over to the Flutter website.
      - Make sure to copy all images over to the proper website directory:
        - `.../tools/devtools/release-notes/images-<VERSION>/`
      - Make sure to update all image links in the markdown with the `site_url` tag:
        - `/tools/devtools/release-notes/images-<VERSION>/<IMAGE_FILE>`
  3. Once you are satisfied with the release notes,
  create a new branch directly on the `flutter/website` repo and open a PR,
  and then proceed to the testing steps below.

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
