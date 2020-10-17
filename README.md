# Simple Chromium Updater (chrupd.cmd)

_**Self executable PowerShell script to auto update Chromium for Windows**_

---

**Latest version: 20201017 ([CHANGES.md](CHANGES.md))**

---

Uses RSS feed from <https://chromium.woolyss.com> to download and install latest Chromium version, if a newer version is available. Options can be set in script or using command line arguments.

- default is to get the "stable" 64-bit Installer by "Hibbiki"
- verifies SHA1/MD5 hash and runs installer

Run `chrupd.cmd` or see below for details.

## Configuration

Make sure the combination of editor and channel is correct. You can also use  the `list` option. For more information about versions check: [chromium.woolyss.com](https://chromium.woolyss.com/?cut=1&ago=1) and it's RSS atom [feed](https://chromium.woolyss.com/feed/windows-64-bit).

| Editor       | Channel      |
|:-------------|:-------------|
| Marmaduke    | stable, dev  |
| RobRich      | dev          |
| Chromium     | dev          |
| ThumbApps    | dev          |
| Ungoogled    | stable       |
| **Hibbiki**  | **stable**, dev  |

_( defaults in **bold**  )_

## Usage

Usually Chromium installation is automatically taken care of by running the downloaded Installer ('mini_installer.exe'). In case the installer left a logfile it's path wil be shown.

If the Editor releases Chromium as an zip or 7z archive, the script will to try to extract it to these paths:

| Path                                   | Example                                   |
|:---------------------------------------|:------------------------------------------|
| %LocalAppData%\Chromium\Application    | C:\Users\\<User\>\Appdata\Local\Chromium  |
| Desktop                                | C:\Users\\<User\>\Desktop                 |
| %TEMP%                                 | C:\Users\\\<User\>\TEMP                   |

_(in that order, top to bottom)_

The folder that was used will be shown and a shortcut will be created on the Desktop called 'Chromium', which links to chrome.exe

A log is saved to "chrupd.log" in the same dir as the script.

## Scheduled Task

You can add a Scheduled Task with ```crTask```. A VBS wrapper will be written to **chrupd.vbs** which is used to hide it's window. Option ```noVbs``` disables the wrapper, this will however cause a flashing window when the task runs.

## Updating

To update Simple Chromium Updater to a newer version just replace "chrupd.cmd" (copy "editor" and "channel" if set). If you have Scheduled Task setup you do not need to change the task.

For a changelog see [CHANGES.md](CHANGES.md)

## File Format

For easy execution this PowerShell script is embedded in a Batch .CMD file using a *"polyglot wrapper"*. It can be renamed to `chrupd.ps1`. More info can be found on [blogs.msdn.microsoft.com](https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot) and [stackoverflow.com](https://stackoverflow.com/questions/29645).

###### *Note that this script has no connection to the preexisting [ChrUpdWin.cmd](https://gist.github.com/mikhaelkh/12dec36d4a1c4136628b#file-chrupdwin-cmd) Batch file by [Michael Kharitonov](https://github.com/mikhaelkh)*

---

## Command Line Options

Options are case senstive: e.g. use `-shTask` _not_ `-shtask`

`chrupd.cmd -h`

```text

Simple Chromium Updater (chrupd.cmd)
------------------------------------

Uses RSS feed from "chromium.woolyss.com" to install latest Chromium version

USAGE: chrupd.cmd -[editor|arch|channel|force|list]
                  -[crTask|rmTask|shTask]

         -editor  option must be set to one of:
                  <Chromium|Hibbiki|Marmaduke|Ungloogled|RobRich|ThumbApps>
         -arch    option must be set to <64bit|32bit>
         -channel option must be set to <stable|dev>
         -force   flag to always (re)install, even if latest ver is installed
         -list    flag to show version, editors and rss feeds from woolyss.com

         -crTask  flag to create a daily scheduled task
         -rmTask  flag to remove scheduled task
         -shTask  flag to show scheduled task details

EXAMPLE: ".\chrupd.cmd -editor Marmaduke -arch 64bit -channel stable [-crTask]"
NOTES:   > Options "editor" and "channel" need an argument (CasE Sensive)
EXTRA:   > See ".\chrupd.cmd -advhelp" for "advanced" options
```
