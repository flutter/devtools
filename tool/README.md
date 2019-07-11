## How to release the next version of DevTools

**Note:** If you need to publish a new version of devtools_server, you will need
to do that prior to performing these steps, and update the devtools pubspec.yaml
to reference the new version of devtools_server.

Create a branch for your release. Below we're creating release 0.0.15, with all the PRs.

## Update master branch and create a local release branch
```shell
cd ~/devtools-git/devtools

checkout master

git pull upstream master

git checkout -b release_0_0_15

cd packages/devtools
```

## Update the release number in two files:
- **packages/devtools/pubspec.yaml**

Change ```version: 0.0.14``` to ```version: 0.0.15```

- **packages/devtools/lib/devtools.dart**

Change ```const String version = '0.0.14';``` to ```const String version = '0.0.15';```

## Update the CHANGELOG.md
- **packages/devtools/CHANGELOG.md**

Add the release number and date followed by the features or changes e.g.,

```
## 0.0.15 - 2019-04-01
* Added a great feature ...
```

## Push the local branch

```shell
git add lib/devtools.dart 

git add pubspec.yaml

git add CHANGELOG.md

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
- #### Verify the package works (DevTools)
- #### Publish the package
```shell
cd packages/devtools

pub publish
...
Looks great! Are you ready to upload your package (y/n)? y
```
- #### Revert the change to .gitignore
```shell
git checkout .gitignore
```
- #### Create the tag for this release and push to the remote repository.
```shell
git tag -a v0.0.15 -m "DevTools 0.0.15"

git push upstream v0.0.15
```