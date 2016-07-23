trap { Write-Warning ($_.ScriptStackTrace | Out-String) }

# This timer is used by Trace-Message, I want to start it immediately
$Script:TraceVerboseTimer = New-Object System.Diagnostics.Stopwatch
$Script:TraceVerboseTimer.Start()

# PS5 introduced PSReadLine, which chokes in non-console shells, so I snuff it.
try { $NOCONSOLE = $FALSE; [System.Console]::Clear() } catch { $NOCONSOLE = $TRUE }

# If your PC doesn't have this set already, someone could tamper with this script...
# but at least now, they can't tamper with any of the modules/scripts that I auto-load!
Set-ExecutionPolicy AllSigned Process

# Ok, now import environment so we have PSProcessElevated and Trace-Message
# The others will get loaded automatically, but it's faster to load them explicitly
Import-Module $PSScriptRoot\Modules\Environment, Microsoft.PowerShell.Management, Microsoft.PowerShell.Security, Microsoft.PowerShell.Utility

# Check SHIFT state ASAP at startup so I can use that to control verbosity :)
Add-Type -Assembly PresentationCore, WindowsBase
try {
    $global:SHIFTED = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -OR
                  [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
} catch {
    $global:SHIFTED = $false
}
# If SHIFT is pressed, use verbose output from here on
if($SHIFTED) { $VerbosePreference = "Continue" }

##  Fix colors before anything gets output.
if($Host.Name -eq "ConsoleHost") {
    $Host.PrivateData.ErrorForegroundColor    = "DarkRed"
    $Host.PrivateData.WarningForegroundColor  = "DarkYellow"
    $Host.PrivateData.DebugForegroundColor    = "Green"
    $Host.PrivateData.VerboseForegroundColor  = "Cyan"
    $Host.PrivateData.ProgressForegroundColor = "Yellow"
    $Host.PrivateData.ProgressBackgroundColor = "DarkMagenta"
    if($PSProcessElevated) {
        $Host.UI.RawUI.BackgroundColor = "DarkGray"
        Clear-Host # To get rid of the weird trim
    }
} elseif($Host.Name -eq "Windows PowerShell ISE Host") {
    $Host.PrivateData.ErrorForegroundColor    = "DarkRed"
    $Host.PrivateData.WarningForegroundColor  = "Gold"
    $Host.PrivateData.DebugForegroundColor    = "Green"
    $Host.PrivateData.VerboseForegroundColor  = "Cyan"
    if($PSProcessElevated) {
        $Host.UI.RawUI.BackgroundColor = "DarkGray"
        Clear-Host # To get rid of the weird trim
    }
}

# First call to Trace-Message, pass in our TraceTimer that I created at the top to make sure we time EVERYTHING.
Trace-Message "Microsoft.PowerShell.* Modules Imported" -Stopwatch $TraceVerboseTimer

## Set the profile directory first, so we can refer to it from now on.
Set-Variable ProfileDir (Split-Path $MyInvocation.MyCommand.Path -Parent) -Scope Global -Option AllScope, Constant -ErrorAction SilentlyContinue
Set-Variable LiveID (
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups |
        Where-Object { $_.Value -match "^S-1-11-96" }
    ).Translate([System.Security.Principal.NTAccount]).Value  -Scope Global -Option AllScope, Constant -ErrorAction SilentlyContinue
Set-Variable ReReverse @('(?sx) . (?<=(?:.(?=.*$(?<=((.) \1?))))*)', '$2') -Scope Global -Option AllScope, Constant -ErrorAction SilentlyContinue

###################################################################################################
## I add my "Scripts" directory and all of its direct subfolders to my PATH
[string[]]$folders = Get-ChildItem $ProfileDir\Tool[s], $ProfileDir\Utilitie[s], $ProfileDir\Scripts\*,$ProfileDir\Script[s] -ad | % FullName

## Developer tools stuff ...
## I need InstallUtil, MSBuild, and TF (TFS) and they're all in the .Net RuntimeDirectory OR Visual Studio*\Common7\IDE
$folders += [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
## MSBuild is now in 'C:\Program Files (x86)\MSBuild\{version}'
$folders += Set-AliasToFirst -Alias "msbuild" -Path 'C:\Program Files (x86)\MSBuild\*\Bin\MsBuild.exe' -Description "Visual Studio's MsBuild" -Force -Passthru
$folders += Set-AliasToFirst -Alias "merge" -Path "C:\Program*Files*\Perforce\p4merge.exe","C:\Program*Files*\DevTools\Perforce\p4merge.exe" -Description "Perforce" -Force -Passthru
$folders += Set-AliasToFirst -Alias "tf" -Path "C:\Program*Files*\*Visual?Studio*\Common7\IDE\TF.exe", "C:\Program*Files*\DevTools\*Visual?Studio*\Common7\IDE\TF.exe" -Description "Visual Studio" -Force -Passthru
$folders += Set-AliasToFirst -Alias "Python","Python2","py2" -Path "C:\Python2*\python.exe", "D:\Python2*\python.exe" -Description "Python 2.x" -Force -Passthru
$folders += Set-AliasToFirst -Alias "Python3","py3" -Path "C:\Python3*\python.exe", "D:\Python3*\python.exe" -Description "Python 3.x" -Force -Passthru
Set-AliasToFirst -Alias "iis","iisexpress" -Path 'C:\Progra*\IIS*\IISExpress.exe' -Description "Personal Profile Alias"

Trace-Message "Development aliases set"

## I really need to make a "Editor" module for this stuff, maybe make this part of the ModuleBuilder suite?
if(!(Test-Path Env:Editor)) {
   if($Editor = Get-Item 'C:\Progra*\Sublime*\sublime_text.exe','C:\Progra*\*\Sublime*\sublime_text.exe' | Sort VersionInfo.ProductVersion -Desc | Select-Object -First 1) {
      $folders += Split-Path $Editor

      function edit { start $Editor @( $Args + @("-n","-w")) }
      [Environment]::SetEnvironmentVariable("Editor", "'${Env:Editor}' -n -w", "User")
      Trace-Message "Env:Editor set: ${Env:Editor} "
   } else {
      Trace-Message -AsWarning "Sublime Text (edit command) is not available"
   }
}

$ENV:PATH = Select-UniquePath $folders ${Env:Path}
Trace-Message "PATH Updated"

###################################################################################################
## Make sure we have my Projects folder in the module path
$Env:PSModulePath = Select-UniquePath "$ProfileDir\Modules",(Get-SpecialFolder *Modules -Value),${Env:PSModulePath},"${Home}\Projects\Modules"
Trace-Message "PSModulePath Updated "

## I have a few additional custom type and format data items which take prescedence over anyone else's
Update-TypeData   -PrependPath "$ProfileDir\Formats\Types.ps1xml"
Trace-Message "Type Data Updated"

Update-FormatData -PrependPath "$ProfileDir\Formats\Formats.ps1xml"
Trace-Message "Format Data Updated"

## And a couple of functions that can't be saved as script files, and aren't worth modularizing
function Reset-Module ($ModuleName) { rmo $ModuleName; ipmo $ModuleName -force -pass | ft Name, Version, Path -Auto }

## The qq shortcut for quick quotes
function qq {param([Parameter(ValueFromRemainingArguments=$true)][string[]]$q)$q}

# Being from profiledir.
if($ProfileDir -ne (Get-Location)) {
   Push-Location $ProfileDir
}

# use PSDrives
New-PSDrive Documents FileSystem (Get-SpecialFolder MyDocuments -Value)

###################################################################################################
## prompt function.
if($Host.Name -ne "Package Manager Host") {
  . Set-Prompt -Clean
  Trace-Message "Prompt fixed"
}

if($Host.Name -eq "ConsoleHost" -and !$NOCONSOLE) {

    if(-not (Get-Module PSReadLine)) { Import-Module PSReadLine }

    ## If you have history to reload, you must do that BEFORE you import PSReadLine
    ## That way, the "up arrow" navigation works on the previous session's commands
    function Set-PSReadLineMyWay {
        param(
            $BackgroundColor = $(if($PSProcessElevated) { "DarkGray" } else { "Black" } )
        )
        $Host.UI.RawUI.BackgroundColor = $BackgroundColor
        $Host.UI.RawUI.ForegroundColor = "Gray"

        Set-PSReadlineOption -TokenKind Keyword -ForegroundColor Yellow -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind String -ForegroundColor Green -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind Operator -ForegroundColor DarkGreen -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind Variable -ForegroundColor DarkMagenta -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind Command -ForegroundColor DarkYellow -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind Parameter -ForegroundColor DarkCyan -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind Type -ForegroundColor Blue -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind Number -ForegroundColor Red -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind Member -ForegroundColor DarkRed -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind None -ForegroundColor White -BackgroundColor $BackgroundColor
        Set-PSReadlineOption -TokenKind Comment -ForegroundColor Black -BackgroundColor DarkGray

        Set-PSReadlineOption -EmphasisForegroundColor White -EmphasisBackgroundColor $BackgroundColor `
                             -ContinuationPromptForegroundColor DarkBlue -ContinuationPromptBackgroundColor $BackgroundColor `
                             -ContinuationPrompt (([char]183) + "  ")
    }

    Set-PSReadLineMyWay
    Set-PSReadlineKeyHandler -Key "Ctrl+Shift+R" -Functio ForwardSearchHistory
    Set-PSReadlineKeyHandler -Key "Ctrl+R" -Functio ReverseSearchHistory

    Set-PSReadlineKeyHandler Ctrl+M SetMark
    Set-PSReadlineKeyHandler Ctrl+Shift+M ExchangePointAndMark

    Set-PSReadlineKeyHandler Ctrl+K KillLine
    Set-PSReadlineKeyHandler Ctrl+I Yank
    Trace-Message "PSReadLine fixed"
} else {
    Remove-Module PSReadLine -ErrorAction SilentlyContinue
    Trace-Message "PSReadLine skipped!"
}

## Fix em-dash screwing up our commands...
$ExecutionContext.SessionState.InvokeCommand.CommandNotFoundAction = {
    param( $CommandName, $CommandLookupEventArgs )
    if($CommandName.Contains([char]8211)) {
        $CommandLookupEventArgs.Command = Get-Command ( $CommandName -replace ([char]8211), ([char]45) ) -ErrorAction Ignore
    }
}

Trace-Message "Profile Finished!" -KillTimer

## And finally, relax the code signing restriction so we can actually get work done
Set-ExecutionPolicy RemoteSigned Process
