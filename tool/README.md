## How to release the next version of DevTools

**Note:** If you need to publish a new version of devtools_server, you will need
to do that prior to performing these steps, and update the devtools pubspec.yaml
to reference the new published version of devtools_server. To publish devtools_server, run
`pub publish` from `packages/devtools_server`. Be sure to test the server locally
before publishing. For instructions on how to do that, see
[CONTRIBUTING.md](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md#devtools-server).

Create a branch for your release. Below we're creating release 0.0.15, with all the PRs.

## Update master branch and create a local release branch
```shell
cd ~/devtools-git/devtools

checkout master

git pull upstream master

git checkout -b release_0_0_15

```

## Update the version number by running:

dart ./tool/update_version.dart 0.0.15

Verify that this script updated the pubspecs under packages/
and updated all references to those packages. These packages always have their
version numbers updated in lock step so we don't have to worry about
versioning. Also make sure that the version constant in
**packages/devtools_app/lib/devtools.dart** was updated.

## Update the CHANGELOG.md
- **packages/devtools/CHANGELOG.md**

Add the release number and date followed by the features or changes e.g.,

```
## 0.0.15 - 2019-04-01
* Added a great feature ...
```

## Push the local branch

```shell

git commit -a -m “Prepare for v0.0.15 release.”

git push origin release_0_0_15
```

## Create the PR and Commit the above changes
From the git UI tool create the PR, squash and commit.

## Publishing DevTools
### Update your master branch from the remote repository
> Ensure that the tip of master is the above commit, just made with the exact set of PRs wanted.  Otherwise, checkout using the SHA1 of the above commit e.g.,
``` git checkout -b release_15 <SHA1>``` then proceed to the step 'Prep to publish'.

```shell
cd ~/devtools-git/devtools

git checkout master

git pull upstream master
```

### Prep to publish
```shell
./tool/publish.sh
``` 

### Publish
#### Verify the package works (DevTools)

- Launch the devtools server
```
cd packages/devtools
dart bin/devtools.dart
```
- open the page in a browser (http://localhost:9100)
- flutter run an application
- connect to the running app from devtools, and verify that the pages
  generally work, and there are no exceptions in the chrome devtools log

#### Publish the packages

```shell
./tool/pub_publish.sh
```

#### Revert the change to .gitignore and pubspec files
```shell
git checkout .gitignore
git checkout packages/*/pubspec.yaml
```

Update the version of DevTools referenced by
https://github.com/flutter/flutter/blob/8c4538618f81a42e45cdb03c6a204f6e7bcf81b3/dev/devicelab/lib/tasks/perf_tests.dart#L1448

with a CL like
https://github.com/flutter/flutter/pull/81869

to avoid the issue described by https://github.com/flutter/flutter/issues/81552
Once DevTools is deployed as part of the Dart SDK we should be able to eliminate this step.


#### Create the tag for this release and push to the remote repository.
This script will automatically determine the version from the `packages/devtools/pubspec.yaml` so there
is no need to manually enter the version.
```shell
tool/tag_version.sh
```
