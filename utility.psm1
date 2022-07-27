Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Function ConvertFrom-Csvm {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String[]]$InputObject
	)
	Return ($InputObject | ForEach-Object -Process {
		[Hashtable]$Condition = @{}
		ForEach ($Column In (Convert-FromCsvsToCsvm -InputObject $_ -Delimiter ',')) {
			If ($Column -imatch '=') {
				[String[]]$ColumnRaw = $Column -isplit '='
				$Condition[$ColumnRaw[0]] = ($ColumnRaw | Select-Object -SkipIndex 0) -join '='
			} Else {
				Throw "Invalid table syntax"
			}
		}
		Return [PSCustomObject]$Condition
	})
}
Function Convert-FromCsvsToCsvm {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject,
		[Parameter(Position = 1)][Char]$Delimiter = ';'
	)
	If ($InputObject -imatch $Delimiter) {
		[String[]]$Result = @()
		ForEach ($Item In [PSCustomObject[]](ConvertFrom-Csv -InputObject $InputObject -Delimiter $Delimiter -Header (@(0..($Matches.Count)) | ForEach-Object -Process {
			Return ((New-Guid).Guid -ireplace '-', '')
		}))) {
			$Result += $Item.PSObject.Properties.Value
		}
		Return $Result
	} Else {
		Return @($InputObject)
	}
}
Function Format-InputList {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$InputObject,
		[Parameter(Mandatory = $True, Position = 1)][RegEx]$Delimiter
	)
	Return [String[]]($InputObject -isplit $Delimiter) | ForEach-Object -Process {
		Return $_.Trim()
	} | Where-Object -FilterScript {
		Return ($_.Length -igt 0)
	} | Sort-Object -Unique -CaseSensitive
}
Function Format-InputTable {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][ValidateSet('csv', 'csvm', 'csvs', 'tsv', 'yaml')][String]$Type,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Input', 'Object')][String]$InputObject
	)
	Switch ($Type) {
		'csv' {
			Return (ConvertFrom-Csv -InputObject $InputObject -Delimiter ',')
		}
		'csvm' {

		}
		'csvs' {

		}
		'tsv' {

		}
		'yaml' {

		}
	}
}
Function Get-InputBoolean {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name
	)
	Return [Boolean]::Parse((Get-GitHubActionsInput -Name $Name -Mandatory -EmptyStringAsNull -Trim))
}
Function Get-InputList {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][RegEx]$Delimiter
	)
	$Raw = Get-GitHubActionsInput -Name $Name -EmptyStringAsNull
	If ($Null -ieq $Raw) {
		Return @()
	}
	Return (Format-InputList -InputObject $Raw -Delimiter $Delimiter)
}
Function Optimize-PSFormatDisplay {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$InputObject
	)
	Return ($InputObject -ireplace '^(?:\r?\n)+|(?:\r?\n)+$', '')
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
	Write-Host -Object "$($PSStyle.Bold)$($Name):$($PSStyle.BoldOff) $Value"
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
	'Get-InputBoolean',
	'Get-InputList',
	'Optimize-PSFormatDisplay',
	'Test-StringIsUrl',
	'Write-NameValue',
	'Write-OptimizePSFormatDisplay'
)
