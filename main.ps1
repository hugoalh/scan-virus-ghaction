#Requires -PSEdition Core
#Requires -Version 7.2
Write-Host -Object 'Begin process.'
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'assets',
		'git',
		'token',
		'utility'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
$Null = Test-GitHubActionsEnvironment -Mandatory# Use `Out-Null` will cause script halted exception.
[Hashtable]$ImportTsvParameters = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[String]$AssetsRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[Hashtable]$AssetsSubPath = @{
	ClamAVOfficial = '/var/lib/clamav'
	ClamAVUnofficial = Join-Path -Path $AssetsRoot -ChildPath 'clamav-unofficial-signatures'
	Yara = Join-Path -Path $AssetsRoot -ChildPath 'yara-rules'
}
[RegEx]$GitHubActionsWorkspaceRootRegEx = "$([RegEx]::Escape($Env:GITHUB_WORKSPACE))\/"
[Hashtable]$IssuesSessions = @{
	ClamAV = @()
	Yara = @()
	Other = @()
}
[String[]]$PostCleanUpFiles = @()
[Hashtable]$Statistics = @{
	Elements = @{
		All = 0
		ClamAV = 0
		Yara = 0
	}
	Sizes = @{
		All = 0
		ClamAV = 0
		Yara = 0
	}
}
Enter-GitHubActionsLogGroup -Title 'Import inputs.'
[Hashtable]$GitHubActionInput = @{}
[RegEx]$GitHubActionInput.InputListDelimiter = Get-GitHubActionsInput -Name 'input_list_delimiter' -Mandatory -EmptyStringAsNull
Write-NameValue -Name 'Input_List_Delimiter' -Value $GitHubActionInput.InputListDelimiter
[String]$GitHubActionInput.InputTableParser = ''
Switch -RegEx (Get-GitHubActionsInput -Name 'input_table_parser' -Mandatory -EmptyStringAsNull -Trim) {
	'^c(?:omma|sv)$' {
		$GitHubActionInput.InputTableParser = 'csv'
		Break
	}
	'^c(?:omma|sv)-?s(?:ingle(?:line)?)?$' {
		$GitHubActionInput.InputTableParser = 'csv-s'
		Break
	}
	'^c(?:omma|sv)-?m(?:ulti(?:ple)?(?:line)?)?$' {
		$GitHubActionInput.InputTableParser = 'csv-m'
		Break
	}
	'^t(?:ab|sv)$' {
		$GitHubActionInput.InputTableParser = 'tsv'
		Break
	}
	'^ya?ml$' {
		$GitHubActionInput.InputTableParser = 'yaml'
		Break
	}
	Default {
		Write-GitHubActionsFail -Message "``$_`` is not a valid table parser!"
		Throw
	}
}
Write-NameValue -Name 'Input_Table_Parser' -Value $GitHubActionInput.InputTableParser
[Uri[]]$GitHubActionInput.Targets = Get-InputList -Name 'targets' -Delimiter $GitHubActionInput.InputListDelimiter |
	ForEach-Object -Process { $_ -as [Uri] }
Write-NameValue -Name "Targets ($($GitHubActionInput.Targets.Count))" -Value (($GitHubActionInput.Targets.Count -ieq 0) ? 'Local' : (
	$GitHubActionInput.Targets |
		Select-Object -ExpandProperty 'OriginalString' |
		Join-String -Separator ', '
))
[Boolean]$GitHubActionInput.GitIntegrate = Get-InputBoolean -Name 'git_integrate'
Write-NameValue -Name 'Git_Integrate' -Value $GitHubActionInput.GitIntegrate





