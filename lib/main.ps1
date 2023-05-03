#Requires -PSEdition Core -Version 7.2
Using Module .\statistics.psm1
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'assets',
		'display',
		'git',
		'internal',
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
[ScanVirusStatisticsIssuesOperations]$StatisticsIssuesOperations = [ScanVirusStatisticsIssuesOperations]::New()
[ScanVirusStatisticsIssuesSessions]$StatisticsIssuesSessions = [ScanVirusStatisticsIssuesSessions]::New()
[ScanVirusStatisticsTotalElements]$StatisticsTotalElements = [ScanVirusStatisticsTotalElements]::New()
[ScanVirusStatisticsTotalSizes]$StatisticsTotalSizes = [ScanVirusStatisticsTotalSizes]::New()
[RegEx]$GitHubActionsWorkspaceRootRegEx = [RegEx]::Escape("$($Env:GITHUB_WORKSPACE)/")
Enter-GitHubActionsLogGroup -Title 'Import inputs.'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_list_delimiter' -Mandatory -EmptyStringAsNull
Write-NameValue -Name 'Input_List_Delimiter' -Value "``$InputListDelimiter``"
Switch -RegEx (Get-GitHubActionsInput -Name 'input_table_markup' -Mandatory -EmptyStringAsNull -Trim) {
	'^csv$' {
		[String]$InputTableMarkup = 'csv'
		Break
	}
	'^csvm$' {
		[String]$InputTableMarkup = 'csvm'
		Break
	}
	'^csvs$' {
		[String]$InputTableMarkup = 'csvs'
		Break
	}
	'^json$' {
		[String]$InputTableMarkup = 'json'
		Break
	}
	'^tsv$' {
		[String]$InputTableMarkup = 'tsv'
		Break
	}
	'^ya?ml$' {
		[String]$InputTableMarkup = 'yaml'
		Break
	}
	Default {
		Write-GitHubActionsFail -Message "``$_`` is not a valid table markup language!" -Finally {
			Exit-GitHubActionsLogGroup
		}
	}
}
Write-NameValue -Name 'Input_Table_Markup' -Value $InputTableMarkup
[AllowEmptyCollection()][Uri[]]$Targets = Get-InputList -Name 'targets' -Delimiter $InputListDelimiter |
	ForEach-Object -Process { $_ -as [Uri] }
