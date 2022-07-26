[String]$ErrorActionOriginalPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
Write-Host -Object 'Starting.'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (@('assets', 'csv', 'git', 'utility') | ForEach-Object -Process {
	Return (Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1")
}) -Scope 'Local'
[String]$ClamAVDatabaseRoot = '/var/lib/clamav'
[String]$AssetsRoot = Join-Path -Path $PSScriptRoot -ChildPath 'assets'
[String]$ClamAVSignaturesIgnorePresetsRoot = Join-Path -Path $AssetsRoot -ChildPath 'clamav-signatures-ignore-presets'
[String]$ClamAVUnofficialSignaturesRoot = Join-Path -Path $AssetsRoot -ChildPath 'clamav-unofficial-signatures'
[String]$YARARulesRoot = Join-Path -Path $AssetsRoot -ChildPath 'yara-rules'
[RegEx]$GitHubActionsWorkspaceRootRegEx = "$([RegEx]::Escape($Env:GITHUB_WORKSPACE))\/"
[String[]]$IssuesSessionsClamAV = @()
[String[]]$IssuesSessionsOther = @()
[String[]]$IssuesSessionsYARA = @()
[UInt64]$TotalElementsAll = 0
[UInt64]$TotalElementsClamAV = 0
[UInt64]$TotalElementsYARA = 0
[UInt64]$TotalSizesAll = 0
[UInt64]$TotalSizesClamAV = 0
[UInt64]$TotalSizesYARA = 0
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
If (!$LocalTarget -and $NetworkTargets.Count -ieq 0) {
	Write-GitHubActionsFail -Message 'Input `targets` does not have valid targets!'
}
[Boolean]$GitIntegrate = Get-InputBoolean -Name 'git_integrate'
Write-NameValue -Name 'Git_Integrate' -Value $GitIntegrate
$GitIgnoresRaw = Get-GitHubActionsInput -Name 'git_ignores' -EmptyStringAsNull






[Boolean]$GitReverse = Get-InputBoolean -Name 'git_reverse'
Write-NameValue -Name 'Git_Reverse' -Value $GitReverse
[Boolean]$ClamAVEnable = Get-InputBoolean -Name 'clamav_enable'
Write-NameValue -Name 'ClamAV_Enable' -Value $ClamAVEnable
[Boolean]$ClamAVDaemon = Get-InputBoolean -Name 'clamav_daemon'
Write-NameValue -Name 'ClamAV_Daemon' -Value $ClamAVDaemon
$ClamAVIgnoresRaw = Get-GitHubActionsInput -Name 'clamav_ignores' -EmptyStringAsNull







[Boolean]$ClamAVMultiScan = Get-InputBoolean -Name 'clamav_multiscan'
Write-NameValue -Name 'ClamAV_MultiScan' -Value $ClamAVMultiScan
[Boolean]$ClamAVReloadPerSession = Get-InputBoolean -Name 'clamav_reloadpersession'
Write-NameValue -Name 'ClamAV_ReloadPerSession' -Value $ClamAVReloadPerSession
[Boolean]$ClamAVSubcursive = Get-InputBoolean -Name -Name 'clamav_subcursive'
Write-NameValue -Name 'ClamAV_Subcursive' -Value $ClamAVSubcursive
[RegEx[]]$ClamAVUnofficialSignaturesRegEx = Get-InputList -Name 'clamav_unofficialsignatures' -Delimiter $InputListDelimiter
Write-NameValue -Name "ClamAV_UnofficialSignatures_RegEx ($($ClamAVUnofficialSignaturesRegEx.Count))" -Value (($ClamAVUnofficialSignaturesRegEx.Count -igt 0) ? "``$($ClamAVUnofficialSignaturesRegEx -join '`, `')``" : '')
[Boolean]$YARAEnable = Get-InputBoolean -Name 'yara_enable'
Write-NameValue -Name 'YARA_Enable' -Value $YARAEnable
$YARAIgnoresRaw = Get-GitHubActionsInput -Name 'yara_ignores' -EmptyStringAsNull





[RegEx[]]$YARARulesRegEx = Get-InputList -Name 'yara_rules' -Delimiter $InputListDelimiter
Write-NameValue -Name "YARA_Rules_RegEx ($($YARARulesRegEx.Count))" -Value (($YARARulesRegEx.Count -igt 0) ? "``$($YARARulesRegEx -join '`, `')``" : '')
[Boolean]$YARAToolWarning = Get-InputBoolean -Name 'yara_toolwarning'
Write-NameValue -Name 'YARA_ToolWarning' -Value $YARAToolWarning
If ($True -notin @($ClamAVEnable, $YARAEnable)) {
	Write-GitHubActionsFail -Message 'No scan virus tools enabled!'
}
Exit-GitHubActionsLogGroup






[PSCustomObject[]]$ClamAVSignaturesIgnorePresetsIndex = Get-Csv -LiteralPath (Join-Path -Path $ClamAVSignaturesIgnorePresetsRoot -ChildPath 'index.tsv') -Delimiter "`t"
[PSCustomObject[]]$ClamAVUnofficialSignaturesIndex = Get-Csv -LiteralPath (Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath 'index.tsv') -Delimiter "`t"
[PSCustomObject[]]$YARARulesIndex = Get-Csv -LiteralPath (Join-Path -Path $YARARulesRoot -ChildPath 'index.tsv') -Delimiter "`t"







[PSCustomObject[]]$ClamAVUnofficialSignaturesApply = $ClamAVUnofficialSignaturesIndex | Where-Object -FilterScript {
	return Test-InputFilter -Target $_.Name -Include $ClamAVUnofficialSignaturesRaw
} | Sort-Object -Property 'Name'
[PSCustomObject[]]$YARARulesApply = $YARARulesIndex | Where-Object -FilterScript {
	return Test-InputFilter -Target $_.Name -Exclude $YARARulesFilter.Exclude -Include $YARARulesFilter.Include
} | Sort-Object -Property 'Name'
if ($ClamAVEnable) {
	[String[]]$ClamAVSignaturesIgnore = $ClamAVSignaturesIgnoreCustom
	[PSCustomObject[]]$ClamAVSignaturesIgnorePresetsDisplay = @()
	[String[]]$ClamAVSignaturesIgnorePresetsInvalid = @()
	$ClamAVSignaturesIgnorePresetsIndex | ForEach-Object -Process {
		[String]$ClamAVSignaturesIgnorePresetFullName = Join-Path -Path $ClamAVSignaturesIgnorePresetsRoot -ChildPath $_.Location
		[bool]$ClamAVSignaturesIgnorePresetExist = Test-Path -LiteralPath $ClamAVSignaturesIgnorePresetFullName
		[bool]$ClamAVSignaturesIgnorePresetApply = $_.Name -in $ClamAVSignaturesIgnorePresetsApply.Name
		[hashtable]$ClamAVSignaturesIgnorePresetDisplay = @{
			Name = $_.Name
			Exist = $ClamAVSignaturesIgnorePresetExist
			Apply = $ClamAVSignaturesIgnorePresetApply
		}
		$ClamAVSignaturesIgnorePresetsDisplay += [PSCustomObject]$ClamAVSignaturesIgnorePresetDisplay
		if ($ClamAVSignaturesIgnorePresetExist) {
			if ($ClamAVSignaturesIgnorePresetApply) {
				$ClamAVSignaturesIgnore += Get-Content -LiteralPath $ClamAVSignaturesIgnorePresetFullName -Encoding 'UTF8NoBOM'
			}
		} else {
			$ClamAVSignaturesIgnorePresetsInvalid += $_.Name
		}
	}
	Enter-GitHubActionsLogGroup -Title "ClamAV signatures ignore presets index (I: $($ClamAVSignaturesIgnorePresetsIndex.Count); A: $($ClamAVSignaturesIgnorePresetsApply.Count); S: $($ClamAVSignaturesIgnorePresetsApply.Count - $ClamAVSignaturesIgnorePresetsInvalid.Count)):"
	if ($ClamAVSignaturesIgnorePresetsInvalid.Count -gt 0) {
		Write-GitHubActionsWarning -Message "Some of the ClamAV signatures ignore presets are indexed but not exist ($($ClamAVSignaturesIgnorePresetsInvalid.Count)): $($ClamAVSignaturesIgnorePresetsInvalid -join ', ')"
	}
	Write-OptimizePSFormatDisplay -InputObject ($ClamAVSignaturesIgnorePresetsDisplay | Format-Table -Property @(
		'Name',
		@{ Expression = 'Exist'; Alignment = 'Right' },
		@{ Expression = 'Apply'; Alignment = 'Right' }
	) -AutoSize -Wrap | Out-String)
	Exit-GitHubActionsLogGroup
	$ClamAVSignaturesIgnore = $ClamAVSignaturesIgnore | ForEach-Object -Process {
		return $_.Trim()
	} | Where-Object -FilterScript {
		return ($_.Length -gt 0)
	} | Sort-Object -Unique -CaseSensitive
	Enter-GitHubActionsLogGroup -Title "ClamAV signatures ignore ($($ClamAVSignaturesIgnore.Count)):"
	if ($ClamAVSignaturesIgnore.Count -gt 0) {
		Write-Host -Object ($ClamAVSignaturesIgnore -join ', ')
		Set-Content -LiteralPath $ClamAVSignaturesIgnoreFileFullName -Value ($ClamAVSignaturesIgnore -join "`n") -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
		$CleanUpFilesFullNames += $ClamAVSignaturesIgnoreFileFullName
	}
	Exit-GitHubActionsLogGroup
	[PSCustomObject[]]$ClamAVUnofficialSignaturesDisplay = @()
	[String[]]$ClamAVUnofficialSignaturesInvalid = @()
	$ClamAVUnofficialSignaturesIndex | ForEach-Object -Process {
		[String]$ClamAVUnofficialSignatureFullName = Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath $_.Location
		[bool]$ClamAVUnofficialSignatureExist = Test-Path -LiteralPath $ClamAVUnofficialSignatureFullName
		[bool]$ClamAVUnofficialSignatureApply = $_.Name -in $ClamAVUnofficialSignaturesApply.Name
		[hashtable]$ClamAVUnofficialSignatureDisplay = @{
			Name = $_.Name
			Exist = $ClamAVUnofficialSignatureExist
			Apply = $ClamAVUnofficialSignatureApply
		}
		$ClamAVUnofficialSignaturesDisplay += [PSCustomObject]$ClamAVUnofficialSignatureDisplay
		if ($ClamAVUnofficialSignatureExist) {
			if ($ClamAVUnofficialSignatureApply) {
				[String]$ClamAVUnofficialSignatureDestination = Join-Path -Path $ClamAVDatabaseRoot -ChildPath ($_.Location -replace '\/', '_')
				Copy-Item -LiteralPath $ClamAVUnofficialSignatureFullName -Destination $ClamAVUnofficialSignatureDestination -Confirm:$False
				$CleanUpFilesFullNames += $ClamAVUnofficialSignatureDestination
			}
		} else {
			$ClamAVUnofficialSignaturesInvalid += $_.Name
		}
	}
	Enter-GitHubActionsLogGroup -Title "ClamAV unofficial signatures index (I: $($ClamAVUnofficialSignaturesIndex.Count); A: $($ClamAVUnofficialSignaturesApply.Count); S: $($ClamAVUnofficialSignaturesApply.Count - $ClamAVUnofficialSignaturesInvalid.Count)):"
	if ($ClamAVUnofficialSignaturesInvalid.Count -gt 0) {
		Write-GitHubActionsWarning -Message "Some of the ClamAV unofficial signatures are indexed but not exist ($($ClamAVUnofficialSignaturesInvalid.Count)): $($ClamAVUnofficialSignaturesInvalid -join ', ')"
	}
	Write-OptimizePSFormatDisplay -InputObject ($ClamAVUnofficialSignaturesDisplay | Format-Table -Property @(
		'Name',
		@{ Expression = 'Exist'; Alignment = 'Right' },
		@{ Expression = 'Apply'; Alignment = 'Right' }
	) -AutoSize -Wrap | Out-String)
	Exit-GitHubActionsLogGroup
}
if ($YARAEnable) {
	[PSCustomObject[]]$YARARulesDisplay = @()
	[String[]]$YARARulesInvalid = @()
	$YARARulesIndex | ForEach-Object -Process {
		[String]$YARARuleFullName = Join-Path -Path $YARARulesRoot -ChildPath $_.Location
		[bool]$YARARuleExist = Test-Path -LiteralPath $YARARuleFullName
		[bool]$YARARuleApply = $_.Name -in $YARARulesApply.Name
		[hashtable]$YARARuleDisplay = @{
			Name = $_.Name
			Exist = $YARARuleExist
			Apply = $YARARuleApply
		}
		$YARARulesDisplay += [PSCustomObject]$YARARuleDisplay
		if ($YARARuleExist -eq $False) {
			$YARARulesInvalid += $_.Name
		}
	}
	Enter-GitHubActionsLogGroup -Title "YARA rules index (I: $($YARARulesIndex.Count); A: $($YARARulesApply.Count); S: $($YARARulesApply.Count - $YARARulesInvalid.Count)):"
	if ($YARARulesInvalid.Count -gt 0) {
		Write-GitHubActionsWarning -Message "Some of the YARA rules are indexed but not exist ($($YARARulesInvalid.Count)): $($YARARulesInvalid -join ', ')"
	}
	Write-OptimizePSFormatDisplay -InputObject ($YARARulesDisplay | Format-Table -Property @(
		'Name',
		@{ Expression = 'Exist'; Alignment = 'Right' },
		@{ Expression = 'Apply'; Alignment = 'Right' }
	) -AutoSize -Wrap | Out-String)
	Exit-GitHubActionsLogGroup
}
Enter-GitHubActionsLogGroup -Title 'Update software.'
try {
	Invoke-Expression -Command 'apt-get --assume-yes update'
	Invoke-Expression -Command 'apt-get --assume-yes upgrade'
} catch {  }
Exit-GitHubActionsLogGroup
if ($ClamAVEnable) {
	Enter-GitHubActionsLogGroup -Title 'Update ClamAV via FreshClam.'
	try {
		Invoke-Expression -Command 'freshclam'
	} catch {  }
	Exit-GitHubActionsLogGroup
	if ($ClamAVDaemon) {
		Enter-GitHubActionsLogGroup -Title 'Start ClamAV daemon.'
		Invoke-Expression -Command 'clamd'
		Exit-GitHubActionsLogGroup
	}
}
function Invoke-ScanVirusSession {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Session
	)
	Write-Host -Object "Begin of session `"$Session`"."
	[PSCustomObject[]]$Elements = Get-ChildItem -LiteralPath $Env:GITHUB_WORKSPACE -Recurse -Force
	if (
		($null -eq $Elements) -or
		($Elements.Count -eq 0)
	) {
		Write-GitHubActionsError -Message "Unable to scan session `"$Session`" due to it is empty! If this is incorrect, probably someone forgot to put files in there."
		if ($Session -notin $script:IssuesSessionsOther) {
			$script:IssuesSessionsOther += $Session
		}
	} else {
		[String[]]$ElementsListClamAV = @()
		[String[]]$ElementsListYARA = @()
		[PSCustomObject[]]$ElementsListDisplay = @()
		[uint]$ElementsIsDirectoryCount = 0
		$Elements | Sort-Object | ForEach-Object -Process {
			[bool]$ElementIsDirectory = Test-Path -LiteralPath $_.FullName -PathType 'Container'
			[String]$ElementName = $_.FullName -replace "^$GitHubActionsWorkspaceRootRegEx", ''
			[UInt64]$ElementSizes = $_.Length
			[hashtable]$ElementListDisplay = @{
				Element = $ElementName
				Flags = @(
					$ElementIsDirectory ? 'D' : ''
				)
			}
			if ($ElementIsDirectory) {
				$ElementsIsDirectoryCount += 1
			} else {
				$ElementListDisplay.Sizes = $ElementSizes
				$script:TotalSizesAll += $ElementSizes
			}
			if ($ClamAVEnable -and (
				($ElementIsDirectory -and $ClamAVSubcursive) -or
				($ElementIsDirectory -eq $False)
			) -and (
				($LocalTarget -eq $False) -or
				(Test-InputFilter -Target $ElementName -FilterList $ClamAVFilesFilterList -FilterMode $ClamAVFilesFilterMode)
			)) {
				$ElementsListClamAV += $_.FullName
				$ElementListDisplay.Flags += 'C'
				if ($ElementIsDirectory -eq $False) {
					$script:TotalSizesClamAV += $ElementSizes
				}
			}
			if ($YARAEnable -and ($ElementIsDirectory -eq $False) -and (
				($LocalTarget -eq $False) -or
				(Test-InputFilter -Target $ElementName -FilterList $YARAFilesFilterList -FilterMode $YARAFilesFilterMode)
			)) {
				$ElementsListYARA += $_.FullName
				$ElementListDisplay.Flags += 'Y'
				$script:TotalSizesYARA += $ElementSizes
			}
			$ElementListDisplay.Flags = ($ElementListDisplay.Flags | Sort-Object) -join ''
			$ElementsListDisplay += [PSCustomObject]$ElementListDisplay
		}
		$script:TotalElementsAll += $Elements.Count
		$script:TotalElementsClamAV += $ElementsListClamAV.Count
		$script:TotalElementsYARA += $ElementsListYARA.Count
		Enter-GitHubActionsLogGroup -Title "Elements of session `"$Session`" (E: $($Elements.Count); FC: $($ElementsListClamAV.Count); FD: $ElementsIsDirectoryCount; FY: $($ElementsListYARA.Count)):"
		Write-OptimizePSFormatDisplay -InputObject ($ElementsListDisplay | Format-Table -Property @(
			'Element',
			'Flags',
			@{ Expression = 'Sizes'; Alignment = 'Right' }
		) -AutoSize -Wrap | Out-String)
		Exit-GitHubActionsLogGroup
		if ($ClamAVEnable -and ($ElementsListClamAV.Count -gt 0)) {
			[String]$ElementsListClamAVFullName = (New-TemporaryFile).FullName
			Set-Content -LiteralPath $ElementsListClamAVFullName -Value ($ElementsListClamAV -join "`n") -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
			Enter-GitHubActionsLogGroup -Title "ClamAV result of session `"$Session`":"
			[String]$ClamAVExpression = ''
			if ($ClamAVDaemon) {
				$ClamAVExpression = "clamdscan --fdpass --file-list=`"$ElementsListClamAVFullName`"$($ClamAVMultiScan ? ' --multiscan' : '')$($ClamAVReloadPerSession ? ' --reload' : '')"
			} else {
				$ClamAVExpression = "clamscan --detect-broken=yes --file-list=`"$ElementsListClamAVFullName`" --follow-dir-symlinks=0 --follow-file-symlinks=0 --recursive"
			}
			[String[]]$ClamAVOutput = Invoke-Expression -Command $ClamAVExpression
			[uint]$ClamAVExitCode = $LASTEXITCODE
			[String[]]$ClamAVResultError = @()
			[hashtable]$ClamAVResultFound = @{}
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
		if ($YARAEnable -and ($ElementsListYARA.Count -gt 0)) {
			[String]$ElementsListYARAFullName = (New-TemporaryFile).FullName
			Set-Content -LiteralPath $ElementsListYARAFullName -Value ($ElementsListYARA -join "`n") -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
			Enter-GitHubActionsLogGroup -Title "YARA result of session `"$Session`":"
			[hashtable]$YARAResult = @{}
			foreach ($YARARule in $YARARulesApply) {
				[String[]]$YARAOutput = Invoke-Expression -Command "yara --scan-list$($YARAToolWarning ? '' : ' --no-warnings') `"$(Join-Path -Path $YARARulesRoot -ChildPath $YARARule.Location)`" `"$ElementsListYARAFullName`""
				if ($LASTEXITCODE -eq 0) {
					$YARAOutput | ForEach-Object -Process {
						if ($_ -match "^.+? $GitHubActionsWorkspaceRootRegEx.+$") {
							[String]$Rule, [String]$IssueElement = $_ -split "(?<=^.+?) $GitHubActionsWorkspaceRootRegEx"
							[String]$YARARuleName = "$($YARARule.Name)/$Rule"
							[String]$YARAElementIssue = "$YARARuleName>$IssueElement"
							Write-GitHubActionsDebug -Message $YARAElementIssue
							if (Test-InputFilter -Target $YARAElementIssue -FilterList $YARARulesFilterList -FilterMode $YARARulesFilterMode) {
								if ($null -eq $YARAResult[$IssueElement]) {
									$YARAResult[$IssueElement] = @()
								}
								if ($YARARuleName -notin $YARAResult[$IssueElement]) {
									$YARAResult[$IssueElement] += $YARARuleName
								}
							} else {
								Write-GitHubActionsDebug -Message '  > Skip'
							}
						} elseif ($_.Length -gt 0) {
							Write-Host -Object $_
						}
					}
				} else {
					Write-GitHubActionsError -Message "Unexpected YARA `"$($YARARule.Name)`" result ``$LASTEXITCODE`` in session `"$Session`"!`n$YARAOutput"
					if ($Session -notin $script:IssuesSessionsYARA) {
						$script:IssuesSessionsYARA += $Session
					}
				}
			}
			if ($YARAResult.Count -gt 0) {
				Write-GitHubActionsError -Message "Found issues in session `"$Session`" via YARA ($($YARAResult.Count)):`n$(Optimize-PSFormatDisplay -InputObject ($YARAResult.GetEnumerator() | ForEach-Object -Process {
					[String[]]$IssueRules = $_.Value | Sort-Object -Unique -CaseSensitive
					return [PSCustomObject]@{
						Element = $_.Name
						Rules_List = $IssueRules -join ', '
						Rules_Count = $IssueRules.Count
					}
				} | Sort-Object -Property 'Element' | Format-List | Out-String))"
				if ($Session -notin $script:IssuesSessionsYARA) {
					$script:IssuesSessionsYARA += $Session
				}
			}
			Exit-GitHubActionsLogGroup
			Remove-Item -LiteralPath $ElementsListYARAFullName -Force -Confirm:$False
		}
	}
	Write-Host -Object "End of session `"$Session`"."
}
if ($LocalTarget) {
	Invoke-ScanVirusSession -Session 'Current'
	if ($GitIntegrate) {
		if (Test-Path -LiteralPath (Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath '.git') -PathType 'Container') {
			Write-Host -Object 'Import Git information.'
			[String[]]$GitCommits = [String[]](Invoke-Expression -Command "git --no-pager log --all --format=%H$($GitReverse ? '' : ' --reverse')") | Select-Object -Unique
			if ($GitCommits.Count -le 1) {
				Write-GitHubActionsWarning -Message "Current Git repository has only $($GitCommits.Count) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run ________`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex++) {
				[String]$GitCommitHash = $GitCommits[$GitCommitsIndex]
				[String]$GitSession = "Commit Hash $GitCommitHash (#$($GitReverse ? ($GitCommits.Count - $GitCommitsIndex) : ($GitCommitsIndex + 1))/$($GitCommits.Count))"
				Enter-GitHubActionsLogGroup -Title "Git checkout for session `"$GitSession`"."
				try {
					Invoke-Expression -Command "git checkout $GitCommitHash --force --quiet"
				} catch {  }
				if ($LASTEXITCODE -eq 0) {
					Exit-GitHubActionsLogGroup
					Invoke-ScanVirusSession -Session $GitSession
				} else {
					Write-GitHubActionsError -Message "Unexpected Git checkout result ``$LASTEXITCODE`` in session `"$GitSession`"!"
					if ($GitSession -notin $IssuesSessionsOther) {
						$IssuesSessionsOther += $GitSession
					}
					Exit-GitHubActionsLogGroup
				}
			}
		} else {
			Write-GitHubActionsWarning -Message 'Unable to scan deeper due to it is not a Git repository! If this is incorrect, probably Git data is broken and/or invalid.'
		}
	}
} else {
	[PSCustomObject[]]$UselessElements = Get-ChildItem -LiteralPath $env:GITHUB_WORKSPACE -Recurse -Force
	if ($UselessElements.Count -gt 0) {
		Write-GitHubActionsWarning -Message 'Require a clean workspace when target is network!'
		Write-Host -Object 'Clean workspace.'
		$UselessElements | Remove-Item -Force -Confirm:$False
	}
	$NetworkTargets | ForEach-Object -Process {
		Enter-GitHubActionsLogGroup -Title "Fetch file `"$_`"."
		[String]$NetworkTemporaryFileFullPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath (New-Guid).Guid
		try {
			Invoke-WebRequest -Uri $_ -UseBasicParsing -Method Get -OutFile $NetworkTemporaryFileFullPath
		} catch {
			Write-GitHubActionsError -Message "Unable to fetch file `"$_`"!"
			continue
		}
		Exit-GitHubActionsLogGroup
		Invoke-ScanVirusSession -Session $_
		Remove-Item -LiteralPath $NetworkTemporaryFileFullPath -Force -Confirm:$False
	}
}
if ($ClamAVEnable -and $ClamAVDaemon) {
	Enter-GitHubActionsLogGroup -Title 'Stop ClamAV daemon.'
	Get-Process -Name '*clamd*' | Stop-Process
	Exit-GitHubActionsLogGroup
}
if ($CleanUpFilesFullNames.Count -gt 0) {
	$CleanUpFilesFullNames | ForEach-Object -Process {
		Remove-Item -LiteralPath $_ -Force -Confirm:$False
	}
}
Enter-GitHubActionsLogGroup -Title 'Statistics:'
[UInt64]$TotalIssues = $IssuesSessionsClamAV.Count + $IssuesSessionsOther.Count + $IssuesSessionsYARA.Count
Write-OptimizePSFormatDisplay -InputObject ([PSCustomObject[]]@(
	[PSCustomObject]@{
		Name = 'TotalElements_Count'
		All = $TotalElementsAll
		ClamAV = $TotalElementsClamAV
		YARA = $TotalElementsYARA
	},
	[PSCustomObject]@{
		Name = 'TotalElements_Percentage'
		ClamAV = ($TotalElementsAll -eq 0) ? 0 : ($TotalElementsClamAV / $TotalElementsAll * 100)
		YARA = ($TotalElementsAll -eq 0) ? 0 : ($TotalElementsYARA / $TotalElementsAll * 100)
	},
	[PSCustomObject]@{
		Name = 'TotalIssuesSessions_Count'
		All = $TotalIssues
		ClamAV = $IssuesSessionsClamAV.Count
		YARA = $IssuesSessionsYARA.Count
		Other = $IssuesSessionsOther.Count
	},
	[PSCustomObject]@{
		Name = 'TotalIssuesSessions_Percentage'
		ClamAV = ($TotalIssues -eq 0) ? 0 : ($IssuesSessionsClamAV.Count / $TotalIssues * 100)
		YARA = ($TotalIssues -eq 0) ? 0 : ($IssuesSessionsYARA.Count / $TotalIssues * 100)
		Other = ($TotalIssues -eq 0) ? 0 : ($IssuesSessionsOther.Count / $TotalIssues * 100)
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_B'
		All = $TotalSizesAll
		ClamAV = $TotalSizesClamAV
		YARA = $TotalSizesYARA
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_KB'
		All = $TotalSizesAll / 1KB
		ClamAV = $TotalSizesClamAV / 1KB
		YARA = $TotalSizesYARA / 1KB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_MB'
		All = $TotalSizesAll / 1MB
		ClamAV = $TotalSizesClamAV / 1MB
		YARA = $TotalSizesYARA / 1MB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_GB'
		All = $TotalSizesAll / 1GB
		ClamAV = $TotalSizesClamAV / 1GB
		YARA = $TotalSizesYARA / 1GB
	},
	[PSCustomObject]@{
		Name = 'TotalSizes_Percentage'
		ClamAV = $TotalSizesClamAV / $TotalSizesAll * 100
		YARA = $TotalSizesYARA / $TotalSizesAll * 100
	}
) | Format-Table -Property @(
	'Name',
	@{ Expression = 'All'; Alignment = 'Right' },
	@{ Expression = 'ClamAV'; Alignment = 'Right' },
	@{ Expression = 'YARA'; Alignment = 'Right' },
	@{ Expression = 'Other'; Alignment = 'Right' }
) -AutoSize -Wrap | Out-String)
Exit-GitHubActionsLogGroup
if ($TotalIssues -gt 0) {
	Enter-GitHubActionsLogGroup -Title 'Issues sessions:'
	Write-OptimizePSFormatDisplay -InputObject ([PSCustomObject]@{
		ClamAV = $IssuesSessionsClamAV -join ', '
		YARA = $IssuesSessionsYARA -join ', '
		Other = $IssuesSessionsOther -join ', '
	} | Format-List | Out-String)
	Exit-GitHubActionsLogGroup
}
Optimize-StepSummary
$ErrorActionPreference = $ErrorActionOriginalPreference
if ($TotalIssues -gt 0) {
	exit 1
}
exit 0