[PSCustomObject[]]$GitIgnores = Get-InputTable -Name 'git_ignores' -Type $InputTableParser
Write-NameValue -Name "Git_Ignores ($($GitIgnores.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject ($GitIgnores | Format-Table -Property '*' -AutoSize -Wrap | Out-String))"
[Boolean]$GitLogAllBranches = Get-InputBoolean -Name 'git_log_allbranches'
Write-NameValue -Name 'Git_Log_AllBranches' -Value $GitLogAllBranches
[Boolean]$GitLogReflogs = Get-InputBoolean -Name 'git_log_reflogs'
Write-NameValue -Name 'Git_Log_Reflogs' -Value $GitLogReflogs
[Boolean]$GitReverse = Get-InputBoolean -Name 'git_reverse'
Write-NameValue -Name 'Git_Reverse' -Value $GitReverse
[Boolean]$ClamAVEnable = Get-InputBoolean -Name 'clamav_enable'
Write-NameValue -Name 'ClamAV_Enable' -Value $ClamAVEnable
[Boolean]$ClamAVDaemon = Get-InputBoolean -Name 'clamav_daemon'
Write-NameValue -Name 'ClamAV_Daemon' -Value $ClamAVDaemon
[PSCustomObject[]]$ClamAVIgnoresRaw = Get-InputTable -Name 'clamav_ignores' -Type $InputTableParser
[PSCustomObject]$ClamAVIgnores = Group-ScanVirusToolsIgnores -InputObject $ClamAVIgnoresRaw
Write-NameValue -Name "ClamAV_Ignores_OnlyPaths ($($ClamAVIgnores.OnlyPaths.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject (
	$ClamAVIgnores.OnlyPaths |
		Format-List -Property '*' |
		Out-String
))"
Write-NameValue -Name "ClamAV_Ignores_OnlySessions ($($ClamAVIgnores.OnlySessions.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject (
	$ClamAVIgnores.OnlySessions |
		Format-List -Property '*' |
		Out-String
))"
Write-NameValue -Name "ClamAV_Ignores_Others ($($ClamAVIgnores.Others.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject (
	$ClamAVIgnores.Others |
		Format-List -Property '*' |
		Out-String
))"
[Boolean]$ClamAVMultiScan = Get-InputBoolean -Name 'clamav_multiscan'
Write-NameValue -Name 'ClamAV_MultiScan' -Value $ClamAVMultiScan
[Boolean]$ClamAVReloadPerSession = Get-InputBoolean -Name 'clamav_reloadpersession'
Write-NameValue -Name 'ClamAV_ReloadPerSession' -Value $ClamAVReloadPerSession
[Boolean]$ClamAVSubcursive = Get-InputBoolean -Name 'clamav_subcursive'
Write-NameValue -Name 'ClamAV_Subcursive' -Value $ClamAVSubcursive
[RegEx[]]$ClamAVUnofficialSignaturesRegEx = Get-InputList -Name 'clamav_unofficialsignatures' -Delimiter $InputListDelimiter
Write-NameValue -Name "ClamAV_UnofficialSignatures_RegEx ($($ClamAVUnofficialSignaturesRegEx.Count))" -Value "`n$(
	$ClamAVUnofficialSignaturesRegEx |
		Join-String -Separator "`n"
)"
[Boolean]$YaraEnable = Get-InputBoolean -Name 'yara_enable'
Write-NameValue -Name 'YARA_Enable' -Value $YaraEnable
[PSCustomObject[]]$YaraIgnoresRaw = Get-InputTable -Name 'yara_ignores' -Type $InputTableParser
[PSCustomObject]$YaraIgnores = Group-ScanVirusToolsIgnores -InputObject $YaraIgnoresRaw
Write-NameValue -Name "YARA_Ignores_OnlyPaths ($($YaraIgnores.OnlyPaths.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject (
	$YaraIgnores.OnlyPaths |
		Format-List -Property '*' |
		Out-String
))"
Write-NameValue -Name "YARA_Ignores_OnlySessions ($($YaraIgnores.OnlySessions.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject (
	$YaraIgnores.OnlySessions |
		Format-List -Property '*' |
		Out-String
))"
Write-NameValue -Name "YARA_Ignores_Others ($($YaraIgnores.Others.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject (
	$YaraIgnores.Others |
		Format-List -Property '*' |
		Out-String
))"
[RegEx[]]$YaraRulesRegEx = Get-InputList -Name 'yara_rules' -Delimiter $InputListDelimiter
Write-NameValue -Name "YARA_Rules_RegEx ($($YaraRulesRegEx.Count))" -Value "`n$(
	$YaraRulesRegEx |
		Join-String -Separator "`n"
)"
[Boolean]$YaraToolWarning = Get-InputBoolean -Name 'yara_toolwarning'
Write-NameValue -Name 'YARA_ToolWarning' -Value $YaraToolWarning
[Boolean]$UpdateAssets = Get-InputBoolean -Name 'update_assets'
Write-NameValue -Name 'Update_Assets' -Value $UpdateAssets
[Boolean]$UpdateClamAV = Get-InputBoolean -Name 'update_clamav'
Write-NameValue -Name 'Update_ClamAV' -Value $UpdateClamAV
Exit-GitHubActionsLogGroup
If ($True -inotin @($ClamAVEnable, $YaraEnable)) {
	Write-GitHubActionsFail -Message 'No tools enabled!'
	Throw
}
If ($UpdateClamAV -and $ClamAVEnable) {
	Enter-GitHubActionsLogGroup -Title 'Update ClamAV assets via FreshClam.'
	Try {
		Invoke-Expression -Command 'freshclam'
	}
	Catch {
		Write-GitHubActionsWarning -Message "Unexpected issues when update ClamAV assets via FreshClam (mostly will not cause critical issues): $_"
	}
	If ($LASTEXITCODE -ine 0) {
		Write-GitHubActionsWarning -Message "Unexpected exit code ``$LASTEXITCODE`` when update ClamAV assets via FreshClam (mostly will not cause critical issues)!"
	}
	Exit-GitHubActionsLogGroup
}
If ($UpdateAssets -and (
	($ClamAVEnable -and $ClamAVUnofficialSignaturesRegEx.Count -igt 0) -or
	($YaraEnable -and $YaraRulesRegEx.Count -igt 0)
)) {
	Enter-GitHubActionsLogGroup -Title 'Update assets.'
	Try {
		Update-GitHubActionScanVirusAssets
	} Catch {
		Write-GitHubActionsError -Message $_
		Exit-GitHubActionsLogGroup
		Exit 1
	}
	Exit-GitHubActionsLogGroup
}
Enter-GitHubActionsLogGroup -Title 'Read assets index.'
[PSCustomObject[]]$ClamAVUnofficialSignaturesAssetsIndex = Import-Csv -LiteralPath (Join-Path -Path $AssetsSubPath.ClamAVUnofficial -ChildPath 'index.tsv') @ImportTsvParameters
[PSCustomObject[]]$YaraRulesAssetsIndex = Import-Csv -LiteralPath (Join-Path -Path $AssetsSubPath.Yara -ChildPath 'index.tsv') @ImportTsvParameters
[PSCustomObject[]]$ClamAVUnofficialSignaturesApply = $ClamAVUnofficialSignaturesAssetsIndex |
	Where-Object -FilterScript { !(Test-StringMatchRegExs -Target $_.Name -Matchers $ClamAVUnofficialSignaturesRegEx) } |
	Sort-Object -Property 'Name'
