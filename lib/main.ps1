#Requires -PSEdition Core
#Requires -Version 7.3
Using Module .\cleanup-duty.psm1
Using Module .\statistics.psm1
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'assets',
		'display',
		'git',
		'input',
		'pcsp',
		'token',
		'utility',
		'ware'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Write-Host -Object 'Initialize.'
Get-HardwareMeta
Get-SoftwareMeta
Test-GitHubActionsEnvironment -Mandatory
Exit 0
[Hashtable]$ImportCsvParameters_Tsv = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[Hashtable]$JoinStringParameters_List = @{
	FormatString = '- {0}'
	Separator = "`n"
}
$CleanupManager = [ScanVirusCleanupDuty]::new()
$StatisticsIssuesSessions = [ScanVirusStatisticsIssuesSessions]::new()
$StatisticsTotalElements = [ScanVirusStatisticsTotalElements]::new()
$StatisticsTotalSizes = [ScanVirusStatisticsTotalSizes]::new()
[RegEx]$GitHubActionsWorkspaceRootRegEx = "$([RegEx]::Escape($Env:GITHUB_WORKSPACE))\/"
Enter-GitHubActionsLogGroup -Title 'Import inputs.'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_list_delimiter' -Mandatory -EmptyStringAsNull
Write-NameValue -Name 'Input_List_Delimiter' -Value $InputListDelimiter
Switch -RegEx (Get-GitHubActionsInput -Name 'input_table_markup' -Mandatory -EmptyStringAsNull -Trim) {
	'^csv$' {
		[String]$InputTableMarkup = 'csv'
		Break
	}
	'^csv-?s(?:ingle(?:line)?)?$' {
		[String]$InputTableMarkup = 'csv-s'
		Break
	}
	'^csv-?m(?:ulti(?:ple)?(?:line)?)?$' {
		[String]$InputTableMarkup = 'csv-m'
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
		Write-GitHubActionsFail -Message "``$_`` is not a valid table markup language!"
		Throw
	}
}
Write-NameValue -Name 'Input_Table_Markup' -Value $InputTableMarkup
[Uri[]]$TargetsInput = ((Get-InputList -Name 'targets' -Delimiter $InputListDelimiter) ?? @()) |
	ForEach-Object -Process { $_ -as [Uri] }
Write-NameValue -Name "Targets [$($TargetsInput.Count)]" -Value (($TargetsInput.Count -ieq 0) ? '(Local)' : "`n$(
	$TargetsInput |
		Select-Object -ExpandProperty 'OriginalString' |
		Join-String @JoinStringParameters_List
)")
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
[RegEx[]]$ClamAVUnofficialSignaturesInput = Get-InputList -Name 'clamav_unofficialsignatures' -Delimiter $InputListDelimiter
Write-NameValue -Name "ClamAV_UnofficialSignatures_RegEx [$($ClamAVUnofficialSignaturesInput.Count)]"
$ClamAVUnofficialSignaturesInput |
	Join-String @JoinStringParameters_List
[Boolean]$YaraEnable = Get-InputBoolean -Name 'yara_enable'
Write-NameValue -Name 'YARA_Enable' -Value $YaraEnable
[RegEx[]]$YaraRulesInput = Get-InputList -Name 'yara_rules' -Delimiter $InputListDelimiter
Write-NameValue -Name "YARA_Rules_RegEx [$($YaraRulesInput.Count)]"
$YaraRulesInput |
	Join-String @JoinStringParameters_List
[Boolean]$UpdateAssetsLocal = Get-InputBoolean -Name 'update_assets'
Write-NameValue -Name 'Update_Assets' -Value $UpdateAssetsLocal
[Boolean]$UpdateClamAV = Get-InputBoolean -Name 'update_clamav'
Write-NameValue -Name 'Update_ClamAV' -Value $UpdateClamAV
[PSCustomObject[]]$ClamAVIgnoresInput = Get-InputTable -Name 'ignores_elements' -Type $InputTableMarkup
Write-NameValue -Name "Ignores_Elements [$($ClamAVIgnoresInput.Count)]"
$ClamAVIgnoresInput |
	Format-List -Property '*'
