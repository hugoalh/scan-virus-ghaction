Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'github-actions-step-summary.psm1') -Scope 'Local'
function Format-InputList {
	[CmdletBinding()][OutputType([string[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()][string]$InputObject,
		[Parameter(Mandatory = $true, Position = 1)][string]$Delimiter
	)
	return [string[]]($InputObject -split $Delimiter) | ForEach-Object -Process {
		return $_.Trim()
	} | Where-Object -FilterScript {
		return ($_.Length -gt 0)
	} | Sort-Object -Unique -CaseSensitive
}
function Get-Input {
	[CmdletBinding()][OutputType([string])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Name
	)
	$Result = Get-GitHubActionsInput -Name $Name -Trim
	if ($null -eq $Result) {
		return Write-TeeFail -Message "Input ``$Name`` is not defined!"
	}
	return $Result
}
function Optimize-PSFormatDisplay {
	[CmdletBinding()][OutputType([string])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	return $InputObject -replace '^(?:\r?\n)+|(?:\r?\n)+$', ''
}
function Test-StringIsURL {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	try {
		$URIObject = $InputObject -as [System.URI]
		return (($null -ne $URIObject.AbsoluteURI) -and ($InputObject -match '^https?:\/\/'))
	} catch {
		return $false
	}
}
function Write-OptimizePSFormatDisplay {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	[string]$OutputObject = Optimize-PSFormatDisplay -InputObject $InputObject
	if ($OutputObject.Length -gt 0) {
		return Write-Host -Object $OutputObject
	}
	return
}
function Write-TeeFail {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Content')][string]$Message
	)
	Set-StepSummaryAppendPlaceholder -Placeholder 'annotations.errors.item' -Value $Message
	Optimize-StepSummary
	return Write-GitHubActionsFail -Message $Message
}
Export-ModuleMember -Function @(
	'Format-InputList',
	'Optimize-PSFormatDisplay',
	'Test-StringIsURL',
	'Write-OptimizePSFormatDisplay',
	'Write-TeeFail'
)
