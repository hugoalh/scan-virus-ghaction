#Requires -PSEdition Core
#Requires -Version 7.3
Function Write-Header1 {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	[UInt]$BoxSize = [UInt]::Min($InputObject.Length, $Host.UI.RawUI.WindowSize.Width)
	[String]$BoxBorderW = '•' * $BoxSize
	Write-Host -Object "$($PSStyle.Background.Blue)$($BoxBorderW)$($PSStyle.Reset)"
	Write-Host -Object "$($PSStyle.Background.Blue)$($PSStyle.Bold)$($InputObject)$($PSStyle.Reset)"
	Write-Host -Object "$($PSStyle.Background.Blue)$($BoxBorderW)$($PSStyle.Reset)"
}
Function Write-Header2 {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($InputObject)$($PSStyle.Reset)"
}
Export-ModuleMember -Function @(
	'Write-Header1',
	'Write-Header2'
)
