#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Class ScanVirusStatistics {
	[String[]]$IssuesOperations = @()
	[String[]]$IssuesSessions = @()
	[UInt64]$TotalElementsDiscover = 0
	[UInt64]$TotalElementsScan = 0
	[UInt64]$TotalElementsClamAV = 0
	[UInt64]$TotalElementsYara = 0
	[UInt64]$TotalSizesDiscover = 0
	[UInt64]$TotalSizesScan = 0
	[UInt64]$TotalSizesClamAV = 0
	[UInt64]$TotalSizesYara = 0
	[Boolean]$IsOverflow = $False
	[PSCustomObject[]]GetTotalElementsTable() {
		[Boolean]$IsNoElements = $This.TotalElementsDiscover -eq 0
		[PSCustomObject[]]$TotalElementsTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				Value = $This.TotalElementsDiscover
				Percentage = $Null
			}
		)
		ForEach ($Type In @('Scan', 'ClamAV', 'Yara')) {
			$TotalElementsTable += [PSCustomObject]@{
				Type = $Type
				Value = $This.("TotalElements$($Type)")
				Percentage = $IsNoElements ? 0 : [Math]::Round(($This.("TotalElements$($Type)") / $This.TotalElementsDiscover * 100), 3)
			}
		}
		Return $TotalElementsTable
	}
	[PSCustomObject[]]GetTotalSizesTable() {
		[Boolean]$IsNoSizes = $This.TotalSizesDiscover -eq 0
		[PSCustomObject[]]$TotalSizesTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				B = $This.TotalSizesDiscover
				KB = [Math]::Round(($This.TotalSizesDiscover / 1KB), 3)
				MB = [Math]::Round(($This.TotalSizesDiscover / 1MB), 3)
				GB = [Math]::Round(($This.TotalSizesDiscover / 1GB), 3)
				Percentage = $Null
			}
		)
		ForEach ($Type In @('Scan', 'ClamAV', 'Yara')) {
			$TotalSizesTable += [PSCustomObject]@{
				Type = $Type
				B = $This.("TotalSizes$($Type)")
				KB = [Math]::Round(($This.("TotalSizes$($Type)") / 1KB), 3)
				MB = [Math]::Round(($This.("TotalSizes$($Type)") / 1MB), 3)
				GB = [Math]::Round(($This.("TotalSizes$($Type)") / 1GB), 3)
				Percentage = $IsNoSizes ? 0 : [Math]::Round(($This.("TotalSizes$($Type)") / $This.TotalSizesDiscover * 100), 3)
			}
		}
		Return $TotalSizesTable
	}
	[Void]ConclusionDisplay() {
		If ($This.IsOverflow) {
			Write-GitHubActionsNotice -Message 'Statistics is not display: Overflow'
			Return
		}
		[PSCustomObject]$DisplayList = [PSCustomObject]@{
			TotalElements = $This.GetTotalElementsTable() |
				Format-Table -Property @(
					'Type',
					@{ Expression = 'Value'; Alignment = 'Right' },
					@{ Expression = 'Percentage'; Name = '%'; Alignment = 'Right' }
				) -AutoSize -Wrap |
				Out-String -Width 80
			TotalSizes = $This.GetTotalSizesTable() |
				Format-Table -Property @(
					'Type',
					@{ Expression = 'B'; Alignment = 'Right' },
					@{ Expression = 'KB'; Alignment = 'Right' },
					@{ Expression = 'MB'; Alignment = 'Right' },
					@{ Expression = 'GB'; Alignment = 'Right' },
					@{ Expression = 'Percentage'; Name = '%'; Alignment = 'Right' }
				) -AutoSize -Wrap |
				Out-String -Width 80
		}
		If ($This.IssuesOperations.Count -gt 0) {
			$DisplayList.("Issues Operations [$($This.IssuesOperations.Count)]") = $This.IssuesOperations |
				Join-String -Separator ', '
		}
		If ($This.IssuesSessions.Count -gt 0) {
			$DisplayList.("Issues Sessions [$($This.IssuesSessions.Count)]") = $This.IssuesSessions |
				Join-String -Separator ', '
		}
		Write-GitHubActionsNotice -Message @"
Statistics:
$(
	$DisplayList |
		Format-List -Property '*' |
		Out-String -Width 120
)
"@
	}
	[Byte]GetExitCode() {
		Return (($This.IssuesSessions.Count -gt 0) ? 1 : 0)
	}
}
