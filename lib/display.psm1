#Requires -PSEdition Core -Version 7.2
Function Write-NameValue {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Key')][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][AllowEmptyString()][AllowNull()]$Value,
		[Switch]$NewLine
	)
	[Boolean]$NoNewLine = !$NewLine.IsPresent
	Write-Host -Object "$($Name): " -NoNewline:$NoNewLine
	If (
		$Null -ieq $Value -or
		$Value -is [Boolean] -or
		$Value -is [Byte] -or
		$Value -is [Int16] -or
		$Value -is [Int32] -or
		$Value -is [Int64] -or
		$Value -is [Int128] -or
		$Value -is [String] -or
		$Value -is [UInt16] -or
		$Value -is [UInt32] -or
		$Value -is [UInt64] -or
		$Value -is [UInt128]
	) {
		Write-Host -Object $Value
	}
	Else {
		Out-Host -InputObject $Value
	}
}
Export-ModuleMember -Function @(
	'Write-NameValue'
)
