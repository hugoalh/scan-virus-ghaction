#!/usr/bin/env pwsh
#Requires -PSEdition Core -Version 7.3
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Write-GitHubActionsNotice -Message 'Hello, world!'
