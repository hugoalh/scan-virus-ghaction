#Requires -PSEdition Core
#Requires -Version 7.3
Function Write-Header1 {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Title')][String]$Header
	)
	Write-Host -Object ''
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($Header)$($PSStyle.Reset)"
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$('-' * [UInt]::Min($Header.Length, $Host.UI.RawUI.WindowSize.Width))$($PSStyle.Reset)"
}
Function Write-Header2 {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Title')][String]$Header
	)
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($PSStyle.Underline)$($PSStyle.Bold)$($Header)$($PSStyle.Reset)"
}
Function Write-NameValue {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Key')][String]$Name,
		[Parameter(Position = 1)][AllowEmptyCollection()][AllowEmptyString()][AllowNull()]$Value
	)
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($Name): $($PSStyle.Reset)$($Value)"
}
Export-ModuleMember -Function @(
	'Write-Header1',
	'Write-Header2',
	'Write-NameValue'
)
