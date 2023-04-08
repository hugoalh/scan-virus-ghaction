#Requires -PSEdition Core -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Class ScanVirusStatisticsIssuesOperations {
	[String[]]$Storage = @()
	[Void]ConclusionDisplay() {
		Enter-GitHubActionsLogGroup -Title "Issues Operations [$($This.Storage.Count)]: "
		$This.Storage |
			Join-String -Separator ', '
		Exit-GitHubActionsLogGroup
	}
}
Class ScanVirusStatisticsIssuesSessions {
	[String[]]$ClamAV = @()
	[String[]]$Yara = @()
	[Void]ConclusionDisplay() {
		Enter-GitHubActionsLogGroup -Title "Issues Sessions [$($This.GetTotal())]: "
		Write-NameValue -Name "ClamAV [$($This.ClamAV.Count)]" -Value (
			$This.ClamAV |
				Join-String -Separator ', '
		)
		Write-NameValue -Name "Yara [$($This.Yara.Count)]" -Value (
			$This.Yara |
				Join-String -Separator ', '
		)
		Exit-GitHubActionsLogGroup
	}
	[UInt64]GetTotal() {
		Return ($This.ClamAV.Count + $This.Yara.Count)
	}
}
Class ScanVirusStatisticsTotalElements {
	[UInt64]$Discover = 0
	[UInt64]$Scan = 0
	[UInt64]$ClamAV = 0
	[UInt64]$Yara = 0
	[Void]ConclusionDisplay() {
		[Boolean]$IsNoElements = $This.Discover -ieq 0
		Enter-GitHubActionsLogGroup -Title 'Total Elements: '
		[PSCustomObject[]]$TotalElementsTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				Value = $This.Discover
				Percentage = $Null
			}
		)
		ForEach ($Type In @('Scan', 'ClamAV', 'Yara')) {
			$TotalElementsTable += [PSCustomObject]@{
				Type = $Type
				Value = $This[$Type]
				Percentage = $IsNoElements ? 0 : [Math]::Round(($This[$Type] / $This.Discover * 100), 3)
			}
		}
		$TotalElementsTable |
			Format-Table -Property @(
				'Type',
				@{ Expression = 'Value'; Alignment = 'Right' },
				@{ Expression = 'Percentage'; Name = '%'; Alignment = 'Right' }
			) -AutoSize |
			Out-String
		Exit-GitHubActionsLogGroup
	}
}
Class ScanVirusStatisticsTotalSizes {
	[UInt64]$Discover = 0
	[UInt64]$Scan = 0
	[UInt64]$ClamAV = 0
	[UInt64]$Yara = 0
	[Void]ConclusionDisplay() {
		[Boolean]$IsNoSizes = $This.Discover -ieq 0
		Enter-GitHubActionsLogGroup -Title 'Total Sizes: '
		[PSCustomObject[]]$TotalSizesTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				B = $This.Discover
				KB = [Math]::Round(($This.Discover / 1KB), 3)
				MB = [Math]::Round(($This.Discover / 1MB), 3)
				GB = [Math]::Round(($This.Discover / 1GB), 3)
				Percentage = $Null
			}
		)
		ForEach ($Type In @('Scan', 'ClamAV', 'Yara')) {
			$TotalSizesTable += [PSCustomObject]@{
				Type = $Type
				B = $This[$Type]
				KB = [Math]::Round(($This[$Type] / 1KB), 3)
				MB = [Math]::Round(($This[$Type] / 1MB), 3)
				GB = [Math]::Round(($This[$Type] / 1GB), 3)
				Percentage = $IsNoSizes ? 0 : [Math]::Round(($This[$Type] / $This.Discover * 100), 3)
			}
		}
		$TotalSizesTable |
			Format-Table -Property @(
				'Type',
				@{ Expression = 'B'; Alignment = 'Right' },
				@{ Expression = 'KB'; Alignment = 'Right' },
				@{ Expression = 'MB'; Alignment = 'Right' },
				@{ Expression = 'GB'; Alignment = 'Right' },
				@{ Expression = 'Percentage'; Name = '%'; Alignment = 'Right' }
			) -AutoSize |
			Out-String
		Exit-GitHubActionsLogGroup
	}
}
