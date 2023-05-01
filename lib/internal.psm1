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
		[Parameter(Mandatory = $True, Position = 1)][ValidateSet('Csv', 'CsvM', 'CsvS', 'Tsv', 'Yaml')][String]$Markup
	)
	$Raw = Get-GitHubActionsInput -Name $Name -EmptyStringAsNull
	If ($Null -ieq $Raw) {
		Write-Output -InputObject @()
		Return
	}
	Try {
		Switch -Exact ($Markup) {
			'Csv' {
				ConvertFrom-Csv -InputObject $Raw -Delimiter ',' |
					Write-Output
				Break
			}
			'CsvM' {
				[String[]]($Raw -isplit '\r?\n') |
					Where-Object -FilterScript { $_ -imatch '^.+$' } |
					ConvertFrom-CsvM |
					Write-Output
				Break
			}
			'CsvS' {
				$Raw |
					Convert-FromCsvSToCsvM |
					ConvertFrom-CsvM |
					Write-Output
				Break
			}
			'Tsv' {
				ConvertFrom-Csv -InputObject $Raw -Delimiter "`t" |
					Write-Output
				Break
			}
			'Yaml' {
				ConvertFrom-Yaml -InputObject $Raw |
					Write-Output
				Break
			}
		}
	}
	Catch {
		Write-Error -Message "Invalid $Markup table syntax: $_" -ErrorAction 'Stop'
	}
}
Function Group-IgnoresElements {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyCollection()][Alias('Input', 'Object')][PSCustomObject[]]$InputObject
	)
	[Hashtable]$Result = @{
		ClamAVPaths = @()
		ClamAVSessions = @()
		Mixes = @()
		Paths = @()
		Rules = @()
		Sessions = @()
		Signatures = @()
		YaraPaths = @()
		YaraSessions = @()
	}
	ForEach ($Item In $InputObject) {
		[String[]]$Keys = $Item.PSObject.Properties.Name
		If ($Keys.Count -ieq 1 -and $Keys -icontains 'Path') {
			$Result.Paths += $Item.Path
		}
		ElseIf ($Keys.Count -ieq 1 -and $Keys -icontains 'Rule') {
			$Result.Rules += $Item.Rule
		}
		ElseIf ($Keys.Count -ieq 1 -and $Keys -icontains 'Session') {
			$Result.Sessions += $Item.Session
		}
		ElseIf ($Keys.Count -ieq 1 -and $Keys -icontains 'Signature') {
			$Result.Signatures += $Item.Signature
		}
		ElseIf ($Keys.Count -ieq 2 -and $Keys -icontains 'Path' -and $Keys -icontains 'Tool') {
			If ('clamav' -imatch $Item.Tool) {
				$Result.ClamAVPaths += $Item.Path
			}
			ElseIf ('yara' -imatch $Item.Tool) {
				$Result.YaraPaths += $Item.Path
			}
		}
		ElseIf ($Keys.Count -ieq 2 -and $Keys -icontains 'Session' -and $Keys -icontains 'Tool') {
			If ('clamav' -imatch $Item.Tool) {
				$Result.ClamAVSessions += $Item.Session
			}
			ElseIf ('yara' -imatch $Item.Tool) {
				$Result.YaraSessions += $Item.Session
			}
		}
		Else {
			$Result.Mixes += $Item
		}
	}
	Write-Output -InputObject $Result
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
	'Group-IgnoresElements',
	'Test-StringIsUri',
	'Test-StringMatchRegExs'
)
