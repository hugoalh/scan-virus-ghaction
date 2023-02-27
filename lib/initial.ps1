#Requires -PSEdition Core
#Requires -Version 7.3
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'assets',
		'ware'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Enter-GitHubActionsLogGroup -Title 'Import assets.'
Import-Assets -Initial
Exit-GitHubActionsLogGroup
Get-HardwareMeta
Get-SoftwareMeta
Enter-GitHubActionsLogGroup -Title 'Tweak console.'
Add-Content -LiteralPath $PROFILE.AllUsersAllHosts -Value @'
$Host.UI.RawUI.BufferSize.Width = 160
$Host.UI.RawUI.MaxPhysicalWindowSize.Width = 160
$Host.UI.RawUI.MaxWindowSize.Width = 160
$Host.UI.RawUI.WindowSize.Width = 120
'@ -Confirm:$False -Encoding 'UTF8NoBOM'
Exit-GitHubActionsLogGroup
