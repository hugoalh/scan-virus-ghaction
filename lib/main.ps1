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
		[String]$InputTableMarkup = 'Csv'
		Break
	}
	'^csv-?m(?:ulti(?:ple)?(?:line)?)?$' {
		[String]$InputTableMarkup = 'CsvM'
		Break
	}
	'^csv-?s(?:ingle(?:line)?)?$' {
		[String]$InputTableMarkup = 'CsvS'
		Break
	}
	'^tsv$' {
		[String]$InputTableMarkup = 'Tsv'
		Break
	}
	'^ya?ml$' {
		[String]$InputTableMarkup = 'Yaml'
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
[Boolean]$GitIncludeAllBranches = Get-InputBoolean -Name 'git_include_allbranches'
Write-NameValue -Name 'Git_Include_AllBranches' -Value $GitIncludeAllBranches
[Boolean]$GitIncludeRefLogs = Get-InputBoolean -Name 'git_include_reflogs'
Write-NameValue -Name 'Git_Include_Reflogs' -Value $GitIncludeRefLogs
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
[AllowEmptyCollection()][PSCustomObject[]]$IgnoresElementsInput = (Get-InputTable -Name 'ignores_elements' -Markup $InputTableMarkup) ?? @()
Write-NameValue -Name "Ignores_Elements [$($IgnoresElementsInput.Count)]" -Value (
	$IgnoresElementsInput |
		Format-List -Property '*' |
		Out-String
) -NewLine
[Hashtable]$IgnoresElements = Group-IgnoresElements -InputObject $IgnoresElementsInput
[AllowEmptyCollection()][PSCustomObject[]]$IgnoresGitCommitsMetaInput = (Get-InputTable -Name 'ignores_gitcommits_meta' -Markup $InputTableMarkup) ?? @()
Write-NameValue -Name "Ignores_GitCommits_Meta [$($IgnoresGitCommitsMetaInput.Count)]" -Value (
	$IgnoresGitCommitsMetaInput |
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

Exit 0<# DEBUG #>

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
	If (Test-StringMatchRegExs -Item $SessionId -Matchers $IgnoresElements.Sessions.Session) {
		Write-Host -Object "Ignore session `"$SessionTitle`"."
	}
	Return
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
			$ElementObject.SkipAll = $ElementObject.IsDirectory -or (Test-StringMatchRegExs -Item $ElementObject.Path -Matchers $IgnoresElements.Paths)
			$ElementObject.SkipClamAV = Test-StringMatchRegExs -Item $ElementObject.Path -Matchers $IgnoresElements.ClamAVPaths
			$ElementObject.SkipYara = Test-StringMatchRegExs -Item $ElementObject.Path -Matchers $IgnoresElements.YaraPaths
			[String[]]$ElementFlags = @()
			If ($ElementObject.IsDirectory) {
				$ElementFlags += 'D'
			}
			If (!$ElementObject.SkipAll -and !$ElementObject.SkipClamAV) {
				$ElementFlags += 'C'
			}
			If (!$ElementObject.SkipAll -and !$ElementObject.SkipYara) {
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
		Where-Object -FilterScript { !$_.SkipAll -and !$_.SkipClamAV } |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	[UInt32]$ElementsCountYara = $Elements |
		Where-Object -FilterScript { !$_.SkipAll -and !$_.SkipYara } |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	$Script:StatisticsTotalElements.Discover += $ElementsCountDiscover
	$Script:StatisticsTotalElements.Scan += $ElementsCountScan
	$Script:StatisticsTotalElements.ClamAV += $ElementsCountClamAV
	$Script:StatisticsTotalElements.Yara += $ElementsCountYara
	$Script:StatisticsTotalSizes.Discover += $Elements |
		Measure-Object -Property 'Size' -Sum
	$Script:StatisticsTotalSizes.Scan += $Elements |
		Where-Object -FilterScript { !$_.SkipAll } |
		Measure-Object -Property 'Size' -Sum
	$Script:StatisticsTotalSizes.ClamAV += $Elements |
		Where-Object -FilterScript { !$_.SkipAll -and !$_.SkipClamAV } |
		Measure-Object -Property 'Size' -Sum
	$Script:StatisticsTotalSizes.Yara += $Elements |
		Where-Object -FilterScript { !$_.SkipAll -and !$_.SkipYara } |
		Measure-Object -Property 'Size' -Sum
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
				Where-Object -FilterScript { !$_.IsDirectory -and !$_.SkipAll -and !$_.SkipClamAV }
		).FullName
		If ($Result.ExitCode -ne 0) {

		}
	}
	If ($YaraEnable -and $ElementsCountYara -gt 0) {
		[String]$ElementsListYaraFullName = (New-TemporaryFile).FullName
		Set-Content -LiteralPath $ElementsListYaraFullName -Value (
			$ElementsListYara |
				Join-String -Separator "`n"
		) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via YARA."
		[Hashtable]$YaraResultFound = @{}
		[String[]]$YaraResultIssue = @()
		ForEach ($YaraRule In $YaraRulesSelect) {
			Try {
				[String[]]$YaraOutput = yara --scan-list "$(Join-Path -Path $YaraRulesAssetsRoot -ChildPath $YaraRule.Location)" "$ElementsListYaraFullName"
				[UInt32]$YaraExitCode = $LASTEXITCODE
			}
			Catch {
				Write-GitHubActionsError -Message "Unexpected issues when invoke YARA (SessionID: $SessionId): $_"
				Exit-GitHubActionsLogGroup
				Exit 1
			}
			If ($YaraExitCode -eq 0) {
				ForEach ($Line In $YaraOutput) {
					If ($Line -imatch "^.+? $GitHubActionsWorkspaceRootRegEx.+$") {
						[String]$Rule, [String]$Element = $Line -isplit "(?<=^.+?) $GitHubActionsWorkspaceRootRegEx"
						[String]$YaraRuleName = "$($YaraRule.Name)/$Rule"
						Write-GitHubActionsDebug -Message "$($Element): $YaraRuleName"
						If ($Null -ieq $YaraResultFound[$Element]) {
							$YaraResultFound[$Element] = @()
						}
						If ($YaraRuleName -inotin $YaraResultFound[$Element]) {
							$YaraResultFound[$Element] += $YaraRuleName
						}
					}
					ElseIf ($Line.Length -gt 0) {
						$YaraResultIssue += $Line
					}
				}
			}
			Else {
				Write-GitHubActionsError -Message "Unexpected YARA `"$($YaraRule.Name)`" exit code ``$YaraExitCode`` in session `"$SessionTitle`"!`n$YaraOutput"
				If ($SessionId -inotin $Script:StatisticsIssuesSessions.Yara) {
					$Script:StatisticsIssuesSessions.Yara += $SessionId
				}
			}
		}
		Enter-GitHubActionsLogGroup -Title "YARA result of session `"$SessionTitle`":"
		If ($YaraResultFound.Count -gt 0) {
			Write-GitHubActionsError -Message "Found issues in session `"$SessionTitle`" via YARA ($($YaraResultFound.Count)): `n$(
				$YaraResultFound.GetEnumerator() |
					ForEach-Object -Process {
						[String[]]$IssueRules = $_.Value |
							Sort-Object -Unique -CaseSensitive
						[PSCustomObject]@{
							Element = $_.Name
							Rules_List = $IssueRules -join ', '
							Rules_Count = $IssueRules.Count
						} |
							Write-Output
					} |
					Sort-Object -Property @('Element') |
					Format-List -Property '*' |
					Out-String |
					Write-Host
			)"
			If ($SessionId -inotin $Script:StatisticsIssuesSessions.Yara) {
				$Script:StatisticsIssuesSessions.Yara += $SessionId
			}
		}
		Exit-GitHubActionsLogGroup
		Remove-Item -LiteralPath $ElementsListYaraFullName -Force -Confirm:$False
	}
	Write-Host -Object "End of session `"$SessionTitle`"."
}
If ($Targets.Count -eq 0) {
	Invoke-Tools -SessionId 'current' -SessionTitle 'Current'
	If ($GitIntegrate) {
		Write-Host -Object 'Import Git commits meta.'
		[AllowEmptyCollection()][PSCustomObject[]]$GitCommits = Get-GitCommits -AllBranches:$GitIncludeAllBranches -Reflogs:$GitIncludeRefLogs
		If ($GitCommits.Count -eq 1) {
			Write-GitHubActionsWarning -Message @'
Current Git repository has only 1 commit!
If this is incorrect, please define `actions/checkout` input `fetch-depth` to `0` and re-trigger the workflow.
'@
		}
		For ([UInt64]$GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex++) {
			[String]$GitCommit = $GitCommits[$GitCommitsIndex]
			[String]$GitSessionTitle = "$($GitCommit.CommitHash) [#$($GitCommitsIndex + 1)/$($GitCommits.Count)]"
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