[PSCustomObject[]]$YaraRulesApply = $YaraRulesAssetsIndex |
	Where-Object -FilterScript { !(Test-StringMatchRegExs -Target $_.Name -Matchers $ClamAVUnofficialSignaturesRegEx) } |
	Sort-Object -Property 'Name'
[PSCustomObject[]]$ClamAVUnofficialSignaturesIndexDisplay = @()
ForEach ($ClamAVUnofficialSignaturesAssetIndex In $ClamAVUnofficialSignaturesAssetsIndex) {
	[String]$ClamAVUnofficialSignaturesAssetIndexFullName = Join-Path -Path $AssetsSubPath.ClamAVUnofficial -ChildPath $ClamAVUnofficialSignaturesAssetIndex.Location
	[Boolean]$ClamAVUnofficialSignaturesAssetIndexExist = Test-Path -LiteralPath $ClamAVUnofficialSignaturesAssetIndexFullName
	[Boolean]$ClamAVUnofficialSignaturesAssetIndexApply = $ClamAVUnofficialSignaturesAssetIndex.Name -iin $ClamAVUnofficialSignaturesApply.Name
	$ClamAVUnofficialSignaturesIndexDisplay += [PSCustomObject]@{
		Name = $ClamAVUnofficialSignaturesAssetIndex.Name
		Exist = $ClamAVUnofficialSignaturesAssetIndexExist
		Apply = $ClamAVUnofficialSignaturesAssetIndexApply
	}
	If ($ClamAVUnofficialSignaturesAssetIndexExist -and $ClamAVUnofficialSignaturesAssetIndexApply) {
		[String]$ClamAVUnofficialSignatureAssetDestination = Join-Path -Path $AssetsSubPath.ClamAVOfficial -ChildPath ($ClamAVUnofficialSignaturesAssetIndex.Location -ireplace '\/', '_')
		Copy-Item -LiteralPath $ClamAVUnofficialSignaturesAssetIndexFullName -Destination $ClamAVUnofficialSignatureAssetDestination -Confirm:$False
		$PostCleanUpFiles += $ClamAVUnofficialSignatureAssetDestination
	}
}
[PSCustomObject[]]$ClamAVUnofficialSignaturesAssetsNotExist = $ClamAVUnofficialSignaturesIndexDisplay |
	Where-Object -FilterScript { !$_.Exist }
