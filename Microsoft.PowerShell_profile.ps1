oh-my-posh init pwsh --config  C:\Users\Justin\justin.omp.json | Invoke-Expression
$env:POSH_GIT_ENABLED = $true

$slackToken = 'xoxp-369080069233-370516623206-421960934752-8ceeac11eeb113641de74214f8c65d91'

enum Sites {
    Addmembers
    Membersite
}

$domain = @{
    [Sites]::Addmembers = 'addmembers.com';
    [Sites]::Membersite = 'member-site.net'
}

###########################################################################
# Define aliases
###########################################################################
$aliasList = @{
    psake="Invoke-Psake";
    'Out-Clipboard'="$env:SystemRoot\system32\clip.exe";
    npp="C:\Program Files\Notepad++\notepad++.exe";
    subl="C:\Program Files\Sublime Text 3\sublime_text.exe";
    which="Get-Command";
    ss="Select-String";
    vi="vim";
}
$aliasList.Keys | %{
    if ((Get-Alias $_ -ea si) -eq $null) {
        New-Alias $_ $aliasList[$_]
    }
}
###########################################################################
# Define functions
###########################################################################

# helper
function Import-Module-With-Measure {
    param ($Name)
    $import = Measure-Command {
        Import-Module $Name
    }
    Write-Host "$Name import $($import.TotalMilliseconds) ms"
}

# SUDO functions
function fcuk {
    $cmd = (Get-History ((Get-History).Count))[0].CommandLine
    Write-Host "Running $cmd in $PWD"
    start-process pwsh -verb runas -WorkingDirectory $PWD -ArgumentList "-NoExit -Command pushd $PWD; Write-host 'cmd to run: $cmd'; $cmd"
}

function sudo {
    if ($first -eq '!!') {
        fcuk;
    }
    else {
        $file=$args[0];
        [string]$arguments = "";
        if ($args.Count -gt 1) {
            $c = $args.Count - 1;
            [string]$arguments = $args[1..$c]
        }
        Write-Host "file = $file args = $arguments";
        start-process $file -verb runas -WorkingDirectory $PWD -ArgumentList $arguments;
    }
}
function sln { Invoke-Item *.sln }
function slna { sudo "$((which devenv.exe).Source)" "$((gci *.sln)[0].FullName)" }
function gca { Start-Process -FilePath "$((which git.exe).Source)" -Verb runas -ArgumentList "clean -xfd" }
function sts  { Start-Process -FilePath 'C:\Users\justin.RAGONK\AppData\Local\SourceTree\SourceTree.exe' -ArgumentList "$pwd" }
function tail { Get-Content -Wait $args }
function tail-last { gci * | sort LastWriteTime | select -last 1 | Get-Content -Wait }

function rmrf {
    Param(
	[parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [SupportsWildcards()]
	[String]
	$Path
	)
    Remove-Item -Recurse -Force -Path $Path
}

function Write-XML ([xml]$xml) {
    $StringWriter = New-Object System.IO.StringWriter;
    $XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter;
    $XmlWriter.Formatting = "indented";
    $xml.WriteTo($XmlWriter);
    $XmlWriter.Flush();
    $StringWriter.Flush();
    Write-Output $StringWriter.ToString();
}

function Search-Code ([string]$query) {
    $extensions = "*.cs, *.htm, *.html, *.vb, *.ps1, *.cmd, *.ashx, *.aspx, *.js, *.ascx, *.php, *.sql, *.asp, *.bat, *.sh, *.jsm, *.xhtml, *.py, *.coffee, *.asmx, *.asax, *.edmx, *.Config, *.cshtml";
    $extensions = @("*.cs", "*.htm", "*.html", "*.vb", "*.ps1", "*.cmd", "*.ashx", "*.aspx", "*.js", "*.ascx", "*.php", "*.sql", "*.asp", "*.bat", "*.sh", "*.jsm", "*.xhtml", "*.py", "*.coffee", "*.asmx", "*.asax", "*.edmx", "*.Config", "*.cshtml");
    Get-Childitem -Recurse -Include $extensions | Select-String $query;
}

function Add-VsVars {
    #Set environment variables for Visual Studio Command Prompt
    $version = (& 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe' -latest -format json) | out-string | ConvertFrom-Json
    Push-Location "$($version.installationPath)\Common7\Tools"

    cmd /c "VsDevCmd.bat&set" |
        ForEach-Object {
            if ($_ -match "=") {
                $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
            }
        }

    Pop-Location
    Write-Host "Loaded $($version.displayName) Environment"
}

function kvs {
    (Get-Process devenv -ErrorAction SilentlyContinue) | % {pskill -t $_.Id}
    (Get-Process msbulid,vbcscompiler -ErrorAction SilentlyContinue) | % {pskill -t $_.Id}
}

function ado {
     $remotes = git remote -v
     $url = $remotes[0].Split()[1]
     Start-Process $url
}

function git-up-all {
    $dirs = Get-ChildItem -Directory;
    foreach($dir in $dirs) {
        Push-Location $dir;
        if (Test-Path -PathType Container .git) {
            Write-Host "Gitting new changes for $dir"
            Write-Host

            ## Stash any changes
            $changes = (& git diff-index --name-only HEAD --) | Out-String
            $stashChanges = ($changes.Length > 0)

            if($stashChanges) {
                Write-Host "Stashing $changes changes"
                & git stash -k -u | Out-Null
            }

            (& git co master) | Out-Null
            (& git up) | Out-Null
            (& git co) | Out-Null

            if($stashChanges) {
                Write-Host "Poping stashed changes"
                (& git stash pop) | Out-Null
            }
        }
        Pop-Location
    }
}

function Test-SitesUp {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('membersite','addmembers')]
        [Sites]$Site,

        [ValidateRange(1,[int]::MaxValue)]
        [int]$Iterations=1,

        [ValidateRange(1, [double]::MaxValue)]
        [double]$Pause=1
    )

    for ($i = 0; $i -lt $Iterations; $i++) {
        $uri = "http://$($domain[$Site])/site.txt"
        $response = Invoke-WebRequest -DisableKeepAlive $uri
        $bytes = $response.RawContentStream.ToArray()
        $content = [system.Text.Encoding]::Unicode.GetString($bytes).Trim("﻿")
        Write-Host $content
        Start-Sleep -Seconds $Pause
    }
}

