Import-Module posh-git

###########################################################################
# Define aliases
###########################################################################
$aliasList = @{
    'Out-Clipboard'="$env:SystemRoot\system32\clip.exe";
    npp="C:\Program Files\Notepad++\notepad++.exe";
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
function rmrf { Remove-Item -Recurse -Force $args }
function sln { Invoke-Item *.sln }
function st  { & 'C:\Program Files (x86)\Atlassian\SourceTree\SourceTree.exe' -f .\ -status }
function tail { Get-Content -Wait $args }
function tail-last { gci * | sort LastWriteTime | select -last 1 | Get-Content -Wait }
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

# Clean ASP
function Clean-AspTemp {
    # ASP Temp
    $directoriesToClean = Get-ChildItem C:\Windows\Microsoft.NET -Recurse -Directory -Filter "Temporary ASP.NET*"
    $directoriesToClean = $directoriesToClean.FullName

    # Visual Studio Website Cache
    $directoriesToClean += "$($env:LOCALAPPDATA)\Microsoft\WebsiteCache"

    # Assembly Cache (NOT GAC)
    $directoriesToClean += "$($env:LOCALAPPDATA)\assembly\dl3"

    # Visual Studio Backups
    $vsbackups = Get-ChildItem "$([Environment]::GetFolderPath("MyDocuments"))\Visual Studio *\Backup Files"
    $directoriesToClean += $vsbackups.FullName

    # Visual Project Assemblies
    $vsprojectAssemblies = Get-ChildItem "$($env:LOCALAPPDATA)\Microsoft\VisualStudio\*\ProjectAssemblies"
    $directoriesToClean += $vsprojectAssemblies.FullName

    foreach( $dir in $directoriesToClean ) {
        Write-Host  "Cleaning $dir"
        rmrf  "$dir\*"
    }
}

Add-VsVars

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
