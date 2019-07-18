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
