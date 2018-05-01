<# :
@echo off
SETLOCAL & SET "PS_BAT_ARGS=%~dp0 %*"
IF DEFINED PS_BAT_ARGS SET "PS_BAT_ARGS=%PS_BAT_ARGS:"="""%"
ENDLOCAL & powershell.exe -NoLogo -NoProfile -Command "&{ [ScriptBlock]::Create( ( Get-Content \"%~f0\" ) -join [char]10 ).Invoke( @( &{ $Args } %PS_BAT_ARGS% ) ) }"
GOTO :EOF
#>

<# -------------------------------------------------------------------------- #>
<# 20180501 MK: Simple Chromium Updater (chrupd.cmd)                          #>
<# -------------------------------------------------------------------------- #>
<# Uses RSS feed from "chromium.woolyss.com" to download and install latest   #>
<# Chromium version, if a newer version is available. Options can be set      #>
<# below or using command line arguments (try "chrupd.cmd -h")                #>
<#  - default is to get the "stable" 64-bit "nosync" Installer by "Nik"       #>
<#  - verifies sha1/md5 hash and runs installer                               #>
<# -------------------------------------------------------------------------- #>

<# NOTES:
   - for easy execution this PowerShell script is embedded in a Batch .CMD
	 file using a "polyglot wrapper". It can be renamed to chrupd.ps1. More info:
     https://blogs.msdn.microsoft.com/jaybaz_ms/2007/04/26/powershell-polyglot
     https://stackoverflow.com/questions/29645
   - if you add a scheduled task with -crTask, a vbs wrapper is written to 
     chrupd.vbs which is used to hide it's window. use -noVbs to disable.     #>

<# -------------------------------------------------------------------------- #>
<# CONFIGURATION:                                                             #>
<# -------------------------------------------------------------------------- #>
<# See "chrupd.cmd -h" for possible settings                                  #>
<# -------------------------------------------------------------------------- #>

$editor = "Nik"
$channel = "stable"
$getFile = "chromium-nosync.exe"
$log = 1

<# -------------------------------------------------------------------------- #>
<# END OF CONFIGURATION #>
<# -------------------------------------------------------------------------- #>

<# $editor = "The Chromium Authors"; channel = "dev" #>
$chkSite = "chromium.woolyss.com"
$rssFeed = "https://$chkSite/feed/windows-64-bit"
$saveAs = "$env:TEMP\$getFile"
$debug = "0"
$fakever = "0"
$force = "0"

#$scriptDir = ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\'))
$scriptDir = $Args[0]
$rm = ($Args[0]); $Args = ($Args) | Where { $_ -ne $rm }
$scriptName = "Simple Chromium Updater"; $scriptCmd = "chrupd.cmd"
$logFile = $scriptDir + "\chrupd.log"
#$logFile = " "
$installLog = "$env:TEMP\chromium_installer.log"
Write-Host -ForeGroundColor White -NoNewLine "`r`n$scriptName"; Write-Host " ($scriptCmd)"; Write-Host ("-" * 36)"`r`n"

<# HELP #>
If ($Args -iMatch "[-/]h") {
	Write-Host "Uses RSS feed from `"$chkSite`" to download and install latest"
	Write-Host "Chromium version, if a newer version is available." "`r`n"
	Write-Host "USAGE: $scriptCmd -[editor|channel|getFile|force]"
	Write-Host "`t`t" " -[crTask|rmTask|shTask|noVbs|confirm]" "`r`n"
	Write-Host "`t" "-editor  can be set to [Nik|RobRich|Chromium]"
	Write-Host "`t" "-channel can be set to [stable|dev]"
	Write-Host "`t" "-getFile can be set to [chromium-sync.exe|chromium-nosync.exe]"
	Write-Host "`t" "-force   always (re)install latest version" "`r`n"
	Write-Host "`t" "-crTask  to create a daily scheduled task"
	Write-Host "`t" "-rmTask  to remove scheduled task"
	Write-Host "`t" "-shTask  to show scheduled task details"
	Write-Host "`t" "-noVbs   to not use vbs wrapper to hide window when creating task"
	Write-Host "`t" "-confirm to answer Y on prompt about removing scheduled task" "`r`n"
	Write-Host "EXAMPLE: .\$scriptCmd -editor Nik -channel stable -getFile chromium-nosync.exe"
	Write-Host "                      [-crTask]" "`r`n"
	Write-Host "NOTES:   - Options are CasE Sensive"
	Write-Host "`t" "- Option `"getFile`" is only used if editor is set to `"Nik`""
	Write-Host "`t" "- Options `"xxTask`" can also be used without any other options"
	Write-Host "`t" "- Options can be set permanently using variables inside script" "`r`n"
	Exit 0
}
<# ARGUMENTS #>
ElseIf (($Args.length % 2) -eq 0) {
	$i = 0; While ($Args -is [Object[]] -And $i -lt $Args.length) {
		If (($Args[$i] -Match "^-") -And ($Args[($i+1)] -Match "^[\w\.]")) {
			Invoke-Expression ('{0}="{1}"' -f ($Args[$i] -Replace "^-", "$"), $Args[++$i].Trim());
		} 
	$i++
	}
}

<# SET VARIABLES #>
If ($editor -ceq "Nik") { $website = "https://$chkSite"; $fileSrc = "https://github.com/henrypp/chromium/releases/download/" }
ElseIf ($editor -ceq "RobRich") { $website = "https://$chkSite"; $fileSrc = "https://github.com/RobRich999/Chromium_Clang/releases/download/"; $getFile = "mini_installer.exe" }
ElseIf ($editor -cMatch "Chromium|The Chromium Authors") { $website = "https://www.chromium.org"; $fileSrc = "https://storage.googleapis.com/chromium-browser-snapshots/Win_x64/";	$getFile = "mini_installer.exe" }
Else { Write-Host -ForeGroundColor Red "ERROR: Settings incorrect - check editor `"$editor`", exiting"; Exit 1 }
If (-Not ($channel -cMatch "^(stable|dev)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid channel `"$channel`", exiting"; Exit 1 }
If (-Not ($getFile -cMatch "^(chromium-sync.exe|chromium-nosync.exe)$")) { Write-Host -ForeGroundColor Red "ERROR: Invalid getFile `"$getFile`", exiting"; Exit 1 }

If ($Args -cMatch "[-/]debug") { $debug = 1 }
If ($Args -cMatch "[-/]force") { $force = 1 }
ElseIf ($Args -cMatch "[-/]fakever") { $fakever = 1 }

<# SCHEDULED TASK #>
$vbsContent = @"
'
' Wrapper for chrupd.cmd to hide window when using Task Scheduler
'
Dim WinScriptHost
For i = 0 to (WScript.Arguments.Count - 1)
				Args = Args & " " & WScript.Arguments(i)
Next
Set WinScriptHost = CreateObject("WScript.Shell")
WinScriptHost.Run Chr(34) & "${scriptDir}$scriptCmd" & Chr(34) & " " & Args, 0
Set WinScriptHost = Nothing
"@

If ($Args -cMatch "[-/]crTask") {
	$vbsWrapper = $scriptDir + "chrupd.vbs"
	If ( $(Try { -Not (&Test-Path $vbsWrapper) } Catch { $False }) ) {
		Write-Host "VBS Wrapper ($vbsWrapper) missing, creating..."
		Add-Content $vbsWrapper -Value $vbsContent
	}
	If ($Args -cMatch "[-/]noVbs") {
		$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy ByPass -NoLogo -NoProfile -WindowStyle Hidden $scriptCmd -scheduler -editor $editor -channel $channel -getFile $getFile" -WorkingDirectory "$scriptDir"
	} Else {
		$action = New-ScheduledTaskAction -Execute $vbsWrapper -Argument "-scheduler -editor $editor -channel $channel -getFile $getFile" -WorkingDirectory "$scriptDir"
	}
	$trigger = New-ScheduledTaskTrigger -RandomDelay (New-TimeSpan -Hour 1) -Daily -At 17:00
	If (-Not (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName")) {
		Write-Host "Creating Daily Task `"$scriptName`" in Task Scheduler..."
		Try { (Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "$scriptName" -Description "Download and install latest Chromium version") } Catch { Write-Host "Something went wrong... $($_.Exception.Message)" }
	} Else {
		Write-Host "Scheduled Task already exists"
	}
	$task = (Get-ScheduledTask -TaskName "$scriptName")
	Write-Host ("Task: `"{0}{1}`", Description: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State);	Write-Host
}
ElseIf ($Args -cMatch "[-/]rmTask") {
	If (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName") {
		Write-Host "Removing Daily Task `"$scriptName`" from Task Scheduler..."`r`n""
		If ($Args -cMatch "[-/]confirm") { $confirm = $false } Else { $confirm = $true }
		Try { UnRegister-ScheduledTask -Confirm:$confirm -TaskName "$scriptName" } Catch { Write-Host "Something went wrong... $($_.Exception.Message)" }
	} Else { 
		Write-Host "Scheduled Task already removed`r`n"
	}
	If (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName" -OutVariable task) {
		Write-Host ("Could not remove Task: `"{0}{1}`", Description: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State)
		Write-Host "Please try removing it manually using `"Start > Task Scheduler`"."; Write-Host
	}
	Exit 0
}
ElseIf ($Args -cMatch "[-/]shTask") {
	If ($task = (&Get-ScheduledTask -ErrorAction SilentlyContinue -TaskName "$scriptName")) {
			$taskinfo = (&Get-ScheduledTaskInfo -TaskName "$scriptName")
			Write-Host ("Task: `"{0}{1}`", Description: `"{2}`", State: {3}." -f ($task).TaskPath, ($task).TaskName, ($task).Description, ($task).State); Write-Host
			Write-Host ("Actions: WorkingDirectory: `"{0}`", Execute: `"{1}`", Arguments: `"{2}`"" -f ($task).actions.WorkingDirectory, ($task).actions.Execute, ($task).actions.Arguments)
			Write-Host ("TaskInfo: LastRunTime: `"{0}`", NextRunTime: `"{1}`", NumberOfMissedRuns: {2}" -f ($taskinfo).LastRunTime, ($taskinfo).NextRunTime, ($taskinfo).NumberOfMissedRuns); Write-Host
	} Else { 
			Write-Host "Scheduled Task not found"
	}
	Exit 0
}

<# VERIFY LOGFILE #>
<# If ( $(Try { (Get-Variable -Name logFile -ErrorAction SilentlyContinue) -And (-Not [string]::IsNullOrWhiteSpace($logFile)) } Catch { $False })) { #>
If ($log -eq 1) {
	If ( $(Try { (Test-Path variable:local:logFile) -And (-Not [string]::IsNullOrWhiteSpace($logFile)) } Catch { $False }) ) {
		Write-Host "Logging to: `"$logFile`"`r`n"
	} Else {
		$log = 0
		Write-Host "Unable to open logfile, output to console only`r`n"
	}
}

If ($debug -eq 1) { 'editor', 'channel', 'getFile', 'website', 'fileSrc' | ForEach { Write-Host "DEBUG: ${_}:" $(Invoke-Expression `$$_) } }

$scheduler = 0; If ($Args -cMatch "[-/]scheduler") { $scheduler = 1 }
If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " Start (pid:$pid name:$($(Get-PSHostProcessInfo).ProcessName) scheduler:$scheduler)") }

$curVersion = (Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chromium).Version
If ($force -eq 1) { 
		Write-Host "Forcing update, ignoring currently installed version `"$curVersion`"`r`n"
		If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " Forcing update, ignoring current version $curVersion") }
		$curVersion = "00.0.0000.000"
}
ElseIf ($fakever -eq 1) {
	Write-Host "DEBUG: Changing real current version `"$curVersion`" to fake value"
	$curVersion = "6.6.6.0-fake"
	<# $url = "https://github.com/henrypp/chromium/releases/download/v64.0.3259.0-r514062-win64/chromium-nosync.exe" #>
} Else {
	Write-Host "Currently installed version: `"$curVersion`"`r`n"
	If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " Current version: $curVersion") }
}

$curSettings = "Checksite: `"$chkSite`", Editor: `"$editor`", Channel: `"$channel`""
Write-Host "Using the folowing settings:"; Write-Host "$curSettings`r`n"
If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " $curSettings") }

<# MAIN OUTER WHILE LOOP: XML #>
$xml = [xml](Invoke-WebRequest $rssFeed); $i = 0; While ($xml.rss.channel.item[$i]) {
	$editorMatch = 0; $archMatch = 0; $chanMatch = 0; $urlMatch = 0; $hashMatch = 0
	If ($debug -eq 1) {
		Write-Host "DEBUG: $i xml title: $($xml.rss.channel.item[$i].title)"
		Write-Host "DEBUG: $i xml link: $($xml.rss.channel.item[$i].link)"
		<# Write-Host "DEBUG: $i xml description: $($xml.rss.channel.item[$i].description."#cdata-section")"
		Write-Host "DEBUG: Matches[0] Matches[1]"; Foreach-Object {$Matches[0]}; Foreach-Object {$Matches[1]}; #>
	}
	<# If ($xml.rss.channel.item[$i].title -Match ".*?(Nik)") { $editorMatch = 1 ; $editorDebug = $Matches[1] #>
		<# INNER WHILE LOOP: HTML #>
		$xml.rss.channel.item[$i].description."#cdata-section" | ForEach {
		<# Write-Host $_ #>
		If ($_ -Match '(?i)' + $channel + '.*?(Editor: <a href="' + $website + '/">' + $editor + '</a>).*(?i)' + $channel) { $editorMatch = 1 }
		If ($_ -Match '(?i)' + $channel + '.*?(Architecture: 64-bit).*(?i)' + $channel) { $archMatch = 1 }
		If ($_ -Match '(?i)' + $channel + '.*?(Channel: ' + $channel + ')') { $chanMatch = 1 }
		<# $version = $_ -Replace ".*Version: ([\d.]+).*", '$1' #>
		$version = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Version: ([\d.]+).*', '$1')
		$revision = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Revision: (?:<[^>]+>)?(\d{6})<[^>]+>.*', '$1')
		$date = [regex]::Replace($_, '.*(?i)' + $channel + '.*?Date: <abbr title="Date format: YYYY-MM-DD">([\d-]{10})</abbr>.*', '$1')
		If ($debug -eq 1) { 'editor', 'architecture', 'version', 'channel', 'revision', 'date' | ForEach { Write-Host "DEBUG: $i cdata ${_}:" $(Invoke-Expression `$$_) } }
		$url = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?Download from.*?repository: .*?<li><a href="(' + $fileSrc + '(?:v' + $version + '-r)?' + $revision + '(?:-win64)?/' + $getFile + ')".*', '$1')
		If ($debug -eq 1) { Write-Host "DEBUG: $i cdata url: $url" }
		If ($url -Match ('^https://.*' + '(' + $version + ')?.*' + $revision + '.*' + $getFile + '$') ) {	
		 	$urlMatch = 1
			<# $sha1 = $_ -Replace "(?i)$channel.*<a href=`"$url`">$getFile</a> - sha1: ([0-9a-z]{40})</li>.*", '$1'#>
			$tmpHash = [regex]::Replace($_, '.*?(?i)' + $channel + '.*?<a href="' + $url + '">' + $getFile + '</a> - (?:(sha1|md5): ([0-9a-f]{32}|[0-9a-f]{40}))</li>.*', '$1 $2')
			$hashAlgo, $hash = $tmpHash.ToUpper().split(' ')
			If (($hashAlgo) -And ($hash)) { $hashMatch = 1 }
			If ($debug -eq 1) { Write-Host "DEBUG: $i cdata hash: $hash`r`n" }
			Break
		}
	}
$i++
}

<# DOWNLOAD LATEST #>
If ($debug -eq 1) { 'editorMatch', 'archMatch', 'chanMatch', 'urlMatch', 'hashMatch' | ForEach { Write-Host "DEBUG: ${_}:" $(Invoke-Expression `$$_) }; Write-Host }
If (($editorMatch -eq 1) -And ($archMatch -eq 1) -And ($chanMatch -eq 1) -And ($urlMatch -eq 1) -And ($hashMatch -eq 1)) {
	If (($url) -And ($url -NotMatch ".*$curVersion.*")) {
	$ago = ((Get-Date) - ([DateTime]::ParseExact($date,'yyyy-MM-dd', $null)))
	If ($ago.Days -lt 1) { $agoTxt = ($ago.Hours, "hours") } Else { $agoTxt = ($ago.Days, "days")	}
	Write-Host "New version `"$version`" from $date is available ($agoTxt ago)"
	If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " New version `"$version`" from $date is available ($agoTxt ago)") }
		If ($debug -eq 1) {
			If (&Test-Path "$saveAs") { Write-Host "DEBUG: Would have deleted $saveAs" }
			Write-Host "DEBUG: Would have downloaded `"$url`" to `"$saveAs`""
			Write-Host "DEBUG: (!) Make sure `"$saveAs`" ALREADY EXISTS to debug further"
		} Else {
			If (&Test-Path "$saveAs") { Remove-Item "$saveAs" }
			Write-Host "Downloading `"$url`" to `"$saveAs`""
			[System.Net.ServicePointManager]::SecurityProtocol = @("Tls12","Tls11","Tls")
			$wc = New-Object System.Net.WebClient
			$wc.DownloadFile($url, "$saveAs")
			If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " Downloading: `"$url`" to: `"$saveAs`"") }
		}
	} Else {
		Write-Host -NoNewLine "["; Write-Host -NoNewLine -ForeGroundColor Green "OK"; Write-Host -NoNewLine "] Latest Chromium version already installed"
		If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " Latest version already installed") }; Write-Host
		Exit 0;
	}
} Else {
	Write-Host "No matching versions found, exiting..."
	If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " No matching versions found") }; Write-Host
	Exit 0;
}

If ((Get-FileHash -Algorithm $hashAlgo "$saveAs").Hash -eq $hash) {
	Write-Host "$hashAlgo Hash matches `"$hash`""
	Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " $hashALgo matches: `"$hash`"")
	Write-Host "Executing `"$getFile`"..."
	If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " Executing `"$getFile`"") }
	If ($fakever -eq 1) { 
		$saveAs = "true"
	}
	If ($debug -eq 1) { 
		Write-Host "DEBUG: $p = Start-Process -FilePath `"$saveAs`" -ArgumentList `"--do-not-launch-chrome`" -Wait -NoNewWindow -PassThru"
	} Else { 
		$p = (Start-Process -FilePath "$saveAs" -ArgumentList "--do-not-launch-chrome" -Wait -NoNewWindow -PassThru)
	}
	If ($p.ExitCode -eq 0) {
	 	Write-Host -NoNewLine "["; Write-Host -NoNewLine -ForeGroundColor Green "OK"; Write-Host -NoNewLine "] Done. "; Write-Host -ForeGroundColor Yellow "New Chromium version will be used on next (re)start."
		If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " Done. New Chromium version will be used on next (re)start") }
	} Else {
		errorMsg = "ERROR: after executing `"$getFile`""
		Write-Host -ForeGroundColor Red -NoNewLine "$errorMsg"
		If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " $errorMsg") }
		If ($p.ExitCode) {
			Write-Host -ForeGroundColor Red ":" $p.ExitCode
			If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " : $p.ExitCode") }
		}
	If (&Test-Path $installLog) {
			logMsg = "Log file: $installLog"
			Write-Host -ForeGroundColor Red -NoNewLine "$logMsg" }
			If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " logMsg") }
	}
} Else {
	Write-Host -ForeGroundColor Red "ERROR: $hashAlgo Hash does NOT match: `"$hash`", exiting..."
	If ($log -eq 1) { Add-Content $logFile -Value (((Get-Date).toString("yyyy-MM-dd HH:mm:ss")) + " $hashALgo does not match: `"$hash`"") }
	Exit 1;
}
Write-Host