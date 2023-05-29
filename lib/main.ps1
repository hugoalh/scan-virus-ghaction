#Requires -PSEdition Core -Version 7.2
Using Module .\enum.psm1
Using Module .\statistics.psm1
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'assets',
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
	Show-EnvironmentVariables
	Show-SoftwareMeta
}
[ScanVirusStatistics]$StatisticsTotal = [ScanVirusStatistics]::New()
[RegEx]$GitHubActionsWorkspaceRootRegEx = [RegEx]::Escape("$($Env:GITHUB_WORKSPACE)/")
Enter-GitHubActionsLogGroup -Title 'Import inputs.'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_listdelimiter' -Mandatory -EmptyStringAsNull
Try {
	[String]$InputTableMarkupInput = Get-GitHubActionsInput -Name 'input_tablemarkup' -Mandatory -EmptyStringAsNull -Trim
	[ScanVirusInputTableMarkup]$InputTableMarkup = [ScanVirusInputTableMarkup]::($InputTableMarkupInput)
}
Catch {
	Write-GitHubActionsFail -Message "``$InputTableMarkupInput`` is not a valid table markup language: $_" -Finally {
		Exit-GitHubActionsLogGroup
	}
}
[AllowEmptyCollection()][Uri[]]$Targets = Get-InputList -Name 'targets' -Delimiter $InputListDelimiter |
	ForEach-Object -Process { $_ -as [Uri] }
[Boolean]$GitIntegrate = [Boolean]::Parse((Get-GitHubActionsInput -Name 'git_integrate' -Mandatory -EmptyStringAsNull -Trim))
[AllowEmptyCollection()][PSCustomObject[]]$GitIgnores = (Get-InputTable -Name 'git_ignores' -Markup $InputTableMarkup) ?? @()
[Boolean]$GitLfs = [Boolean]::Parse((Get-GitHubActionsInput -Name 'git_lfs' -Mandatory -EmptyStringAsNull -Trim))
[UInt64]$GitLimit = [UInt64]::Parse((Get-GitHubActionsInput -Name 'git_limit' -Mandatory -EmptyStringAsNull -Trim))
[Boolean]$GitReverse = [Boolean]::Parse((Get-GitHubActionsInput -Name 'git_reverse' -Mandatory -EmptyStringAsNull -Trim))
[Boolean]$ClamAVEnable = $AllBundle ? [Boolean]::Parse((Get-GitHubActionsInput -Name 'clamav_enable' -Mandatory -EmptyStringAsNull -Trim)) : $ClamAVForce
[AllowEmptyCollection()][RegEx[]]$ClamAVUnofficialAssetsInput = $ClamAVBundle ? ((Get-InputList -Name 'clamav_unofficialassets' -Delimiter $InputListDelimiter) ?? @()) : @()
[Boolean]$ClamAVUpdate = $ClamAVBundle ? [Boolean]::Parse((Get-GitHubActionsInput -Name 'clamav_update' -Mandatory -EmptyStringAsNull -Trim)) : $False
[Boolean]$YaraEnable = $AllBundle ? [Boolean]::Parse((Get-GitHubActionsInput -Name 'yara_enable' -Mandatory -EmptyStringAsNull -Trim)) : $YaraForce
[AllowEmptyCollection()][RegEx[]]$YaraUnofficialAssetsInput = $YaraBundle ? ((Get-InputList -Name 'yara_unofficialassets' -Delimiter $InputListDelimiter) ?? @()) : @()
[AllowEmptyCollection()][PSCustomObject[]]$Ignores = (Get-InputTable -Name 'ignores' -Markup $InputTableMarkup) ?? @()
Try {
	[String]$LogElementsInput = Get-GitHubActionsInput -Name 'log_elements' -Mandatory -EmptyStringAsNull -Trim
	[ScanVirusLogElementsChoices]$LogElements = [ScanVirusLogElementsChoices]::($LogElementsInput)
}
Catch {
	Write-GitHubActionsFail -Message "``$LogElementsInput`` is not a valid value of log elements usage: $_" -Finally {
		Exit-GitHubActionsLogGroup
	}
}
Try {
	[String]$SummaryFoundInput = Get-GitHubActionsInput -Name 'summary_found' -Mandatory -EmptyStringAsNull -Trim
	[ScanVirusStepSummaryChoices]$SummaryFound = [ScanVirusStepSummaryChoices]::($SummaryFoundInput)
}
Catch {
	Write-GitHubActionsFail -Message "``$SummaryFoundInput`` is not a valid value of found summary usage: $_" -Finally {
		Exit-GitHubActionsLogGroup
	}
}
Try {
	[String]$SummaryStatisticsInput = Get-GitHubActionsInput -Name 'summary_statistics' -Mandatory -EmptyStringAsNull -Trim
	[ScanVirusStepSummaryChoices]$SummaryStatistics = [ScanVirusStepSummaryChoices]::($SummaryStatisticsInput)
}
Catch {
	Write-GitHubActionsFail -Message "``$SummaryStatisticsInput`` is not a valid value of statistics summary usage: $_" -Finally {
		Exit-GitHubActionsLogGroup
	}
}
[PSCustomObject]@{
	Bundle = $Env:GHACTION_SCANVIRUS_BUNDLE
	Input_ListDelimiter = $InputListDelimiter.ToString()
	Input_TableMarkup = $InputTableMarkup.ToString()
	"Targets [$($Targets.Count)]" = ($Targets.Count -eq 0) ? '{Local}' : (
		$Targets |
			Select-Object -ExpandProperty 'OriginalString' |
			Join-String -Separator ', '
	)
	Git_Integrate = $GitIntegrate
	"Git_Ignores [$($GitIgnores.Count)]" = $GitIgnores |
		Format-List -Property '*' |
		Out-String -Width 80
	Git_LFS = $GitLfs
	Git_Limit = $GitLimit
	Git_Reverse = $GitReverse
	ClamAV_Enable = $ClamAVEnable
	ClamAV_UnofficialAssets_RegEx = $ClamAVUnofficialAssetsInput |
		Join-String -Separator '|'
	ClamAV_Update = $ClamAVUpdate
	YARA_Enable = $YaraEnable
	YARA_UnofficialAssets_RegEx = $YaraUnofficialAssetsInput |
		Join-String -Separator '|'
	"Ignores [$($Ignores.Count)]" = $Ignores |
		Format-List -Property '*' |
		Out-String -Width 80
	Log_Elements = $LogElements.ToString()
	Summary_Found = $SummaryFound.ToString()
	Summary_Statistics = $SummaryStatistics.ToString()
} |
	Format-List |
	Out-String -Width 120 |
	Write-Host
