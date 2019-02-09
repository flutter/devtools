---
title: Running from the Command Line
---

* toc
{:toc}

## Installing DevTools

If you have `pub` on your path, you can run:

- `pub global activate devtools`

If you have `flutter` on your path, you can run:

- `flutter packages pub global activate devtools`

That will install (or update) DevTools on your machine.

## Run the DevTools application server

Next, run the local web server, which serves the DevTools application itself.
To do that, run one of the following two commands:

- `pub global run devtools` (if you have `pub` on your path)

- `flutter packages pub global run devtools` (if you have `flutter` on your path)

On the command-line, you should see output that looks something like:

> Serving DevTools at http://127.0.0.1:9100

## Start an application to debug

Next, start an app to connect to. This can be either a Flutter application or a Dart
command-line application. The example below uses a Flutter app:

- `cd path/to/flutter/app`
- `flutter run --observatory-port=9200`

You'll need to have a device connected - or a simulator open - for `flutter run` to work.
Once the app starts you'll be able to connect to it from DevTools.

## Opening DevTools and connecting to the target app

Using DevTools now is as simple as opening a local browser window. If you used the same
ports as the example above, you can either open `http://localhost:9100/?port=9200` in a
browser, or run:

```
open http://localhost:9100/?port=9200
```

from the command line.

In the above url, the first port is for the local server serving the DevTools web UI. The
second port is to tell DevTools itself which local app to connect to in order to debug and
inspect the app.
