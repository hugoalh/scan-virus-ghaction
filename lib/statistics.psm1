#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name (
	@(
		'display'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Class ScanVirusStatisticsIssuesSessions {
	[String[]]$ClamAV = @()
	[String[]]$Yara = @()
	[String[]]$Other = @()
	[Void]ConclusionDisplay() {
		Write-Header2 -Header "Issues Sessions [$($This.ClamAV.Count + $This.Yara.Count + $This.Other.Count)]"
		Write-NameValue -Name "ClamAV [$($This.ClamAV.Count)]" -Value $This.ClamAV
		Write-NameValue -Name "Yara [$($This.Yara.Count)]" -Value $This.Yara
		Write-NameValue -Name "Other [$($This.Other.Count)]" -Value $This.Other
	}
}
Class ScanVirusStatisticsTotalElements {
	[UInt64]$All = 0
	[UInt64]$ClamAV = 0
	[UInt64]$Yara = 0
}
Class ScanVirusStatisticsTotalSizes {
	[UInt64]$All = 0
	[UInt64]$ClamAV = 0
	[UInt64]$Yara = 0
}