function Add-VpnRoutes {
    Start-Process -FilePath "$((which route.exe).Source)" -Verb runas -ArgumentList "-P add 172.16.0.0 mask 255.255.0.0 10.10.16.254"
    Start-Process -FilePath "$((which route.exe).Source)" -Verb runas -ArgumentList "-P add 10.0.0.0 mask 255.0.0.0 10.10.16.254"
}
function Remove-VpnRoutes {
    Start-Process -FilePath "$((which route.exe).Source)" -Verb runas -ArgumentList "delete 172.16.0.0"
    Start-Process -FilePath "$((which route.exe).Source)" -Verb runas -ArgumentList "delete 10.0.0.0"
}

# Clean ASP
function Clean-AspTemp {
    # ASP Temp
    $directoriesToClean = @();
    $tempDir = Get-ChildItem C:\Windows\Microsoft.NET -Recurse -Directory -Filter "Temporary ASP.NET*"
    $directoriesToClean += $tempDir.FullName

    $tempDir = Get-ChildItem "$($env:LOCALAPPDATA)\Temp\Temporary ASP.NET*"
    $directoriesToClean += $tempDir.FullName


    $tempDir = Get-ChildItem "$($env:USERPROFILE)\Local Settings\Temp\Temporary ASP.NET*"
    $directoriesToClean += $tempDir.FullName

    # Visual Studio Website Cache
    $directoriesToClean += "$($env:LOCALAPPDATA)\Microsoft\WebsiteCache"

    # Assembly Cache (NOT GAC)
    $directoriesToClean += "$($env:LOCALAPPDATA)\assembly\dl3"

    # Visual Studio Backups
    $vsbackups = Get-ChildItem "$([Environment]::GetFolderPath("MyDocuments"))\Visual Studio *\Backup Files"
    if ($null -ne $vsbackups) {
        $directoriesToClean += $vsbackups.FullName
    }

    # Visual Project Assemblies
    $vsprojectAssemblies = Get-ChildItem "$($env:LOCALAPPDATA)\Microsoft\VisualStudio\*\ProjectAssemblies"
    if ($null -ne $vsprojectAssemblies) {
        $directoriesToClean += $vsprojectAssemblies.FullName
    }

    foreach( $dir in $directoriesToClean ) {
        Write-Host  "Checking $dir"
        if (Test-Path $dir -PathType Container) {
            Write-Host  "Cleaning $dir"
            rmrf -Path $dir
            mkdir -Path $dir > $null
        }
    }
}

function Measure-Command2 ([ScriptBlock]$Expression, [int]$Samples = 1, [Switch]$Silent, [Switch]$Long) {
<#
.SYNOPSIS
  Runs the given script block and returns the execution duration.
  Discovered on StackOverflow. http://stackoverflow.com/questions/3513650/timing-a-commands-execution-in-powershell

.EXAMPLE
  Measure-Command2 { ping -n 1 google.com }
#>
  $timings = @()
  do {
    $sw = New-Object Diagnostics.Stopwatch
    if ($Silent) {
      $sw.Start()
      $null = & $Expression
      $sw.Stop()
      Write-Host "." -NoNewLine
    }
    else {
      $sw.Start()
      & $Expression
      $sw.Stop()
    }
    $timings += $sw.Elapsed

    $Samples--
  }
  while ($Samples -gt 0)

  Write-Host

  $stats = $timings | Measure-Object -Average -Minimum -Maximum -Property Ticks

  # Print the full timespan if the $Long switch was given.
  if ($Long) {
    Write-Host "Avg: $((New-Object System.TimeSpan $stats.Average).ToString())"
    Write-Host "Min: $((New-Object System.TimeSpan $stats.Minimum).ToString())"
    Write-Host "Max: $((New-Object System.TimeSpan $stats.Maximum).ToString())"
  }
  else {
    # Otherwise just print the milliseconds which is easier to read.
    Write-Host "Avg: $((New-Object System.TimeSpan $stats.Average).TotalMilliseconds)ms"
    Write-Host "Min: $((New-Object System.TimeSpan $stats.Minimum).TotalMilliseconds)ms"
    Write-Host "Max: $((New-Object System.TimeSpan $stats.Maximum).TotalMilliseconds)ms"
  }
}

Set-Alias time Measure-Command2

Add-VsVars

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module-With-Measure "$ChocolateyProfile"
}

Import-Module-With-Measure -Name Terminal-Icons

$GitPromptSettings.EnableStashStatus = $true
#Import-Module posh-git
#Import-Module oh-my-posh
#Set-Theme Paradox
# Set-PoshPrompt -Theme Paradox