#Requires -PSEdition Core -Version 7.3
[Hashtable]$GetDateParameters_IsoString = @{
	AsUTC = $True
	UFormat = '%Y-%m-%dT%H:%M:%SZ'
}
Function ConvertTo-DateTimeIsoString {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)][Alias('Input', 'Object')][DateTime]$InputObject
	)
	Process {
		Get-Date -Date $InputObject @GetDateParameters_IsoString
	}
}
Export-ModuleMember -Function @(
	'ConvertTo-DateTimeIsoString'
)
