#How to connect to Office 365 Cloud Services using PowerShell

#Capture administrative credential for future connections.
$credential = get-credential

#Imports the installed Azure Active Directory module.
Import-Module MSOnline

#Establishes Online Services connection to Office 365 Management Layer.
Connect-MsolService -Credential $credential

#Imports the installed Skype for Business Online services module.
Import-Module LyncOnlineConnector

#Create a Skype for Business Powershell session using defined credential.
$lyncSession = New-CsOnlineSession -Credential $credential

#Imports Skype for Business session commands into your local Windows PowerShell session.
Import-PSSession $lyncSession

#Imports SharePoint Online session commands into your local Windows PowerShell session.
Import-Module Microsoft.Online.Sharepoint.PowerShell

#This connects you to your SharePoint Online services. Substitute the ‘contoso’ portion of the URL with the name of your SharePoint Online tenant.
Connect-SPOService -url https://contoso-admin.sharepoint.com -Credential $credential

#Creates an Exchange Online session using defined credential.
$ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" -Credential $credential -Authentication "Basic" -AllowRedirection

#This imports the Office 365 session into your active Shell.
Import-PSSession $ExchangeSession
