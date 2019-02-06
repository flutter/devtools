[![Build Status](https://travis-ci.org/flutter/devtools.svg?branch=master)](https://travis-ci.org/flutter/devtools)

## Trying it out

### Installing

Currently, the best way to try DevTools out is by running it as a pub globally activated package.

If you have `pub` on your path, you can run:

- `pub global activate devtools`

If you have `flutter` on your path, you can run:

- `flutter packages pub global activate devtools`

That will  install (or update) DevTools on your machine.

Going forward, we expect to have additional (and easier!) distributions mechanisms for DevTools.

### Run the DevTools application server

Next, you want to run the local web server which can serve the DevTools application itself.

Run one of the following two commands; if you have `pub` on your path:

- `pub global run devtools`

And if you have `flutter` on your path:

- `flutter packages pub global run devtools`

On the command-line, you should see output that looks something like:

```
Serving DevTools at http://127.0.0.1:9100
```

### Start an application to debug

Next, you'll want to start an app to connect to. This can be either a Flutter application or a Dart
command-line application. The example below uses a Flutter app.

- change to the directory for a Flutter app
- run `flutter run --observatory-port=9200`

You'll need to have a device connected or a simulator open for `flutter run` to work. Once the app
starts up, you'll be able to connect to it from devtools.

### Open DevTools and connect to the target app

Using DevTools now is as simple as opening a local browser window and pointing the DevTools app to the 
running Flutter application. If you used the same ports as the example above, you can open:

```
http://localhost:9100/?port=9200
```

This can also be done via the command line with `open http://localhost:9100/?port=9200`. The first port
in the url is for the local server that is serving the DevTools web UI. The second port is to tell
DevTools itself which local app to connect to for debugging and inspection.

## Feedback

Feedback and issues are best reported at https://github.com/flutter/devtools/issues. Thanks for
trying out DevTools!
