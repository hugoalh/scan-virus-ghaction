#Requires -PSEdition Core
#Requires -Version 7.2
Function Get-Csv {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('LP', 'PSPath')][String]$LiteralPath,
		[Char]$Delimiter = ',',
		[ValidateSet('ASCII', 'BigEndianUnicode', 'BigEndianUTF32', 'OEM', 'Unicode', 'UTF7', 'UTF8', 'UTF8BOM', 'UTF8NoBOM', 'UTF32')][String]$Encoding = 'UTF8NoBOM'
	)
	[String[]]$Raw = Get-Content -LiteralPath $LiteralPath -Encoding $Encoding
	Return (ConvertFrom-Csv -InputObject $Raw[1..(($Raw.Count -igt 1) ? ($Raw.Count - 1) : 1)] -Delimiter $Delimiter -Header ($Raw[0] -isplit $Delimiter))
}
Function Set-Csv {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('LP', 'PSPath')][String]$LiteralPath,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Input', 'Object')][PSCustomObject[]]$InputObject,
		[Char]$Delimiter = ',',
		[ValidateSet('ASCII', 'BigEndianUnicode', 'BigEndianUTF32', 'OEM', 'Unicode', 'UTF7', 'UTF8', 'UTF8BOM', 'UTF8NoBOM', 'UTF32')][String]$Encoding = 'UTF8NoBOM'
	)
	Return (Set-Content -LiteralPath $LiteralPath -Value (($InputObject | ConvertTo-Csv -Delimiter $Delimiter -NoTypeInformation -UseQuotes 'AsNeeded') -join "`n") -Confirm:$False -NoNewLine -Encoding $Encoding)
}
Export-ModuleMember -Function @(
	'Get-Csv',
	'Set-Csv'
)