[PSCustomObject[]]$IgnoresGitCommitsMetaInput = Get-InputTable -Name 'ignores_gitcommits_meta' -Type $InputTableMarkup
Write-NameValue -Name "Ignores_GitCommits_Meta [$($IgnoresGitCommitsMetaInput.Count)]"
$IgnoresGitCommitsMetaInput |
	Format-List -Property '*'
[UInt]$IgnoresGitCommitsNonLatest = Get-GitHubActionsInput -Name 'ignores_gitcommits_nonlatest' -EmptyStringAsNull ?? 0
Exit-GitHubActionsLogGroup
If ($True -inotin @($ClamAVEnable, $YaraEnable)) {
	Write-GitHubActionsFail -Message 'No tools are enabled!'
	Throw
}
If ($ClamAVEnable) {
	Enter-GitHubActionsLogGroup -Title 'Restore ClamAV database.'
	Restore-ClamAVDatabase
	Exit-GitHubActionsLogGroup
}
If ($UpdateClamAV -and $ClamAVEnable) {
	Enter-GitHubActionsLogGroup -Title 'Update ClamAV assets via FreshClam.'
	Try {
		freshclam
		If ($LASTEXITCODE -ine 0) {
			Write-GitHubActionsWarning -Message "Unexpected exit code ``$LASTEXITCODE`` when update ClamAV assets via FreshClam! Mostly will not cause critical issues."
		}
		$StatisticsIssuesSessions.Other += 'FreshClam'
	}
	Catch {
		Write-GitHubActionsError -Message "Unexpected issues when update ClamAV assets via FreshClam: $_"
		Exit-GitHubActionsLogGroup
		Exit 1
	}
	Exit-GitHubActionsLogGroup
}
If ($UpdateAssetsLocal -and (
	($ClamAVEnable -and $ClamAVUnofficialSignaturesInput.Count -igt 0) -or
	($YaraEnable -and $YaraRulesInput.Count -igt 0)
)) {
	Enter-GitHubActionsLogGroup -Title 'Update local assets.'
	[Hashtable]$Result = Update-Assets
	If (!$Result.Continue) {
		Write-GitHubActionsError -Message $Result.Reason
		Exit-GitHubActionsLogGroup
		Exit 1
	}
	If (!$Result.Success) {
		$StatisticsIssuesSessions.Other += 'UpdateAssetsLocal'
	}
	Exit-GitHubActionsLogGroup
}
If ($ClamAVEnable -and $ClamAVUnofficialSignaturesInput.Count -igt 0) {
	Enter-GitHubActionsLogGroup -Title 'Register ClamAV unofficial signatures and signatures ignores.'
	[Hashtable]$Result = Register-ClamAVUnofficialSignatures -SignaturesSelection $ClamAVUnofficialSignaturesInput
	ForEach ($IssuesSignature In $Result.IssuesSignatures) {
		$StatisticsIssuesSessions.Other += "ClamAV/UnofficialSignature:$IssuesSignature"
	}
	ForEach ($NeedCleanUpSignature In $Result.NeedCleanUp) {
		$CleanupManager.Pending += $NeedCleanUpSignature
	}
	Exit-GitHubActionsLogGroup
}
If ($YaraEnable -and $YaraRulesInput.Count -igt 0) {
	Enter-GitHubActionsLogGroup -Title 'Register YARA rules.'
	[PSCustomObject[]]$YaraRulesIndex = Import-Csv -LiteralPath (Join-Path -Path $YaraRulesAssetsRoot -ChildPath 'index.tsv') @ImportCsvParameters_Tsv
	[PSCustomObject[]]$YaraRulesSelect = $YaraRulesIndex |
		Where-Object -FilterScript { Test-StringMatchRegExs -Item $_.Name -Matchers $YaraRulesInput } |
		Sort-Object -Property 'Name'
	[PSCustomObject[]]$YaraRulesIndexDisplay = $YaraRulesIndex |
		ForEach-Object -Process {
			[String]$SourceFullName = Join-Path -Path $YaraRulesAssetsRoot -ChildPath $_.Location
			[String]$Name = $_.Name
			[Boolean]$Exist = Test-Path -LiteralPath $SourceFullName
			[Boolean]$Select = $Name -iin $YaraRulesSelect.Name
			[Boolean]$Apply = $Select -and $Exist
			If (!$Exist) {
				Write-GitHubActionsWarning -Message "YARA rule ``$Name`` was indexed but not exist! (Please create a bug report!)"
				$Script:StatisticsIssuesSessions.Other += "YARARules/Exist/$Name"
			}
			Write-Output -InputObject ([PSCustomObject]@{
				Name = $Name
				Exist = $Exist
				Select = $Select
				Apply = $Apply
			})
		}
	Exit-GitHubActionsLogGroup
	Enter-GitHubActionsLogGroup -Title "YARA rules index (All: $($YaraRulesIndexDisplay.Count); Exist: $((
		$YaraRulesIndexDisplay |
			Where-Object -FilterScript { $_.Exist }
	).Count); Select: $((
		$YaraRulesIndexDisplay |
			Where-Object -FilterScript { $_.Select }
	).Count); Apply: $((
		$YaraRulesIndexDisplay |
			Where-Object -FilterScript { $_.Apply }
	).Count)):"
	$YaraRulesIndexDisplay |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Select'; Alignment = 'Right' },
			@{ Expression = 'Apply'; Alignment = 'Right' }
		) -AutoSize -Wrap
	Exit-GitHubActionsLogGroup
}
If ($ClamAVEnable) {
	Enter-GitHubActionsLogGroup -Title 'Start ClamAV daemon.'
	Try {
		clamd
	}
	Catch {
		Write-GitHubActionsError -Message "Unexpected issues when start ClamAV daemon: $_"
		Exit-GitHubActionsLogGroup
		Exit 1
	}
	Exit-GitHubActionsLogGroup
}
Function Invoke-Tools {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$SessionId,
		[Parameter(Mandatory = $True, Position = 1)][String]$SessionTitle
	)
	Write-Host -Object "Begin of session `"$SessionTitle`"."
	[PSCustomObject[]]$Elements = Get-ChildItem -LiteralPath $Env:GITHUB_WORKSPACE -Recurse -Force
	If ($Elements.Count -ieq 0){
		Write-GitHubActionsError -Message "Unable to scan session `"$SessionTitle`" due to the workspace is empty! If this is incorrect, probably something went wrong."
		$Script:StatisticsIssuesSessions.Other += $SessionId
		Write-Host -Object "End of session `"$SessionTitle`"."
		Return
	}
	[Boolean]$SkipClamAV = Test-StringMatchRegExs -Item $SessionId -Matchers $ClamAVIgnores.OnlySessions.Session
	[Boolean]$SkipYara = Test-StringMatchRegExs -Item $SessionId -Matchers $YaraIgnores.OnlySessions.Session
	[UInt64]$ElementsIsDirectoryCount = 0
	[String[]]$ElementsListClamAV = @()
	[String[]]$ElementsListYara = @()
	[PSCustomObject[]]$ElementsListDisplay = @()
	ForEach ($Element In (
		$Elements |
			Sort-Object -Property 'FullName'
	)) {
		[Boolean]$ElementIsDirectory = Test-Path -LiteralPath $Element.FullName -PathType 'Container'
		[String]$ElementName = $Element.FullName -ireplace "^$GitHubActionsWorkspaceRootRegEx", ''
		[Hashtable]$ElementListDisplay = @{
			Element = $ElementName
			Flags = @()
		}
		If ($ElementIsDirectory) {
			$ElementsIsDirectoryCount += 1
			$ElementListDisplay.Flags += 'D'
		}
		Else {
			$ElementListDisplay.Sizes = $Element.Length
			$Script:StatisticsTotalSizes.All += $Element.Length
		}
		If ($ClamAVEnable -and !$SkipClamAV -and (
			($ElementIsDirectory -and $ClamAVSubcursive) -or
			!$ElementIsDirectory
		) -and !(Test-StringMatchRegExs -Item $ElementName -Matchers $ClamAVIgnores.OnlyPaths.Path)) {
			$ElementsListClamAV += $Element.FullName
			$ElementListDisplay.Flags += 'C'
			If (!$ElementIsDirectory) {
				$Script:StatisticsTotalSizes.ClamAV += $Element.Length
			}
		}
		If ($YaraEnable -and !$SkipYara -and !$ElementIsDirectory -and !(Test-StringMatchRegExs -Item $ElementName -Matchers $YaraIgnores.OnlyPaths.Path)) {
			$ElementsListYara += $Element.FullName
			$ElementListDisplay.Flags += 'Y'
			$Script:StatisticsTotalSizes.Yara += $Element.Length
		}
		$ElementListDisplay.Flags = $ElementListDisplay.Flags |
			Sort-Object |
			Join-String -Separator ''
		$ElementsListDisplay += [PSCustomObject]$ElementListDisplay
	}
	$Script:StatisticsTotalElements.All += $Elements.Count
	$Script:StatisticsTotalElements.ClamAV += $ElementsListClamAV.Count
	$Script:StatisticsTotalElements.Yara += $ElementsListYara.Count
	Enter-GitHubActionsLogGroup -Title "Elements of session `"$SessionTitle`" (Elements: $($Elements.Count); irectory: $ElementsIsDirectoryCount; ClamAV: $($ElementsListClamAV.Count); Yara: $($ElementsListYara.Count)):"
	$ElementsListDisplay |
		Format-Table -Property @(
			'Element',
			'Flags',
			@{ Expression = 'Sizes'; Alignment = 'Right' }
		) -AutoSize -Wrap
	Exit-GitHubActionsLogGroup
	If ($ClamAVEnable -and !$SkipClamAV -and ($ElementsListClamAV.Count -igt 0)) {
		[String]$ElementsListClamAVFullName = (New-TemporaryFile).FullName
		Set-Content -LiteralPath $ElementsListClamAVFullName -Value (
			$ElementsListClamAV |
				Join-String -Separator "`n"
		) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via ClamAV."
		Try {
			[String[]]$ClamAVOutput = Invoke-Expression -Command "clamdscan --fdpass --file-list=`"$ElementsListClamAVFullName`" --multiscan"
			[UInt32]$ClamAVExitCode = $LASTEXITCODE
		}
		Catch {
			Write-GitHubActionsError -Message "Unexpected issues when invoke ClamAV (SessionID: $SessionId): $_"
			Exit-GitHubActionsLogGroup
			Exit 1
		}
		Enter-GitHubActionsLogGroup -Title "ClamAV result of session `"$SessionTitle`":"
		[String[]]$ClamAVResultError = @()
		[Hashtable]$ClamAVResultFound = @{}
		ForEach ($Line In (
			$ClamAVOutput |
				ForEach-Object -Process { $_ -ireplace "^$GitHubActionsWorkspaceRootRegEx", '' }
		)) {
			If ($Line -cmatch '^[-=]+\s*SCAN SUMMARY\s*[-=]+$') {
				Break
			}
			If (
				($Line -cmatch ': OK$') -or
				($Line -imatch '^\s*$')
			) {
				Continue
			}
			If ($Line -cmatch ': .+ FOUND$') {
				[String]$ClamAVElementIssue = $Line -creplace ' FOUND$', ''
				Write-GitHubActionsDebug -Message $ClamAVElementIssue
				[String]$Element, [String]$Signature = $ClamAVElementIssue -isplit '(?<=^.+?): '
				If ($Null -ieq $ClamAVResultFound[$Element]) {
					$ClamAVResultFound[$Element] = @()
				}
				If ($Signature -inotin $ClamAVResultFound[$Element]) {
					$ClamAVResultFound[$Element] += $Signature
				}
				Continue
			}
			$ClamAVResultError += $Line
		}
		If ($ClamAVResultFound.Count -igt 0) {
			Write-GitHubActionsError -Message "Found issues in session `"$SessionTitle`" via ClamAV ($($ClamAVResultFound.Count)): `n$(
				$ClamAVResultFound.GetEnumerator() |
					ForEach-Object -Process {
						[String[]]$IssueSignatures = $_.Value |
							Sort-Object -Unique -CaseSensitive
						[PSCustomObject]@{
							Element = $_.Name
							Signatures_List = $IssueSignatures |
								Join-String -Separator ', '
							Signatures_Count = $IssueSignatures.Count
						}
					} |
					Sort-Object -Property 'Element' |
					Format-List -Property '*' |
					Out-String
			)"
			If ($SessionId -inotin $Script:StatisticsIssuesSessions.ClamAV) {
				$Script:StatisticsIssuesSessions.ClamAV += $SessionId
			}
		}
		If ($ClamAVResultError.Count -igt 0) {
			Write-GitHubActionsError -Message "Unexpected ClamAV result ``$ClamAVExitCode`` in session `"$SessionTitle`":`n$($ClamAVResultError -join "`n")"
			If ($SessionId -inotin $Script:StatisticsIssuesSessions.ClamAV) {
				$Script:StatisticsIssuesSessions.ClamAV += $SessionId
			}
		}
		Exit-GitHubActionsLogGroup
		Remove-Item -LiteralPath $ElementsListClamAVFullName -Force -Confirm:$False
	}
	If ($YaraEnable -and !$SkipYara -and ($ElementsListYara.Count -igt 0)) {
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
				[String[]]$YaraOutput = Invoke-Expression -Command "yara --scan-list `"$(Join-Path -Path $YaraRulesAssetsRoot -ChildPath $YaraRule.Location)`" `"$ElementsListYaraFullName`""
				[UInt32]$YaraExitCode = $LASTEXITCODE
			}
			Catch {
				Write-GitHubActionsError -Message "Unexpected issues when invoke YARA (SessionID: $SessionId): $_"
				Exit-GitHubActionsLogGroup
				Exit 1
			}
			If ($YaraExitCode -ieq 0) {
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
					ElseIf ($Line.Length -igt 0) {
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
		If ($YaraResultFound.Count -igt 0) {
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
					Sort-Object -Property 'Element' |
					Format-List -Property '*' |
					Out-String
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
If ($Targets.Count -ieq 0) {
	Invoke-Tools -SessionId 'current' -SessionTitle 'Current'
	If ($GitIntegrate) {
		Write-Host -Object 'Import Git commits meta.'
		Try {
			[PSCustomObject[]]$GitCommits = Get-GitCommits -AllBranches:$GitIncludeAllBranches -Reflogs:$GitIncludeRefLogs
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to integrate with Git! $_ If this is incorrect, probably Git database is broken and/or invalid."
			Throw
		}
		If ($GitCommits.Count -ile 1) {
			Write-GitHubActionsWarning -Message "Current Git repository has only $($GitCommits.Count) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: Re-run cannot apply the modified workflow!)"
		}
		For ([UInt64]$GitCommitsIndex = 0; $GitCommitsIndex -ilt $GitCommits.Count; $GitCommitsIndex++) {
			[String]$GitCommitHash = $GitCommits[$GitCommitsIndex]
			[String]$GitSessionTitle = "$GitCommitHash (#$($GitReverse ? ($GitCommits.Count - $GitCommitsIndex) : ($GitCommitsIndex + 1))/$($GitCommits.Count))"
			Enter-GitHubActionsLogGroup -Title "Git checkout for commit $GitSessionTitle."
			Try {
				Invoke-Expression -Command "git checkout $GitCommitHash --force --quiet"
			}
			Catch {
				Write-GitHubActionsError -Message "Unexpected issues when invoke Git checkout (SessionID: $GitCommitHash): $_"
				Exit-GitHubActionsLogGroup
				Exit 1
			}
			If ($LASTEXITCODE -ieq 0) {
				Exit-GitHubActionsLogGroup
				Invoke-Tools -SessionId $GitCommitHash -SessionTitle "Git Commit $GitSessionTitle"
				Continue
			}
			Write-GitHubActionsError -Message "Unexpected Git checkout exit code ``$LASTEXITCODE`` in commit $GitSessionTitle!"
			If ($GitCommitHash -inotin $StatisticsIssuesSessions.Other) {
				$StatisticsIssuesSessions.Other += $GitCommitHash
			}
			Exit-GitHubActionsLogGroup
		}
	}
}
Else {
	If ((Get-ChildItem -LiteralPath $Env:GITHUB_WORKSPACE -Recurse -Force).Count -igt 0) {
		Write-GitHubActionsFail -Message 'Require a clean workspace for network targets!'
		Throw
	}
	ForEach ($Target In $Targets) {
		If (!(Test-StringIsUri -InputObject $Target)) {
			Write-GitHubActionsWarning -Message "``$($Target.OriginalString)`` is not a valid URI!"
			Continue
		}
		Enter-GitHubActionsLogGroup -Title "Fetch file `"$Target`"."
		[String]$NetworkTemporaryFileFullPath = Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath (New-RandomToken -Length 32)
		Try {
			Invoke-WebRequest -Uri $Target -UseBasicParsing -Method 'Get' -OutFile $NetworkTemporaryFileFullPath
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to fetch file `"$Target`"!"
			Exit-GitHubActionsLogGroup
			Continue
		}
		Exit-GitHubActionsLogGroup
		Invoke-Tools -SessionId $Target -SessionTitle $Target
		Remove-Item -LiteralPath $NetworkTemporaryFileFullPath -Force -Confirm:$False
	}
}
If ($ClamAVEnable) {
	Write-Host -Object 'Stop ClamAV daemon.'
	Get-Process -Name 'clamd' -ErrorAction 'Continue' |
		Stop-Process
}
$CleanupManager.Cleanup()
Write-Header1 -Header 'Statistics'
[UInt64]$TotalIssues = $StatisticsIssuesSessions.ClamAV.Count + $StatisticsIssuesSessions.Other.Count + $StatisticsIssuesSessions.Yara.Count
[PSCustomObject[]]@(
	[PSCustomObject]@{
		Name = 'TotalElements_Count'
		All = $StatisticsTotalElements.All
		ClamAV = $StatisticsTotalElements.ClamAV
		YARA = $StatisticsTotalElements.Yara
	},
	[PSCustomObject]@{
		Name = 'TotalElements_Percentage'
		ClamAV = ($StatisticsTotalElements.All -ieq 0) ? 0 : ($StatisticsTotalElements.ClamAV / $StatisticsTotalElements.All * 100)
		YARA = ($StatisticsTotalElements.All -ieq 0) ? 0 : ($StatisticsTotalElements.Yara / $StatisticsTotalElements.All * 100)
	},
	[PSCustomObject]@{
		Name = 'TotalIssuesSessions_Count'
		All = $TotalIssues
		ClamAV = $StatisticsIssuesSessions.ClamAV.Count
		YARA = $StatisticsIssuesSessions.Yara.Count
		Other = $StatisticsIssuesSessions.Other.Count
	},
	[PSCustomObject]@{
		Name = 'TotalIssuesSessions_Percentage'
		ClamAV = ($TotalIssues -ieq 0) ? 0 : ($StatisticsIssuesSessions.ClamAV.Count / $TotalIssues * 100)
		YARA = ($TotalIssues -ieq 0) ? 0 : ($StatisticsIssuesSessions.Yara.Count / $TotalIssues * 100)
		Other = ($TotalIssues -ieq 0) ? 0 : ($StatisticsIssuesSessions.Other.Count / $TotalIssues * 100)
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_B'
		All = $StatisticsTotalSizes.All
		ClamAV = $StatisticsTotalSizes.ClamAV
		YARA = $StatisticsTotalSizes.Yara
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_KB'
		All = $StatisticsTotalSizes.All / 1KB
		ClamAV = $StatisticsTotalSizes.ClamAV / 1KB
		YARA = $StatisticsTotalSizes.Yara / 1KB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_MB'
		All = $StatisticsTotalSizes.All / 1MB
		ClamAV = $StatisticsTotalSizes.ClamAV / 1MB
		YARA = $StatisticsTotalSizes.Yara / 1MB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_GB'
		All = $StatisticsTotalSizes.All / 1GB
		ClamAV = $StatisticsTotalSizes.ClamAV / 1GB
		YARA = $StatisticsTotalSizes.Yara / 1GB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_Percentage'
		ClamAV = $StatisticsTotalSizes.ClamAV / $StatisticsTotalSizes.All * 100
		YARA = $StatisticsTotalSizes.Yara / $StatisticsTotalSizes.All * 100
	}
) |
	Format-Table -Property @(
		'Name',
		@{ Expression = 'All'; Alignment = 'Right' },
		@{ Expression = 'ClamAV'; Alignment = 'Right' },
		@{ Expression = 'YARA'; Alignment = 'Right' },
		@{ Expression = 'Other'; Alignment = 'Right' }
	) -AutoSize -Wrap
If ($TotalIssues -igt 0) {
	Write-Header1 -Header 'Issues Sessions'
	[PSCustomObject]@{
		ClamAV = $StatisticsIssuesSessions.ClamAV |
			Join-String -Separator ', '
		YARA = $StatisticsIssuesSessions.Yara |
			Join-String -Separator ', '
		Other = $StatisticsIssuesSessions.Other |
			Join-String -Separator ', '
	} |
		Format-List -Property '*'
	Exit-GitHubActionsLogGroup
}
If ($TotalIssues -igt 0) {
	Exit 1
}
Exit 0
