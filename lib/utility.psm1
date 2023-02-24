#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name @(
	'hugoalh.GitHubActionsToolkit',
	'psyml'
) -Scope 'Local'
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
Export-ModuleMember -Function @(
	'Group-Ignores',
	'Test-StringIsUri',
	'Test-StringMatchRegExs'
)
