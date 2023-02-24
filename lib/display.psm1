#Requires -PSEdition Core
#Requires -Version 7.3
Function Write-Header1 {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Title')][String]$Header
	)
	[String]$BoxBorderW = ':' * $Host.UI.RawUI.WindowSize.Width
	[String]$HeaderWhitespace = ' ' * [Math]::Floor([Math]::Max(0, $Host.UI.RawUI.WindowSize.Width - $Header.Length) / 2)
	Write-Host -Object @"

$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($HeaderWhitespace)$($Header)$($HeaderWhitespace)$($PSStyle.Reset)
$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($BoxBorderW)$($PSStyle.Reset)
"@
}
Function Write-Header2 {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Title')][String]$Header
	)
	[String]$BoxBorderW = '-' * [Math]::Min($Header.Length, $Host.UI.RawUI.WindowSize.Width)
	Write-Host -Object @"

$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($Header)$($PSStyle.Reset)
$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($BoxBorderW)$($PSStyle.Reset)
"@
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
Function Write-NameValueFormat {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Key')][String]$Name,
		[Parameter(Position = 1)][AllowEmptyCollection()][AllowEmptyString()][AllowNull()]$Value
	)
	Write-Host -Object "$($PSStyle.Formatting.TableHeader)$($PSStyle.Bold)$($Name): $($PSStyle.Reset)$($Value)"
}
Export-ModuleMember -Function @(
	'Write-Header1',
	'Write-Header2',
	'Write-NameValue',
	'Write-NameValueFormat'
)
