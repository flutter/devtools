## 0.2.6-dev.2
- Updated package:vm_service to >= 4.1.0

## 0.2.3
- Updated package:vm_service to >= 3.0.0
- Move shared code out of handlers.dart and rename to `external_handlers.dart`

## 0.2.2
- Coordinated release with DevTools 0.2.2

## 0.1.15
- Added new setActiveSurvey requests.  Set will create the survey e.g., Q1-2020 and subsequent surveys will perform on the current activeSurvey.

## 0.1.14
- Added CLI support to collect memory profile statistics to collect run run:</br>
`dart ../devtools/bin/devtools.dart --vm-uri `**VM_Auth_URI**` --profile-memory `**FileName**` --verbose`</br></br>
**VM_Auth_URI** \- token displayed in flutter run e.g., `http://127.0.0.1:37141/m6a1twmdRpI=/`</br>**FileName** \- location and file name to store statistics e.g., `/usr/local/home/myname/Downloads/memory_samples.json`

## 0.1.13
- Depend on the latest `package:sse`.

## 0.1.12
- Change from HttpMultiServer to HttpServer.

## 0.1.11
- Add APIs to persist enabling/disabling properties for GA and Surveys to a local file `~/.devtools`.
- Created shared devtools_api.dart list of APIs known between server and devtools_app.
- Removed sample API endpoint for `logScreenView`.

## 0.1.10
- Add API for handling http requests.
- Add API endpoint for `logScreenView`.

## 0.1.9

- Support configurable `hostname`.

## 0.1.8

- Use `http_multi_server` for serving.
- Make stdin commands configurable.
- Return the underlying server so that it can be closed.

## 0.1.7

- Rev to using the latest version of `package:vm_service` (1.2.0).

## 0.1.6

- Rev to using the latest version of `package:vm_service` (1.1.1).

## 0.1.4
- The `launchDevTools` service will now register with VMs using public APIs when available, falling back to private APIs otherwise.

## 0.1.3
- vm_service_lib dependency has been pinned to 3.21.0

## 0.1.2
- The `launchDevTools` service will now return well-formed errors if it fails to
  launch the browser for any reason.

## 0.1.1
- When running on ChromeOS, the `launchDevTools` service will now launch the native
  ChromeOS browser (instead of the Linux version of Chrome installed in the Linux
  container) if both the DevTools and VM Service ports are accessible (tunneled)
  to the ChromeOS browser.

## 0.1.0
- JSON-RPC commands are now accepted over stdin, the first method being `vm.register` which allows registering of VM services:
  ```
  {
    "id":"1",
    "method":"vm.register",
    "params":{
      "uri":"<vm-service-uri-here>",
    }
  }
  ```
  DevTools will connect to each registered VM and register a `launchDevTools` service that can then be called (via the VM service protocol). The arguments to this service can include a `queryParams` object that will be used to build the querystring:
  ```
  {
    queryParams: {
      hide: "debugger",
      theme: "dark",
    },
  }
  ```

## 0.0.2
* Reduce the minimum Dart SDK requirements for activating DevTools to cover Flutter v1.2.1 (Dart v2.1)

## 0.0.1
- initial (pre-release) release
