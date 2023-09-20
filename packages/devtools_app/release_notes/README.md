## Updating NEXT_RELEASE_NOTES.md

When you add a user-facing change to DevTools,
please add a release note entry to document this improvement.

This entry should be phrased in the past tense (e.g. "Added XYZ" instead of "Add XYZ").

If you want to add an image to the release note entry,
add the image to the `release_notes/images` folder,
and then reference it in the markdown. For example:

```markdown
![Accessible image description](images/my_feature.png "Image hover description")
```

When adding these release notes to the Flutter website,
you'll have to copy the image over and edit the path
to match the structure of the Flutter website.

## Generating release notes for the Flutter website

- Release notes for DevTools are hosted on the Flutter website.
  They are indexed at https://docs.flutter.dev/tools/devtools/release-notes.
- To add release notes for the latest release,
  create a PR with the appropriate changes for your release:

  - The [NEXT_RELEASE_NOTES.md](NEXT_RELEASE_NOTES.md) file contains
    the running release notes for the current version.
  - See an example [PR](https://github.com/flutter/website/pull/6791) for
    an example of how to add those to the Flutter website.
  - NOTE: When adding images, be cognizant that the images will be
    rendered in a relatively small window in DevTools,
    and they should be sized accordingly.

- Once you are satisfied with the release notes,
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
