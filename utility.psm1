Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'github-actions-step-summary.psm1') -Scope 'Local'
Function Format-InputList {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyString()][String]$InputObject,
		[Parameter(Mandatory = $True, Position = 1)][String]$Delimiter
	)
	Return [String[]]($InputObject -isplit $Delimiter) | ForEach-Object -Process {
		Return $_.Trim()
	} | Where-Object -FilterScript {
		Return ($_.Length -igt 0)
	} | Sort-Object -Unique -CaseSensitive
}
Function Get-Input {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name,
		[Switch]$AllowEmptyValue,
		[Switch]$BooleanType
	)
	$Result = Get-GitHubActionsInput -Name $Name -Trim
	If ($AllowEmptyValue) {
		If ($Null -ieq $Result) {
			$Result = ''
		}
		Return $Result
	}
	If (
		$Null -ieq $Result -or
		$Result.Length -ieq 0
	) {
		Return Write-FailTee -Message "Input ``$Name`` is not defined!"
	}
	If ($BooleanType -and $Result -inotin @([Boolean]::FalseString, [Boolean]::TrueString)) {
		Return Write-FailTee -Message "Input ``$Name`` must be type of boolean!"
	}
	Return $Result
}
Function Get-InputFilter {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][String]$Delimiter
	)
	[String[]]$Result = Get-InputList -Name $Name -Delimiter $Delimiter
	[String[]]$FilterInvalid = @()
	[Hashtable]$OutputObject = @{
		Exclude = @()
		Include = @()
	}
	ForEach ($Item In $Result) {
		If ($Item.StartsWith('-')) {
			$OutputObject.Exclude += $Item.Substring(1)
		} ElseIf ($Item.StartsWith('+')) {
			$OutputObject.Include += $Item.Substring(1)
		} Else {
			$FilterInvalid += $Item
		}
	}
	If ($FilterInvalid.Count -gt 0) {
		Write-GitHubActionsWarning -Message "Input ``$Name`` contains $($FilterInvalid.Count) invalid filter$(($FilterInvalid.Count -eq 1) ? '' : 's'): ``$($FilterInvalid -join '`, `')``"
	}
	Return $OutputObject
}
Function Get-InputList {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][String]$Delimiter
	)
	Return Format-InputList -InputObject (Get-Input -Name $Name -AllowEmptyValue) -Delimiter $Delimiter
}
Function Optimize-PSFormatDisplay {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$InputObject
	)
	Return ($InputObject -ireplace '^(?:\r?\n)+|(?:\r?\n)+$', '')
}
Function Test-InputFilter {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Target,
		[String[]]$Exclude = @(),
		[String[]]$Include = @(),
		[Switch]$IncludeUseLogicAnd
	)
	If ($Exclude.Count -ieq 0 -and $Include.Count -ieq 0) {
		Return $True
	}
	[UInt32]$IsExclude = 0
	[UInt32]$IsInclude = 0
	ForEach ($Item In $Exclude) {
		If ($Target -imatch $Item) {
			$IsExclude += 1
		}
	}
	ForEach ($Item In $Include) {
		If ($Target -imatch $Item) {
			$IsInclude += 1
		}
	}
	If ($Exclude.Count -ieq 0) {
		Return ($IncludeUseLogicAnd ? ($Include.Count -ieq $IsInclude) : ($IsInclude -igt 0))
	}
	If ($Include.Count -ieq 0) {
		Return ($IsExclude -ieq 0)
	}
	Return ($IsInclude -igt 0)
}
Function Test-StringIsUri {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][Uri]$InputObject
	)
	Return ($Null -ine $InputObject.AbsoluteURI -and $InputObject.Scheme -imatch '^https?$')
}
Function Write-NameValue {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Key')][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyString()][String]$Value
	)
	Write-Host -Object "$($PSStyle.Bold)$($Name):$($PSStyle.Reset) $Value"
}
Function Write-OptimizePSFormatDisplay {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	[String]$OutputObject = Optimize-PSFormatDisplay -InputObject $InputObject
	If ($OutputObject.Length -igt 0) {
		Write-Host -Object $OutputObject
	}
}
Export-ModuleMember -Function @(
	'Format-InputList',
	'Get-Input',
	'Get-InputFilter',
	'Get-InputList',
	'Optimize-PSFormatDisplay',
	'Test-InputFilter',
	'Test-StringIsUrl',
	'Write-NameValue',
	'Write-OptimizePSFormatDisplay'
)
