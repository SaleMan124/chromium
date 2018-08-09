# Simple Chromium Updater (chrupd.cmd)

#### Self executable PowerShell script to auto update Chromium for Windows

Uses RSS feed from https://chromium.woolyss.com to download and install latest Chromium version, if a newer version is available. Options can be set in script or using command line arguments (try "`chrupd.cmd -h`")

 - default is to get the "stable" 64-bit ("sync") Installer by "Nik"
 - verifies SHA1/MD5 hash and runs installer

#### Changes:

2018-08-09: Nik's nosync builds are no longer available ([more info](https://chromium.woolyss.com/#news)). Removed related getFile option as it is no longer needed.

2018-07-29: ~~There seems to be an mismatch between the Version and Revision listed in the RSS feed and URL of Nik's dev "sync" Installer (issue [#1](https://github.com/mkorthof/chrupd/issues/1)). Added option "`-ignVer`" to ignore this and skip checking version, be sure to manually check correct version when using this option.~~

#### Configuration:

Make sure the combination of editor and channel is correct:

| editor:      | channel:     |
|--------------|--------------|
| Nik          | stable, dev  |
| RobRich      | dev          |
| Chromium     | dev          |
| ThumbApps    | dev          |

~~Also note that if editor is set to "Nik", you need to set getFile to either "chromium-sync.exe" (default) or "chromium-nosync.exe".~~

For more information about versions: [chromium.woolyss.com](https://chromium.woolyss.com/?cut=1&ago=1) (RSS atom [feed](https://chromium.woolyss.com/feed/windows-64-bit)).

#### Scheduled Task:

You can add a Scheduled Task with "-crTask". A VBS wrapper will be written to **chrupd.vbs** which is used to hide it's window. Option "-noVbs" disables the wrapper, this will however cause a flashing window when the task runs.

#### Updating:

To update Simple Chromium Updater to a newer version just replace "chrupd.cmd". If you have Scheduled Task setup you do not need to change it.

---

> *For easy execution this PowerShell script is embedded in a Batch .CMD file using a "polyglot wrapper". It can be renamed to chrupd.ps1. More info: [blogs.msdn.microsoft.com](https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot) and [stackoverflow.com](https://stackoverflow.com/questions/29645).*
> 
> <small>Note that this script has no connection to the preexisting [ChrUpdWin.cmd](https://gist.github.com/mikhaelkh/12dec36d4a1c4136628b#file-chrupdwin-cmd) Batch file by [Michael Kharitonov](https://github.com/mikhaelkh)</small>
> 
> 
---

<pre>

USAGE: chrupd.cmd -[editor|channel|force|list]
                  -[crTask|rmTask|shTask|noVbs|confirm]

         -editor  can be set to &lt;Nik|RobRich|Chromium|ThumbApps&gt;
         -channel can be set to &lt;stable|dev&gt;
         -force   always (re)install, even if latest version installed already
         -list    lists editors and urls

         -crTask  to create a daily scheduled task
         -rmTask  to remove scheduled task
         -shTask  to show scheduled task details
         -noVbs   to not use vbs wrapper to hide window when creating task
         -confirm to answer Y on prompt about removing scheduled task

EXAMPLE: .\chrupd.cmd -editor Nik -channel stable [-crTask]

NOTES:   Options "editor" and "channel" need an argument (CasE Sensive)
         Schedule "xxTask" options can also be used without any other options
         Options can be set permanently using variables inside script

</pre>

