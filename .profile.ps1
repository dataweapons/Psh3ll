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

$modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
    if(!(Test-Path $modulePath))
       {
           New-Item -Path $modulePath -ItemType Directory
       }

$filePath = $PROFILE.CurrentUserCurrentHost
    if(!(Test-Path $filePath))
       {
           New-Item -Path $filePath -ItemType File
       }
