#Requires -PSEdition Core
#Requires -Version 7.2
[Hashtable]$DateTimeParameters_ISOString = @{
	AsUTC = $True
	UFormat = '%Y-%m-%dT%H:%M:%SZ'
}
Function ConvertTo-DateTimeISOString {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)][Alias('Input', 'Object')][DateTime]$InputObject
	)
	Process {
		Get-Date -Date $InputObject @DateTimeParameters_ISOString
	}
}
Export-ModuleMember -Function @(
	'ConvertTo-DateTimeISOString'
)
