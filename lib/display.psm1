#Requires -PSEdition Core
#Requires -Version 7.3
Function Write-Display {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)][Alias('Input', 'Object')][PSCustomObject]$InputObject
	)
	Process {
		[String]$Result = (Out-String -InputObject $InputObject) -ireplace '^(?:\r?\n)+|(?:\r?\n)+$', ''
		If ($Result.Length -igt 0) {
			Write-Host -Object $Result
		}
	}
}
Function Write-Header1 {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	Write-Host -Object "$($PSStyle.Background.BrightBlue)$($PSStyle.Bold)$($InputObject)$($PSStyle.Reset)"
}
Function Write-Header2 {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	Write-Host -Object "$($PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($InputObject)$($PSStyle.Reset)"
}
Export-ModuleMember -Function @(
	'Write-Display',
	'Write-Header1',
	'Write-Header2'
)
