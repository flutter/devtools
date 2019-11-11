# DevTools Server Daemon

## Overview

The `devtools` tool supports running in a server mode for use by IDEs and other tools.

```
pub global run devtools --machine
```

This runs a persistent, JSON-RPC based server. IDEs and other tools can start DevTools in this mode and get in order to launch browser windows (or reuse existing ones) and track which DevTools instances are connected to VMs.

### Additional Command-Line Flags

- `--enable-notifications`. This flag causes DevTools to request browser notification permissions immediately at startup. This supports the IDE requesting to show notifications when DevTools windows are re-used so that the user can easily find them if they're not visible on the screen. This flag itself does not cause any notifications be sent, it controls only whether permissions are requested at startup - the IDE sends a flag with each request to control whether notifications should be shown.

- `--try-ports {numPorts}`. This option tells the server to try binding to ascending ports if it fails to bind to the requested port up to `{numPorts}`. This is preferred over random ports because each new port will result in a new permissions request. Sticking to the default port (or the few after it) will reduce the chances of the user seeing too many permissions prompts.

### Events

Events are sent as objects with a string `event` field and a json object `params` field.

#### Example

```js
{
	'event': 'server.started',
	'params': {
		'host': 'localhost',
		'port': 9100,
		'pid': 9876,
	}
}
```

#### server.started Event

This event is sent when the server starts up and has bound to a port. Each event contains the following params:

- `host` - the hostname/IP the server is listening on
- `port` - the port the server bound to (this may differ from the supplied `--port` if `--try-ports` was used)
- `pid` - the PID of the current process (supplied to improve reliability of sending kill signals since the process handle the IDE has may be a shell)
- `protocolVersion` - the version number for this protocol (if this field is missing it is protocol version `1.0.0`)

<!--
This request is only used for testing purposes so is currently "undocumented"

### client.launch Event

This event is sent when the server launches a new client in response to a call to `launchDevTools`. `params` contains the following fields:

- `reused` - whether an existing DevTools instance was reused (otherwise a new browser was launched)
- `notified` - whether or not a notification was shown
-->

### Requests

### `vm.register` Request

This request is used to tell the server about a new VM service it should connect to and register the `launchDevTools` service into. The request takes the following params:

- `uri` - the URI of the VM service to register with

<!--
This request is only used for testing purposes so is currently "undocumented"

### `client.list` Request

This request lists all DevTools instances that are currently connected back to the server along with which VM services they're connected to and the pages they are showing. The request requires no `params`.
-->

### launchDevTools Request (VM Service)

`launchDevTools` is registered as a VM service (it is *not* sent over stdin to the server) and takes the following params:

- `reuseWindows` - whether an existing DevTools instance that is not connected to a VM (or is connected to the same one) should be reused
- `notify` - whether to send a browser notification to the user in the case where a DevTools instance is reused, to help them find the window
- `page` - the page to launch DevTools on (matches the IDs used in DevTools that show in the URL fragments) or - if reusing a window - to switch to
- `queryParams` - an object of additional query parameters that may be added to the query string that may influence DevTools behaviour, such as:
  - `theme` - allows using the `dark` theme
  - `ide` - the client (eg. `VSCode`) to be logged in analytics
  - `hide` - IDs of pages to hide (eg. `debugger` when launching from an IDE with its own debugger)

#### Example

```js
{
	'id': '123',
	// The `method` field is populated based on the ServiceRegistered VM event
	'method': 's2.launchDevTools',
	'params': {
		'notify': true,
		'page': 'inspector',
		'queryParams': {
			'hide': 'debugger',
			'ide': 'VSCode',
			'theme': 'dark'
		},
		'reuseWindows': true
	}
}
```

## Changelog

- 1.0.0: Initial documentation for DevTools server API
