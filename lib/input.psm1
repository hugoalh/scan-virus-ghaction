#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name @(
	'hugoalh.GitHubActionsToolkit',
	'psyml'
) -Scope 'Local'
Function ConvertFrom-CsvM {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String[]]$InputObject
	)
	$InputObject |
		ForEach-Object -Process { [PSCustomObject](
			[String[]](Convert-FromCsvSToCsvM -InputObject $_ -Delimiter ',') |
				Join-String -Separator "`n" |
				ConvertFrom-StringData
		) } |
		Write-Output
}
Function Convert-FromCsvSToCsvM {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject,
		[Parameter(Position = 1)][Char]$Delimiter = ';'
	)
	If ($InputObject -inotmatch $Delimiter) {
		Write-Output -InputObject $InputObject
		Return
	}
	[String[]]$Result = @()
	ForEach ($Item In [PSCustomObject[]](ConvertFrom-Csv -InputObject $InputObject -Delimiter $Delimiter -Header @(0..($Matches.Count)))) {
		$Result += $Item.PSObject.Properties.Value
	}
	Write-Output -InputObject $Result
}
Function Format-InputList {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyString()][Alias('Input', 'Object')][String]$InputObject,
		[Parameter(Mandatory = $True, Position = 1)][RegEx]$Delimiter
	)
	$InputObject -isplit $Delimiter |
		ForEach-Object -Process { $_.Trim() } |
		Where-Object -FilterScript { $_.Length -igt 0 } |
		Write-Output
}
Function Format-InputTable {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][ValidateSet('csv', 'csv-m', 'csv-s', 'tsv', 'yaml')][String]$Markup,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Input', 'Object')][String]$InputObject
	)
	Try {
		Switch -Exact ($Markup) {
			'csv' {
				ConvertFrom-Csv -InputObject $InputObject -Delimiter ',' |
					Write-Output
				Break
			}
			'csv-m' {
				[String[]]($InputObject -isplit '\r?\n') |
					Where-Object -FilterScript { $_ -imatch '^.+$' } |
					ConvertFrom-CsvM |
					Write-Output
				Break
			}
			'csv-s' {
				$InputObject |
					Convert-FromCsvSToCsvM |
					ConvertFrom-CsvM |
					Write-Output
				Break
			}
			'tsv' {
				ConvertFrom-Csv -InputObject $InputObject -Delimiter "`t" |
					Write-Output
				Break
			}
			'yaml' {
				ConvertFrom-Yaml -InputObject $InputObject |
					Write-Output
				Break
			}
		}
	}
	Catch {
		Write-GitHubActionsFail -Message @"
Invalid ``$Markup`` table syntax!
$_
"@
		Exit 1
	}
}
Function Get-InputBoolean {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name
	)
	[Boolean]::Parse((Get-GitHubActionsInput -Name $Name -Mandatory -EmptyStringAsNull -Trim)) |
		Write-Output
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
		Write-Output -InputObject @()
		Return
	}
	Format-InputList -InputObject $Raw -Delimiter $Delimiter |
		Write-Output
}
Function Get-InputTable {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][ValidateSet('csv', 'csv-m', 'csv-s', 'tsv', 'yaml')][String]$Type
	)
	$Raw = Get-GitHubActionsInput -Name $Name -EmptyStringAsNull
	If ($Null -ieq $Raw) {
		Write-Output -InputObject @()
		Return
	}
	Format-InputTable -Type $Type -InputObject $Raw |
		Write-Output
}
Export-ModuleMember -Function @(
	'ConvertFrom-CsvM',
	'Convert-FromCsvSToCsvM',
	'Format-InputList',
	'Format-InputTable',
	'Get-InputBoolean',
	'Get-InputList',
	'Get-InputTable'
)
