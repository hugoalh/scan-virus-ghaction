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
function Test-InputFilter {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Target,
		[string[]]$Excludes = @(),
		[string[]]$Includes = @()
	)
	foreach ($Include in $Includes) {
		if ($Target -match $Include) {
			return $true
		}
	}
	if ($Excludes.Count -gt 0) {
		foreach ($Exclude in $Excludes) {
			if ($Target -match $Exclude) {
				return $false
			}
		}
		return $true
	}
	return $false
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
function Write-ErrorTee {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Content')][string]$Message
	)
	Set-StepSummaryAppendPlaceholder -Placeholder 'annotations.item' -Value "- **❌ Error:** $Message"
	return Write-GitHubActionsError -Message $Message
}
function Write-FailTee {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Content')][string]$Message
	)
	Set-StepSummaryAppendPlaceholder -Placeholder 'annotations.item' -Value "- **🛑 Fail:** $Message"
	Set-StepSummaryStatus -Message 'Fail (by issue(s))'
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
function Write-NoticeTee {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Content')][string]$Message
	)
	Set-StepSummaryAppendPlaceholder -Placeholder 'annotations.item' -Value "- **ℹ Notice:** $Message"
	return Write-GitHubActionsNotice -Message $Message
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
function Write-WarningTee {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('Content')][string]$Message
	)
	Set-StepSummaryAppendPlaceholder -Placeholder 'annotations.item' -Value "- **⚠ Warning:** $Message"
	return Write-GitHubActionsWarning -Message $Message
}
Export-ModuleMember -Function @(
	'Format-InputList',
	'Get-Input',
	'Get-InputFilter',
	'Get-InputList',
	'Optimize-PSFormatDisplay',
	'Test-InputFilter',
	'Test-StringIsUrl',
	'Write-ErrorTee',
	'Write-FailTee',
	'Write-NameValue',
	'Write-NoticeTee',
	'Write-OptimizePSFormatDisplay',
	'Write-WarningTee'
)
