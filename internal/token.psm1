#Requires -PSEdition Core
#Requires -Version 7.2
[Char[]]$TokenPool = [String[]]@(0..9) + [Char[]]@(97..122)
<#
.SYNOPSIS
Scan Virus - Internal - New Random Token
.DESCRIPTION
Get a new random token.
.PARAMETER Length
Token length.
.OUTPUTS
[String] A new random token.
#>
Function New-RandomToken {
	[CmdletBinding()]
	[OutputType([String])]
	Param (
		[Parameter(Position = 0)][ValidateRange(1, [UInt32]::MaxValue)][UInt32]$Length = 8
	)
	@(1..$Length) |
		ForEach-Object -Process {
			$TokenPool |
				Get-Random -Count 1
		} |
		Join-String -Separator '' |
		Write-Output
}
Export-ModuleMember -Function @(
	'New-RandomToken'
)