Write-NameValue -Name "Targets [$($Targets.Count)]" -Value (($Targets.Count -eq 0) ? '(Local)' : (
	$Targets |
		Select-Object -ExpandProperty 'OriginalString' |
		Join-String -Separator ', ' -FormatString '`{0}`'
))
[Boolean]$GitIntegrate = Get-InputBoolean -Name 'git_integrate'
Write-NameValue -Name 'Git_Integrate' -Value $GitIntegrate
[Boolean]$GitReverse = Get-InputBoolean -Name 'git_reverse'
Write-NameValue -Name 'Git_Reverse' -Value $GitReverse
[Boolean]$ClamAVEnable = Get-InputBoolean -Name 'clamav_enable'
Write-NameValue -Name 'ClamAV_Enable' -Value $ClamAVEnable
[AllowEmptyCollection()][RegEx[]]$ClamAVUnofficialAssetsInput = Get-InputList -Name 'clamav_unofficialassets' -Delimiter $InputListDelimiter
Write-NameValue -Name "ClamAV_UnofficialAssets_RegEx [$($ClamAVUnofficialAssetsInput.Count)]" -Value (
	$ClamAVUnofficialAssetsInput |
		Join-String -Separator ', ' -FormatString '`{0}`'
)
[Boolean]$YaraEnable = Get-InputBoolean -Name 'yara_enable'
Write-NameValue -Name 'YARA_Enable' -Value $YaraEnable
[AllowEmptyCollection()][RegEx[]]$YaraUnofficialAssetsInput = Get-InputList -Name 'yara_unofficialassets' -Delimiter $InputListDelimiter
Write-NameValue -Name "YARA_UnofficialAssets_RegEx [$($YaraUnofficialAssetsInput.Count)]" -Value (
	$YaraUnofficialAssetsInput |
		Join-String -Separator ', ' -FormatString '`{0}`'
)
[Boolean]$UpdateClamAV = Get-InputBoolean -Name 'update_clamav'
Write-NameValue -Name 'Update_ClamAV' -Value $UpdateClamAV
[AllowEmptyCollection()][PSCustomObject[]]$IgnoresElements = (Get-InputTable -Name 'ignores_elements' -Markup $InputTableMarkup) ?? @()
Write-NameValue -Name "Ignores_Elements [$($IgnoresElements.Count)]" -Value (
	$IgnoresElements |
		Format-List -Property '*' |
		Out-String
) -NewLine
[AllowEmptyCollection()][PSCustomObject[]]$IgnoresGitCommitsMeta = (Get-InputTable -Name 'ignores_gitcommits_meta' -Markup $InputTableMarkup) ?? @()
Write-NameValue -Name "Ignores_GitCommits_Meta [$($IgnoresGitCommitsMeta.Count)]" -Value (
	$IgnoresGitCommitsMeta |
		Format-List -Property '*' |
		Out-String
) -NewLine
[UInt]$IgnoresGitCommitsNonNewest = [UInt]::Parse((Get-GitHubActionsInput -Name 'ignores_gitcommits_nonnewest' -EmptyStringAsNull))
Write-NameValue -Name 'Ignores_GitCommits_NonNewest' -Value $IgnoresGitCommitsNonNewest
Exit-GitHubActionsLogGroup
If ($True -inotin @($ClamAVEnable, $YaraEnable)) {
	Write-GitHubActionsFail -Message 'No tools are enabled!'
}
If ($UpdateClamAV -and $ClamAVEnable) {
	Update-ClamAV
}
If ($ClamAVEnable -and $ClamAVUnofficialAssetsInput.Count -gt 0) {
	Enter-GitHubActionsLogGroup -Title 'Register ClamAV unofficial assets.'
	[Hashtable]$Result = Register-ClamAVUnofficialAssets -Selection $ClamAVUnofficialAssetsInput
	ForEach ($ApplyIssue In $Result.ApplyIssues) {
		$StatisticsIssuesOperations.Storage += "ClamAV/UnofficialAssets/$ApplyIssue"
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
	If (Test-ElementIsIgnore -Element ([PSCustomObject]@{
		Session = $SessionId
	}) -Ignore $IgnoresElements) {
		Write-Host -Object "Ignore session `"$SessionTitle`"."
		Return
	}
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
			}) -Ignore $IgnoresElements) -or (Test-ElementIsIgnore -Element ([PSCustomObject]@{
				Path = $ElementObject.Path
				Session = $SessionId
			}) -Ignore $IgnoresElements)
			$ElementObject.SkipClamAV = $ElementObject.SkipAll -or (
				Test-ElementIsIgnore -Element ([PSCustomObject]@{
					Path = $ElementObject.Path
					Tool = 'clamav'
				}) -Ignore $IgnoresElements
			) -or (
				Test-ElementIsIgnore -Element ([PSCustomObject]@{
					Path = $ElementObject.Path
					Session = $SessionId
					Tool = 'clamav'
				}) -Ignore $IgnoresElements
			)
			$ElementObject.SkipYara = $ElementObject.SkipAll -or (
				Test-ElementIsIgnore -Element ([PSCustomObject]@{
					Path = $ElementObject.Path
					Tool = 'yara'
				}) -Ignore $IgnoresElements
			) -or (
				Test-ElementIsIgnore -Element ([PSCustomObject]@{
					Path = $ElementObject.Path
					Session = $SessionId
					Tool = 'yara'
				}) -Ignore $IgnoresElements
			)
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
			[PSCustomObject]$ElementObject |
				Write-Output
		}
	If ($Elements.Count -eq 0){
		Write-GitHubActionsError -Message @"
Unable to scan session `"$SessionTitle`": Workspace is empty!
If this is incorrect, probably something went wrong.
"@
		$Script:StatisticsIssuesOperations.Storage += "Workspace/$SessionId"
		Write-Host -Object "End of session `"$SessionTitle`"."
		Return
	}
	[UInt32]$ElementsCountDiscover = $Elements.Count
	[UInt32]$ElementsCountScan = $Elements |
		Where-Object -FilterScript { !$_.SkipAll } |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	[UInt32]$ElementsCountClamAV = $Elements |
		Where-Object -FilterScript { !$_.SkipClamAV } |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	[UInt32]$ElementsCountYara = $Elements |
		Where-Object -FilterScript { !$_.SkipYara } |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	$Script:StatisticsTotalElements.Discover += $ElementsCountDiscover
	$Script:StatisticsTotalElements.Scan += $ElementsCountScan
	$Script:StatisticsTotalElements.ClamAV += $ElementsCountClamAV
	$Script:StatisticsTotalElements.Yara += $ElementsCountYara
	$Script:StatisticsTotalSizes.Discover += $Elements |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	$Script:StatisticsTotalSizes.Scan += $Elements |
		Where-Object -FilterScript { !$_.SkipAll } |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	$Script:StatisticsTotalSizes.ClamAV += $Elements |
		Where-Object -FilterScript { !$_.SkipClamAV } |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	$Script:StatisticsTotalSizes.Yara += $Elements |
		Where-Object -FilterScript { !$_.SkipYara } |
		Measure-Object -Property 'Size' -Sum |
		Select-Object -ExpandProperty 'Sum'
	Enter-GitHubActionsLogGroup -Title "Elements of session `"$SessionTitle`": "
	Write-NameValue -Name 'Discover' -Value $ElementsCountDiscover
	Write-NameValue -Name 'Scan' -Value $ElementsCountScan
	Write-NameValue -Name 'ClamAV' -Value $ElementsCountClamAV
	Write-NameValue -Name 'Yara' -Value $ElementsCountYara
	$Elements |
		Format-Table -Property @(
			'Path',
			'Flag',
			@{ Expression = 'Size'; Alignment = 'Right' }
		) -AutoSize |
		Out-String |
		Write-Host
	Exit-GitHubActionsLogGroup
	If ($ClamAVEnable -and $ElementsCountClamAV -gt 0) {
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via ClamAV."
		[Hashtable]$Result = Invoke-ClamAVScan -Target (
			$Elements |
				Where-Object -FilterScript { !$_.SkipClamAV } |
				Select-Object -ExpandProperty 'FullName'
		)
		Write-GitHubActionsDebug -Message (
			$Result.Output |
				Join-String -Separator "`n"
		)
		If ($Result.IsSuccess) {
			If ($Result.ErrorMessage.Count -gt 0) {
				Write-GitHubActionsError -Message @"
Unexpected issue in session `"$SessionTitle`" via ClamAV:

$(
	$Result.ErrorMessage |
		Join-String -Separator "`n" -FormatString '- {0}'
)
"@
				$Script:StatisticsIssuesOperations.Storage += "$SessionId/ClamAV"
			}
			If ($Result.Found.Count -gt 0) {
				Write-GitHubActionsError -Message @"
Found in session `"$SessionTitle`" via ClamAV:

$(
	$Result.Found.GetEnumerator() |
		ForEach-Object -Process { "$($_.Name): $(
			$_.Value |
				Sort-Object -Unique |
				Join-String -Separator ', ' -FormatString '`{0}`'
		)" } |
		Join-String -Separator "`n"
)
"@
				$Script:StatisticsIssuesSessions.ClamAV += $SessionId
			}
		}
		Else {
			Write-GitHubActionsError -Message (
				$Result.ErrorMessage |
					Join-String -Separator "`n"
			)
			$Script:StatisticsIssuesOperations.Storage += "ClamAV/$SessionId"
		}
	}
	If ($YaraEnable -and $ElementsCountYara -gt 0) {
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via YARA."
		[Hashtable]$YaraResultFound = @{}
		[String[]]$YaraResultIssue = @()
		ForEach ($YaraUnofficialAsset In (
			$YaraUnofficialAssetsIndexTable |
				Where-Object -FilterScript { $_.Select }
		)) {
			[Hashtable]$Result = Invoke-Yara -Target (
				$Elements |
					Where-Object -FilterScript { !$_.SkipYara } |
					Select-Object -ExpandProperty 'FullName'
			) -Asset $YaraUnofficialAsset
			Write-GitHubActionsDebug -Message (
				$Result.Output |
					Join-String -Separator "`n"
			)
			If ($Result.IsSuccess) {
				If ($Result.ErrorMessage.Count -gt 0) {
					Write-GitHubActionsError -Message @"
Unexpected issue in session `"$SessionTitle`" via YARA:

$(
	$Result.ErrorMessage |
		Join-String -Separator "`n" -FormatString '- {0}'
)
"@
					$Script:StatisticsIssuesOperations.Storage += "$SessionId/YARA"
				}
				If ($Result.Found.Count -gt 0) {
					Write-GitHubActionsError -Message @"
Found in session `"$SessionTitle`" via YARA:

$(
	$Result.Found.GetEnumerator() |
		ForEach-Object -Process { "$($_.Name): $(
			$_.Value |
				Sort-Object -Unique |
				Join-String -Separator ', ' -FormatString '`{0}`'
		)" }
)
"@
					$Script:StatisticsIssuesSessions.Yara += $SessionId
				}
			}
			Else {
				Write-GitHubActionsError -Message (
					$Result.ErrorMessage |
						Join-String -Separator "`n"
				)
				$Script:StatisticsIssuesOperations.Storage += "YARA/$SessionId"
			}
		}
	}
	Write-Host -Object "End of session `"$SessionTitle`"."
}
If ($Targets.Count -eq 0) {
	Invoke-Tools -SessionId 'current' -SessionTitle 'Current'
	If ($GitIntegrate) {
		Write-Host -Object 'Import Git commits meta.'
		[AllowEmptyCollection()][PSCustomObject[]]$GitCommits = Get-GitCommits
		If ($GitCommits.Count -le 1) {
			Write-GitHubActionsWarning -Message "Current Git repository has $($GitCommits.Count) commit! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow."
		}
		For ([UInt64]$GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex++) {
			[PSCustomObject]$GitCommit = $GitCommits[$GitCommitsIndex]
			[String]$GitSessionTitle = "$($GitCommit.CommitHash) [#$($GitCommitsIndex + 1)/$($GitCommits.Count)]"
			If (Test-GitCommitIsIgnore -GitCommit $GitCommit -Ignore $IgnoresGitCommitsMeta) {
				Write-Host -Object "Ignore Git commit $GitSessionTitle."
				Continue
			}
			Enter-GitHubActionsLogGroup -Title "Git checkout for commit $GitSessionTitle."
			Try {
				git checkout $GitCommit.CommitHash --force --quiet
				If ($LASTEXITCODE -ne 0) {
					Throw "Exit code ``$LASTEXITCODE``"
				}
			}
			Catch {
				Write-GitHubActionsError -Message "Unexpected issues when invoke Git checkout with commit hash ``$($GitCommit.CommitHash)``: $_"
				$StatisticsIssuesOperations.Storage += "Git/$($GitCommit.CommitHash)"
				Exit-GitHubActionsLogGroup
				Continue
			}
			Exit-GitHubActionsLogGroup
			Invoke-Tools -SessionId $GitCommit.CommitHash -SessionTitle "Git Commit $GitSessionTitle"
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
	ForEach ($Target In $Targets) {
		If (!(Test-StringIsUri -InputObject $Target)) {
			Write-GitHubActionsWarning -Message "``$($Target.OriginalString)`` is not a valid URI!"
			Continue
		}
		$NetworkTargetFilePath = Import-NetworkTarget -Target $Target
		If ($Null -ine $NetworkTargetFilePath) {
			Invoke-Tools -SessionId $Target -SessionTitle $Target
			Remove-Item -LiteralPath $NetworkTargetFilePath -Force -Confirm:$False
		}
	}
}
If ($ClamAVEnable) {
	Stop-ClamAVDaemon
}
Write-Host -Object 'Statistics.'
$StatisticsTotalElements.ConclusionDisplay()
$StatisticsTotalSizes.ConclusionDisplay()
If ($StatisticsIssuesOperations.Storage.Count -gt 0) {
	$StatisticsIssuesOperations.ConclusionDisplay()
}
If ($StatisticsIssuesSessions.GetTotal() -gt 0) {
	$StatisticsIssuesSessions.ConclusionDisplay()
	Exit 1
}
Exit 0
