## How to release the next version of DevTools

Create a branch for your release.

```shell
cd ~/path/to/devtools
git checkout master
git pull upstream master
git checkout -b release_2.7.0
```

### Prepare the release

#### Update the DevTools version number

Run the `tool/update_version.dart` script to update the DevTools version.
For monthly releases use `auto --type minor`.

```shell
# To manually set the version:
dart tool/update_version.dart manual --new-version 1.2.3

# To automatically update the version by `major`, `minor`, `patch`, or `dev`:
dart tool/update_version.dart auto --type patch

# For regular monthly releases, use `minor`:
dart tool/update_version.dart auto --type minor
```

Verify that this script updated the pubspecs under packages/
and updated all references to those packages. These packages always have their
version numbers updated in lock, so we don't have to worry about
versioning. Also make sure that the version constant in
`packages/devtools_app/lib/devtools.dart` was updated.

#### Update the CHANGELOG.md (for non-dev releases)

Use the tool `generate-changelog` to automatically update the `packages/devtools/CHANGELOG.md` file.

```shell
cd ~/path/to/devtools
dart tool/bin/repo_tool.dart generate-changelog
```

Be sure to manually check that the version for the CHANGELOG entry was correctly generated
and that the entries don't have any syntax errors. The `generate-changelog` script is
intended to do the bulk of the work, but still needs manual review.

#### Push the local branch

```shell
git add .
git commit -m “Prepare for 2.7.0 release.”
git push origin release_2.7.0
```

From the git GUI tool or from github.com directly:
1. Create a PR.
2. Add the entry about the created PR to the CHANGELOG.md manually, and push to the PR.
3. Receive an LGTM, squash and commit.

### Test the release
Checkout the commit you just created, or remain on the branch you just landed the prep PR from.
```shell
git checkout 8881a7caa9067471008a8e00750b161f53cdb843
```

Build the DevTools binary and run it from your local Dart SDK. From the main devtools/ directory.
```shell
dart ./tool/build_e2e.dart
```

Launch DevTools and verify that everything generally works.
- open the page in a browser (http://localhost:53432)
- `flutter run` an application
- connect to the running app from DevTools, verify that the pages
  generally work and that there are no exceptions in the chrome devtools log

If you find any release blocking issues, fix them before releasing. Then 
grab the latest commit hash that includes both the release prep commit and the bug fixes,
and use this commit hash for the following steps.

Once the build is in good shape, you can revert any local changes and proceed to the next step.
```shell
git checkout .
git clean -f -d
```

### Tag the release
Checkout the commit from which you want to release DevTools (likely the
commit for the PR you just landed). You can run `git log -v` to see the commits.
Run the `tag_version.sh` script to create a tag on the `flutter/devtools` repo for this
release. This script will automatically determine the version from `packages/devtools/pubspec.yaml`
so there is no need to manually enter the version.
```shell
tool/tag_version.sh
```

### Upload the DevTools binary to CIPD
Using the commit hash you want to release DevTools from (this should match the
commit hash for the tag you just created) and the [update.sh](https://github.com/dart-lang/sdk/blob/master/third_party/devtools/update.sh)
script, build and upload the DevTools binary to CIPD.

```shell
cd path/to/dart-sdk/sdk
git rebase-update
third_party/devtools/update.sh 8881a7caa9067471008a8e00750b161f53cdb843
```

### Update the DevTools hash in the Dart SDK

Navigate to your local checkout of the Dart SDK (for getting started instructions,
see [sdk/CONTRIBUTING.md](https://github.com/dart-lang/sdk/blob/main/CONTRIBUTING.md)).

Create new branch for your changes:
```shell
git new-branch dt-release
```

Update the `devtools_rev` entry in the Dart SDK 
[DEPS file](https://github.com/dart-lang/sdk/blob/master/DEPS)
with the git commit hash you just built DevTools from (this is
the id for the CIPD upload in the previous step). See this 
[example CL](https://dart-review.googlesource.com/c/sdk/+/215520).

Verify that running `dart devtools` launches the version of DevTools you just released. You'll
need to build the dart sdk locally to do this.
```shell
cd path/to/dart-sdk/sdk
gclient sync -D
./tools/build.py -mrelease -ax64 create_sdk
out/ReleaseX64/dart-sdk/bin/dart devtools  # On OSX replace 'out' with 'xcodebuild'
```

If the version of DevTools you just published to CIPD loads properly, push up the SDK CL for review.
```shell
git add .
git commit -m "Bump DevTools DEP to 2.16.0"
git cl upload -s
```

### Publish package:devtools_shared on pub

`package:devtools_shared` is the only DevTools package that is published on pub.
From the `devtools/packages/devtools_shared` directory, run:
```shell
pub publish
```

### Write release notes for the release
Release notes should contain details about the user-facing changes included in the release.
These notes are shown directly in DevTools when a user opens a new version of DevTools. Please
see the release notes
[README.md](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/framework/release_notes/README.md)
for details on where to add release notes and how to test them.
