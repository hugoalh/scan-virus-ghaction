#Requires -PSEdition Core
#Requires -Version 7.3
Class ScanVirusStatistics {
	[UInt64]$TotalElements_All = 0
	[UInt64]$TotalElements_ClamAV = 0
	[UInt64]$TotalElements_Yara = 0
	[UInt64]$TotalSizes_All = 0
	[UInt64]$TotalSizes_ClamAV = 0
	[UInt64]$TotalSizes_Yara = 0
}
