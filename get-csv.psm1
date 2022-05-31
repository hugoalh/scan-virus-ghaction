function Get-Csv {
	[CmdletBinding()][OutputType([pscustomobject[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Path,
		[string]$Delimiter = ',',
		[System.Text.Encoding]$Encoding = 'UTF8NoBOM'
	)
	[string[]]$Raw = Get-Content -Path $Path -Encoding $Encoding
	return ConvertFrom-Csv -InputObject $Raw[1..(($Raw.Count -gt 1) ? ($Raw.Count - 1) : 1)] -Delimiter $Delimiter -Header ($Raw[0] -split $Delimiter)
}
Export-ModuleMember -Function 'Get-Csv'