Write-NameValue -Name "ClamAV unofficial signatures index (Index: $($ClamAVUnofficialSignaturesAssetsIndex.Count); Exist: $($ClamAVUnofficialSignaturesAssetsIndex.Count - $ClamAVUnofficialSignaturesAssetsNotExist.Count); Apply: $($ClamAVUnofficialSignaturesApply.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject (
	$ClamAVUnofficialSignaturesIndexDisplay |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Apply'; Alignment = 'Right' }
		) -AutoSize -Wrap |
		Out-String
))"
If ($ClamAVUnofficialSignaturesAssetsNotExist.Count -igt 0) {
	Write-GitHubActionsWarning -Message "Some of the ClamAV unofficial signatures are indexed but not exist ($($ClamAVUnofficialSignaturesAssetsNotExist.Count)): $(
		$ClamAVUnofficialSignaturesAssetsNotExist.Name |
			Join-String -Separator ', '
	)"
}
[PSCustomObject[]]$YaraRulesIndexDisplay = @()
ForEach ($YaraRulesAssetIndex In $YaraRulesAssetsIndex) {
	[String]$YaraRuleFullName = Join-Path -Path $AssetsSubPath.Yara -ChildPath $YaraRulesAssetIndex.Location
	[Boolean]$YaraRuleAssetExist = Test-Path -LiteralPath $YaraRuleFullName
	[Boolean]$YaraRuleAssetApply = $YaraRulesAssetIndex.Name -iin $YaraRulesApply.Name
	$YaraRulesIndexDisplay += [PSCustomObject]@{
		Name = $YaraRulesAssetIndex.Name
		Exist = $YaraRuleAssetExist
		Apply = $YaraRuleAssetApply
	}
}
[PSCustomObject[]]$YaraRulesAssetsNotExist = $YaraRulesIndexDisplay |
	Where-Object -FilterScript { !$_.Exist }
