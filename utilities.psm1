function Get-TSVTable {
	[CmdletBinding()][OutputType([pscustomobject[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Path
	)
	[string[]]$Raw = Get-Content -Path $Path -Encoding UTF8NoBOM
	return ConvertFrom-Csv -InputObject $Raw[1..$Raw.Count] -Delimiter "`t" -Header ($Raw[0] -split "`t")
}
Export-ModuleMember -Function 'Get-TSVTable'
