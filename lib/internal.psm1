#Requires -PSEdition Core -Version 7.2
Import-Module -Name @(
	'hugoalh.GitHubActionsToolkit',
	'psyml'
) -Scope 'Local'
Function ConvertFrom-CsvM {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	$InputObject -isplit '\r?\n' |
		ForEach-Object -Process {
			$Null = $_ -imatch ','
			[PSCustomObject](
				(ConvertFrom-Csv -InputObject $_ -Header @(0..($Matches.Count + 1))).PSObject.Properties.Value |
					Join-String -Separator "`n" |
					ConvertFrom-StringData
			) |
				Write-Output
		} |
		Write-Output
}
Function ConvertFrom-CsvS {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	$Null = $InputObject -imatch ';'
	[String]$Raw = (ConvertFrom-Csv -InputObject $InputObject -Delimiter ';' -Header @(0..($Matches.Count + 1))).PSObject.Properties.Value |
		Join-String -Separator "`n"
	ConvertFrom-CsvM -InputObject $Raw |
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
		[Parameter(Mandatory = $True, Position = 1)][ScanVirusInputTableMarkup]$Markup
	)
	$Raw = Get-GitHubActionsInput -Name $Name -EmptyStringAsNull
	If ($Null -ieq $Raw) {
		Write-Output -InputObject @()
		Return
	}
	Try {
		Switch ($Markup.GetHashCode()) {
			([ScanVirusInputTableMarkup]::Csv).GetHashCode() {
				ConvertFrom-Csv -InputObject $Raw -Delimiter ',' |
					Write-Output
				Break
			}
			([ScanVirusInputTableMarkup]::CsvM).GetHashCode() {
				ConvertFrom-CsvM -InputObject $Raw |
					Write-Output
				Break
			}
			([ScanVirusInputTableMarkup]::CsvS).GetHashCode() {
				ConvertFrom-CsvS -InputObject $Raw |
					Write-Output
				Break
			}
			([ScanVirusInputTableMarkup]::Json).GetHashCode() {
				(ConvertFrom-Json -InputObject $Raw -Depth 100) -as [PSCustomObject[]] |
					Write-Output
				Break
			}
			([ScanVirusInputTableMarkup]::Tsv).GetHashCode() {
				ConvertFrom-Csv -InputObject $Raw -Delimiter "`t" |
					Write-Output
				Break
			}
			([ScanVirusInputTableMarkup]::Yaml).GetHashCode() {
				(ConvertFrom-Yaml -InputObject $Raw) -as [PSCustomObject[]] |
					Write-Output
				Break
			}
		}
	}
	Catch {
		Write-GitHubActionsFail -Message "Invalid $($Markup.ToString()) table syntax: $_"
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
	ForEach ($_C In $Combination) {
		ForEach ($_I In $Ignore) {
			[String[]]$IgnoreItemKeys = $_I.PSObject.Properties.Name
			If (
				$IgnoreItemKeys.Count -ne $_C.Count -or
				$False -iin (
					$_C |
						ForEach-Object -Process { $_ -iin $IgnoreItemKeys }
				)
			) {
				Continue
			}
			[UInt64]$IgnoreMatchCount = 0
			ForEach ($Property In $_C) {
				If ($Null -ieq $_I.($Property)) {
					Continue
				}
				Try {
					If ($Element.($Property) -imatch $_I.($Property)) {
						$IgnoreMatchCount += 1
					}
				}
				Catch {}
			}
			If ($IgnoreMatchCount -ge $_C.Count) {
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
Function Test-StringMatchRegEx {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Item,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][Alias('Matchers')][RegEx[]]$Matcher
	)
	ForEach ($_M In $Matcher) {
		If ($Item -imatch $_M) {
			Write-Output -InputObject $True
			Return
		}
	}
	Write-Output -InputObject $False
}
Export-ModuleMember -Function @(
	'Get-InputList',
	'Get-InputTable',
	'Test-ElementIsIgnore',
	'Test-StringIsUri',
	'Test-StringMatchRegEx'
)