Write-NameValue -Name "YARA rules index (Index: $($YaraRulesAssetsIndex.Count); Exist: $($YaraRulesAssetsIndex.Count - $YaraRulesAssetsNotExist.Count); Apply: $($YaraRulesApply.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject (
	$YaraRulesIndexDisplay |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'Exist'; Alignment = 'Right' },
			@{ Expression = 'Apply'; Alignment = 'Right' }
		) -AutoSize -Wrap |
		Out-String
))"
If ($YaraRulesAssetsNotExist.Count -igt 0) {
	Write-GitHubActionsWarning -Message "Some of the YARA rules are indexed but not exist ($($YaraRulesAssetsNotExist.Count)): $(
		$YaraRulesAssetsNotExist.Name |
			Join-String -Separator ', '
	)"
}
Exit-GitHubActionsLogGroup
If ($ClamAVEnable -and $ClamAVDaemon) {
	Enter-GitHubActionsLogGroup -Title 'Start ClamAV daemon.'
	Invoke-Expression -Command 'clamd'
	Exit-GitHubActionsLogGroup
}
Function Invoke-ScanVirusTools {
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
		If ($SessionId -inotin $Script:IssuesSessions.Other) {
			$Script:IssuesSessions.Other += $SessionId
		}
		Write-Host -Object "End of session `"$SessionTitle`"."
		Return
	}
	[Boolean]$SkipClamAV = Test-StringMatchRegExs -Target $SessionId -Matchers $ClamAVIgnores.OnlySessions.Session
	[Boolean]$SkipYara = Test-StringMatchRegExs -Target $SessionId -Matchers $YaraIgnores.OnlySessions.Session
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
			$Script:Statistics.Sizes.All += $Element.Length
		}
		If ($ClamAVEnable -and !$SkipClamAV -and (
			($ElementIsDirectory -and $ClamAVSubcursive) -or
			!$ElementIsDirectory
		) -and !(Test-StringMatchRegExs -Target $ElementName -Matchers $ClamAVIgnores.OnlyPaths.Path)) {
			$ElementsListClamAV += $Element.FullName
			$ElementListDisplay.Flags += 'C'
			If (!$ElementIsDirectory) {
				$Script:Statistics.Sizes.ClamAV += $Element.Length
			}
		}
		If ($YaraEnable -and !$SkipYara -and !$ElementIsDirectory -and !(Test-StringMatchRegExs -Target $ElementName -Matchers $YaraIgnores.OnlyPaths.Path)) {
			$ElementsListYara += $Element.FullName
			$ElementListDisplay.Flags += 'Y'
			$Script:Statistics.Sizes.Yara += $Element.Length
		}
		$ElementListDisplay.Flags = $ElementListDisplay.Flags |
			Sort-Object |
			Join-String -Separator ''
		$ElementsListDisplay += [PSCustomObject]$ElementListDisplay
	}
	$Script:Statistics.Elements.All += $Elements.Count
	$Script:Statistics.Elements.ClamAV += $ElementsListClamAV.Count
	$Script:Statistics.Elements.Yara += $ElementsListYara.Count
	Enter-GitHubActionsLogGroup -Title "Elements of session `"$SessionTitle`" (Elements: $($Elements.Count); irectory: $ElementsIsDirectoryCount; ClamAV: $($ElementsListClamAV.Count); Yara: $($ElementsListYara.Count)):"
	Write-OptimizePSFormatDisplay -InputObject (
		$ElementsListDisplay |
			Format-Table -Property @(
				'Element',
				'Flags',
				@{ Expression = 'Sizes'; Alignment = 'Right' }
			) -AutoSize -Wrap |
			Out-String
	)
	Exit-GitHubActionsLogGroup
	If ($ClamAVEnable -and !$SkipClamAV -and ($ElementsListClamAV.Count -igt 0)) {
		[String]$ElementsListClamAVFullName = (New-TemporaryFile).FullName
		Set-Content -LiteralPath $ElementsListClamAVFullName -Value (
			$ElementsListClamAV |
				Join-String -Separator "`n"
		) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via ClamAV."
		Try {
			[String[]]$ClamAVOutput = Invoke-Expression -Command ($ClamAVDaemon ? "clamdscan --fdpass --file-list=`"$ElementsListClamAVFullName`"$($ClamAVMultiScan ? ' --multiscan' : '')$($ClamAVReloadPerSession ? ' --reload' : '')" : "clamscan --detect-broken=yes --file-list=`"$ElementsListClamAVFullName`" --follow-dir-symlinks=0 --follow-file-symlinks=0 --recursive")
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
			Write-GitHubActionsError -Message "Found issues in session `"$SessionTitle`" via ClamAV ($($ClamAVResultFound.Count)): `n$(Optimize-PSFormatDisplay -InputObject (
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
			))"
			If ($SessionId -inotin $Script:IssuesSessions.ClamAV) {
				$Script:IssuesSessions.ClamAV += $SessionId
			}
		}
		If ($ClamAVResultError.Count -igt 0) {
			Write-GitHubActionsError -Message "Unexpected ClamAV result ``$ClamAVExitCode`` in session `"$SessionTitle`":`n$($ClamAVResultError -join "`n")"
			If ($SessionId -inotin $Script:IssuesSessions.ClamAV) {
				$Script:IssuesSessions.ClamAV += $SessionId
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
		ForEach ($YaraRule In $YaraRulesApply) {
			Try {
				[String[]]$YaraOutput = Invoke-Expression -Command "yara --scan-list$($YaraToolWarning ? '' : ' --no-warnings') `"$(Join-Path -Path $AssetsSubPath.Yara -ChildPath $YaraRule.Location)`" `"$ElementsListYaraFullName`""
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
				If ($SessionId -inotin $Script:IssuesSessions.Yara) {
					$Script:IssuesSessions.Yara += $SessionId
				}
			}
		}
		Enter-GitHubActionsLogGroup -Title "YARA result of session `"$SessionTitle`":"
		If ($YaraResultFound.Count -igt 0) {
			Write-GitHubActionsError -Message "Found issues in session `"$SessionTitle`" via YARA ($($YaraResultFound.Count)): `n$(Optimize-PSFormatDisplay -InputObject (
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
			))"
			If ($SessionId -inotin $Script:IssuesSessions.Yara) {
				$Script:IssuesSessions.Yara += $SessionId
			}
		}
		Exit-GitHubActionsLogGroup
		Remove-Item -LiteralPath $ElementsListYaraFullName -Force -Confirm:$False
	}
	Write-Host -Object "End of session `"$SessionTitle`"."
}
If ($Targets.Count -ieq 0) {
	Invoke-ScanVirusTools -SessionId 'current' -SessionTitle 'Current'
	If ($GitIntegrate) {
		If (Test-Path -LiteralPath (Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath '.git') -PathType 'Container') {
			Write-Host -Object 'Import Git information.'
			Try {
				[PSCustomObject[]]$GitCommits = Get-GitCommitsInformation -Property -AllBranches:$GitLogAllBranches -Reflogs:$GitLogReflogs
			}
			Catch {
				Write-GitHubActionsFail -Message $_
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
					Invoke-ScanVirusTools -SessionId $GitCommitHash -SessionTitle "Git Commit $GitSessionTitle"
					Continue
				}
				Write-GitHubActionsError -Message "Unexpected Git checkout exit code ``$LASTEXITCODE`` in commit $GitSessionTitle!"
				If ($GitCommitHash -inotin $IssuesSessions.Other) {
					$IssuesSessions.Other += $GitCommitHash
				}
				Exit-GitHubActionsLogGroup
			}
		}
		Else {
			Write-GitHubActionsWarning -Message 'Unable to integrate with Git due to the workspace is not a Git repository! If this is incorrect, probably Git data is broken and/or invalid.'
		}
	}
}
Else {
	If ((Get-ChildItem -LiteralPath $Env:GITHUB_WORKSPACE -Recurse -Force).Count -igt 0) {
		Write-GitHubActionsFail -Message 'Require a clean workspace for network targets!'
		Throw
	}
	ForEach ($NetworkTarget In $NetworkTargets) {
		If (!(Test-StringIsUri -InputObject $NetworkTarget)) {
			Write-GitHubActionsWarning -Message "``$($NetworkTarget.OriginalString)`` is not a valid URI!"
			Continue
		}
		Enter-GitHubActionsLogGroup -Title "Fetch file `"$NetworkTarget`"."
		[String]$NetworkTemporaryFileFullPath = Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath "$(New-RandomToken -Length 8).$(New-RandomToken -Length 4)"
		Try {
			Invoke-WebRequest -Uri $NetworkTarget -UseBasicParsing -Method 'Get' -OutFile $NetworkTemporaryFileFullPath
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to fetch file `"$NetworkTarget`"!"
			Exit-GitHubActionsLogGroup
			Continue
		}
		Exit-GitHubActionsLogGroup
		Invoke-ScanVirusTools -SessionId $NetworkTarget -SessionTitle $NetworkTarget
		Remove-Item -LiteralPath $NetworkTemporaryFileFullPath -Force -Confirm:$False
	}
}
If ($ClamAVEnable -and $ClamAVDaemon) {
	Enter-GitHubActionsLogGroup -Title 'Stop ClamAV daemon.'
	Get-Process -Name '*clamd*' |
		Stop-Process
	Exit-GitHubActionsLogGroup
}
$PostCleanUpFiles |
	ForEach-Object -Process { Remove-Item -LiteralPath $_ -Force -Confirm:$False }
Enter-GitHubActionsLogGroup -Title 'Statistics:'
[UInt64]$TotalIssues = $IssuesSessions.ClamAV.Count + $IssuesSessions.Other.Count + $IssuesSessions.Yara.Count
Write-OptimizePSFormatDisplay -InputObject (
	[PSCustomObject[]]@(
		[PSCustomObject]@{
			Name = 'TotalElements_Count'
			All = $Statistics.Elements.All
			ClamAV = $Statistics.Elements.ClamAV
			YARA = $Statistics.Elements.Yara
		},
		[PSCustomObject]@{
			Name = 'TotalElements_Percentage'
			ClamAV = ($Statistics.Elements.All -ieq 0) ? 0 : ($Statistics.Elements.ClamAV / $Statistics.Elements.All * 100)
			YARA = ($Statistics.Elements.All -ieq 0) ? 0 : ($Statistics.Elements.Yara / $Statistics.Elements.All * 100)
		},
		[PSCustomObject]@{
			Name = 'TotalIssuesSessions_Count'
			All = $TotalIssues
			ClamAV = $IssuesSessions.ClamAV.Count
			YARA = $IssuesSessions.Yara.Count
			Other = $IssuesSessions.Other.Count
		},
		[PSCustomObject]@{
			Name = 'TotalIssuesSessions_Percentage'
			ClamAV = ($TotalIssues -ieq 0) ? 0 : ($IssuesSessions.ClamAV.Count / $TotalIssues * 100)
			YARA = ($TotalIssues -ieq 0) ? 0 : ($IssuesSessions.Yara.Count / $TotalIssues * 100)
			Other = ($TotalIssues -ieq 0) ? 0 : ($IssuesSessions.Other.Count / $TotalIssues * 100)
		},
		[PSCustomObject]@{
			Name = 'TotalSizes_B'
			All = $Statistics.Sizes.All
			ClamAV = $Statistics.Sizes.ClamAV
			YARA = $Statistics.Sizes.Yara
		},
		[PSCustomObject]@{
			Name = 'TotalSizes_KB'
			All = $Statistics.Sizes.All / 1KB
			ClamAV = $Statistics.Sizes.ClamAV / 1KB
			YARA = $Statistics.Sizes.Yara / 1KB
		},
		[PSCustomObject]@{
			Name = 'TotalSizes_MB'
			All = $Statistics.Sizes.All / 1MB
			ClamAV = $Statistics.Sizes.ClamAV / 1MB
			YARA = $Statistics.Sizes.Yara / 1MB
		},
		[PSCustomObject]@{
			Name = 'TotalSizes_GB'
			All = $Statistics.Sizes.All / 1GB
			ClamAV = $Statistics.Sizes.ClamAV / 1GB
			YARA = $Statistics.Sizes.Yara / 1GB
		},
		[PSCustomObject]@{
			Name = 'TotalSizes_Percentage'
			ClamAV = $Statistics.Sizes.ClamAV / $Statistics.Sizes.All * 100
			YARA = $Statistics.Sizes.Yara / $Statistics.Sizes.All * 100
		}
	) |
		Format-Table -Property @(
			'Name',
			@{ Expression = 'All'; Alignment = 'Right' },
			@{ Expression = 'ClamAV'; Alignment = 'Right' },
			@{ Expression = 'YARA'; Alignment = 'Right' },
			@{ Expression = 'Other'; Alignment = 'Right' }
		) -AutoSize -Wrap |
		Out-String
)
Exit-GitHubActionsLogGroup
If ($TotalIssues -igt 0) {
	Enter-GitHubActionsLogGroup -Title 'Issues sessions:'
	Write-OptimizePSFormatDisplay -InputObject (
		[PSCustomObject]@{
			ClamAV = $IssuesSessions.ClamAV |
				Join-String -Separator ', '
			YARA = $IssuesSessions.Yara |
				Join-String -Separator ', '
			Other = $IssuesSessions.Other |
				Join-String -Separator ', '
		} |
			Format-List -Property '*' |
			Out-String
	)
	Exit-GitHubActionsLogGroup
}
If ($TotalIssues -igt 0) {
	Exit 1
}
Exit 0
