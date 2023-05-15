#Requires -PSEdition Core -Version 7.2
Using Module .\enum.psm1
Using Module .\statistics.psm1
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'assets',
		'display',
		'git',
		'internal',
		'step-summary'
		'tool',
		'ware-meta'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Write-Host -Object 'Initialize.'
If (Get-GitHubActionsIsDebug) {
	Get-WareMeta
}
[ScanVirusStatistics]$Statistics = [ScanVirusStatistics]::New()
[RegEx]$GitHubActionsWorkspaceRootRegEx = [RegEx]::Escape("$($Env:GITHUB_WORKSPACE)/")
Enter-GitHubActionsLogGroup -Title 'Import inputs.'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_listdelimiter' -Mandatory -EmptyStringAsNull
Write-NameValue -Name 'Input_ListDelimiter' -Value $InputListDelimiter.ToString()
Try {
	[String]$InputTableMarkupInput = Get-GitHubActionsInput -Name 'input_tablemarkup' -Mandatory -EmptyStringAsNull -Trim
	[ScanVirusInputTableMarkup]$InputTableMarkup = [ScanVirusInputTableMarkup]::($InputTableMarkupInput)
}
Catch {
	Write-GitHubActionsFail -Message "``$InputTableMarkupInput`` is not a valid table markup language: $_" -Finally {
		Exit-GitHubActionsLogGroup
	}
}
Write-NameValue -Name 'Input_TableMarkup' -Value $InputTableMarkup.ToString()
[AllowEmptyCollection()][Uri[]]$Targets = Get-InputList -Name 'targets' -Delimiter $InputListDelimiter |
	ForEach-Object -Process { $_ -as [Uri] }
