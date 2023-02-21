#Requires -PSEdition Core
#Requires -Version 7.3
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name (
	@(
		'assets',
		'ware'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Import-Assets -IsInitial
Get-HardwareMeta
Get-SoftwareMeta
