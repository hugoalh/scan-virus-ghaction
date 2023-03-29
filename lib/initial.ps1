#Requires -PSEdition Core -Version 7.3
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name (
	@(
		'assets',
		'ware-meta'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Write-Host -Object 'List ware meta.'
Get-WareMeta
Write-Host -Object 'Update ClamAV via FreshClam.'
freshclam --verbose
Write-Host -Object 'Import assets.'
Import-Assets -Initial
Write-Host -Object 'Tweak Git.'
Invoke-Expression -Command "git config --global --add `"safe.directory`" `"*`""
git config --global --list