Exit-GitHubActionsLogGroup
If ($True -inotin @($ClamAVEnable, $YaraEnable)) {
	Write-GitHubActionsFail -Message 'No tools are enabled!'
}
If (!$GitLfs) {
	Disable-GitLfsProcess
}
If ($ClamAVEnable -and $ClamAVUpdate) {
	Update-ClamAV
}
If ($ClamAVEnable -and $ClamAVUnofficialAssetsInput.Count -gt 0) {
	Enter-GitHubActionsLogGroup -Title 'Register ClamAV unofficial assets.'
	[Hashtable]$Result = Register-ClamAVUnofficialAssets -Selection $ClamAVUnofficialAssetsInput
	ForEach ($ApplyIssue In $Result.ApplyIssues) {
		$StatisticsTotal.IssuesOperations += "ClamAV/UnofficialAssets/$ApplyIssue"
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
		$Script:StatisticsTotal.IssuesOperations += "Workspace/$SessionId"
		Write-Host -Object "End of session `"$SessionTitle`"."
		Return
	}
	[ScanVirusStatistics]$StatisticsSession = [ScanVirusStatistics]::new()
	$StatisticsSession.ElementDiscover = $Elements.Count
	$StatisticsSession.ElementScan = $Elements |
		Where-Object -FilterScript { !$_.SkipAll } |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	$StatisticsSession.ElementClamAV = $ClamAVEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipClamAV } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	) : 0
	$StatisticsSession.ElementYara = $YaraEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipYara } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	) : 0
	$StatisticsSession.SizeDiscover = $Elements |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	$StatisticsSession.SizeScan = $Elements |
		Where-Object -FilterScript { !$_.SkipAll } |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	$StatisticsSession.SizeClamAV = $ClamAVEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipClamAV } |
			Measure-Object -Property 'Size' -Sum |
			Select-Object -ExpandProperty 'Sum'
	) : 0
	$StatisticsSession.SizeYara = $YaraEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipYara } |
			Measure-Object -Property 'Size' -Sum |
			Select-Object -ExpandProperty 'Sum'
	) : 0
	Try {
		$Script:StatisticsTotal.ElementDiscover += $StatisticsSession.ElementDiscover
		$Script:StatisticsTotal.ElementScan += $StatisticsSession.ElementScan
		$Script:StatisticsTotal.ElementClamAV += $StatisticsSession.ElementClamAV
		$Script:StatisticsTotal.ElementYara += $StatisticsSession.ElementYara
		$Script:StatisticsTotal.SizeDiscover += $StatisticsSession.SizeDiscover
		$Script:StatisticsTotal.SizeScan += $StatisticsSession.SizeScan
		$Script:StatisticsTotal.SizeClamAV += $StatisticsSession.SizeClamAV
		$Script:StatisticsTotal.SizeYara += $StatisticsSession.SizeYara
	}
	Catch {
		$Script:StatisticsTotal.IsOverflow = $True
	}
	If (
		$LogElements.GetHashCode() -eq ([ScanVirusLogElementsChoices]::All).GetHashCode() -or
		($LogElements.GetHashCode() -eq ([ScanVirusLogElementsChoices]::OnlyCurrent).GetHashCode() -and $SessionId -ieq 'current')
	) {
		Enter-GitHubActionsLogGroup -Title "Elements of session `"$SessionTitle`": "
		Write-Host -Object $StatisticsSession.GetStatisticsTableString(120)
		$Elements |
			Format-Table -Property @(
				'Flag',
				@{ Expression = 'Size'; Alignment = 'Right' },
				'Path'
			) -AutoSize -Wrap |
			Out-String -Width 120 |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	[PSCustomObject[]]$ResultFound = @()
	If ($ClamAVEnable -and $StatisticsSession.ElementClamAV -gt 0) {
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
				$Script:StatisticsTotal.IssuesOperations += "$SessionId/ClamAV"
			}
			$ResultFound += $Result.Found
		}
		Catch {
			Write-GitHubActionsError -Message $_
			$Script:StatisticsTotal.IssuesOperations += "$SessionId/ClamAV"
		}
		Exit-GitHubActionsLogGroup
	}
	If ($YaraEnable -and $StatisticsSession.ElementYara -gt 0) {
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
			$Script:StatisticsTotal.IssuesOperations += "$SessionId/YARA"
		}
		Exit-GitHubActionsLogGroup
	}
	If ($ResultFound.Count -gt 0) {
		[PSCustomObject[]]$ResultFoundNotIgnore = @()
		[PSCustomObject[]]$ResultFoundIgnore = @()
		ForEach ($Row In (
			$ResultFound |
				Group-Object -Property @('Element', 'Symbol') -NoElement
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
		$ResultFoundNotIgnore = $ResultFoundNotIgnore |
			Sort-Object -Property @('Path', 'Symbol') |
			Sort-Object -Property @('Hit') -Descending
		$ResultFoundIgnore = $ResultFoundIgnore |
			Sort-Object -Property @('Path', 'Symbol') |
			Sort-Object -Property @('Hit') -Descending
		If ($ResultFoundNotIgnore.Count -gt 0) {
			$Script:StatisticsTotal.IssuesSessions += $SessionId
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
		}
		If ($SummaryFound.GetHashCode() -ne ([ScanVirusStepSummaryChoices]::None).GetHashCode() -and (
			$ResultFoundNotIgnore.Count -gt 0 -or
			$ResultFoundIgnore.Count -gt 0
		)) {
			[PSCustomObject[]]$ResultFoundDisplay = @()
			If ($ResultFoundNotIgnore.Count -gt 0) {
				$ResultFoundDisplay += $ResultFoundNotIgnore |
					ForEach-Object -Process { [PSCustomObject]@{
						Indicator = '🔴'
						Path = $_.Path
						Symbol = $_.Symbol
						Hit = $_.Hit
					} }
			}
			If ($ResultFoundIgnore.Count -gt 0) {
				$ResultFoundDisplay += $ResultFoundIgnore |
					ForEach-Object -Process { [PSCustomObject]@{
						Indicator = '🟡'
						Path = $_.Path
						Symbol = $_.Symbol
						Hit = $_.Hit
					} }
			}
			Add-StepSummaryFound -Session $SessionId -Issue $ResultFoundDisplay
		}
	}
	Write-Host -Object "End of session `"$SessionTitle`"."
}
If ($Targets.Count -eq 0) {
	Invoke-Tools -SessionId 'current' -SessionTitle 'Current'
	If ($GitIntegrate -and (Test-IsGitRepository)) {
		[String[]]$GitCommitsHash = Get-GitCommitsIndexes -SortFromOldest:($GitReverse)
		If ($GitCommitsHash.Count -le 1) {
			Write-GitHubActionsWarning -Message "Current Git repository has $($GitCommitsHash.Count) commit! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow."
		}
		[UInt64]$GitCommitsPassCount = 0
		For ([UInt64]$GitCommitsHashIndex = 0; $GitCommitsHashIndex -lt $GitCommitsHash.Count; $GitCommitsHashIndex += 1) {
			[String]$GitCommitHash = $GitCommitsHash[$GitCommitsHashIndex]
			[String]$GitSessionTitle = "$GitCommitHash [#$($GitCommitsHashIndex + 1)/$($GitCommitsHash.Count)]"
			If ($GitLimit -gt 0 -and $GitCommitsPassCount -ge $GitLimit) {
				Write-Host -Object "Ignore Git commit $($GitSessionTitle): Reach the Git commits count limit"
				Continue
			}
			$GitCommit = Get-GitCommitMeta -Index $GitCommitHash
			If ($Null -ieq $GitCommit) {
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
				git checkout $GitCommitHash --force --quiet
				If ($LASTEXITCODE -ne 0) {
					Throw "Exit code ``$LASTEXITCODE``"
				}
			}
			Catch {
				Write-GitHubActionsError -Message "Unexpected issues when invoke Git checkout with commit hash ``$($GitCommitHash)``: $_"
				$StatisticsTotal.IssuesOperations += "Git/$GitCommitHash"
				Exit-GitHubActionsLogGroup
				Continue
			}
			Exit-GitHubActionsLogGroup
			Invoke-Tools -SessionId $GitCommitHash -SessionTitle "Git Commit $GitSessionTitle"
		}
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
	$StatisticsTotal.StatisticsDisplay()
}
If ($SummaryStatistics.GetHashCode() -ne ([ScanVirusStepSummaryChoices]::None).GetHashCode()) {
	$StatisticsTotal.StatisticsSummary()
}
Exit $StatisticsTotal.GetExitCode()
