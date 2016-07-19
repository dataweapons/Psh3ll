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
