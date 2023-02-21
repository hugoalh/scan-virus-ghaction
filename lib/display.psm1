#Requires -PSEdition Core
#Requires -Version 7.3
Function Write-Header1 {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	[UInt]$BoxSize = [UInt]::Min($InputObject.Length, $Host.UI.RawUI.WindowSize.Width)
	[String]$BoxBorderW = '=' * $BoxSize
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($BoxBorderW)$($PSStyle.Reset)"
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($InputObject)$($PSStyle.Reset)"
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($BoxBorderW)$($PSStyle.Reset)"
}
Function Write-Header2 {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($PSStyle.Underline)$($PSStyle.Bold)$($InputObject)$($PSStyle.Reset)"
}
Function Write-NameValue {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Key')][String]$Name,
		[Parameter(Position = 1)][AllowEmptyString()][String]$Value
	)
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($Name): $($PSStyle.Reset)$($Value)"
}
Export-ModuleMember -Function @(
	'Write-Header1',
	'Write-Header2',
	'Write-NameValue'
)
