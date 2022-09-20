## What is this?

This directory stores pre-built assets of the
[Perfetto UI](https://github.com/google/perfetto/tree/master/ui) web app, along
with some additional files authored by the DevTools team, to support custom
styling for the Perfetto UI. We embed this web app in an iFrame on the DevTools
Performance page. This allows us to leverage the first-in-class trace viewer for
viewing Dart and Flutter timeline traces.

## Why are we loading pre-compiled sources instead of the live Perfetto UI url?

This build output is included with the DevTools app bundle so that we can load
the Perfetto UI web app from source at runtime. We do this for the following
reasons:
* this allows us to include our custom theming .css and .js files in the build.
These theming files enable a more dense interface that better fits our tooling,
and they also enable a dark theme that we can switch to and from.
* this allows us to load the Perfetto UI web app directly from assets, meaning
  we have zero latency and can support users with a slow or non-existent internet
  connection.

## How often is this build output updated?

This build output should be updated as needed, for example, if the Perfetto
team releases some new features or fixes we want to take advantage of. Outside
of ad hoc updates, this output should be refreshed at least once per quarter.

To update the Perfetto build output, run the `update_perfetto.sh` script located
in `devtools/tools/`. Be sure that all DevTools-authored files under
`assets/perfetto` are not deleted by mistake. 