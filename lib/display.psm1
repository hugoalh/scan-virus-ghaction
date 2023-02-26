#Requires -PSEdition Core
#Requires -Version 7.3
Function Write-NameValue {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Key')][String]$Name,
		[Parameter(Position = 1)][AllowEmptyCollection()][AllowEmptyString()][AllowNull()]$Value,
		[Switch]$UsePSTableHeaderFormat
	)
	Write-Host -Object "$($UsePSTableHeaderFormat.IsPresent ? $PSStyle.Formatting.TableHeader : $PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($Name): $($PSStyle.Reset)" -NoNewline
	Write-Host -Object $Value
}
Export-ModuleMember -Function @(
	'Write-NameValue'
)
