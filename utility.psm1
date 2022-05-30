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
		[Parameter(Mandatory = $true, Position = 0)][string]$Name,
		[switch]$AllowEmptyValue,
		[switch]$BooleanType
	)
	$Result = Get-GitHubActionsInput -Name $Name -Trim
	if ($AllowEmptyValue) {
		if ($null -eq $Result) {
			$Result = ''
		}
		return $Result
	}
	if (
		$null -eq $Result -or
		$Result.Length -eq 0
	) {
		return Write-FailTee -Message "Input ``$Name`` is not defined!"
	}
	if ($BooleanType -and $Result -inotin @([bool]::FalseString, [bool]::TrueString)) {
		return Write-FailTee -Message "Input ``$Name`` must be type of boolean!"
	}
	return $Result
}
function Get-InputFilter {
	[CmdletBinding()][OutputType([hashtable])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Name,
		[Parameter(Mandatory = $true, Position = 1)][string]$Delimiter
	)
	[string[]]$Result = Get-InputList -Name $Name -Delimiter $Delimiter
	[string[]]$FilterInvalid = @()
	[hashtable]$OutputObject = @{
		Exclude = @()
		Include = @()
	}
	$Result | ForEach-Object -Process {
		if ($_.StartsWith('-')) {
			$OutputObject.Exclude += $_.Substring(1)
		} elseif ($_.StartsWith('+')) {
			$OutputObject.Include += $_.Substring(1)
		} else {
			$FilterInvalid += $_
		}
	}
	if ($FilterInvalid.Count -gt 0) {
		Write-GitHubActionsWarning -Message "Input ``$Name`` contains $($FilterInvalid.Count) invalid filter$(($FilterInvalid.Count -eq 1) ? '' : 's'): ``$($FilterInvalid -join '`, `')``"
	}
	return $OutputObject
}
function Get-InputList {
	[CmdletBinding()][OutputType([string[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Name,
		[Parameter(Mandatory = $true, Position = 1)][string]$Delimiter
	)
	return Format-InputList -InputObject (Get-Input -Name $Name -AllowEmptyValue) -Delimiter $Delimiter
}
function Optimize-PSFormatDisplay {
	[CmdletBinding()][OutputType([string])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	return $InputObject -replace '^(?:\r?\n)+|(?:\r?\n)+$', ''
}
function Test-StringIsUrl {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	try {
		$URIObject = $InputObject -as [System.URI]
		return ($null -ne $URIObject.AbsoluteURI -and $InputObject -match '^https?:\/\/')
	} catch {
		return $false
	}
}
function Write-FailTee {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Content')][string]$Message
	)
	Set-StepSummaryAppendPlaceholder -Placeholder 'annotations.errors.item' -Value $Message
	Set-StepSummaryStatus -Message 'Fail by issue(s)'
	Optimize-StepSummary
	return Write-GitHubActionsFail -Message $Message
}
function Write-NameValue {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Key')][string]$Name,
		[Parameter(Mandatory = $true, Position = 1)][AllowEmptyString()][string]$Value
	)
	return Write-Host -Object "$($PSStyle.Bold)$($Name):$($PSStyle.Reset) $Value"
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
Export-ModuleMember -Function @(
	'Format-InputList',
	'Get-Input',
	'Get-InputFilter',
	'Get-InputList',
	'Optimize-PSFormatDisplay',
	'Test-StringIsUrl',
	'Write-FailTee',
	'Write-NameValue',
	'Write-OptimizePSFormatDisplay'
)
