function Get-Csv {
	[CmdletBinding()][OutputType([pscustomobject[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('LP', 'PSPath')][string]$LiteralPath,
		[char]$Delimiter = ',',
		[ValidateSet('ASCII', 'BigEndianUnicode', 'BigEndianUTF32', 'OEM', 'Unicode', 'UTF7', 'UTF8', 'UTF8BOM', 'UTF8NoBOM', 'UTF32')][string]$Encoding = 'UTF8NoBOM'
	)
	[string[]]$Raw = Get-Content -LiteralPath $LiteralPath -Encoding $Encoding
	return ConvertFrom-Csv -InputObject $Raw[1..(($Raw.Count -gt 1) ? ($Raw.Count - 1) : 1)] -Delimiter $Delimiter -Header ($Raw[0] -split $Delimiter)
}
function Set-Csv {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][Alias('LP', 'PSPath')][string]$LiteralPath,
		[Parameter(Mandatory = $true, Position = 1)][Alias('Input', 'Object')][pscustomobject[]]$InputObject,
		[char]$Delimiter = ',',
		[ValidateSet('ASCII', 'BigEndianUnicode', 'BigEndianUTF32', 'OEM', 'Unicode', 'UTF7', 'UTF8', 'UTF8BOM', 'UTF8NoBOM', 'UTF32')][string]$Encoding = 'UTF8NoBOM'
	)
	return Set-Content -LiteralPath $LiteralPath -Value (($InputObject | ConvertTo-Csv -Delimiter $Delimiter -NoTypeInformation -UseQuotes 'AsNeeded') -join "`n") -Confirm:$false -NoNewLine -Encoding $Encoding
}
Export-ModuleMember -Function @(
	'Get-Csv',
	'Set-Csv'
)
