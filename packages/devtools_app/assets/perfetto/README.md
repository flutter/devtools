## What is this?

This directory stores pre-built assets of the
[Perfetto UI](https://github.com/google/perfetto/tree/master/ui) web app, along
with some additional files authored by the DevTools team to support custom
styling for the Perfetto UI.

## Why is this included in `assets/`?

This build output is stored in our `assets/` directory for the following
reasons:
* this allows us to include our custom theming .css and .js files in the build.
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