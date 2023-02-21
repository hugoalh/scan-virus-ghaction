#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name @(
	'hugoalh.GitHubActionsToolkit',
	'psyml'
) -Scope 'Local'
[String[]]$NeedCleanUpFiles = @()
Function Add-NeedCleanUpFile {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$File
	)
	$Script:NeedCleanUpFiles += $File
}
Function ConvertFrom-CsvMultipleLine {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String[]]$InputObject
	)
	$InputObject |
		ForEach-Object -Process { [PSCustomObject](
			[String[]](Convert-FromCsvSingleLineToCsvMultipleLine -InputObject $_ -Delimiter ',') |
				Join-String -Separator "`n" |
				ConvertFrom-StringData
		) } |
		Write-Output
}
Function Convert-FromCsvSingleLineToCsvMultipleLine {
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
		Where-Object -FilterScript { $_ -imatch '^.+$' } |
		Sort-Object -Unique -CaseSensitive |
		Write-Output
}
Function Format-InputTable {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][ValidateSet('csv', 'csv-m', 'csv-s', 'tsv', 'yaml')][String]$Type,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Input', 'Object')][String]$InputObject
	)
	Try {
		Switch -Exact ($Type) {
			'csv' {
				ConvertFrom-Csv -InputObject $InputObject -Delimiter ',' |
					Write-Output
				Break
			}
			'csv-m' {
				[String[]]($InputObject -isplit '\r?\n') |
					Where-Object -FilterScript { $_ -imatch '^.+$' } |
					ConvertFrom-CsvMultipleLine |
					Write-Output
				Break
			}
			'csv-s' {
				$InputObject |
					Convert-FromCsvSingleLineToCsvMultipleLine |
					ConvertFrom-CsvMultipleLine |
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
		Write-GitHubActionsFail -Message "Invalid ``$Type`` table syntax! $_"
		Throw
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
Function Group-Ignores {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyCollection()][Alias('Input', 'Object')][PSCustomObject[]]$InputObject
	)
	[PSCustomObject[]]$OnlyPaths = $InputObject |
		Where-Object -FilterScript {
			[String[]]$Keys = $_.PSObject.Properties.Name
			$Keys.Count -ieq 1 -and $Keys -icontains 'Path' |
				Write-Output
	}
	[PSCustomObject[]]$OnlySessions = $InputObject |
		Where-Object -FilterScript {
			[String[]]$Keys = $_.PSObject.Properties.Name
			$Keys.Count -ieq 1 -and $Keys -icontains 'Session' |
				Write-Output
	}
	[PSCustomObject[]]$Others = $InputObject |
		Where-Object -FilterScript {
			[String[]]$Keys = $_.PSObject.Properties.Name
			!($Keys.Count -ieq 1 -and (
				$Keys -icontains 'Path' -or
				$Keys -icontains 'Session'
			)) |
				Write-Output
	}
	[PSCustomObject]@{
		OnlyPaths = $OnlyPaths
		OnlySessions = $OnlySessions
		Others = $Others
	} |
		Write-Output
}
Function Optimize-PSFormatDisplay {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyString()][Alias('Input', 'Object')][String]$InputObject
	)
	$InputObject -ireplace '^(?:\r?\n)+|(?:\r?\n)+$', '' |
		Write-Output
}
Function Remove-NeedCleanUpFiles {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Remove-Item -LiteralPath $NeedCleanUpFiles -Force:$True -Confirm:$False
	$Script:NeedCleanUpFiles = @()
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
		[Parameter(Mandatory = $true, Position = 0)][String]$Item,
		[Parameter(Mandatory = $true, Position = 1)][AllowEmptyCollection()][RegEx[]]$Matchers
	)
	ForEach ($Matcher in $Matchers) {
		If ($Item -imatch $Matcher) {
			Write-Output -InputObject $True
			Return
		}
	}
	Write-Output -InputObject $False
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
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyString()][Alias('Input', 'Object')][String]$InputObject
	)
	[String]$Result = Optimize-PSFormatDisplay -InputObject $InputObject
	If ($Result.Length -igt 0) {
		Write-Host -Object $Result
	}
}
Export-ModuleMember -Function @(
	'Add-NeedCleanUpFile',
	'ConvertFrom-CsvMultipleLine',
	'Convert-FromCsvSingleLineToCsvMultipleLine',
	'Format-InputList',
	'Format-InputTable',
	'Get-InputBoolean',
	'Get-InputList',
	'Get-InputTable',
	'Group-Ignores',
	'Optimize-PSFormatDisplay',
	'Remove-NeedCleanUpFiles',
	'Test-StringIsUri',
	'Test-StringMatchRegExs',
	'Write-NameValue',
	'Write-OptimizePSFormatDisplay'
)
