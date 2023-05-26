#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'step-summary'
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
		[Boolean]$IsNoElement = $This.ElementDiscover -eq 0
		[Boolean]$IsNoSize = $This.SizeDiscover -eq 0
		[PSCustomObject[]]$StatisticsTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				Element = $This.ElementDiscover
				ElementPercentage = $Null
				SizeB = $This.SizeDiscover
				SizeKb = [Math]::Round(($This.SizeDiscover / 1KB), 3, [System.MidpointRounding]::ToZero)
				SizeMb = [Math]::Round(($This.SizeDiscover / 1MB), 3, [System.MidpointRounding]::ToZero)
				SizeGb = [Math]::Round(($This.SizeDiscover / 1GB), 3, [System.MidpointRounding]::ToZero)
				SizePercentage = $Null
			}
		)
		ForEach ($Type In @('Scan', 'ClamAV', 'Yara')) {
			$StatisticsTable += [PSCustomObject]@{
				Type = $Type
				Element = $This.("Element$($Type)")
				ElementPercentage = $IsNoElement ? 0 : [Math]::Round(($This.("Element$($Type)") / $This.ElementDiscover * 100), 3, [System.MidpointRounding]::ToZero)
				SizeB = $This.("Size$($Type)")
				SizeKb = [Math]::Round(($This.("Size$($Type)") / 1KB), 3, [System.MidpointRounding]::ToZero)
				SizeMb = [Math]::Round(($This.("Size$($Type)") / 1MB), 3, [System.MidpointRounding]::ToZero)
				SizeGb = [Math]::Round(($This.("Size$($Type)") / 1GB), 3, [System.MidpointRounding]::ToZero)
				SizePercentage = $IsNoSize ? 0 : [Math]::Round(($This.("Size$($Type)") / $This.SizeDiscover * 100), 3, [System.MidpointRounding]::ToZero)
			}
		}
		Return $StatisticsTable
	}
	[String]GetStatisticsTableString([UInt32]$Width) {
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
	[Void]ConclusionDisplay() {
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
	[Void]ConclusionSummary() {
		If ($This.IsOverflow) {
			Write-GitHubActionsNotice -Message 'Statistics is not display: Overflow'
			Return
		}
		Add-StepSummaryConclusion -StatisticsTable $This.GetStatisticsTable() -IssuesOperations $This.IssuesOperations -IssuesSessions $This.IssuesSessions
	}
	[Byte]GetExitCode() {
		Return (($This.IssuesSessions.Count -gt 0) ? 1 : 0)
	}
}
