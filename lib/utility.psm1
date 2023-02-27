#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name @(
	'hugoalh.GitHubActionsToolkit',
	'psyml'
) -Scope 'Local'
Function Group-IgnoresElements {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyCollection()][Alias('Input', 'Object')][PSCustomObject[]]$InputObject
	)
	[PSCustomObject[]]$Mixes = @()
	[PSCustomObject[]]$OnlyPaths = @()
	[PSCustomObject[]]$OnlyRules = @()
	[PSCustomObject[]]$OnlySessions = @()
	[PSCustomObject[]]$OnlySignatures = @()
	ForEach ($Item In $InputObject) {
		[String[]]$Keys = $Item.PSObject.Properties.Name
		If (($Keys.Count -ieq 1) -and ($Keys -icontains 'Path')) {
			$OnlyPaths += $Item
		}
		ElseIf (($Keys.Count -ieq 1) -and ($Keys -icontains 'Rule')) {
			$OnlyRules += $Item
		}
		ElseIf (($Keys.Count -ieq 1) -and ($Keys -icontains 'Session')) {
			$OnlySessions += $Item
		}
		ElseIf (($Keys.Count -ieq 1) -and ($Keys -icontains 'Signature')) {
			$OnlySignatures += $Item
		}
		Else {
			$Mixes += $Item
		}
	}
	[PSCustomObject]@{
		Mixes = $Mixes
		Paths = $OnlyPaths
		Rules = $OnlyRules
		Sessions = $OnlySessions
		Signatures = $OnlySignatures
	} |
		Write-Output
}
Function Test-StringIsUri {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][Uri]$InputObject
	)
	($Null -ine $InputObject.AbsoluteUri) -and ($InputObject.Scheme -imatch '^https?$') |
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
	'Group-Ignores',
	'Test-StringIsUri',
	'Test-StringMatchRegExs'
)
