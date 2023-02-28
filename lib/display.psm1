#Requires -PSEdition Core
#Requires -Version 7.3
Function Write-NameValue {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Key')][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][AllowEmptyString()][AllowNull()]$Value,
		[Switch]$NewLine,
		[Switch]$UsePSTableHeaderFormat
	)
	[Boolean]$NoNewLine = !$NewLine.IsPresent
	Write-Host -Object "$($UsePSTableHeaderFormat.IsPresent ? $PSStyle.Formatting.TableHeader : $PSStyle.Foreground.BrightBlue)$($PSStyle.Bold)$($Name): $($PSStyle.Reset)" -NoNewline:$NoNewLine
	If (
		($Null -ieq $Value) -or
		($Value -is [Boolean]) -or
		($Value -is [Int16]) -or
		($Value -is [Int32]) -or
		($Value -is [Int64]) -or
		($Value -is [String]) -or
		($Value -is [UInt16]) -or
		($Value -is [UInt32]) -or
		($Value -is [UInt64])
	) {
		Write-Host -Object $Value
	}
	Else {
		Out-Host -InputObject $Value
	}
}
Function Write-Status {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Input', 'Object')][String]$InputObject
	)
	Write-Host -Object "$($PSStyle.Foreground.BrightMagenta)$($InputObject)$($PSStyle.Reset)"
}
Export-ModuleMember -Function @(
	'Write-NameValue',
	'Write-Status'
)
