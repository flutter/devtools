## plan for integration tests

Integration tests are expected to be heavyweight and test broad areas of a
use case. We likely wouldn't have more than 1-2 dozen of them.

### startup

- start a Dart VM or a Flutter app on a sample app
- connect to it via a service protocol connection
- start a chrome process
- connect to it via a chrome debug protocol connection
- start a web serve serving a debug build of the devtools app
- switch the chrome tab page to the devtools app w/ the port of the running dart/flutter app
- wait for app initialization

### testing
- interact with devtools by invoking methods on objects registered globally
- verify expected behavior by invoking methods, or listening to events written
  to the browser's console

### teardown

- tear down chrome
- tear down the web server
- tear down the running Dart/Flutter app
