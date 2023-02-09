#Requires -PSEdition Core
#Requires -Version 7.2
[String[]]$ClamAVIssues = @()
[String[]]$YaraIssues = @()
[String[]]$OtherIssues = @()
[UInt64]$AllTotalElements = 0
[UInt64]$AllTotalSizes = 0
[UInt64]$ClamAVTotalElements = 0
[UInt64]$ClamAVTotalSizes = 0
[UInt64]$YaraTotalElements = 0
[UInt64]$YaraTotalSizes = 0
Function Add-StatisticsTotalElement {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Type,
		[Parameter(Mandatory = $True, Position = 1)][UInt64]$Value
	)
	Switch -Exact ($Type) {
		'All' {
			$Script:AllTotalElements += $Value
			Break;
		}
		'ClamAV' {
			$Script:ClamAVTotalElements += $Value
			Break;
		}
		'YARA' {
			$Script:YaraTotalElements += $Value
			Break;
		}
	}
}
Function Add-StatisticsIssue {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Type,
		[Parameter(Mandatory = $True, Position = 1)][String]$Value
	)
	Switch -Exact ($Type) {
		'ClamAV' {
			$Script:ClamAVIssues += $Value
			Break;
		}
		'YARA' {
			$Script:YaraIssues += $Value
			Break;
		}
		'Other' {
			$Script:OtherIssues += $Value
			Break;
		}
	}
}
Function Add-StatisticsTotalSize {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Type,
		[Parameter(Mandatory = $True, Position = 1)][UInt64]$Value
	)
	Switch -Exact ($Type) {
		'All' {
			$Script:AllTotalSizes += $Value
			Break;
		}
		'ClamAV' {
			$Script:ClamAVTotalSizes += $Value
			Break;
		}
		'YARA' {
			$Script:YaraTotalSizes += $Value
			Break;
		}
	}
}
Function Write-Statistics {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()

}
Export-ModuleMember -Function @(
	'Add-StatisticsTotalElement',
	'Add-StatisticsIssue',
	'Add-StatisticsTotalSize',
	'Write-Statistics'
)
