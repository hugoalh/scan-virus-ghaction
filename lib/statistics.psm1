#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'step-summary',
		'ware-meta'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Class ScanVirusStatistics {
	[String[]]$IssuesOperations = @()
	[String[]]$IssuesSessions = @()
	[UInt64]$ElementDiscover = 0
	[UInt64]$ElementScan = 0
	[UInt64]$ElementClamAV = 0
	[UInt64]$ElementYara = 0
	[UInt64]$SizeDiscover = 0
	[UInt64]$SizeScan = 0
	[UInt64]$SizeClamAV = 0
	[UInt64]$SizeYara = 0
	[Boolean]$IsOverflow = $False
	[PSCustomObject[]]GetStatisticsTable() {
		[String[]]$Types = @('Scan')
		If ($Script:AllBundle -or $Script:ClamAVBundle) {
			$Types += 'ClamAV'
		}
		If ($Script:AllBundle -or $Script:YaraBundle) {
			$Types += 'Yara'
		}
		[Boolean]$IsNoElement = $This.ElementDiscover -eq 0
		[Boolean]$IsNoSize = $This.SizeDiscover -eq 0
		[PSCustomObject[]]$StatisticsTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				Element = $This.ElementDiscover.ToString()
				ElementPercentage = $Null
				SizeB = $This.SizeDiscover.ToString()
				SizeKb = ($This.SizeDiscover / 1KB).ToString('0.000')
				SizeMb = ($This.SizeDiscover / 1MB).ToString('0.000')
				SizeGb = ($This.SizeDiscover / 1GB).ToString('0.000')
				SizePercentage = $Null
			}
		)
		ForEach ($Type In $Types) {
			$StatisticsTable += [PSCustomObject]@{
				Type = $Type
				Element = $This.("Element$($Type)").ToString()
				ElementPercentage = ($IsNoElement ? 0 : ($This.("Element$($Type)") / $This.ElementDiscover * 100)).ToString('0.000')
				SizeB = $This.("Size$($Type)").ToString()
				SizeKb = ($This.("Size$($Type)") / 1KB).ToString('0.000')
				SizeMb = ($This.("Size$($Type)") / 1MB).ToString('0.000')
				SizeGb = ($This.("Size$($Type)") / 1GB).ToString('0.000')
				SizePercentage = ($IsNoSize ? 0 : ($This.("Size$($Type)") / $This.SizeDiscover * 100)).ToString('0.000')
			}
		}
		Return $StatisticsTable
	}
	[String]GetStatisticsTableString([UInt16]$Width) {
		Return (
			$This.GetStatisticsTable() |
			Format-Table -Property @(
				'Type',
				@{ Expression = 'Element'; Alignment = 'Right' },
				@{ Expression = 'ElementPercentage'; Name = 'Element %'; Alignment = 'Right' },
				@{ Expression = 'SizeB'; Name = 'Size B'; Alignment = 'Right' },
				@{ Expression = 'SizeKb'; Name = 'Size KB'; Alignment = 'Right' },
				@{ Expression = 'SizeMb'; Name = 'Size MB'; Alignment = 'Right' },
				@{ Expression = 'SizeGb'; Name = 'Size GB'; Alignment = 'Right' },
				@{ Expression = 'SizePercentage'; Name = 'Size %'; Alignment = 'Right' }
			) -AutoSize -Wrap |
			Out-String -Width $Width
		)
	}
	[String]GetStatisticsTableString() {
		Return $This.GetStatisticsTableString(80)
	}
	[Void]StatisticsDisplay() {
		If ($This.IsOverflow) {
			Write-GitHubActionsNotice -Message 'Statistics is not display: Overflow'
			Return
		}
		$DisplayList = [Ordered]@{
			Statistics = $This.GetStatisticsTableString()
		}
		If ($This.IssuesOperations.Count -gt 0) {
			$DisplayList.("IssuesOperations [$($This.IssuesOperations.Count)]") = $This.IssuesOperations |
				Join-String -Separator ', '
		}
		If ($This.IssuesSessions.Count -gt 0) {
			$DisplayList.("IssuesSessions [$($This.IssuesSessions.Count)]") = $This.IssuesSessions |
				Join-String -Separator ', '
		}
		Write-GitHubActionsNotice -Message (
			[PSCustomObject]$DisplayList |
				Format-List -Property '*' |
				Out-String -Width 120
		)
	}
	[Void]StatisticsSummary() {
		If ($This.IsOverflow) {
			Write-GitHubActionsNotice -Message 'Statistics is not display: Overflow'
			Return
		}
		Add-StepSummaryStatistics -StatisticsTable $This.GetStatisticsTable() -IssuesOperations $This.IssuesOperations -IssuesSessions $This.IssuesSessions
	}
	[Byte]GetExitCode() {
		Return (($This.IssuesSessions.Count -gt 0) ? 1 : 0)
	}
}
