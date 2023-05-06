#Requires -PSEdition Core -Version 7.2
Import-Module -Name @(
	'hugoalh.GitHubActionsToolkit',
	'psyml'
) -Scope 'Local'
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
	$Raw -isplit $Delimiter |
		ForEach-Object -Process { $_.Trim() } |
		Where-Object -FilterScript { $_.Length -gt 0 } |
		Write-Output
}
Function Get-InputTable {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][ValidateSet('csv', 'csvm', 'csvs', 'json', 'tsv', 'yaml')][String]$Markup
	)
	$Raw = Get-GitHubActionsInput -Name $Name -EmptyStringAsNull
	If ($Null -ieq $Raw) {
		Write-Output -InputObject @()
		Return
	}
	Try {
		Switch -Exact ($Markup) {
			'csv' {
				ConvertFrom-Csv -InputObject $Raw -Delimiter ',' |
					Write-Output
				Break
			}
			'csvm' {
				[String[]]($Raw -isplit '\r?\n') |
					Where-Object -FilterScript { $_ -imatch '^.+$' } |
					ConvertFrom-CsvM |
					Write-Output
				Break
			}
			'csvs' {
				$Raw |
					Convert-FromCsvSToCsvM |
					ConvertFrom-CsvM |
					Write-Output
				Break
			}
			'json' {
				(ConvertFrom-Json -InputObject $Raw -Depth 100) -as [PSCustomObject[]] |
					Write-Output
				Break
			}
			'tsv' {
				ConvertFrom-Csv -InputObject $Raw -Delimiter "`t" |
					Write-Output
				Break
			}
			'yaml' {
				(ConvertFrom-Yaml -InputObject $Raw) -as [PSCustomObject[]] |
					Write-Output
				Break
			}
		}
	}
	Catch {
		Write-Error -Message "Invalid $Markup table syntax: $_" -ErrorAction 'Stop'
	}
}
Function Test-ElementIsIgnore {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][PSCustomObject]$Element,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Combinations')][String[][]]$Combination,
		[Parameter(Mandatory = $True, Position = 2)][AllowEmptyCollection()][Alias('Ignores')][PSCustomObject[]]$Ignore
	)
	ForEach ($CombinationGroup In $Combination) {
		ForEach ($IgnoreItem In $Ignore) {
			[String[]]$IgnoreItemKeys = $IgnoreItem.PSObject.Properties.Name
			If (
				$IgnoreItemKeys.Count -ne $CombinationGroup.Count -or
				$False -iin (
					$CombinationGroup |
						ForEach-Object -Process { $_ -iin $IgnoreItemKeys }
				)
			) {
				Continue
			}
			[UInt16]$IgnoreMatchCount = 0
			ForEach ($Property In $CombinationGroup) {
				If ($Null -ieq $IgnoreItem.($Property)) {
					Continue
				}
				Try {
					If ($Element.($Property) -imatch $IgnoreItem.($Property)) {
						$IgnoreMatchCount += 1
					}
				}
				Catch {}
			}
			If ($IgnoreMatchCount -ge $ElementKeys.Count) {
				Write-Output -InputObject $True
				Return
			}
		}
	}
	Write-Output -InputObject $False
}
Function Test-StringIsUri {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][Uri]$InputObject
	)
	$Null -ine $InputObject.AbsoluteUri -and $InputObject.Scheme -imatch '^https?$' |
		Write-Output
}
Function Test-StringMatchRegExs {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Item,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][RegEx[]]$Matchers
	)
	ForEach ($Matcher In $Matchers) {
		If ($Item -imatch $Matcher) {
			Write-Output -InputObject $True
			Return
		}
	}
	Write-Output -InputObject $False
}
Export-ModuleMember -Function @(
	'Get-InputBoolean',
	'Get-InputList',
	'Get-InputTable',
	'Test-ElementIsIgnore',
	'Test-StringIsUri',
	'Test-StringMatchRegExs'
)
