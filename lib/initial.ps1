#Requires -PSEdition Core
#Requires -Version 7.3
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name (
	@(
		'ware-meta'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Get-WareMeta
