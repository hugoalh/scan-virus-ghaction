#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'step-summary'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Class ScanVirusStatistics {
	[String[]]$StatisticsTypes = @('Scan', 'ClamAV', 'Yara')
	[UInt64[]]$ElementsDiscover = @()
	[UInt64[]]$ElementsScan = @()
	[UInt64[]]$ElementsClamAV = @()
	[UInt64[]]$ElementsYara = @()
	[UInt64[]]$SizesDiscover = @()
	[UInt64[]]$SizesScan = @()
	[UInt64[]]$SizesClamAV = @()
	[UInt64[]]$SizesYara = @()
	[String[]]$IssuesOperations = @()
	[String[]]$IssuesSessions = @()
	[Boolean]$IsOverflow = $False
	[PSCustomObject[]]GetElementsTable() {
		$MeasureElementsDiscover = $This.ElementsDiscover |
			Measure-Object -StandardDeviation -Sum -Average -Maximum -Minimum
		$MeasureElementsScan = $This.ElementsScan |
			Measure-Object -StandardDeviation -Sum -Average -Maximum -Minimum
		$MeasureElementsClamAV = $This.ElementsClamAV |
			Measure-Object -StandardDeviation -Sum -Average -Maximum -Minimum
		$MeasureElementsYara = $This.ElementsYara |
			Measure-Object -StandardDeviation -Sum -Average -Maximum -Minimum
		[Boolean]$IsNoElements = $MeasureElementsDiscover.Sum -eq 0
		[PSCustomObject[]]$ElementsTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				Sum = $MeasureElementsDiscover.Sum ?? 0
				Minimum = $MeasureElementsDiscover.Minimum ?? 0
				Average = $MeasureElementsDiscover.Average ?? 0
				Maximum = $MeasureElementsDiscover.Maximum ?? 0
				StandardDeviation = $MeasureElementsDiscover.StandardDeviation ?? 0
				Percentage = $Null
			},
			[PSCustomObject]@{
				Type = 'Scan'
				Sum = $MeasureElementsScan.Sum ?? 0
				Minimum = $MeasureElementsScan.Minimum ?? 0
				Average = $MeasureElementsScan.Average ?? 0
				Maximum = $MeasureElementsScan.Maximum ?? 0
				StandardDeviation = $MeasureElementsScan.StandardDeviation ?? 0
				Percentage = ($IsNoElements ? 0 : [Math]::Round(($MeasureElementsScan.Sum / $MeasureElementsDiscover.Sum * 100), 3, [System.MidpointRounding]::ToZero)) ?? 0
			},
			[PSCustomObject]@{
				Type = 'ClamAV'
				Sum = $MeasureElementsClamAV.Sum ?? 0
				Minimum = $MeasureElementsClamAV.Minimum ?? 0
				Average = $MeasureElementsClamAV.Average ?? 0
				Maximum = $MeasureElementsClamAV.Maximum ?? 0
				StandardDeviation = $MeasureElementsClamAV.StandardDeviation ?? 0
				Percentage = ($IsNoElements ? 0 : [Math]::Round(($MeasureElementsClamAV.Sum / $MeasureElementsDiscover.Sum * 100), 3, [System.MidpointRounding]::ToZero)) ?? 0
			},
			[PSCustomObject]@{
				Type = 'Yara'
				Sum = $MeasureElementsYara.Sum ?? 0
				Minimum = $MeasureElementsYara.Minimum ?? 0
				Average = $MeasureElementsYara.Average ?? 0
				Maximum = $MeasureElementsYara.Maximum ?? 0
				StandardDeviation = $MeasureElementsYara.StandardDeviation ?? 0
				Percentage = ($IsNoElements ? 0 : [Math]::Round(($MeasureElementsYara.Sum / $MeasureElementsDiscover.Sum * 100), 3, [System.MidpointRounding]::ToZero)) ?? 0
			}
		)
		Return $ElementsTable
	}
	[String]GetSizeUnit([UInt64]$Value = 0) {
		Return @"
$Value  B
$([Math]::Round(($Value / 1KB), 3, [System.MidpointRounding]::ToZero)) KB
$([Math]::Round(($Value / 1MB), 3, [System.MidpointRounding]::ToZero)) MB
$([Math]::Round(($Value / 1GB), 3, [System.MidpointRounding]::ToZero)) GB
"@
	}
	[PSCustomObject[]]GetSizesTable() {
		$MeasureSizesDiscover = $This.SizesDiscover |
			Measure-Object -StandardDeviation -Sum -Average -Maximum -Minimum
		$MeasureSizesScan = $This.SizesScan |
			Measure-Object -StandardDeviation -Sum -Average -Maximum -Minimum
		$MeasureSizesClamAV = $This.SizesClamAV |
			Measure-Object -StandardDeviation -Sum -Average -Maximum -Minimum
		$MeasureSizesYara = $This.SizesYara |
			Measure-Object -StandardDeviation -Sum -Average -Maximum -Minimum
		[Boolean]$IsNoSizes = $MeasureSizesDiscover.Sum -eq 0
		[PSCustomObject[]]$SizesTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				Sum = $This.GetSizeUnit($MeasureSizesDiscover.Sum)
				Minimum = $This.GetSizeUnit($MeasureSizesDiscover.Minimum)
				Average = $This.GetSizeUnit($MeasureSizesDiscover.Average)
				Maximum = $This.GetSizeUnit($MeasureSizesDiscover.Maximum)
				StandardDeviation = $This.GetSizeUnit($MeasureSizesDiscover.StandardDeviation)
				Percentage = $Null
			},
			[PSCustomObject]@{
				Type = 'Scan'
				Sum = $This.GetSizeUnit($MeasureSizesScan.Sum)
				Minimum = $This.GetSizeUnit($MeasureSizesScan.Minimum)
				Average = $This.GetSizeUnit($MeasureSizesScan.Average)
				Maximum = $This.GetSizeUnit($MeasureSizesScan.Maximum)
				StandardDeviation = $This.GetSizeUnit($MeasureSizesScan.StandardDeviation)
				Percentage = ($IsNoSizes ? 0 : [Math]::Round(($MeasureSizesScan.Sum / $This.TotalSizesDiscover * 100), 3, [System.MidpointRounding]::ToZero)) ?? 0
			},
			[PSCustomObject]@{
				Type = 'ClamAV'
				Sum = $This.GetSizeUnit($MeasureSizesClamAV.Sum)
				Minimum = $This.GetSizeUnit($MeasureSizesClamAV.Minimum)
				Average = $This.GetSizeUnit($MeasureSizesClamAV.Average)
				Maximum = $This.GetSizeUnit($MeasureSizesClamAV.Maximum)
				StandardDeviation = $This.GetSizeUnit($MeasureSizesClamAV.StandardDeviation)
				Percentage = ($IsNoSizes ? 0 : [Math]::Round(($MeasureSizesClamAV.Sum / $This.TotalSizesDiscover * 100), 3, [System.MidpointRounding]::ToZero)) ?? 0
			},
			[PSCustomObject]@{
				Type = 'Yara'
				Sum = $This.GetSizeUnit($MeasureSizesYara.Sum)
				Minimum = $This.GetSizeUnit($MeasureSizesYara.Minimum)
				Average = $This.GetSizeUnit($MeasureSizesYara.Average)
				Maximum = $This.GetSizeUnit($MeasureSizesYara.Maximum)
				StandardDeviation = $This.GetSizeUnit($MeasureSizesYara.StandardDeviation)
				Percentage = ($IsNoSizes ? 0 : [Math]::Round(($MeasureSizesYara.Sum / $This.TotalSizesDiscover * 100), 3, [System.MidpointRounding]::ToZero)) ?? 0
			}
		)
		Return $SizesTable
	}
	[Void]ConclusionDisplay() {
		Try {
			If ($This.IsOverflow) {
				Throw 'Overflow'
			}
			$DisplayList = [Ordered]@{
				TotalElements = $This.GetElementsTable() |
					Format-Table -Property @(
						'Type',
						@{ Expression = 'Sum'; Alignment = 'Right' }
						@{ Expression = 'Minimum'; Alignment = 'Right' }
						@{ Expression = 'Average'; Alignment = 'Right' }
						@{ Expression = 'Maximum'; Alignment = 'Right' }
						@{ Expression = 'StandardDeviation'; Alignment = 'Right' }
						@{ Expression = 'Percentage'; Name = '%'; Alignment = 'Right' }
					) -AutoSize -Wrap |
					Out-String -Width 80
				TotalSizes = $This.GetSizesTable() |
					Format-Table -Property @(
						'Type',
						@{ Expression = 'Sum'; Alignment = 'Right' }
						@{ Expression = 'Minimum'; Alignment = 'Right' }
						@{ Expression = 'Average'; Alignment = 'Right' }
						@{ Expression = 'Maximum'; Alignment = 'Right' }
						@{ Expression = 'StandardDeviation'; Alignment = 'Right' }
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
	[PSCustomObject]$DisplayList |
		Format-List -Property '*' |
		Out-String -Width 120
)
"@
		}
		Catch {
			Write-GitHubActionsNotice -Message "Statistics is not display: $_"
		}
	}
	[Void]ConclusionSummary() {
		Try {
			If ($This.IsOverflow) {
				Throw 'Overflow'
			}
			Add-StepSummaryStatistics -TotalElements $This.GetElementsTable() -TotalSizes $This.GetSizesTable() -IssuesOperations $This.IssuesOperations -IssuesSessions $This.IssuesSessions
		}
		Catch {
			Write-GitHubActionsNotice -Message "Statistics is not display: $_"
		}
	}
	[Byte]GetExitCode() {
		Return (($This.IssuesSessions.Count -gt 0) ? 1 : 0)
	}
}
