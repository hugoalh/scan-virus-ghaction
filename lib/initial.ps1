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
Enter-GitHubActionsLogGroup -Title 'Update ClamAV.'
freshclam --verbose
Exit-GitHubActionsLogGroup
Enter-GitHubActionsLogGroup -Title 'Import assets.'
Import-Assets -Initial
Exit-GitHubActionsLogGroup
Enter-GitHubActionsLogGroup -Title 'Tweak Git.'
git config --global safe.directory *
Exit-GitHubActionsLogGroup
Get-HardwareMeta
Get-SoftwareMeta
