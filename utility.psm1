Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name 'psyml' -Scope 'Local'
Function ConvertFrom-Csvm {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)][Alias('Input', 'Object')][String[]]$InputObject
	)
	Begin {}
	Process {
		Return ($InputObject | ForEach-Object -Process {
			[Hashtable]$Condition = @{}
			ForEach ($Column In [String[]](Convert-FromCsvsToCsvm -InputObject $_ -Delimiter ',')) {
				If ($Column -imatch '=') {
					[String]$Key, [String[]]$Value = $Column -isplit '='
					$Condition[$Key] = $Value -join '='
					Continue
				}
				Throw 'Invalid table syntax!'
			}
			Return [PSCustomObject]$Condition
		})
	}
	End {}
}
Function Convert-FromCsvsToCsvm {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)][Alias('Input', 'Object')][String]$InputObject,
		[Parameter(Position = 1)][Char]$Delimiter = ';'
	)
	Begin {}
	Process {
		If ($InputObject -imatch $Delimiter) {
			[String[]]$Result = @()
			ForEach ($Item In [PSCustomObject[]](ConvertFrom-Csv -InputObject $InputObject -Delimiter $Delimiter -Header @(0..($Matches.Count)))) {
				$Result += $Item.PSObject.Properties.Value
			}
			Return $Result
		}
		Return @($InputObject)
	}
	End {}
}
Function Format-InputList {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyString()][Alias('Input', 'Object')][String]$InputObject,
		[Parameter(Mandatory = $True, Position = 1)][RegEx]$Delimiter
	)
	Return ([String[]]($InputObject -isplit $Delimiter) | ForEach-Object -Process {
		Return $_.Trim()
	} | Where-Object -FilterScript {
		Return ($_ -imatch '^.+$')
	} | Sort-Object -Unique -CaseSensitive)
}
Function Format-InputTable {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][ValidateSet('csv', 'csvm', 'csvs', 'tsv', 'yaml')][String]$Type,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Input', 'Object')][String]$InputObject
	)
	Try {
		Switch ($Type) {
			'csv' {
				Return (ConvertFrom-Csv -InputObject $InputObject -Delimiter ',')
			}
			'csvm' {
				Return ([String[]]($InputObject -isplit '\r?\n') | Where-Object -FilterScript {
					Return ($_ -imatch '^.+$')
				} | ConvertFrom-Csvm)
			}
			'csvs' {
				Return ($InputObject | Convert-FromCsvsToCsvm | ConvertFrom-Csvm)
			}
			'tsv' {
				Return (ConvertFrom-Csv -InputObject $InputObject -Delimiter "`t")
			}
			'yaml' {
				Return (ConvertFrom-Yaml -InputObject $InputObject)
			}
		}
	} Catch {
		Write-GitHubActionsFail -Message "Invalid ``$Type`` table syntax: $_"
		Throw
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
		Return [String[]]@()
	}
	Return (Format-InputList -InputObject $Raw -Delimiter $Delimiter)
}
Function Get-InputTable {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][ValidateSet('csv', 'csvm', 'csvs', 'tsv', 'yaml')][String]$Type
	)
	$Raw = Get-GitHubActionsInput -Name $Name -EmptyStringAsNull
	If ($Null -ieq $Raw) {
		Return [PSCustomObject[]]@()
	}
	Return (Format-InputTable -Type $Type -InputObject $Raw)
}
Function Group-ScanVirusToolsIgnores {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyCollection()][Alias('Input', 'Object')][PSCustomObject[]]$InputObject
	)
	[PSCustomObject[]]$OnlyPaths = ($InputObject | Where-Object -FilterScript {
		[String[]]$Keys = $_.PSObject.Properties.Name
		Return ($Keys.Count -ieq 1 -and $Keys -icontains 'Path')
	})
	[PSCustomObject[]]$OnlySessions = ($InputObject | Where-Object -FilterScript {
		[String[]]$Keys = $_.PSObject.Properties.Name
		Return ($Keys.Count -ieq 1 -and $Keys -icontains 'Session')
	})
	[PSCustomObject[]]$Others = ($InputObject | Where-Object -FilterScript {
		[String[]]$Keys = $_.PSObject.Properties.Name
		Return !($Keys.Count -ieq 1 -and (
			$Keys -icontains 'Path' -or
			$Keys -icontains 'Session'
		))
	})
	Return [PSCustomObject]@{
		OnlyPaths = $OnlyPaths
		OnlySessions = $OnlySessions
		Others = $Others
	}
}
Function Optimize-PSFormatDisplay {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)][AllowEmptyString()][Alias('Input', 'Object')][String]$InputObject
	)
	Begin {}
	Process {
		Return ($InputObject -ireplace '^(?:\r?\n)+|(?:\r?\n)+$', '')
	}
	End {}
}
Function Test-StringIsUri {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][Uri]$InputObject
	)
	Return ($Null -ine $InputObject.AbsoluteUri -and $InputObject.Scheme -imatch '^https?$')
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
		[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)][AllowEmptyString()][Alias('Input', 'Object')][String]$InputObject
	)
	Begin {}
	Process {
		[String]$OutputObject = Optimize-PSFormatDisplay -InputObject $InputObject
		If ($OutputObject.Length -igt 0) {
			Write-Host -Object $OutputObject
		}
	}
	End {}
}
Export-ModuleMember -Function @(
	'Format-InputList',
	'Format-InputTable',
	'Get-InputBoolean',
	'Get-InputList',
	'Get-InputTable',
	'Group-ScanVirusToolsIgnores',
	'Optimize-PSFormatDisplay',
	'Test-StringIsUri',
	'Test-StringMatchRegExs',
	'Write-NameValue',
	'Write-OptimizePSFormatDisplay'
)
