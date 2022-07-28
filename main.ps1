Write-Host -Object 'Starting.'
$Script:ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (@('assets', 'git', 'utility') | ForEach-Object -Process {
	Return (Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1")
}) -Scope 'Local'
[Hashtable]$TsvParameters = @{
	Delimiter = "`t"
	Encoding = 'UTF8NoBOM'
}
[String]$AssetsRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[String]$ClamAVUnofficialSignaturesRoot = Join-Path -Path $AssetsRoot -ChildPath 'clamav-unofficial-signatures'
[String]$YaraRulesRoot = Join-Path -Path $AssetsRoot -ChildPath 'yara-rules'
[String]$ClamAVDatabaseRoot = '/var/lib/clamav'
[RegEx]$GitHubActionsWorkspaceRootRegEx = "$([RegEx]::Escape($Env:GITHUB_WORKSPACE))\/"
[String[]]$IssuesSessionsClamAV = @()
[String[]]$IssuesSessionsOther = @()
[String[]]$IssuesSessionsYara = @()
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
Switch -RegEx ($InputTableParserRaw) {
	'^c(?:omma|sv)$' {
		[String]$InputTableParser = 'csv'
		Break
	}
	'^c(?:omma|sv)-?(?:kv)?-?s(?:ingle(?:line)?)?$' {
		[String]$InputTableParser = 'csvs'
		Break
	}
	'^c(?:omma|sv)-?(?:kv)?-?m(?:ulti(?:ple)?(?:line)?)?$' {
		[String]$InputTableParser = 'csvm'
		Break
	}
	'^t(?:ab|sv)$' {
		[String]$InputTableParser = 'tsv'
		Break
	}
	'^ya?ml$' {
		[String]$InputTableParser = 'yaml'
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
	$Targets | ForEach-Object -Process {
		If (Test-StringIsUrl -InputObject $_) {
			$NetworkTargets += $_ -as [Uri]
		} Else {
			$TargetsInvalid += $_
		}
	}
	If ($TargetsInvalid.Count -igt 0) {
		Write-GitHubActionsWarning -Message "Input ``targets`` has $($TargetsInvalid.Count) invalid network target$(($TargetsInvalid.Count -ieq 1) ? '' : 's'): ``$($TargetsInvalid -join '`, `')``"
	}
}
Write-NameValue -Name "Targets ($($LocalTarget ? 1 : $NetworkTargets.Count))" -Value ($LocalTarget ? 'Local' : ($NetworkTargets -join ', '))
[Boolean]$GitIntegrate = Get-InputBoolean -Name 'git_integrate'
Write-NameValue -Name 'Git_Integrate' -Value $GitIntegrate
[PSCustomObject[]]$GitIgnores = Get-InputTable -Name 'git_ignores' -Type $InputTableParser
Write-NameValue -Name "Git_Ignores ($($GitIgnores.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject ($GitIgnores | Format-Table -AutoSize -Wrap | Out-String))"
[Boolean]$GitReverse = Get-InputBoolean -Name 'git_reverse'
Write-NameValue -Name 'Git_Reverse' -Value $GitReverse
[Boolean]$ClamAVEnable = Get-InputBoolean -Name 'clamav_enable'
Write-NameValue -Name 'ClamAV_Enable' -Value $ClamAVEnable
[Boolean]$ClamAVDaemon = Get-InputBoolean -Name 'clamav_daemon'
Write-NameValue -Name 'ClamAV_Daemon' -Value $ClamAVDaemon
[PSCustomObject[]]$ClamAVIgnoresRaw = Get-InputTable -Name 'clamav_ignores' -Type $InputTableParser
[PSCustomObject]$ClamAVIgnores = Group-ScanVirusToolsIgnores -InputObject $ClamAVIgnoresRaw
Write-NameValue -Name "ClamAV_Ignores ($($ClamAVIgnoresRaw.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject ($ClamAVIgnoresRaw | Format-Table -AutoSize -Wrap | Out-String))"
[Boolean]$ClamAVMultiScan = Get-InputBoolean -Name 'clamav_multiscan'
Write-NameValue -Name 'ClamAV_MultiScan' -Value $ClamAVMultiScan
[Boolean]$ClamAVReloadPerSession = Get-InputBoolean -Name 'clamav_reloadpersession'
Write-NameValue -Name 'ClamAV_ReloadPerSession' -Value $ClamAVReloadPerSession
[Boolean]$ClamAVSubcursive = Get-InputBoolean -Name -Name 'clamav_subcursive'
Write-NameValue -Name 'ClamAV_Subcursive' -Value $ClamAVSubcursive
[RegEx[]]$ClamAVUnofficialSignaturesRegEx = Get-InputList -Name 'clamav_unofficialsignatures' -Delimiter $InputListDelimiter
Write-NameValue -Name "ClamAV_UnofficialSignatures_RegEx ($($ClamAVUnofficialSignaturesRegEx.Count))" -Value (($ClamAVUnofficialSignaturesRegEx.Count -igt 0) ? "``$($ClamAVUnofficialSignaturesRegEx -join '`, `')``" : '')
[Boolean]$YaraEnable = Get-InputBoolean -Name 'yara_enable'
Write-NameValue -Name 'YARA_Enable' -Value $YaraEnable
[PSCustomObject[]]$YaraIgnoresRaw = Get-InputTable -Name 'yara_ignores' -Type $InputTableParser
[PSCustomObject]$YaraIgnores = Group-ScanVirusToolsIgnores -InputObject $YaraIgnoresRaw
Write-NameValue -Name "YARA_Ignores ($($YaraIgnoresRaw.Count))" -Value "`n$(Optimize-PSFormatDisplay -InputObject ($YaraIgnoresRaw | Format-Table -AutoSize -Wrap | Out-String))"
[RegEx[]]$YaraRulesRegEx = Get-InputList -Name 'yara_rules' -Delimiter $InputListDelimiter
Write-NameValue -Name "YARA_Rules_RegEx ($($YaraRulesRegEx.Count))" -Value (($YaraRulesRegEx.Count -igt 0) ? "``$($YaraRulesRegEx -join '`, `')``" : '')
[Boolean]$YaraToolWarning = Get-InputBoolean -Name 'yara_toolwarning'
Write-NameValue -Name 'YARA_ToolWarning' -Value $YaraToolWarning
[Boolean]$UpdateAssets = Get-InputBoolean -Name -Name 'update_assets'
Write-NameValue -Name 'Update_Assets' -Value $UpdateAssets
[Boolean]$UpdateClamAVAssets = Get-InputBoolean -Name -Name 'update_clamavassets'
Write-NameValue -Name 'Update_Assets' -Value $UpdateClamAVAssets
[Boolean]$UpdatePackages = Get-InputBoolean -Name -Name 'update_packages'
Write-NameValue -Name 'Update_Assets' -Value $UpdatePackages
Exit-GitHubActionsLogGroup
If (!$LocalTarget -and $NetworkTargets.Count -ieq 0) {
	Write-GitHubActionsFail -Message 'Input `targets` does not have valid targets!'
	Throw
}
If ($True -notin @($ClamAVEnable, $YaraEnable)) {
	Write-GitHubActionsFail -Message 'No scan virus tools enabled!'
	Throw
}
If ($UpdatePackages) {
	Enter-GitHubActionsLogGroup -Title 'Update packages.'
	Try {
		Invoke-Expression -Command 'apt-get --assume-yes update'
		Invoke-Expression -Command 'apt-get --assume-yes dist-upgrade'
	} Catch {
		Write-GitHubActionsWarning -Message "Unexpected issues when update packages (mostly will not cause critical issues): $_"
	}
	If ($LASTEXITCODE -igt 0) {
		Write-GitHubActionsWarning -Message "Unexpected exit code ``$LASTEXITCODE`` when update packages (mostly will not cause critical issues)!"
	}
	Exit-GitHubActionsLogGroup
}
If ($UpdateClamAVAssets -and $ClamAVEnable) {
	Enter-GitHubActionsLogGroup -Title 'Update ClamAV assets via FreshClam.'
	Try {
		Invoke-Expression -Command 'freshclam'
	} Catch {
		Write-GitHubActionsWarning -Message "Unexpected issues when update ClamAV assets via FreshClam (mostly will not cause critical issues): $_"
	}
	If ($LASTEXITCODE -igt 0) {
		Write-GitHubActionsWarning -Message "Unexpected exit code ``$LASTEXITCODE`` when update ClamAV assets via FreshClam (mostly will not cause critical issues)!"
	}
	Exit-GitHubActionsLogGroup
}
If ($UpdateAssets -and (
	($ClamAVEnable -and $ClamAVUnofficialSignaturesRegEx.Count -igt 0) -or
	($YaraEnable -and $YaraRulesRegEx.Count -igt 0)
)) {
	Enter-GitHubActionsLogGroup -Title 'Update assets.'
	Update-GitHubActionScanVirusAssets
	Exit-GitHubActionsLogGroup
}
Enter-GitHubActionsLogGroup -Title 'Read assets index.'
[PSCustomObject[]]$ClamAVUnofficialSignaturesIndex = Import-Csv -LiteralPath (Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath 'index.tsv') @TsvParameters
[PSCustomObject[]]$YaraRulesIndex = Import-Csv -LiteralPath (Join-Path -Path $YaraRulesRoot -ChildPath 'index.tsv') @TsvParameters
[PSCustomObject[]]$ClamAVUnofficialSignaturesApply = ($ClamAVUnofficialSignaturesIndex | Where-Object -FilterScript {
	Return (Test-StringMatchesRegExs -Target $_.Name -Matchers $ClamAVUnofficialSignaturesRegEx)
} | Sort-Object -Property 'Name')
[PSCustomObject[]]$YaraRulesApply = ($YaraRulesIndex | Where-Object -FilterScript {
	Return (Test-StringMatchesRegExs -Target $_.Name -Matchers $YaraRulesRegEx.Exclude)
} | Sort-Object -Property 'Name')
[PSCustomObject[]]$ClamAVUnofficialSignaturesDisplay = @()
$ClamAVUnofficialSignaturesIndex | ForEach-Object -Process {
	[String]$ClamAVUnofficialSignatureFullName = Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath $_.Location
	[Boolean]$ClamAVUnofficialSignatureExist = Test-Path -LiteralPath $ClamAVUnofficialSignatureFullName
	[Boolean]$ClamAVUnofficialSignatureApply = $_.Name -iin $ClamAVUnofficialSignaturesApply.Name
	$ClamAVUnofficialSignaturesDisplay += [PSCustomObject]@{
		Name = $_.Name
		Exist = $ClamAVUnofficialSignatureExist
		Apply = $ClamAVUnofficialSignatureApply
	}
	If ($ClamAVUnofficialSignatureExist -and $ClamAVUnofficialSignatureApply) {
		[String]$ClamAVUnofficialSignatureDestination = Join-Path -Path $ClamAVDatabaseRoot -ChildPath ($_.Location -ireplace '\/', '_')
		Copy-Item -LiteralPath $ClamAVUnofficialSignatureFullName -Destination $ClamAVUnofficialSignatureDestination -Confirm:$False
		$CleanUpFilesFullNames += $ClamAVUnofficialSignatureDestination
	}
}
[PSCustomObject[]]$ClamAVUnofficialSignaturesNotExist = ($ClamAVUnofficialSignaturesDisplay | Where-Object -FilterScript {
	Return ($_.Exist -ieq $False)
})
Write-NameValue -Name "ClamAV unofficial signatures index (Index: $($ClamAVUnofficialSignaturesIndex.Count); Exist: $($ClamAVUnofficialSignaturesIndex.Count - $ClamAVUnofficialSignaturesNotExist.Count); Apply: $($ClamAVUnofficialSignaturesApply.Count))" -Value "`n$($ClamAVUnofficialSignaturesDisplay | Format-Table -Property @(
	'Name',
	@{ Expression = 'Exist'; Alignment = 'Right' },
	@{ Expression = 'Apply'; Alignment = 'Right' }
) -AutoSize -Wrap | Out-String)"
If ($ClamAVUnofficialSignaturesNotExist.Count -igt 0) {
	Write-GitHubActionsWarning -Message "Some of the ClamAV unofficial signatures are indexed but not exist ($($ClamAVUnofficialSignaturesNotExist.Count)): $($ClamAVUnofficialSignaturesNotExist.Name -join ', ')"
}
[PSCustomObject[]]$YaraRulesDisplay = @()
$YaraRulesIndex | ForEach-Object -Process {
	[String]$YaraRuleFullName = Join-Path -Path $YaraRulesRoot -ChildPath $_.Location
	[Boolean]$YaraRuleExist = Test-Path -LiteralPath $YaraRuleFullName
	[Boolean]$YaraRuleApply = $_.Name -iin $YaraRulesApply.Name
	$YaraRulesDisplay += [PSCustomObject]@{
		Name = $_.Name
		Exist = $YaraRuleExist
		Apply = $YaraRuleApply
	}
}
[PSCustomObject[]]$YaraRulesNotExist = ($YaraRulesDisplay | Where-Object -FilterScript {
	Return ($_.Exist -ieq $False)
})
Write-NameValue -Name "YARA rules index (Index: $($YaraRulesIndex.Count); Exist: $($YaraRulesIndex.Count - $YaraRulesNotExist.Count); Apply: $($YaraRulesApply.Count))" -Value "`n$($YaraRulesDisplay | Format-Table -Property @(
	'Name',
	@{ Expression = 'Exist'; Alignment = 'Right' },
	@{ Expression = 'Apply'; Alignment = 'Right' }
) -AutoSize -Wrap | Out-String)"
If ($YaraRulesNotExist.Count -igt 0) {
	Write-GitHubActionsWarning -Message "Some of the YARA rules are indexed but not exist ($($YaraRulesNotExist.Count)): $($YaraRulesNotExist.Name -join ', ')"
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
		[Parameter(Mandatory = $True, Position = 0)][String]$Session
	)
	Write-Host -Object "Begin of session `"$Session`"."
	[PSCustomObject[]]$Elements = Get-ChildItem -LiteralPath $Env:GITHUB_WORKSPACE -Recurse -Force
	If ($Elements.Count -ieq 0){
		Write-GitHubActionsError -Message "Unable to scan session `"$Session`" due to the workspace is empty! If this is incorrect, probably something went wrong."
		If ($Session -inotin $Script:IssuesSessionsOther) {
			$Script:IssuesSessionsOther += $Session
		}
	} Else {
		[Boolean]$SkipClamAV = Test-StringMatchesRegExs -Target $Session -Matchers $ClamAVIgnores.OnlySessions.Session
		[Boolean]$SkipYara = Test-StringMatchesRegExs -Target $Session -Matchers $YaraIgnores.OnlySessions.Session
		[UInt64]$ElementsIsDirectoryCount = 0
		[String[]]$ElementsListClamAV = @()
		[String[]]$ElementsListYara = @()
		[PSCustomObject[]]$ElementsListDisplay = @()
		ForEach ($Element In ($Elements | Sort-Object -Property 'FullName')) {
			[Boolean]$ElementIsDirectory = Test-Path -LiteralPath $Element.FullName -PathType 'Container'
			[String]$ElementName = $Element.FullName -ireplace "^$GitHubActionsWorkspaceRootRegEx", ''
			[UInt64]$ElementSizes = $Element.Length
			[Hashtable]$ElementListDisplay = @{
				Element = $ElementName
				Flags = @()
			}
			If ($ElementIsDirectory) {
				$ElementsIsDirectoryCount += 1
				$ElementListDisplay.Flags += 'D'
			} Else {
				$ElementListDisplay.Sizes = $ElementSizes
				$Script:TotalSizesAll += $ElementSizes
			}
			If ($ClamAVEnable -and !$SkipClamAV -and (
				($ElementIsDirectory -and $ClamAVSubcursive) -or
				!$ElementIsDirectory
			) -and !(Test-StringMatchesRegExs -Target $ElementName -Matchers $ClamAVIgnores.OnlyPaths.Path)) {
				$ElementsListClamAV += $Element.FullName
				$ElementListDisplay.Flags += 'C'
				If (!$ElementIsDirectory) {
					$Script:TotalSizesClamAV += $ElementSizes
				}
			}
			If ($YaraEnable -and !$SkipYara -and !$ElementIsDirectory -and !(Test-StringMatchesRegExs -Target $ElementName -Matchers $YaraIgnores.OnlyPaths.Path)) {
				$ElementsListYara += $Element.FullName
				$ElementListDisplay.Flags += 'Y'
				$Script:TotalSizesYara += $ElementSizes
			}
			$ElementListDisplay.Flags = ($ElementListDisplay.Flags | Sort-Object) -join ''
			$ElementsListDisplay += [PSCustomObject]$ElementListDisplay
		}
		$Script:TotalElementsAll += $Elements.Count
		$Script:TotalElementsClamAV += $ElementsListClamAV.Count
		$Script:TotalElementsYara += $ElementsListYara.Count
		Enter-GitHubActionsLogGroup -Title "Elements in the session `"$Session`" (Elements: $($Elements.Count); Flag - ClamAV: $($ElementsListClamAV.Count); Flag - Directory: $ElementsIsDirectoryCount; Flag - Yara: $($ElementsListYara.Count)):"
		Write-OptimizePSFormatDisplay -InputObject ($ElementsListDisplay | Format-Table -Property @(
			'Element',
			'Flags',
			@{ Expression = 'Sizes'; Alignment = 'Right' }
		) -AutoSize -Wrap | Out-String)
		Exit-GitHubActionsLogGroup
		If ($ClamAVEnable -and !$SkipClamAV -and ($ElementsListClamAV.Count -igt 0)) {
			[String]$ElementsListClamAVFullName = (New-TemporaryFile).FullName
			Set-Content -LiteralPath $ElementsListClamAVFullName -Value ($ElementsListClamAV -join "`n") -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
			Enter-GitHubActionsLogGroup -Title "ClamAV result of session `"$Session`":"
			[String]$ClamAVExpression = ''
			If ($ClamAVDaemon) {
				$ClamAVExpression = "clamdscan --fdpass --file-list=`"$ElementsListClamAVFullName`"$($ClamAVMultiScan ? ' --multiscan' : '')$($ClamAVReloadPerSession ? ' --reload' : '')"
			} Else {
				$ClamAVExpression = "clamscan --detect-broken=yes --file-list=`"$ElementsListClamAVFullName`" --follow-dir-symlinks=0 --follow-file-symlinks=0 --recursive"
			}
			[String[]]$ClamAVOutput = Invoke-Expression -Command $ClamAVExpression
			[UInt32]$ClamAVExitCode = $LASTEXITCODE
			[String[]]$ClamAVResultError = @()
			[Hashtable]$ClamAVResultFound = @{}





			for ($ClamAVOutputLineIndex = 0; $ClamAVOutputLineIndex -lt $ClamAVOutput.Count; $ClamAVOutputLineIndex++) {
				[String]$ClamAVOutputLineContent = $ClamAVOutput[$ClamAVOutputLineIndex] -replace "^$GitHubActionsWorkspaceRootRegEx", ''
				if ($ClamAVOutputLineContent -match '^[-=]+ SCAN SUMMARY [-=]+$') {
					Write-Host -Object ($ClamAVOutput[$ClamAVOutputLineIndex..($ClamAVOutput.Count - 1)] -join "`n")
					break
				}
				if (
					($ClamAVOutputLineContent -match ': OK$') -or
					($ClamAVOutputLineContent -match '^\s*$')
				) {
					continue
				}
				if ($ClamAVOutputLineContent -match ': .+ FOUND$') {
					[String]$ClamAVElementIssue = $ClamAVOutputLineContent -replace ' FOUND$', ''
					Write-GitHubActionsDebug -Message $ClamAVElementIssue
					[String]$Element, [String]$Signature = $ClamAVElementIssue -split '(?<=^.+?): '
					if ($null -eq $ClamAVResultFound[$Element]) {
						$ClamAVResultFound[$Element] = @()
					}
					if ($Signature -notin $ClamAVResultFound[$Element]) {
						$ClamAVResultFound[$Element] += $Signature
					}
				} else {
					$ClamAVResultError += $ClamAVOutputLineContent
				}
			}
			if ($ClamAVResultFound.Count -gt 0) {
				Write-GitHubActionsError -Message "Found issues in session `"$Session`" via ClamAV ($($ClamAVResultFound.Count)):`n$(Optimize-PSFormatDisplay -InputObject ($ClamAVResultFound.GetEnumerator() | ForEach-Object -Process {
					[String[]]$IssueSignatures = $_.Value | Sort-Object -Unique -CaseSensitive
					return [PSCustomObject]@{
						Element = $_.Name
						Signatures_List = $IssueSignatures -join ', '
						Signatures_Count = $IssueSignatures.Count
					}
				} | Sort-Object -Property 'Element' | Format-List | Out-String))"
				if ($Session -notin $script:IssuesSessionsClamAV) {
					$script:IssuesSessionsClamAV += $Session
				}
			}
			if ($ClamAVResultError.Count -gt 0) {
				Write-GitHubActionsError -Message "Unexpected ClamAV result ``$ClamAVExitCode`` in session `"$Session`":`n$($ClamAVResultError -join "`n")"
				if ($Session -notin $script:IssuesSessionsClamAV) {
					$script:IssuesSessionsClamAV += $Session
				}
			}
			Exit-GitHubActionsLogGroup
			Remove-Item -LiteralPath $ElementsListClamAVFullName -Force -Confirm:$False
		}
		if ($YaraEnable -and ($ElementsListYara.Count -gt 0)) {
			[String]$ElementsListYaraFullName = (New-TemporaryFile).FullName
			Set-Content -LiteralPath $ElementsListYaraFullName -Value ($ElementsListYara -join "`n") -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
			Enter-GitHubActionsLogGroup -Title "YARA result of session `"$Session`":"
			[hashtable]$YaraResult = @{}
			foreach ($YaraRule in $YaraRulesApply) {
				[String[]]$YaraOutput = Invoke-Expression -Command "yara --scan-list$($YaraToolWarning ? '' : ' --no-warnings') `"$(Join-Path -Path $YaraRulesRoot -ChildPath $YaraRule.Location)`" `"$ElementsListYaraFullName`""
				if ($LASTEXITCODE -eq 0) {
					$YaraOutput | ForEach-Object -Process {
						if ($_ -match "^.+? $GitHubActionsWorkspaceRootRegEx.+$") {
							[String]$Rule, [String]$IssueElement = $_ -split "(?<=^.+?) $GitHubActionsWorkspaceRootRegEx"
							[String]$YaraRuleName = "$($YaraRule.Name)/$Rule"
							[String]$YaraElementIssue = "$YaraRuleName>$IssueElement"
							Write-GitHubActionsDebug -Message $YaraElementIssue
							if (Test-InputFilter -Target $YaraElementIssue -FilterList $YaraRulesFilterList -FilterMode $YaraRulesFilterMode) {
								if ($null -eq $YaraResult[$IssueElement]) {
									$YaraResult[$IssueElement] = @()
								}
								if ($YaraRuleName -notin $YaraResult[$IssueElement]) {
									$YaraResult[$IssueElement] += $YaraRuleName
								}
							} else {
								Write-GitHubActionsDebug -Message '  > Skip'
							}
						} elseif ($_.Length -gt 0) {
							Write-Host -Object $_
						}
					}
				} else {
					Write-GitHubActionsError -Message "Unexpected YARA `"$($YaraRule.Name)`" result ``$LASTEXITCODE`` in session `"$Session`"!`n$YaraOutput"
					if ($Session -notin $script:IssuesSessionsYara) {
						$script:IssuesSessionsYara += $Session
					}
				}
			}
			if ($YaraResult.Count -gt 0) {
				Write-GitHubActionsError -Message "Found issues in session `"$Session`" via YARA ($($YaraResult.Count)):`n$(Optimize-PSFormatDisplay -InputObject ($YaraResult.GetEnumerator() | ForEach-Object -Process {
					[String[]]$IssueRules = $_.Value | Sort-Object -Unique -CaseSensitive
					return [PSCustomObject]@{
						Element = $_.Name
						Rules_List = $IssueRules -join ', '
						Rules_Count = $IssueRules.Count
					}
				} | Sort-Object -Property 'Element' | Format-List | Out-String))"
				if ($Session -notin $script:IssuesSessionsYara) {
					$script:IssuesSessionsYara += $Session
				}
			}
			Exit-GitHubActionsLogGroup
			Remove-Item -LiteralPath $ElementsListYaraFullName -Force -Confirm:$False
		}
	}
	Write-Host -Object "End of session `"$Session`"."
}
If ($LocalTarget) {
	Invoke-ScanVirusTools -Session 'Current'
	If ($GitIntegrate) {
		If (Test-Path -LiteralPath (Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath '.git') -PathType 'Container') {
			Write-Host -Object 'Import Git information.'
			[PSCustomObject[]]$GitCommits = Get-GitCommitsInformation
			If ($GitCommits.Count -ile 1) {
				Write-GitHubActionsWarning -Message "Current Git repository has only $($GitCommits.Count) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: Re-run cannot apply the modified workflow!)"
			}
			For ($GitCommitsIndex = 0; $GitCommitsIndex -ilt $GitCommits.Count; $GitCommitsIndex++) {
				[String]$GitCommitHash = $GitCommits[$GitCommitsIndex]
				[String]$GitSession = "Git Commit $GitCommitHash (#$($GitReverse ? ($GitCommits.Count - $GitCommitsIndex) : ($GitCommitsIndex + 1))/$($GitCommits.Count))"
				Enter-GitHubActionsLogGroup -Title "Git checkout for commit $GitCommitHash."
				Try {
					Invoke-Expression -Command "git checkout $GitCommitHash --force --quiet"
				} Catch {  }
				If ($LASTEXITCODE -ieq 0) {
					Exit-GitHubActionsLogGroup
					Invoke-ScanVirusTools -Session $GitSession
				} Else {
					Write-GitHubActionsError -Message "Unexpected Git checkout exit code ``$LASTEXITCODE`` in commit $GitCommitHash!"
					If ($GitCommitHash -inotin $IssuesSessionsOther) {
						$IssuesSessionsOther += $GitCommitHash
					}
					Exit-GitHubActionsLogGroup
				}
			}
		} Else {
			Write-GitHubActionsWarning -Message 'Unable to integrate with Git due to the workspace is not a Git repository! If this is incorrect, probably Git data is broken and/or invalid.'
		}
	}
} Else {
	[PSCustomObject[]]$UselessElements = Get-ChildItem -LiteralPath $env:GITHUB_WORKSPACE -Recurse -Force
	If ($UselessElements.Count -igt 0) {
		Write-GitHubActionsWarning -Message 'Require a clean workspace when target is network!'
		Write-Host -Object 'Clean workspace.'
		$UselessElements | Remove-Item -Force -Confirm:$False
	}
	$NetworkTargets | ForEach-Object -Process {
		Enter-GitHubActionsLogGroup -Title "Fetch file `"$_`"."
		[String]$NetworkTemporaryFileFullPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath (New-Guid).Guid
		Try {
			Invoke-WebRequest -Uri $_ -UseBasicParsing -Method 'Get' -OutFile $NetworkTemporaryFileFullPath
		} Catch {
			Write-GitHubActionsError -Message "Unable to fetch file `"$_`"!"
			Continue
		}
		Exit-GitHubActionsLogGroup
		Invoke-ScanVirusTools -Session $_
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
	} | Format-List | Out-String)
	Exit-GitHubActionsLogGroup
}
If ($TotalIssues -igt 0) {
	Exit 1
}
Exit 0
