
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$snapins = @(
    "Quest.ActiveRoles.ADManagement",
    "PowerGadgets",
    "VMware.VimAutomation.Core",
    "NetCmdlets"
)

$snapins | ForEach-Object { 
    if ( Get-PSSnapin -Registered $_ -ErrorAction SilentlyContinue )
       {
           Add-PSSnapin $_
       }
    }
# create if necessary.
$modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
    if(!(Test-Path $modulePath))
       {
           New-Item -Path $modulePath -ItemType Directory
       }

# load all script modules available to us
Get-Module -ListAvailable |
? { $_.ModuleType -eq "Script" } |
 Import-Module


$filePath = $PROFILE.CurrentUserCurrentHost
    if(!(Test-Path $filePath))
       {
           New-Item -Path $filePath -ItemType File
       }

# function loader 
Resolve-Path $here\functions\*.ps1 | 
? { -not ($_.ProviderPath.Contains(".Tests.")) } |
% { . $_.ProviderPath }

# inline functions, aliases and variables
function which($name) { Get-Command $name | Select-Object Definition }
function rm-rf($item) { Remove-Item $item -Recurse -Force }
function touch($file) { "" | Out-File $file -Encoding ASCII }
Set-Alias g gvim
$TransientScriptDir = "$here\scripts"
$UserBinDir = "$($env:UserProfile)\bin"
$SysBinDir = "D:\bin"

# PATH update
#
# creates paths to every subdirectory of userprofile\bin
# adds a transient script dir that I use for experiments
$paths = @("$($env:Path)", $TransientScriptDir)
gci $UserBinDir | % { $paths += $_.FullName }
$env:Path = [String]::Join(";", $paths) 
