## How to release the next version of DevTools

Create a branch for your release.

```shell
cd ~/devtools-git/devtools

checkout master

git pull upstream master

git checkout -b release_2.7.0

```

### Update the version number by running:

dart ./tool/update_version.dart 2.7.0

Verify that this script updated the pubspecs under packages/
and updated all references to those packages. These packages always have their
version numbers updated in lock, so we don't have to worry about
versioning. Also make sure that the version constant in
**packages/devtools_app/lib/devtools.dart** was updated.

### Update the CHANGELOG.md

Use the tool `generate-changelog` to automatically update the `packages/devtools/CHANGELOG.md` file e.g.,

```shell
cd ~/path/to/devtools

dart tool/bin/repo_tool.dart generate-changelog
```

Be sure to manually check that the version for the CHANGELOG entry was correctly generated
and that the entries don't have any syntax errors. The `generate-changelog` script is
intended to do the bulk of the work, but still needs manual review.

### Push the local branch

```shell
git add .

git commit -m “Prepare for 2.7.0 release.”

git push origin release_2.7.0
```

From the git GUI tool or from github.com directly, create a PR, send for review,
then squash and commit after receiving an LGTM.

### Publishing DevTools
#### Update your master branch from the remote repository
> Ensure that the tip of master is the above commit, just made with the exact set of PRs wanted.  Otherwise, checkout using the SHA1 of the above commit e.g.,
``` git checkout <SHA1>``` then proceed to the step **Update the local flutter-sdk**.

```shell
cd ~/path/to/devtools

git checkout master

git pull upstream master
```

#### Update the local flutter-sdk 

The build release script checks if your local Flutter matches the version expected.
This is to ensure that we are building DevTools from the same version of Flutter that
our CI tests against. To switch your Flutter version to the expected Flutter build, run:

```shell
./tool/update_flutter_sdk.sh
``` 

#### Build DevTools for publishing

```shell
./tool/publish.sh
```

#### Verify the DevTools binary works

- Launch the DevTools server
```
dart packages/devtools/bin/devtools.dart
```
- open the page in a browser (http://localhost:9100)
- `flutter run` an application
- connect to the running app from DevTools, verify that the pages
  generally work and that there are no exceptions in the chrome devtools log

#### Publish the packages

```shell
./tool/pub_publish.sh
```

#### Revert changes caused by the `publish.sh` script
```shell
git checkout .

git clean -f -d
```

#### Create the tag for this release and push to the remote repository.
This script will automatically determine the version from the `packages/devtools/pubspec.yaml` so there
is no need to manually enter the version.
```shell
tool/tag_version.sh
```

#### Upload the DevTools binary to CIPD

Checkout the version of DevTools you just tagged (for example, `2.7.0`):
```shell
git checkout v2.7.0

Note: switching to 'v2.7.0'.

You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by switching back to a branch.

If you want to create a new branch to retain commits you create, you may
do so (now or later) by using -c with the switch command. Example:

  git switch -c <new-branch-name>

Or undo this operation with:

  git switch -

Turn off this advice by setting config variable advice.detachedHead to false

HEAD is now at 8881a7ca Update release scripts (#3426)
```

Copy the commit hash from the bottom of the CLI output (in the example above, `8881a7ca`).

Using the [update.sh](https://github.com/dart-lang/sdk/blob/master/third_party/devtools/update.sh)
script at https://github.com/dart-lang/sdk/tree/master/third_party/devtools, build DevTools at the 
given git commit hash, and upload the binary to CIPD.

```shell
sdk/third_party/devtools/update.sh 8881a7ca
```

#### Update the DevTools hash in the Dart SDK

Update the `devtools_rev` entry in the Dart SDK 
[DEPS file](https://github.com/dart-lang/sdk/blob/master/DEPS)
with the git commit hash you just built DevTools from (this is
the id for the CIPD upload in the previous step). See this 
[example CL](https://dart-review.googlesource.com/c/sdk/+/215520).

Now verify that running `dart devtools` launches the version of DevTools you just released.
> You'll need to ensure that `which dart` points to your local dart sdk or that your CL has
> landed and is part of the dart version on your local machine.