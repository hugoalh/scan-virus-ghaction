#!/usr/bin/env pwsh
#Requires -PSEdition Core -Version 7.2
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
Update-ClamAV -Build
Import-Assets
Write-Host -Object 'Tweak Git.'
Invoke-Expression -Command "git config --global --add `"safe.directory`" `"*`"" |
	Write-Verbose -Verbose
git config --global --list |
	Write-Verbose -Verbose
