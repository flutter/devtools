## DevTools releases
For instructions on how to release DevTools, please see
[RELEASE_INSTRUCTIONS.md](https://github.com/flutter/devtools/blob/master/tool/RELEASE_INSTRUCTIONS.md).

## Debug Logs

Debug logs found in `Settings > Copy Logs` are saved such that they can be read by (lnav)[https://lnav.org/]

### Configuring `lnav` for linux and MacOS
> For Windows, you will need find a different program to parse and read these logs.

- Follow the installation instructions found at https://lnav.org/downloads
- After installation create a symbolic link to the `tool/devtools_lnav.json` file, inside the `lnav` formats:
   ```sh
      ln -s ${DEVTOOLS}/tool/devtools_lnav.json ~/.lnav/formats/installed/`
   ```
- Your `lnav` installation will now be able to format logs created by Dart DevTools.

### Reading logs using `lnav`
- Save your Dart DevTools [Debug Logs](#debug-logs) to a file.
  ```sh
  DEBUG_LOGS=/path/to/your/logs # Let DEBUG_LOGS represent the path to your log file.
  ```
- Open the logs
  ```sh
  lnav $DEBUG_LOGS
  ```
- You should now be navigating the nicely formatted Dart Devtools Logs inside `lnav`

### `lnav` tips

For a quick tutorial on how to navigate logs using `lnav`
you can give [ their tutorial ](https://lnav.org/tutorials) a try.
