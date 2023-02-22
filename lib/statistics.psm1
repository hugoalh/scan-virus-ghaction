#Requires -PSEdition Core
#Requires -Version 7.3
Class ScanVirusStatisticsIssuesSessions {
	[String[]]$ClamAV = @()
	[String[]]$Yara = @()
	[String[]]$Other = @()
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
