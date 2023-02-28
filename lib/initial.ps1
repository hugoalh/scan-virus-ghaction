#Requires -PSEdition Core
#Requires -Version 7.3
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name (
	@(
		'assets',
		'display',
		'ware'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Get-HardwareMeta
Get-SoftwareMeta
Write-Status -InputObject 'Update ClamAV.'
freshclam --verbose
Write-Status -InputObject 'Import assets.'
Import-Assets -Initial
Write-Status -InputObject 'Tweak Git.'
git config --global --add 'safe.directory' '*'
git config --global --list
