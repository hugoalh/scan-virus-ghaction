#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'control',
		'summary'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Class ScanVirusStatistics {
	[String[]]$Issues = @()
	[String[]]$SessionsFound = @()
	[UInt64[]]$ElementDiscover = @()
	[UInt64[]]$ElementScan = @()
	[UInt64[]]$ElementFound = @()
	[UInt64[]]$ElementClamAVScan = @()
	[UInt64[]]$ElementClamAVFound = @()
	[UInt64[]]$ElementYaraScan = @()
	[UInt64[]]$ElementYaraFound = @()
	[UInt64[]]$SizeDiscover = @()
	[UInt64[]]$SizeScan = @()
	[UInt64[]]$SizeFound = @()
	[UInt64[]]$SizeClamAVScan = @()
	[UInt64[]]$SizeClamAVFound = @()
	[UInt64[]]$SizeYaraScan = @()
	[UInt64[]]$SizeYaraFound = @()
	[PSCustomObject[]]GetStatisticsTable() {
		[String[]]$Types = @('Scan', 'Found')
		If ($Script:ToolHasClamAV) {
			$Types += 'ClamAVScan'
			$Types += 'ClamAVFound'
		}
		If ($Script:ToolHasYara) {
			$Types += 'YaraScan'
			$Types += 'YaraFound'
		}
		$ThisSizeDiscoverSum = (
			$This.SizeDiscover |
				Measure-Object -Sum
		).Sum
		[PSCustomObject[]]$StatisticsTable = @(
			[PSCustomObject]@{
				Type = 'Discover'
				Element = (
					$This.ElementDiscover |
						Measure-Object -Sum
				).Sum.ToString()
				SizeB = $ThisSizeDiscoverSum.ToString()
				SizeKb = ($ThisSizeDiscoverSum / 1KB).ToString('F3')
				SizeMb = ($ThisSizeDiscoverSum / 1MB).ToString('F3')
				SizeGb = ($ThisSizeDiscoverSum / 1GB).ToString('F3')
				SizeTb = ($ThisSizeDiscoverSum / 1TB).ToString('F3')
			}
		)
		ForEach ($Type In $Types) {
			$ThisSizeTypeSum = (
				$This.("Size$($Type)") |
					Measure-Object -Sum
			).Sum
			$StatisticsTable += [PSCustomObject]@{
				Type = $Type
				Element = (
					$This.("Element$($Type)") |
						Measure-Object -Sum
				).Sum.ToString()
				SizeB = $ThisSizeTypeSum.ToString()
				SizeKb = ($ThisSizeTypeSum / 1KB).ToString('F3')
				SizeMb = ($ThisSizeTypeSum / 1MB).ToString('F3')
				SizeGb = ($ThisSizeTypeSum / 1GB).ToString('F3')
				SizeTb = ($ThisSizeTypeSum / 1TB).ToString('F3')
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
					@{ Expression = 'SizeB'; Name = 'Size B'; Alignment = 'Right' },
					@{ Expression = 'SizeKb'; Name = 'Size KB'; Alignment = 'Right' },
					@{ Expression = 'SizeMb'; Name = 'Size MB'; Alignment = 'Right' },
					@{ Expression = 'SizeGb'; Name = 'Size GB'; Alignment = 'Right' },
					@{ Expression = 'SizeTb'; Name = 'Size TB'; Alignment = 'Right' }
				) -AutoSize:$False -Wrap |
				Out-String -Width $Width
		)
	}
	[String]GetStatisticsTableString() {
		Return $This.GetStatisticsTableString(80)
	}
	[Void]StatisticsDisplay() {
		$DisplayList = [Ordered]@{
			Statistics = $This.GetStatisticsTableString()
		}
		If ($This.Issues.Count -gt 0) {
			$DisplayList.("Issues [$($This.Issues.Count)]") = $This.Issues |
				Join-String -Separator "`n" -FormatString '- {0}'
		}
		If ($This.SessionsFound.Count -gt 0) {
			$DisplayList.("SessionsFound [$($This.SessionsFound.Count)]") = $This.SessionsFound |
				Join-String -Separator ', '
		}
		Write-GitHubActionsNotice -Message (
			[PSCustomObject]$DisplayList |
				Format-List -Property '*' |
				Out-String -Width 120
		)
	}
	[Void]StatisticsSummary() {
		Add-StepSummaryStatistics -StatisticsTable $This.GetStatisticsTable() -Issues $This.Issues -SessionsFound $This.SessionsFound
	}
	[Byte]GetExitCode() {
		Return (((
			$This.SizeFound |
				Measure-Object -Sum
		).Sum -gt 0) ? 1 : 0)
	}
}
