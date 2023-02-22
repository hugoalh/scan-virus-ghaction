#Requires -PSEdition Core
#Requires -Version 7.3
[Hashtable]$GetDateParameters_ISOString = @{
	AsUTC = $True
	UFormat = '%Y-%m-%dT%H:%M:%SZ'
}
Function ConvertTo-DateTimeISOString {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)][Alias('Input', 'Object')][DateTime]$InputObject
	)
	Process {
		Get-Date -Date $InputObject @GetDateParameters_ISOString
	}
}
Export-ModuleMember -Function @(
	'ConvertTo-DateTimeISOString'
)
