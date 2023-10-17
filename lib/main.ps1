#Requires -PSEdition Core -Version 7.2
Using Module .\statistics.psm1
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Function Invoke-ProtectiveScriptBlock {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Name,
		[Parameter(Mandatory = $True, Position = 1)][AllowNull()][ScriptBlock]$ScriptBlock,
		[Parameter(Mandatory = $True, Position = 2)][Object[]]$ArgumentList
	)
	If ($Null -ieq $ScriptBlock) {
		Write-Output -InputObject $False
		Return
	}
	Try {
		$Result = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
		If ($Result -is [Boolean]) {
			Write-Output -InputObject $Result
			Return
		}
		Write-GitHubActionsFail -Message "Unexpected issues with script block ``$Name``: Result is not a boolean!"
	}
	Catch {
		Write-GitHubActionsFail -Message "Unexpected issues with script block ``$Name``: $_"
	}
}
Enter-GitHubActionsLogGroup -Title 'Softwares Version: '
Get-Content -LiteralPath $Env:SCANVIRUS_GHACTION_SOFTWARESVERSIONFILE -Raw -Encoding 'UTF8NoBOM' |
	ConvertFrom-Json -Depth 100 |
	Format-List
Exit-GitHubActionsLogGroup
$InputDebugScript = Get-GitHubActionsInput -Name 'debug_script' -EmptyStringAsNull
If ($Null -ine $InputDebugScript) {
	Write-GitHubActionsNotice -Message 'Debug script exists! Only execute debug script.'
	Invoke-Command -ScriptBlock ([ScriptBlock]::Create($InputDebugScript)) |
		Write-Host
	Exit ($LASTEXITCODE ?? 0)
}
Write-Host -Object 'Initialize.'
Set-GitHubActionsOutput -Name 'finish' -Value $False.ToString().ToLower()
Import-Module -Name (
	@(
		'control',
		'summary'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[ScanVirusStatistics]$StatisticsTotal = [ScanVirusStatistics]::New()
[Boolean]$InputClamAVEnable = ($ToolHasClamAV -and !$ToolForceClamAV) ? ([Boolean]::Parse((Get-GitHubActionsInput -Name 'clamav_enable' -Mandatory -EmptyStringAsNull))) : $ToolForceClamAV
[Boolean]$InputClamAVUpdate = ($ToolHasClamAV) ? [Boolean]::Parse((Get-GitHubActionsInput -Name 'clamav_update' -Mandatory -EmptyStringAsNull)) : $False
[RegEx]$InputClamAVUnofficialAssetsUse = ((Get-GitHubActionsInput -Name 'clamav_unofficialassets_use' -EmptyStringAsNull) ?? '') -isplit '\r?\n' |
	Where-Object -FilterScript { $_.Length -gt 0 } |
	Join-String -Separator '|'
$InputClamAVCustomAssetsDirectory = Get-GitHubActionsInput -Name 'clamav_customassets_directory' -EmptyStringAsNull
If ($Null -ine $InputClamAVCustomAssetsDirectory) {
	If (!(Test-Path -LiteralPath $InputClamAVCustomAssetsDirectory -PathType 'Container')) {
		Write-GitHubActionsFail -Message "``$InputClamAVCustomAssetsDirectory`` is not a valid ClamAV custom assets absolute directory path!"
	}
}
[RegEx]$InputClamAVCustomAssetsUse = ((Get-GitHubActionsInput -Name 'clamav_customassets_use' -EmptyStringAsNull) ?? '') -isplit '\r?\n' |
	Where-Object -FilterScript { $_.Length -gt 0 } |
	Join-String -Separator '|'
[Boolean]$InputYaraEnable = ($ToolHasYara -and !$ToolForceYara) ? ([Boolean]::Parse((Get-GitHubActionsInput -Name 'yara_enable' -Mandatory -EmptyStringAsNull))) : $ToolForceYara
[RegEx]$InputYaraUnofficialAssetsUse = ((Get-GitHubActionsInput -Name 'yara_unofficialassets_use' -EmptyStringAsNull) ?? '') -isplit '\r?\n' |
	Where-Object -FilterScript { $_.Length -gt 0 } |
	Join-String -Separator '|'
$InputYaraCustomAssetsDirectory = Get-GitHubActionsInput -Name 'yara_customassets_directory' -EmptyStringAsNull
If ($Null -ine $InputYaraCustomAssetsDirectory) {
	If (!(Test-Path -LiteralPath $InputYaraCustomAssetsDirectory -PathType 'Container')) {
		Write-GitHubActionsFail -Message "``$InputYaraCustomAssetsDirectory`` is not a valid YARA custom assets absolute directory path!"
	}
}
[RegEx]$InputYaraCustomAssetsUse = ((Get-GitHubActionsInput -Name 'yara_customassets_use' -EmptyStringAsNull) ?? '') -isplit '\r?\n' |
	Where-Object -FilterScript { $_.Length -gt 0 } |
	Join-String -Separator '|'
[Boolean]$InputGitIntegrate = [Boolean]::Parse((Get-GitHubActionsInput -Name 'git_integrate' -Mandatory -EmptyStringAsNull))
$InputGitIgnoresRaw = Get-GitHubActionsInput -Name 'git_ignores' -EmptyStringAsNull
If ($Null -ne $InputGitIgnoresRaw) {
	[ScriptBlock]$InputGitIgnores = [ScriptBlock]::Create($InputGitIgnoresRaw)
}
[Boolean]$InputGitLfs = [Boolean]::Parse((Get-GitHubActionsInput -Name 'git_lfs' -Mandatory -EmptyStringAsNull))
[UInt64]$InputGitLimit = [UInt64]::Parse((Get-GitHubActionsInput -Name 'git_limit' -Mandatory -EmptyStringAsNull))
[Boolean]$InputGitReverse = [Boolean]::Parse((Get-GitHubActionsInput -Name 'git_reverse' -Mandatory -EmptyStringAsNull))
$InputIgnoresPreRaw = Get-GitHubActionsInput -Name 'ignores_pre' -EmptyStringAsNull
If ($Null -ne $InputIgnoresPreRaw) {
	[ScriptBlock]$InputIgnoresPre = [ScriptBlock]::Create($InputIgnoresPreRaw)
}
$InputIgnoresPostRaw = Get-GitHubActionsInput -Name 'ignores_post' -EmptyStringAsNull
If ($Null -ne $InputIgnoresPostRaw) {
	[ScriptBlock]$InputIgnoresPost = [ScriptBlock]::Create($InputIgnoresPostRaw)
}
[Boolean]$InputFoundLog = [Boolean]::Parse((Get-GitHubActionsInput -Name 'found_log' -Mandatory -EmptyStringAsNull))
[Boolean]$InputFoundSummary = [Boolean]::Parse((Get-GitHubActionsInput -Name 'found_summary' -Mandatory -EmptyStringAsNull))
[Boolean]$InputStatisticsLog = [Boolean]::Parse((Get-GitHubActionsInput -Name 'statistics_log' -Mandatory -EmptyStringAsNull))
[Boolean]$InputStatisticsSummary = [Boolean]::Parse((Get-GitHubActionsInput -Name 'statistics_summary' -Mandatory -EmptyStringAsNull))
[RegEx]$InputDebugListElements = ((Get-GitHubActionsInput -Name 'debug_listelements' -EmptyStringAsNull) ?? '') -isplit '\r?\n' |
	Where-Object -FilterScript { $_.Length -gt 0 } |
	Join-String -Separator '|'
If (!$InputClamAVEnable -and !$InputYaraEnable) {
	Write-GitHubActionsFail -Message 'No tools are enabled!'
}
If ($InputGitIntegrate) {
	Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'git.psm1') -Scope 'Local'
}
If ($InputClamAVEnable) {
	Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'clamav.psm1') -Scope 'Local'
}
If ($InputYaraEnable) {
	Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'yara.psm1') -Scope 'Local'
}
If ($InputGitIntegrate -and !$InputGitLfs) {
	Write-Host -Object 'Disable Git LFS process.'
	Disable-InputGitLfsProcess
}
If ($InputClamAVEnable -and $InputClamAVUpdate) {
	Write-Host -Object 'Update ClamAV.'
	Update-ClamAV
}
If ($InputClamAVEnable -and $InputClamAVUnofficialAssetsUse.ToString().Length -gt 0) {
	Write-Host -Object 'Register ClamAV unofficial asset.'
	[PSCustomObject]$Result = Register-ClamAVUnofficialAsset -Selection $InputClamAVUnofficialAssetsUse
	ForEach ($ApplyIssue In $Result.ApplyIssues) {
		$StatisticsTotal.IssuesOperations += "ClamAV/UnofficialAsset/$ApplyIssue"
	}
}
If ($InputYaraEnable -and $InputYaraUnofficialAssetsUse.ToString().Length -gt 0) {
	Write-Host -Object 'Register YARA unofficial asset.'
	Register-YaraUnofficialAsset -Selection $InputYaraUnofficialAssetsRaw
}
If ($InputClamAVEnable) {
	Write-Host -Object 'Start ClamAV daemon.'
	Start-ClamAVDaemon
}
Function Invoke-Tools {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$SessionName,
		[Parameter(Mandatory = $True, Position = 1)][AllowNull()][PSCustomObject]$Meta
	)
	Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionName`"."
	[PSCustomObject[]]$Elements = Get-ChildItem -LiteralPath $CurrentWorkingDirectory -Recurse -Force |
		Sort-Object -Property @('FullName') |
		ForEach-Object -Process {
			[Hashtable]$ElementObject = @{
				FullName = $_.FullName
				Path = $_.FullName -ireplace "^$CurrentWorkingDirectoryRegExEscape", ''
				Size = $_.Length
				IsDirectory = $_.PSIsContainer
			}
			$ElementObject.SkipClamAV = !$InputClamAVEnable -or $ElementObject.IsDirectory -or (Invoke-ProtectiveScriptBlock -Name 'ignores_pre' -ScriptBlock $InputIgnoresPre -ArgumentList @($SessionName, ([PSCustomObject]@{
				Path = $ElementObject.Path
				Session = [PSCustomObject]@{
					Name = $SessionName
					GitCommitMeta = $Meta
				}
				Tool = 'clamav'
			})))
			$ElementObject.SkipYara = !$InputYaraEnable -or $ElementObject.IsDirectory -or (Invoke-ProtectiveScriptBlock -Name 'ignores_pre' -ScriptBlock $InputIgnoresPre -ArgumentList @($SessionName, ([PSCustomObject]@{
				Path = $ElementObject.Path
				Session = [PSCustomObject]@{
					Name = $SessionName
					GitCommitMeta = $Meta
				}
				Tool = 'yara'
			})))
			[String[]]$ElementFlags = @()
			If ($ElementObject.IsDirectory) {
				$ElementFlags += 'D'
			}
			If (!$ElementObject.SkipClamAV) {
				$ElementFlags += 'C'
			}
			If (!$ElementObject.SkipYara) {
				$ElementFlags += 'Y'
			}
			$ElementObject.Flag = $ElementFlags |
				Sort-Object |
				Join-String -Separator ''
			Write-Output -InputObject ([PSCustomObject]$ElementObject)
		}
	If ($Elements.Count -eq 0){
		[String]$Message = @"
Unable to scan session `"$SessionName`": Empty!
If this is incorrect, probably something went wrong.
"@
		Write-GitHubActionsError -Message $Message
		$Script:StatisticsTotal.IssuesOperations += $Message
		Exit-GitHubActionsLogGroup
		Return
	}
	[ScanVirusStatistics]$StatisticsSession = [ScanVirusStatistics]::new()
	$StatisticsSession.ElementDiscover = $Elements.Count
	$StatisticsSession.ElementScan = $Elements |
		Where-Object -FilterScript { !$_.SkipClamAV -or !$_.SkipYara } |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	$StatisticsSession.ElementClamAV = $InputClamAVEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipClamAV } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	) : 0
	$StatisticsSession.ElementYara = $InputYaraEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipYara } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	) : 0
	$StatisticsSession.SizeDiscover = $Elements |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	$StatisticsSession.SizeScan = $Elements |
		Where-Object -FilterScript { !$_.SkipClamAV -or !$_.SkipYara } |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	$StatisticsSession.SizeClamAV = $InputClamAVEnable ? (
		$Elements |
			Where-Object -FilterScript { !$_.SkipClamAV } |
			Measure-Object -Property 'Size' -Sum |
			Select-Object -ExpandProperty 'Sum'
	) : 0
	$StatisticsSession.SizeYara = $InputYaraEnable ? (
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
	If ($InputDebugListElements.ToString().Length -gt 0 -and $SessionName -imatch $InputDebugListElements) {
		$Elements |
			Format-Table -Property @(
				@{ Name = ''; Expression = 'Flag' },
				@{ Expression = 'Size'; Alignment = 'Right' },
				'Path'
			) -AutoSize:$False -Wrap |
			Out-String -Width 120 |
			Write-GitHubActionsDebug
	}
	[PSCustomObject[]]$ResultFounds = @()
	If ($InputClamAVEnable -and $StatisticsSession.ElementClamAV -gt 0) {
		Write-Host -Object 'Scan via ClamAV.'
		[PSCustomObject]$Result = Invoke-ClamAVScan -Element (
			$Elements |
				Where-Object -FilterScript { !$_.SkipClamAV } |
				Select-Object -ExpandProperty 'FullName'
		)
		If ($Result.Errors.Count -gt 0) {
			Write-GitHubActionsError -Message @"
Unexpected issue in session `"$SessionName`" via ClamAV:

$(
$Result.Errors |
	Join-String -Separator "`n" -FormatString '- {0}'
)
"@
			$Script:StatisticsTotal.IssuesOperations += $Result.Errors
		}
		$ResultFounds += $Result.Founds
	}
	If ($InputYaraEnable -and $StatisticsSession.ElementYara -gt 0) {
		Write-Host -Object 'Scan via YARA.'
		[PSCustomObject]$Result = Invoke-Yara -Element (
			$Elements |
				Where-Object -FilterScript { !$_.SkipYara } |
				Select-Object -ExpandProperty 'FullName'
		)
		If ($Result.Errors.Count -gt 0) {
			Write-GitHubActionsError -Message @"
Unexpected issue in session `"$SessionName`" via YARA:

$(
$Result.Errors |
	Join-String -Separator "`n" -FormatString '- {0}'
)
"@
			$Script:StatisticsTotal.IssuesOperations += $Result.Errors
		}
		$ResultFounds += $Result.Founds
	}
	$StatisticsSession.ElementFound = $ResultFounds.Element |
		Select-Object -Unique |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	$StatisticsSession.SizeFound = $Elements |
		Where-Object -FilterScript { $_.Path -iin $ResultFounds.Element } |
		Select-Object -ExpandProperty 'Size' |
		Measure-Object -Sum |
		Select-Object -ExpandProperty 'Sum'
	Try {
		$Script:StatisticsTotal.ElementFound += $StatisticsSession.ElementFound
		$Script:StatisticsTotal.SizeFound += $StatisticsSession.SizeFound
	}
	Catch {
		$Script:StatisticsTotal.IsOverflow = $True
	}
	[PSCustomObject[]]$ResultFoundResolve = $ResultFounds |
		Group-Object -Property @('Element', 'Symbol') -NoElement |
		ForEach-Object -Process {
			[String]$Element, [String]$Symbol = $_.Name -isplit ', '
			Write-Output -InputObject ([PSCustomObject]@{
				Path = $Element
				Symbol = $Symbol
				Hit = $_.Count
				IsIgnore = Invoke-ProtectiveScriptBlock -Name 'ignores_post' -ScriptBlock $InputIgnoresPost -ArgumentList @($SessionName, ([PSCustomObject]@{
					Path = $Element
					Session = [PSCustomObject]@{
						Name = $SessionName
						GitCommitMeta = $Meta
					}
					Symbol = $Symbol
				}))
			})
		} |
		Sort-Object -Property @('Path', 'Symbol') |
		Sort-Object -Property @('Hit') -Descending |
		Sort-Object -Property @('IsIgnore')
	If ($ResultFoundResolve.Count -gt 0) {
		If ($InputFoundLog) {
			$ResultFoundResolve |
				Format-Table -Property @(
					@{ Name = ''; Expression = { $_.IsIgnore ? '🟡' : '🔴' } },
					@{ Expression = 'Hit'; Alignment = 'Right' },
					@{ Expression = 'Path'; Width = 40 },
					@{ Expression = 'Symbol'; Width = 40 }
				) -AutoSize:$False -Wrap |
				Out-String -Width 120 |
				Write-Host
		}
		If ($InputFoundSummary) {
			Add-StepSummaryFound -Session $SessionId -Issue (
				$ResultFoundResolve |
					ForEach-Object -Process { [PSCustomObject]@{
						Indicator = $_.IsIgnore ? '🟡' : '🔴'
						Path = $_.Path
						Symbol = $_.Symbol
						Hit = $_.Hit
					} }
			)
		}
		If ((
			$ResultFoundResolve |
				Where-Object -FilterScript { !$_.IsIgnore } |
				Measure-Object |
				Select-Object -ExpandProperty 'Count'
		) -gt 0) {
			$Script:StatisticsTotal.IssuesSessions += $SessionId
			Write-GitHubActionsError -Message "Found in session `"$SessionName`"!"
		}
		Else {
			Write-GitHubActionsWarning -Message "Found in session `"$SessionName`" but ignored!"
		}
	}
	Write-Host -Object $StatisticsSession.GetStatisticsTableString(120)
	Exit-GitHubActionsLogGroup
}
Invoke-Tools -SessionName 'Current' -Meta $Null
If ($InputGitIntegrate -and (Test-IsGitRepository)) {
	Write-Host -Object 'Get Git commits meta.'
	[String[]]$GitCommitsHash = Get-GitCommitIndex -SortFromOldest:($InputGitReverse)
	If ($GitCommitsHash.Count -le 1) {
		Write-GitHubActionsNotice -Message "Current Git repository has $($GitCommitsHash.Count) commit! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow."
	}
	[UInt64]$GitCommitsPassCount = 0
	For ([UInt64]$GitCommitsHashIndex = 0; $GitCommitsHashIndex -lt $GitCommitsHash.Count; $GitCommitsHashIndex += 1) {
		[String]$GitCommitHash = $GitCommitsHash[$GitCommitsHashIndex]
		[String]$GitSessionTitle = "$GitCommitHash [#$($GitCommitsHashIndex + 1)/$($GitCommitsHash.Count)]"
		If ($InputGitLimit -gt 0 -and $GitCommitsPassCount -ge $InputGitLimit) {
			Write-Host -Object "Reach the Git commits count limit, these Git commits are ignore: $(
				@($GitCommitsHashIndex..($GitCommitsHash.Count - 1)) |
					ForEach-Object -Process { "$($GitCommitsHash[$_]) [#$($_ + 1)/$($GitCommitsHash.Count)]" } |
					Join-String -Separator ', '
			)"
			Break
		}
		$GitCommit = Get-GitCommitMeta -Index $GitCommitHash
		If ($Null -ieq $GitCommit) {
			Continue
		}
		If (Invoke-ProtectiveScriptBlock -Name 'git_ignores' -ScriptBlock $InputGitIgnores -ArgumentList @($GitCommit)) {
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
			git --no-pager checkout $GitCommitHash --force --quiet |
				Write-GitHubActionsDebug
			If ($LASTEXITCODE -ne 0) {
				Throw "Exit code is ``$LASTEXITCODE``"
			}
		}
		Catch {
			Exit-GitHubActionsLogGroup
			Write-GitHubActionsError -Message "Unexpected issues when invoke Git checkout with commit hash ``$($GitCommitHash)``: $_"
			$StatisticsTotal.IssuesOperations += "Git/$GitCommitHash"
			Continue
		}
		Exit-GitHubActionsLogGroup
		Invoke-Tools -SessionName $GitCommitHash -Meta $GitCommit
	}
}
If ($InputClamAVEnable) {
	Write-Host -Object 'Stop ClamAV daemon.'
	Stop-ClamAVDaemon
}
If ($InputStatisticsLog) {
	$StatisticsTotal.StatisticsDisplay()
}
If ($InputStatisticsSummary) {
	$StatisticsTotal.StatisticsSummary()
}
Set-GitHubActionsOutput -Name 'finish' -Value $True.ToString().ToLower()
Set-GitHubActionsOutput -Name 'found' -Value ($StatisticsTotal.IssuesSessions.Count -gt 0).ToString().ToLower()
Exit $StatisticsTotal.GetExitCode()