Write-NameValue -Name "Targets [$($Targets.Count)]" -Value (($Targets.Count -eq 0) ? '{Local}' : (
	$Targets |
		Select-Object -ExpandProperty 'OriginalString' |
		Join-String -Separator ', ' -FormatString '`{0}`'
))
[Boolean]$GitIntegrate = Get-InputBoolean -Name 'git_integrate'
Write-NameValue -Name 'Git_Integrate' -Value $GitIntegrate
[AllowEmptyCollection()][PSCustomObject[]]$GitIgnores = (Get-InputTable -Name 'git_ignores' -Markup $InputTableMarkup) ?? @()
Write-NameValue -Name "Git_Ignores [$($GitIgnores.Count)]" -Value (
	$GitIgnores |
		Format-List -Property '*' |
		Out-String -Width 120
) -NewLine
[UInt64]$GitLimit = [UInt64]::Parse((Get-GitHubActionsInput -Name 'git_limit' -EmptyStringAsNull))
Write-NameValue -Name 'Git_Limit' -Value $GitLimit
[Boolean]$GitReverse = Get-InputBoolean -Name 'git_reverse'
Write-NameValue -Name 'Git_Reverse' -Value $GitReverse
[Boolean]$ClamAVEnable = Get-InputBoolean -Name 'clamav_enable'
Write-NameValue -Name 'ClamAV_Enable' -Value $ClamAVEnable
[AllowEmptyCollection()][RegEx[]]$ClamAVUnofficialAssetsInput = Get-InputList -Name 'clamav_unofficialassets' -Delimiter $InputListDelimiter
Write-NameValue -Name "ClamAV_UnofficialAssets_RegEx" -Value (
	$ClamAVUnofficialAssetsInput |
		Join-String -Separator '|'
)
[Boolean]$ClamAVUpdate = Get-InputBoolean -Name 'clamav_update'
Write-NameValue -Name 'ClamAV_Update' -Value $ClamAVUpdate
[Boolean]$YaraEnable = Get-InputBoolean -Name 'yara_enable'
Write-NameValue -Name 'YARA_Enable' -Value $YaraEnable
[AllowEmptyCollection()][RegEx[]]$YaraUnofficialAssetsInput = Get-InputList -Name 'yara_unofficialassets' -Delimiter $InputListDelimiter
Write-NameValue -Name "YARA_UnofficialAssets_RegEx" -Value (
	$YaraUnofficialAssetsInput |
		Join-String -Separator '|'
)
[AllowEmptyCollection()][PSCustomObject[]]$Ignores = (Get-InputTable -Name 'ignores' -Markup $InputTableMarkup) ?? @()
Write-NameValue -Name "Ignores [$($Ignores.Count)]" -Value (
	$Ignores |
		Format-List -Property '*' |
		Out-String -Width 120
) -NewLine
Try {
	[String]$SummaryFoundInput = Get-GitHubActionsInput -Name 'summary_found' -Mandatory -EmptyStringAsNull -Trim
	[ScanVirusStepSummaryChoices]$SummaryFound = [ScanVirusStepSummaryChoices]::($SummaryFoundInput)
}
Catch {
	Write-GitHubActionsFail -Message "``$SummaryFoundInput`` is not a valid found summary usage: $_" -Finally {
		Exit-GitHubActionsLogGroup
	}
}
Write-NameValue -Name 'Summary_Found' -Value $SummaryFound.ToString()
Try {
	[String]$SummaryStatisticsInput = Get-GitHubActionsInput -Name 'summary_statistics' -Mandatory -EmptyStringAsNull -Trim
	[ScanVirusStepSummaryChoices]$SummaryStatistics = [ScanVirusStepSummaryChoices]::($SummaryStatisticsInput)
}
Catch {
	Write-GitHubActionsFail -Message "``$SummaryStatisticsInput`` is not a valid statistics summary usage: $_" -Finally {
		Exit-GitHubActionsLogGroup
	}
}
Write-NameValue -Name 'Summary_Statistics' -Value $SummaryStatistics.ToString()
Exit-GitHubActionsLogGroup
If ($True -inotin @($ClamAVEnable, $YaraEnable)) {
	Write-GitHubActionsFail -Message 'No tools are enabled!'
}
If ($ClamAVUpdate -and $ClamAVEnable) {
	Update-ClamAV
}
If ($ClamAVEnable -and $ClamAVUnofficialAssetsInput.Count -gt 0) {
	Enter-GitHubActionsLogGroup -Title 'Register ClamAV unofficial assets.'
	[Hashtable]$Result = Register-ClamAVUnofficialAssets -Selection $ClamAVUnofficialAssetsInput
	ForEach ($ApplyIssue In $Result.ApplyIssues) {
		$Statistics.IssuesOperations += "ClamAV/UnofficialAssets/$ApplyIssue"
	}
	Exit-GitHubActionsLogGroup
}
[PSCustomObject[]]$YaraUnofficialAssetsIndexTable = @()
If ($YaraEnable -and $YaraUnofficialAssetsInput.Count -gt 0) {
	Enter-GitHubActionsLogGroup -Title 'Register YARA unofficial assets.'
	$YaraUnofficialAssetsIndexTable = Register-YaraUnofficialAssets -Selection $YaraUnofficialAssetsInput
	Exit-GitHubActionsLogGroup
}
If ($ClamAVEnable) {
	Start-ClamAVDaemon
}
Function Invoke-Tools {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$SessionId,
		[Parameter(Mandatory = $True, Position = 1)][String]$SessionTitle
	)
	Write-Host -Object "Begin of session `"$SessionTitle`"."
	[AllowEmptyCollection()][PSCustomObject[]]$Elements = Get-ChildItem -LiteralPath $Env:GITHUB_WORKSPACE -Recurse -Force |
		Sort-Object -Property @('FullName') |
		ForEach-Object -Process {
			[Hashtable]$ElementObject = @{
				FullName = $_.FullName
				Path = $_.FullName -ireplace "^$GitHubActionsWorkspaceRootRegEx", ''
				Size = $_.Length
				IsDirectory = $_.PSIsContainer
			}
			$ElementObject.SkipAll = $ElementObject.IsDirectory -or (Test-ElementIsIgnore -Element ([PSCustomObject]@{
				Path = $ElementObject.Path
				Session = $SessionId
			}) -Combination @(
				@('Path'),
				@('Path', 'Session')
			) -Ignore $Ignores)
			$ElementObject.SkipClamAV = $ElementObject.SkipAll -or (Test-ElementIsIgnore -Element ([PSCustomObject]@{
				Path = $ElementObject.Path
				Session = $SessionId
				Tool = 'clamav'
			}) -Combination @(
				@('Path', 'Tool'),
				@('Path', 'Session', 'Tool')
			) -Ignore $Ignores)
			$ElementObject.SkipYara = $ElementObject.SkipAll -or (Test-ElementIsIgnore -Element ([PSCustomObject]@{
				Path = $ElementObject.Path
				Session = $SessionId
				Tool = 'yara'
			}) -Combination @(
				@('Path', 'Tool'),
				@('Path', 'Session', 'Tool')
			) -Ignore $Ignores)
			[String[]]$ElementFlags = @()
			If ($ElementObject.IsDirectory) {
				$ElementFlags += 'D'
			}
			If (!$ElementObject.SkipClamAV -and $ClamAVEnable) {
				$ElementFlags += 'C'
			}
			If (!$ElementObject.SkipYara -and $YaraEnable) {
				$ElementFlags += 'Y'
			}
			$ElementObject.Flag = $ElementFlags |
				Sort-Object |
				Join-String -Separator ''
			[PSCustomObject]$ElementObject |
				Write-Output
		}
	If ($Elements.Count -eq 0){
		Write-GitHubActionsError -Message @"
Unable to scan session `"$SessionTitle`": Workspace is empty!
If this is incorrect, probably something went wrong.
"@
		$Script:Statistics.IssuesOperations += "Workspace/$SessionId"
		Write-Host -Object "End of session `"$SessionTitle`"."
		Return
	}
	[UInt64]$ElementsCountDiscover = $Elements.Count
	[UInt64]$ElementsCountScan = $Elements |
		Where-Object -FilterScript { !$_.SkipAll } |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	[UInt64]$ElementsCountClamAV = $ClamAVEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipClamAV } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	) : 0
	[UInt64]$ElementsCountYara = $YaraEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipYara } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	) : 0
	[UInt64]$ElementsSizeDiscover = $Elements |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	[UInt64]$ElementsSizeScan = $Elements |
		Where-Object -FilterScript { !$_.SkipAll } |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	[UInt64]$ElementsSizeClamAV = $ClamAVEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipClamAV } |
			Measure-Object -Property 'Size' -Sum |
			Select-Object -ExpandProperty 'Sum'
	) : 0
	[UInt64]$ElementsSizeYara = $YaraEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipYara } |
			Measure-Object -Property 'Size' -Sum |
			Select-Object -ExpandProperty 'Sum'
	) : 0
	Try {
		$Script:Statistics.TotalElementsDiscover += $ElementsCountDiscover
		$Script:Statistics.TotalElementsScan += $ElementsCountScan
		$Script:Statistics.TotalElementsClamAV += $ElementsCountClamAV
		$Script:Statistics.TotalElementsYara += $ElementsCountYara
		$Script:Statistics.TotalSizesDiscover += $ElementsSizeDiscover
		$Script:Statistics.TotalSizesScan += $ElementsSizeScan
		$Script:Statistics.TotalSizesClamAV += $ElementsSizeClamAV
		$Script:Statistics.TotalSizesYara += $ElementsSizeYara
	}
	Catch {
		$Script:Statistics.IsOverflow = $True
	}
	Enter-GitHubActionsLogGroup -Title "Elements of session `"$SessionTitle`": "
	@(
		[PSCustomObject]@{ Type = 'Discover'; Count = $ElementsCountDiscover; Size = $ElementsSizeDiscover }
		[PSCustomObject]@{ Type = 'Scan'; Count = $ElementsCountScan; Size = $ElementsSizeScan }
		[PSCustomObject]@{ Type = 'ClamAV'; Count = $ElementsCountClamAV; Size = $ElementsSizeClamAV }
		[PSCustomObject]@{ Type = 'Yara'; Count = $ElementsCountYara; Size = $ElementsSizeYara }
	) |
		Format-Table -Property @(
			'Type',
			@{ Expression = 'Count'; Alignment = 'Right' },
			@{ Expression = 'Size'; Alignment = 'Right' }
		) -AutoSize -Wrap |
		Out-String -Width 120 |
		Write-Host
	$Elements |
		Format-Table -Property @(
			'Flag',
			@{ Expression = 'Size'; Alignment = 'Right' },
			'Path'
		) -AutoSize -Wrap |
		Out-String -Width 120 |
		Write-Host
	Exit-GitHubActionsLogGroup
	[PSCustomObject[]]$ResultFound = @()
	If ($ClamAVEnable -and $ElementsCountClamAV -gt 0) {
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via ClamAV."
		Try {
			[Hashtable]$Result = Invoke-ClamAVScan -Target (
				$Elements |
					Where-Object -FilterScript { !$_.SkipClamAV } |
					Select-Object -ExpandProperty 'FullName'
			)
			Write-GitHubActionsDebug -Message (
				$Result.Output |
					Join-String -Separator "`n"
			)
			If ($Result.ErrorMessage.Count -gt 0) {
				Write-GitHubActionsError -Message @"
Unexpected issue in session `"$SessionTitle`" via ClamAV:

$(
	$Result.ErrorMessage |
		Join-String -Separator "`n" -FormatString '- {0}'
)
"@
				$Script:Statistics.IssuesOperations += "$SessionId/ClamAV"
			}
			$ResultFound += $Result.Found
		}
		Catch {
			Write-GitHubActionsError -Message $_
			$Script:Statistics.IssuesOperations += "$SessionId/ClamAV"
		}
		Exit-GitHubActionsLogGroup
	}
	If ($YaraEnable -and $ElementsCountYara -gt 0) {
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via YARA."
		[String[]]$YaraResultIssue = @()
		ForEach ($YaraUnofficialAsset In (
			$YaraUnofficialAssetsIndexTable |
				Where-Object -FilterScript { $_.Select }
		)) {
			Try {
				[Hashtable]$Result = Invoke-Yara -Target (
					$Elements |
						Where-Object -FilterScript { !$_.SkipYara } |
						Select-Object -ExpandProperty 'FullName'
				) -Asset $YaraUnofficialAsset
				If ($Result.Output.Count -gt 0) {
					Write-GitHubActionsDebug -Message (
						$Result.Output |
							Join-String -Separator "`n"
					)
				}
				If ($Result.ErrorMessage.Count -gt 0) {
					$YaraResultIssue += $Result.ErrorMessage
				}
				$ResultFound += $Result.Found
			}
			Catch {
				$YaraResultIssue += $_
			}	
		}
		If ($YaraResultIssue.Count -gt 0) {
			Write-GitHubActionsError -Message @"
Unexpected issue in session `"$SessionTitle`" via YARA:

$(
$YaraResultIssue |
	Join-String -Separator "`n" -FormatString '- {0}'
)
"@
			$Script:Statistics.IssuesOperations += "$SessionId/YARA"
		}
		Exit-GitHubActionsLogGroup
	}
	If ($ResultFound.Count -gt 0) {
		[PSCustomObject[]]$ResultFoundNotIgnore = @()
		[PSCustomObject[]]$ResultFoundIgnore = @()
		ForEach ($Row In (
			$ResultFound |
				Group-Object -Property @('Element', 'Symbol') -NoElement |
				Sort-Object -Property 'Name'
		)) {
			[String]$Element, [String]$Symbol = $Row.Name -isplit ', '
			[PSCustomObject]$ResultFoundElementObject = [PSCustomObject]@{
				Path = $Element
				Symbol = $Symbol
				Hit = $Row.Count
			}
			If (Test-ElementIsIgnore -Element ([PSCustomObject]@{
				Path = $Element
				Session = $SessionId
				Symbol = $Symbol
			}) -Combination @(
				@('Symbol'),
				@('Path', 'Symbol'),
				@('Path', 'Session', 'Symbol')
			) -Ignore $Ignores) {
				$ResultFoundIgnore += $ResultFoundElementObject
			}
			Else {
				$ResultFoundNotIgnore += $ResultFoundElementObject
			}
		}
		If ($ResultFoundNotIgnore.Count -gt 0) {
			If ($SummaryFound.GetHashCode() -ne ([ScanVirusStepSummaryChoices]::Redirect).GetHashCode()) {
				Write-GitHubActionsError -Message @"
Found in session `"$SessionTitle`":
$(
	$ResultFoundNotIgnore |
		Format-Table -Property @(
			@{ Expression = 'Hit'; Alignment = 'Right' },
			'Symbol',
			'Path'
		) -AutoSize -Wrap |
		Out-String -Width 120
)
"@
			}
			If ($SummaryFound.GetHashCode() -ne ([ScanVirusStepSummaryChoices]::None).GetHashCode()) {
				Add-StepSummaryFound -Session $SessionId -Indicator '🔴' -Issue $ResultFoundNotIgnore
			}
			$Script:Statistics.IssuesSessions += $SessionId
		}
		If ($ResultFoundIgnore.Count -gt 0) {
			If ($SummaryFound.GetHashCode() -ne ([ScanVirusStepSummaryChoices]::Redirect).GetHashCode()) {
				Write-GitHubActionsWarning -Message @"
Found in session `"$SessionTitle`" but ignored:
$(
	$ResultFoundIgnore |
		Format-Table -Property @(
			@{ Expression = 'Hit'; Alignment = 'Right' },
			'Symbol',
			'Path'
		) -AutoSize -Wrap |
		Out-String -Width 120
)
"@
			}
			If ($SummaryFound.GetHashCode() -ne ([ScanVirusStepSummaryChoices]::None).GetHashCode()) {
				Add-StepSummaryFound -Session $SessionId -Indicator '🟡' -Issue $ResultFoundIgnore
			}
		}
	}
	Write-Host -Object "End of session `"$SessionTitle`"."
}
If ($Targets.Count -eq 0) {
	Invoke-Tools -SessionId 'current' -SessionTitle 'Current'
	If ($GitIntegrate) {
		Write-Host -Object 'Import Git commits meta.'
		Try {
			[PSCustomObject]$GitCommitsMetaPayload = Start-GetGitCommits -SortFromOldest:($GitReverse)
			If ($GitCommitsMetaPayload.Total -le 1) {
				Write-GitHubActionsWarning -Message "Current Git repository has $($GitCommitsMetaPayload.Total) commit! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow."
			}
			[PSCustomObject[]]$GitCommits = @()
			[UInt64]$GitCommitsPassCount = 0
			For ([UInt64]$GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommitsMetaPayload.Total;) {
				If ($GitCommitsMetaPayload.Job.State -ieq 'Failed') {
					Throw $GitCommitsMetaPayload.Job.ChildJobs[0].JobStateInfo.Reason.Message
				}
				$GitCommits += Receive-Job -Job $GitCommitsMetaPayload.Job
				$GitCommit = $GitCommits[$GitCommitsIndex]
				If ($Null -ieq $GitCommit) {
					Start-Sleep -Seconds 2
					Continue
				}
				[String]$GitSessionTitle = "$($GitCommit.CommitHash) [#$($GitCommitsIndex + 1)/$($GitCommitsMetaPayload.Total)]"
				If ($GitLimit -gt 0 -and $GitCommitsPassCount -ge $GitLimit) {
					Write-Host -Object "Ignore Git commit $($GitSessionTitle): Reach the Git commits count limit"
					Continue
				}
				If (Test-GitCommitIsIgnore -GitCommit $GitCommit -Ignore $GitIgnores) {
					Write-Host -Object "Ignore Git commit $($GitSessionTitle): Git ignore"
					Continue
				}
				$GitCommitsPassCount += 1
				$GitCommitsIndex += 1
				Enter-GitHubActionsLogGroup -Title "Git checkout for commit $GitSessionTitle."
				$GitCommit |
					Format-List -Property @('AuthorDate', 'AuthorName', 'CommitHash', 'CommitterDate', 'CommitterName', 'Subject') |
					Out-String -Width 120 |
					Write-Host
				Try {
					git checkout $GitCommit.CommitHash --force --quiet
					If ($LASTEXITCODE -ne 0) {
						Throw "Exit code ``$LASTEXITCODE``"
					}
				}
				Catch {
					Write-GitHubActionsError -Message "Unexpected issues when invoke Git checkout with commit hash ``$($GitCommit.CommitHash)``: $_"
					$Statistics.IssuesOperations += "Git/$($GitCommit.CommitHash)"
					Exit-GitHubActionsLogGroup
					Continue
				}
				Exit-GitHubActionsLogGroup
				Invoke-Tools -SessionId $GitCommit.CommitHash -SessionTitle "Git Commit $GitSessionTitle"
			}
		}
		Catch {
			Write-GitHubActionsError -Message $_
		}
		<# Legacy.
		[AllowEmptyCollection()][PSCustomObject[]]$GitCommits = Get-GitCommits -SortFromOldest:($GitReverse)
		If ($GitCommits.Count -le 1) {
			Write-GitHubActionsWarning -Message "Current Git repository has $($GitCommits.Count) commit! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow."
		}
		[UInt64]$GitCommitsPassCount = 0
		For ([UInt64]$GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex += 1) {
			[PSCustomObject]$GitCommit = $GitCommits[$GitCommitsIndex]
			[String]$GitSessionTitle = "$($GitCommit.CommitHash) [#$($GitCommitsIndex + 1)/$($GitCommits.Count)]"
			If ($GitLimit -gt 0 -and $GitCommitsPassCount -ge $GitLimit) {
				Write-Host -Object "Ignore Git commit $($GitSessionTitle): Reach the Git commits count limit"
				Continue
			}
			If (Test-GitCommitIsIgnore -GitCommit $GitCommit -Ignore $GitIgnores) {
				Write-Host -Object "Ignore Git commit $($GitSessionTitle): Git ignore"
				Continue
			}
			$GitCommitsPassCount += 1
			Enter-GitHubActionsLogGroup -Title "Git checkout for commit $GitSessionTitle."
			$GitCommit |
				Format-List -Property @('AuthorDate', 'AuthorName', 'CommitHash', 'CommitterDate', 'CommitterName', 'Subject') |
				Out-String -Width 120 |
				Write-Host
			Try {
				git checkout $GitCommit.CommitHash --force --quiet
				If ($LASTEXITCODE -ne 0) {
					Throw "Exit code ``$LASTEXITCODE``"
				}
			}
			Catch {
				Write-GitHubActionsError -Message "Unexpected issues when invoke Git checkout with commit hash ``$($GitCommit.CommitHash)``: $_"
				$Statistics.IssuesOperations += "Git/$($GitCommit.CommitHash)"
				Exit-GitHubActionsLogGroup
				Continue
			}
			Exit-GitHubActionsLogGroup
			Invoke-Tools -SessionId $GitCommit.CommitHash -SessionTitle "Git Commit $GitSessionTitle"
		}
		#>
	}
}
Else {
	If ((
		Get-ChildItem -LiteralPath $Env:GITHUB_WORKSPACE -Recurse -Force |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	) -gt 0) {
		Write-GitHubActionsFail -Message 'Workspace is not clean for network targets!'
	}
	For ([UInt64]$TargetsIndex = 0; $TargetsIndex -lt $Targets.Count; $TargetsIndex += 1) {
		[String]$Target = $Targets[$TargetsIndex]
		If (!(Test-StringIsUri -InputObject $Target)) {
			Write-GitHubActionsWarning -Message "``$($Target.OriginalString)`` is not a valid URI!"
			Continue
		}
		$NetworkTargetFilePath = Import-NetworkTarget -Target $Target
		If ($Null -ine $NetworkTargetFilePath) {
			Invoke-Tools -SessionId $Target.ToString() -SessionTitle "Remote Target $Target [#$($TargetsIndex + 1)/$($Targets.Count)]"
			Remove-Item -LiteralPath $NetworkTargetFilePath -Force -Confirm:$False
		}
	}
}
If ($ClamAVEnable) {
	Stop-ClamAVDaemon
}
If ($SummaryStatistics.GetHashCode() -ne ([ScanVirusStepSummaryChoices]::Redirect).GetHashCode()) {
	$Statistics.ConclusionDisplay()
}
If ($SummaryStatistics.GetHashCode() -ne ([ScanVirusStepSummaryChoices]::None).GetHashCode()) {
	$Statistics.ConclusionSummary()
}
Exit $Statistics.GetExitCode()
