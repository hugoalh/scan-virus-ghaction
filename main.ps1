Write-Host -Object 'Starting.'
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (@('assets', 'git', 'utility') | ForEach-Object -Process {
	Return (Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1")
}) -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
[Hashtable]$TsvParameters = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[String]$AssetsRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[String]$ClamAVDatabaseRoot = '/var/lib/clamav'
[String]$ClamAVUnofficialSignaturesAssetsRoot = Join-Path -Path $AssetsRoot -ChildPath 'clamav-unofficial-signatures'
[String]$YaraRulesAssetsRoot = Join-Path -Path $AssetsRoot -ChildPath 'yara-rules'
[RegEx]$GitHubActionsWorkspaceRootRegEx = "$([RegEx]::Escape($Env:GITHUB_WORKSPACE))\/"
[String[]]$IssuesSessionsClamAV = @()
[String[]]$IssuesSessionsYara = @()
[String[]]$IssuesSessionsOther = @()
[UInt64]$TotalElementsAll = 0
[UInt64]$TotalElementsClamAV = 0
[UInt64]$TotalElementsYara = 0
[UInt64]$TotalSizesAll = 0
[UInt64]$TotalSizesClamAV = 0
[UInt64]$TotalSizesYara = 0
[Boolean]$LocalTarget = $False
[Uri[]]$NetworkTargets = @()
[String[]]$CleanUpFilesFullNames = @()
Enter-GitHubActionsLogGroup -Title 'Import inputs.'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_listdelimiter' -Mandatory -EmptyStringAsNull
Write-NameValue -Name 'Input_ListDelimiter' -Value $InputListDelimiter
[String]$InputTableParserRaw = Get-GitHubActionsInput -Name 'input_tableparser' -Mandatory -EmptyStringAsNull -Trim
[String]$InputTableParser = ''
Switch -RegEx ($InputTableParserRaw) {
	'^c(?:omma|sv)$' {
		$InputTableParser = 'csv'
		Break
	}
	'^c(?:omma|sv)-?(?:kv)?-?s(?:ingle(?:line)?)?$' {
		$InputTableParser = 'csvs'
		Break
	}
	'^c(?:omma|sv)-?(?:kv)?-?m(?:ulti(?:ple)?(?:line)?)?$' {
		$InputTableParser = 'csvm'
		Break
	}
	'^t(?:ab|sv)$' {
		$InputTableParser = 'tsv'
		Break
	}
	'^ya?ml$' {
		$InputTableParser = 'yaml'
		Break
	}
	Default {
		Write-GitHubActionsFail -Message "``$InputTableParserRaw`` is not a valid table parser!"
		Throw
	}
}
Write-NameValue -Name 'Input_TableParser' -Value $InputTableParser
[String[]]$Targets = Get-InputList -Name 'targets' -Delimiter $InputListDelimiter
If ($Targets.Count -ieq 0) {
	$LocalTarget = $True
} Else {
	[String[]]$TargetsInvalid = @()
	ForEach ($Target In $Targets) {
		If (Test-StringIsUrl -InputObject $Target) {
			$NetworkTargets += $Target -as [Uri]
		} Else {
			$TargetsInvalid += $Target
		}
	}
	If ($TargetsInvalid.Count -igt 0) {
		Write-GitHubActionsWarning -Message "Input ``targets`` contains invalid network targets ($($TargetsInvalid.Count)): ``$($TargetsInvalid -join '`, `')``"
	}
}
Write-NameValue -Name "Targets ($($LocalTarget ? 1 : $NetworkTargets.Count))" -Value ($LocalTarget ? 'Local' : ($NetworkTargets -join ', '))
[Boolean]$GitIntegrate = Get-InputBoolean -Name 'git_integrate'
Write-NameValue -Name 'Git_Integrate' -Value $GitIntegrate
[PSCustomObject[]]$GitIgnores = Get-InputTable -Name 'git_ignores' -Type $InputTableParser
Write-NameValue -Name "Git_Ignores ($($GitIgnores.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject ($GitIgnores | Format-Table -Property '*' -AutoSize -Wrap | Out-String))"
[Boolean]$GitReverse = Get-InputBoolean -Name 'git_reverse'
Write-NameValue -Name 'Git_Reverse' -Value $GitReverse
[Boolean]$ClamAVEnable = Get-InputBoolean -Name 'clamav_enable'
Write-NameValue -Name 'ClamAV_Enable' -Value $ClamAVEnable
[Boolean]$ClamAVDaemon = Get-InputBoolean -Name 'clamav_daemon'
Write-NameValue -Name 'ClamAV_Daemon' -Value $ClamAVDaemon
[PSCustomObject[]]$ClamAVIgnoresRaw = Get-InputTable -Name 'clamav_ignores' -Type $InputTableParser
[PSCustomObject]$ClamAVIgnores = Group-ScanVirusToolsIgnores -InputObject $ClamAVIgnoresRaw
Write-NameValue -Name "ClamAV_Ignores ($($ClamAVIgnoresRaw.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject ($ClamAVIgnoresRaw | Format-Table -Property '*' -AutoSize -Wrap | Out-String))"
[Boolean]$ClamAVMultiScan = Get-InputBoolean -Name 'clamav_multiscan'
Write-NameValue -Name 'ClamAV_MultiScan' -Value $ClamAVMultiScan
[Boolean]$ClamAVReloadPerSession = Get-InputBoolean -Name 'clamav_reloadpersession'
Write-NameValue -Name 'ClamAV_ReloadPerSession' -Value $ClamAVReloadPerSession
[Boolean]$ClamAVSubcursive = Get-InputBoolean -Name -Name 'clamav_subcursive'
Write-NameValue -Name 'ClamAV_Subcursive' -Value $ClamAVSubcursive
[RegEx[]]$ClamAVUnofficialSignaturesRegEx = Get-InputList -Name 'clamav_unofficialsignatures' -Delimiter $InputListDelimiter
Write-NameValue -Name "ClamAV_UnofficialSignatures_RegEx ($($ClamAVUnofficialSignaturesRegEx.Count))" -Value "`n$($ClamAVUnofficialSignaturesRegEx -join "`n")"
[Boolean]$YaraEnable = Get-InputBoolean -Name 'yara_enable'
Write-NameValue -Name 'YARA_Enable' -Value $YaraEnable
[PSCustomObject[]]$YaraIgnoresRaw = Get-InputTable -Name 'yara_ignores' -Type $InputTableParser
[PSCustomObject]$YaraIgnores = Group-ScanVirusToolsIgnores -InputObject $YaraIgnoresRaw
Write-NameValue -Name "YARA_Ignores ($($YaraIgnoresRaw.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject ($YaraIgnoresRaw | Format-Table -AutoSize -Wrap | Out-String))"
[RegEx[]]$YaraRulesRegEx = Get-InputList -Name 'yara_rules' -Delimiter $InputListDelimiter
Write-NameValue -Name "YARA_Rules_RegEx ($($YaraRulesRegEx.Count))" -Value "`n$($YaraRulesRegEx -join "`n")"
[Boolean]$YaraToolWarning = Get-InputBoolean -Name 'yara_toolwarning'
Write-NameValue -Name 'YARA_ToolWarning' -Value $YaraToolWarning
[Boolean]$UpdateAssets = Get-InputBoolean -Name -Name 'update_assets'
Write-NameValue -Name 'Update_Assets' -Value $UpdateAssets
[Boolean]$UpdateClamAV = Get-InputBoolean -Name -Name 'update_clamav'
Write-NameValue -Name 'Update_ClamAV' -Value $UpdateClamAV
Exit-GitHubActionsLogGroup
If (!$LocalTarget -and $NetworkTargets.Count -ieq 0) {
	Write-GitHubActionsFail -Message 'Input `targets` does not have valid targets!'
	Throw
}
If ($True -notin @($ClamAVEnable, $YaraEnable)) {
	Write-GitHubActionsFail -Message 'No scan virus tools enabled!'
	Throw
}
If ($UpdateClamAV -and $ClamAVEnable) {
	Enter-GitHubActionsLogGroup -Title 'Update ClamAV assets via FreshClam.'
	Try {
		Invoke-Expression -Command 'freshclam'
	} Catch {
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
[PSCustomObject[]]$ClamAVUnofficialSignaturesAssetsIndex = Import-Csv -LiteralPath (Join-Path -Path $ClamAVUnofficialSignaturesAssetsRoot -ChildPath 'index.tsv') @TsvParameters
[PSCustomObject[]]$YaraRulesAssetsIndex = Import-Csv -LiteralPath (Join-Path -Path $YaraRulesAssetsRoot -ChildPath 'index.tsv') @TsvParameters
[PSCustomObject[]]$ClamAVUnofficialSignaturesApply = ($ClamAVUnofficialSignaturesAssetsIndex | Where-Object -FilterScript {
	Return (($_.Name | Select-String -Pattern $ClamAVUnofficialSignaturesRegEx -Quiet -AllMatches) ?? $False)
} | Sort-Object -Property 'Name')
[PSCustomObject[]]$YaraRulesApply = ($YaraRulesAssetsIndex | Where-Object -FilterScript {
	Return (($_.Name | Select-String -Pattern $ClamAVUnofficialSignaturesRegEx -Quiet -AllMatches) ?? $False)
} | Sort-Object -Property 'Name')
[PSCustomObject[]]$ClamAVUnofficialSignaturesIndexDisplay = @()
ForEach ($ClamAVUnofficialSignaturesAssetIndex In $ClamAVUnofficialSignaturesAssetsIndex) {
	[String]$ClamAVUnofficialSignaturesAssetIndexFullName = Join-Path -Path $ClamAVUnofficialSignaturesAssetsRoot -ChildPath $ClamAVUnofficialSignaturesAssetIndex.Location
	[Boolean]$ClamAVUnofficialSignaturesAssetIndexExist = Test-Path -LiteralPath $ClamAVUnofficialSignaturesAssetIndexFullName
	[Boolean]$ClamAVUnofficialSignaturesAssetIndexApply = $ClamAVUnofficialSignaturesAssetIndex.Name -iin $ClamAVUnofficialSignaturesApply.Name
	$ClamAVUnofficialSignaturesIndexDisplay += [PSCustomObject]@{
		Name = $ClamAVUnofficialSignaturesAsset.Name
		Exist = $ClamAVUnofficialSignaturesAssetIndexExist
		Apply = $ClamAVUnofficialSignaturesAssetIndexApply
	}
	If ($ClamAVUnofficialSignaturesAssetIndexExist -and $ClamAVUnofficialSignaturesAssetIndexApply) {
		[String]$ClamAVUnofficialSignatureAssetDestination = Join-Path -Path $ClamAVDatabaseRoot -ChildPath ($ClamAVUnofficialSignaturesAssetIndex.Location -ireplace '\/', '_')
		Copy-Item -LiteralPath $ClamAVUnofficialSignaturesAssetIndexFullName -Destination $ClamAVUnofficialSignatureAssetDestination -Confirm:$False
		$CleanUpFilesFullNames += $ClamAVUnofficialSignatureAssetDestination
	}
}
[PSCustomObject[]]$ClamAVUnofficialSignaturesAssetsNotExist = ($ClamAVUnofficialSignaturesIndexDisplay | Where-Object -FilterScript {
	Return !$_.Exist
})
Write-NameValue -Name "ClamAV unofficial signatures index (Index: $($ClamAVUnofficialSignaturesAssetsIndex.Count); Exist: $($ClamAVUnofficialSignaturesAssetsIndex.Count - $ClamAVUnofficialSignaturesAssetsNotExist.Count); Apply: $($ClamAVUnofficialSignaturesApply.Count))" -Value "`n$($ClamAVUnofficialSignaturesIndexDisplay | Format-Table -Property @(
	'Name',
	@{ Expression = 'Exist'; Alignment = 'Right' },
	@{ Expression = 'Apply'; Alignment = 'Right' }
) -AutoSize -Wrap | Out-String)"
If ($ClamAVUnofficialSignaturesAssetsNotExist.Count -igt 0) {
	Write-GitHubActionsWarning -Message "Some of the ClamAV unofficial signatures are indexed but not exist ($($ClamAVUnofficialSignaturesAssetsNotExist.Count)): $($ClamAVUnofficialSignaturesAssetsNotExist.Name -join ', ')"
}
[PSCustomObject[]]$YaraRulesIndexDisplay = @()
ForEach ($YaraRulesAssetIndex In $YaraRulesAssetsIndex) {
	[String]$YaraRuleFullName = Join-Path -Path $YaraRulesAssetsRoot -ChildPath $YaraRulesAssetIndex.Location
	[Boolean]$YaraRuleExist = Test-Path -LiteralPath $YaraRuleFullName
	[Boolean]$YaraRuleApply = $YaraRulesAssetIndex.Name -iin $YaraRulesApply.Name
	$YaraRulesIndexDisplay += [PSCustomObject]@{
		Name = $YaraRulesAssetIndex.Name
		Exist = $YaraRuleExist
		Apply = $YaraRuleApply
	}
}
[PSCustomObject[]]$YaraRulesAssetsNotExist = ($YaraRulesIndexDisplay | Where-Object -FilterScript {
	Return !$_.Exist
})
Write-NameValue -Name "YARA rules index (Index: $($YaraRulesAssetsIndex.Count); Exist: $($YaraRulesAssetsIndex.Count - $YaraRulesAssetsNotExist.Count); Apply: $($YaraRulesApply.Count))" -Value "`n$($YaraRulesIndexDisplay | Format-Table -Property @(
	'Name',
	@{ Expression = 'Exist'; Alignment = 'Right' },
	@{ Expression = 'Apply'; Alignment = 'Right' }
) -AutoSize -Wrap | Out-String)"
If ($YaraRulesAssetsNotExist.Count -igt 0) {
	Write-GitHubActionsWarning -Message "Some of the YARA rules are indexed but not exist ($($YaraRulesAssetsNotExist.Count)): $($YaraRulesAssetsNotExist.Name -join ', ')"
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
		If ($SessionId -inotin $Script:IssuesSessionsOther) {
			$Script:IssuesSessionsOther += $SessionId
		}
		Write-Host -Object "End of session `"$SessionTitle`"."
		Return
	}
	[Boolean]$SkipClamAV = ($SessionId | Select-String -Pattern $ClamAVIgnores.OnlySessions.Session -Quiet -AllMatches) ?? $False
	[Boolean]$SkipYara = ($SessionId | Select-String -Pattern $YaraIgnores.OnlySessions.Session -Quiet -AllMatches) ?? $False
	[UInt64]$ElementsIsDirectoryCount = 0
	[String[]]$ElementsListClamAV = @()
	[String[]]$ElementsListYara = @()
	[PSCustomObject[]]$ElementsListDisplay = @()
	ForEach ($Element In ($Elements | Sort-Object -Property 'FullName')) {
		[Boolean]$ElementIsDirectory = Test-Path -LiteralPath $Element.FullName -PathType 'Container'
		[String]$ElementName = $Element.FullName -ireplace "^$GitHubActionsWorkspaceRootRegEx", ''
		[Hashtable]$ElementListDisplay = @{
			Element = $ElementName
			Flags = @()
		}
		If ($ElementIsDirectory) {
			$ElementsIsDirectoryCount += 1
			$ElementListDisplay.Flags += 'D'
		} Else {
			$ElementListDisplay.Sizes = $Element.Length
			$Script:TotalSizesAll += $Element.Length
		}
		If ($ClamAVEnable -and !$SkipClamAV -and (
			($ElementIsDirectory -and $ClamAVSubcursive) -or
			!$ElementIsDirectory
		) -and !(($ElementName | Select-String -Pattern $ClamAVIgnores.OnlyPaths.Path -Quiet -AllMatches) ?? $False)) {
			$ElementsListClamAV += $Element.FullName
			$ElementListDisplay.Flags += 'C'
			If (!$ElementIsDirectory) {
				$Script:TotalSizesClamAV += $Element.Length
			}
		}
		If ($YaraEnable -and !$SkipYara -and !$ElementIsDirectory -and !(($ElementName | Select-String -Pattern $YaraIgnores.OnlyPaths.Path -Quiet -AllMatches) ?? $False)) {
			$ElementsListYara += $Element.FullName
			$ElementListDisplay.Flags += 'Y'
			$Script:TotalSizesYara += $Element.Length
		}
		$ElementListDisplay.Flags = ($ElementListDisplay.Flags | Sort-Object) -join ''
		$ElementsListDisplay += [PSCustomObject]$ElementListDisplay
	}
	$Script:TotalElementsAll += $Elements.Count
	$Script:TotalElementsClamAV += $ElementsListClamAV.Count
	$Script:TotalElementsYara += $ElementsListYara.Count
	Enter-GitHubActionsLogGroup -Title "Elements of session `"$SessionTitle`" (Elements: $($Elements.Count); irectory: $ElementsIsDirectoryCount; ClamAV: $($ElementsListClamAV.Count); Yara: $($ElementsListYara.Count)):"
	Write-OptimizePSFormatDisplay -InputObject ($ElementsListDisplay | Format-Table -Property @(
		'Element',
		'Flags',
		@{ Expression = 'Sizes'; Alignment = 'Right' }
	) -AutoSize -Wrap | Out-String)
	Exit-GitHubActionsLogGroup
	If ($ClamAVEnable -and !$SkipClamAV -and ($ElementsListClamAV.Count -igt 0)) {
		[String]$ElementsListClamAVFullName = (New-TemporaryFile).FullName
		Set-Content -LiteralPath $ElementsListClamAVFullName -Value ($ElementsListClamAV -join "`n") -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via ClamAV."
		[String]$ClamAVExpression = ''
		If ($ClamAVDaemon) {
			$ClamAVExpression = "clamdscan --fdpass --file-list=`"$ElementsListClamAVFullName`"$($ClamAVMultiScan ? ' --multiscan' : '')$($ClamAVReloadPerSession ? ' --reload' : '')"
		} Else {
			$ClamAVExpression = "clamscan --detect-broken=yes --file-list=`"$ElementsListClamAVFullName`" --follow-dir-symlinks=0 --follow-file-symlinks=0 --recursive"
		}
		Try {
			[String[]]$ClamAVOutput = Invoke-Expression -Command $ClamAVExpression
			[UInt32]$ClamAVExitCode = $LASTEXITCODE
		} Catch {
			Write-GitHubActionsError -Message "Unexpected issues when invoke ClamAV (SessionID: $SessionId; Expression: ``$ClamAVExpression``): $_"
			Exit-GitHubActionsLogGroup
			Exit 1
		}
		Enter-GitHubActionsLogGroup -Title "ClamAV result of session `"$SessionTitle`":"
		[String[]]$ClamAVResultError = @()
		[Hashtable]$ClamAVResultFound = @{}
		ForEach ($Line In ($ClamAVOutput | ForEach-Object -Process {
			Return ($_ -ireplace "^$GitHubActionsWorkspaceRootRegEx", '')
		})) {
			If ($Line -imatch '^[-=]+ SCAN SUMMARY [-=]+$') {
				Break
			}
			If (
				($Line -imatch ': OK$') -or
				($Line -imatch '^\s*$')
			) {
				Continue
			}
			If ($Line -imatch ': .+ FOUND$') {
				[String]$ClamAVElementIssue = $Line -ireplace ' FOUND$', ''
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
			Write-GitHubActionsError -Message "Found issues in session `"$SessionTitle`" via ClamAV ($($ClamAVResultFound.Count)): `n$(Optimize-PSFormatDisplay -InputObject ($ClamAVResultFound.GetEnumerator() | ForEach-Object -Process {
				[String[]]$IssueSignatures = ($_.Value | Sort-Object -Unique -CaseSensitive)
				Return [PSCustomObject]@{
					Element = $_.Name
					Signatures_List = $IssueSignatures -join ', '
					Signatures_Count = $IssueSignatures.Count
				}
			} | Sort-Object -Property 'Element' | Format-List -Property '*' | Out-String))"
			If ($SessionId -inotin $Script:IssuesSessionsClamAV) {
				$Script:IssuesSessionsClamAV += $SessionId
			}
		}
		If ($ClamAVResultError.Count -igt 0) {
			Write-GitHubActionsError -Message "Unexpected ClamAV result ``$ClamAVExitCode`` in session `"$SessionTitle`":`n$($ClamAVResultError -join "`n")"
			If ($SessionId -inotin $Script:IssuesSessionsClamAV) {
				$Script:IssuesSessionsClamAV += $SessionId
			}
		}
		Exit-GitHubActionsLogGroup
		Remove-Item -LiteralPath $ElementsListClamAVFullName -Force -Confirm:$False
	}
	If ($YaraEnable -and !$SkipYara -and ($ElementsListYara.Count -igt 0)) {
		[String]$ElementsListYaraFullName = (New-TemporaryFile).FullName
		Set-Content -LiteralPath $ElementsListYaraFullName -Value ($ElementsListYara -join "`n") -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
		Enter-GitHubActionsLogGroup -Title "Scan session `"$SessionTitle`" via YARA."
		[Hashtable]$YaraResultFound = @{}
		[String[]]$YaraResultIssue = @()
		ForEach ($YaraRule In $YaraRulesApply) {
			[String]$YaraExpression = "yara --scan-list$($YaraToolWarning ? '' : ' --no-warnings') `"$(Join-Path -Path $YaraRulesAssetsRoot -ChildPath $YaraRule.Location)`" `"$ElementsListYaraFullName`""
			Try {
				[String[]]$YaraOutput = Invoke-Expression -Command $YaraExpression
				[UInt32]$YaraExitCode = $LASTEXITCODE
			} Catch {
				Write-GitHubActionsError -Message "Unexpected issues when invoke YARA (SessionID: $SessionId; Expression: ``$YaraExpression``): $_"
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
					} ElseIf ($Line.Length -igt 0) {
						$YaraResultIssue += $Line
					}
				}
			} Else {
				Write-GitHubActionsError -Message "Unexpected YARA `"$($YaraRule.Name)`" exit code ``$YaraExitCode`` in session `"$SessionTitle`"!`n$YaraOutput"
				If ($SessionId -inotin $Script:IssuesSessionsYara) {
					$Script:IssuesSessionsYara += $SessionId
				}
			}
		}
		Enter-GitHubActionsLogGroup -Title "YARA result of session `"$SessionTitle`":"
		If ($YaraResultFound.Count -igt 0) {
			Write-GitHubActionsError -Message "Found issues in session `"$SessionTitle`" via YARA ($($YaraResultFound.Count)): `n$(Optimize-PSFormatDisplay -InputObject ($YaraResultFound.GetEnumerator() | ForEach-Object -Process {
				[String[]]$IssueRules = ($_.Value | Sort-Object -Unique -CaseSensitive)
				Return [PSCustomObject]@{
					Element = $_.Name
					Rules_List = $IssueRules -join ', '
					Rules_Count = $IssueRules.Count
				}
			} | Sort-Object -Property 'Element' | Format-List -Property '*' | Out-String))"
			If ($SessionId -inotin $Script:IssuesSessionsYara) {
				$Script:IssuesSessionsYara += $SessionId
			}
		}
		Exit-GitHubActionsLogGroup
		Remove-Item -LiteralPath $ElementsListYaraFullName -Force -Confirm:$False
	}
	Write-Host -Object "End of session `"$SessionTitle`"."
}
If ($LocalTarget) {
	Invoke-ScanVirusTools -SessionId 'current' -SessionTitle 'Current'
	If ($GitIntegrate) {
		If (Test-Path -LiteralPath (Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath '.git') -PathType 'Container') {
			Write-Host -Object 'Import Git information.'
			Try {
				[PSCustomObject[]]$GitCommits = Get-GitCommitsInformation
			} Catch {
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
				} Catch {
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
				If ($GitCommitHash -inotin $IssuesSessionsOther) {
					$IssuesSessionsOther += $GitCommitHash
				}
				Exit-GitHubActionsLogGroup
			}
		} Else {
			Write-GitHubActionsWarning -Message 'Unable to integrate with Git due to the workspace is not a Git repository! If this is incorrect, probably Git data is broken and/or invalid.'
		}
	}
} Else {
	[PSCustomObject[]]$UselessElements = Get-ChildItem -LiteralPath $Env:GITHUB_WORKSPACE -Recurse -Force
	If ($UselessElements.Count -igt 0) {
		Write-GitHubActionsWarning -Message 'Require a clean workspace when targets are network type!'
		Write-Host -Object 'Clean up workspace.'
		$UselessElements | Remove-Item -Force -Confirm:$False
	}
	ForEach ($NetworkTarget In $NetworkTargets) {
		Enter-GitHubActionsLogGroup -Title "Fetch file `"$NetworkTarget`"."
		[String]$NetworkTemporaryFileFullPath = Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath (New-Guid).Guid
		Try {
			Invoke-WebRequest -Uri $NetworkTarget -UseBasicParsing -Method 'Get' -OutFile $NetworkTemporaryFileFullPath
		} Catch {
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
	Get-Process -Name '*clamd*' | Stop-Process
	Exit-GitHubActionsLogGroup
}
$CleanUpFilesFullNames | ForEach-Object -Process {
	Remove-Item -LiteralPath $_ -Force -Confirm:$False
}
Enter-GitHubActionsLogGroup -Title 'Statistics:'
[UInt64]$TotalIssues = $IssuesSessionsClamAV.Count + $IssuesSessionsOther.Count + $IssuesSessionsYara.Count
Write-OptimizePSFormatDisplay -InputObject ([PSCustomObject[]]@(
	[PSCustomObject]@{
		Name = 'TotalElements_Count'
		All = $TotalElementsAll
		ClamAV = $TotalElementsClamAV
		YARA = $TotalElementsYara
	},
	[PSCustomObject]@{
		Name = 'TotalElements_Percentage'
		ClamAV = ($TotalElementsAll -ieq 0) ? 0 : ($TotalElementsClamAV / $TotalElementsAll * 100)
		YARA = ($TotalElementsAll -ieq 0) ? 0 : ($TotalElementsYara / $TotalElementsAll * 100)
	},
	[PSCustomObject]@{
		Name = 'TotalIssuesSessions_Count'
		All = $TotalIssues
		ClamAV = $IssuesSessionsClamAV.Count
		YARA = $IssuesSessionsYara.Count
		Other = $IssuesSessionsOther.Count
	},
	[PSCustomObject]@{
		Name = 'TotalIssuesSessions_Percentage'
		ClamAV = ($TotalIssues -ieq 0) ? 0 : ($IssuesSessionsClamAV.Count / $TotalIssues * 100)
		YARA = ($TotalIssues -ieq 0) ? 0 : ($IssuesSessionsYara.Count / $TotalIssues * 100)
		Other = ($TotalIssues -ieq 0) ? 0 : ($IssuesSessionsOther.Count / $TotalIssues * 100)
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_B'
		All = $TotalSizesAll
		ClamAV = $TotalSizesClamAV
		YARA = $TotalSizesYara
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_KB'
		All = $TotalSizesAll / 1KB
		ClamAV = $TotalSizesClamAV / 1KB
		YARA = $TotalSizesYara / 1KB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_MB'
		All = $TotalSizesAll / 1MB
		ClamAV = $TotalSizesClamAV / 1MB
		YARA = $TotalSizesYara / 1MB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_GB'
		All = $TotalSizesAll / 1GB
		ClamAV = $TotalSizesClamAV / 1GB
		YARA = $TotalSizesYara / 1GB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_Percentage'
		ClamAV = $TotalSizesClamAV / $TotalSizesAll * 100
		YARA = $TotalSizesYara / $TotalSizesAll * 100
	}
) | Format-Table -Property @(
	'Name',
	@{ Expression = 'All'; Alignment = 'Right' },
	@{ Expression = 'ClamAV'; Alignment = 'Right' },
	@{ Expression = 'YARA'; Alignment = 'Right' },
	@{ Expression = 'Other'; Alignment = 'Right' }
) -AutoSize -Wrap | Out-String)
Exit-GitHubActionsLogGroup
if ($TotalIssues -igt 0) {
	Enter-GitHubActionsLogGroup -Title 'Issues sessions:'
	Write-OptimizePSFormatDisplay -InputObject ([PSCustomObject]@{
		ClamAV = $IssuesSessionsClamAV -join ', '
		YARA = $IssuesSessionsYara -join ', '
		Other = $IssuesSessionsOther -join ', '
	} | Format-List -Property '*' | Out-String)
	Exit-GitHubActionsLogGroup
}
If ($TotalIssues -igt 0) {
	Exit 1
}
Exit 0
