[string]$ErrorActionOriginalPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
Import-Module -Name @(
	'hugoalh.GitHubActionsToolkit',
	(Join-Path -Path $PSScriptRoot -ChildPath 'csv.psm1'),
	(Join-Path -Path $PSScriptRoot -ChildPath 'test-stringisurl.psm1')
) -Scope 'Local'
enum FilterMode {
	Exclude = 0
	E = 0
	Ex = 0
	Include = 1
	I = 1
	In = 1
}
function Format-InputList {
	[CmdletBinding()][OutputType([string[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()][string]$InputObject
	)
	return [string[]]($InputObject -split ';|\r?\n') | ForEach-Object -Process {
		return $_.Trim()
	} | Where-Object -FilterScript {
		return ($_.Length -gt 0)
	} | Sort-Object -Unique -CaseSensitive
}
function Get-InputList {
	[CmdletBinding()][OutputType([string[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Name
	)
	return Format-InputList -InputObject (Get-GitHubActionsInput -Name $Name -Trim)
}
function Optimize-PSFormatDisplay {
	[CmdletBinding()][OutputType([string])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	return $InputObject -replace '^(?:\r?\n)+|(?:\r?\n)+$', ''
}
function Test-InputFilter {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Target,
		[Parameter(Mandatory = $true, Position = 1)][AllowEmptyCollection()][AllowNull()][string[]]$FilterList,
		[Parameter(Mandatory = $true, Position = 2)][FilterMode]$FilterMode
	)
	foreach ($Filter in $FilterList) {
		if ($Target -match $Filter) {
			switch ($FilterMode.GetHashCode()) {
				0 { return $false }
				1 { return $true }
			}
		}
	}
	switch ($FilterMode.GetHashCode()) {
		0 { return $true }
		1 { return $false }
	}
}
function Write-OptimizePSFormatDisplay {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	[string]$OutputObject = Optimize-PSFormatDisplay -InputObject $InputObject
	if ($OutputObject.Length -gt 0) {
		Write-Host -Object $OutputObject
	}
}
[string]$ClamAVDatabaseRoot = '/var/lib/clamav'
[string]$ClamAVSignaturesIgnoreFileFullName = Join-Path -Path $ClamAVDatabaseRoot -ChildPath 'ignore_list.ign2'
[string]$ClamAVSignaturesIgnorePresetsRoot = Join-Path -Path $PSScriptRoot -ChildPath 'clamav-signatures-ignore-presets'
[pscustomobject[]]$ClamAVSignaturesIgnorePresetsIndex = Get-Csv -LiteralPath (Join-Path -Path $ClamAVSignaturesIgnorePresetsRoot -ChildPath 'index.tsv') -Delimiter "`t"
[string]$ClamAVUnofficialSignaturesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'clamav-unofficial-signatures'
[pscustomobject[]]$ClamAVUnofficialSignaturesIndex = Get-Csv -LiteralPath (Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath 'index.tsv') -Delimiter "`t"
[string[]]$IssuesClamAV = @()
[string[]]$IssuesOther = @()
[string[]]$IssuesYARA = @()
[bool]$LocalTarget = $false
[string[]]$NetworkTargets = @()
[string]$RegExpGitHubActionsWorkspaceRoot = "$([regex]::Escape($env:GITHUB_WORKSPACE))\/"
[string[]]$RequireCleanUpFiles = @()
[UInt64]$TotalElementsAll = 0
[UInt64]$TotalElementsClamAV = 0
[UInt64]$TotalElementsYARA = 0
[UInt64]$TotalSizesAll = 0
[UInt64]$TotalSizesClamAV = 0
[UInt64]$TotalSizesYARA = 0
[string]$YARARulesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'yara-rules'
[pscustomobject[]]$YARARulesIndex = Get-Csv -LiteralPath (Join-Path -Path $YARARulesRoot -ChildPath 'index.tsv') -Delimiter "`t"
Enter-GitHubActionsLogGroup -Title 'Import inputs.'
[string]$Targets = Get-GitHubActionsInput -Name 'targets' -Trim
if ($Targets -match '^\.\/$') {
	$LocalTarget = $true
} else {
	[string[]]$TargetsInvalid = @()
	Format-InputList -InputObject $Targets | ForEach-Object -Process {
		if (Test-StringIsURL -InputObject $_) {
			$NetworkTargets += $_
		} else {
			$TargetsInvalid += $_
		}
	}
	if ($TargetsInvalid.Count -gt 0) {
		Write-GitHubActionsWarning -Message "Input ``targets`` included invalid targets ($($TargetsInvalid.Count)): $($TargetsInvalid -join ', ')"
	}
}
[bool]$GitDeep = [bool]::Parse((Get-GitHubActionsInput -Name 'git_deep' -Require -Trim))
[bool]$GitReverseSession = [bool]::Parse((Get-GitHubActionsInput -Name 'git_reversesession' -Require -Trim))
[bool]$ClamAVEnable = [bool]::Parse((Get-GitHubActionsInput -Name 'clamav_enable' -Require -Trim))
[bool]$ClamAVDaemon = [bool]::Parse((Get-GitHubActionsInput -Name 'clamav_daemon' -Require -Trim))
[string[]]$ClamAVFilesFilterList = Get-InputList -Name 'clamav_filesfilter_list'
[FilterMode]$ClamAVFilesFilterMode = Get-GitHubActionsInput -Name 'clamav_filesfilter_mode' -Require -Trim
[bool]$ClamAVMultiScan = [bool]::Parse((Get-GitHubActionsInput -Name 'clamav_multiscan' -Require -Trim))
[bool]$ClamAVReloadPerSession = [bool]::Parse((Get-GitHubActionsInput -Name 'clamav_reloadpersession' -Require -Trim))
[string[]]$ClamAVSignaturesIgnoreCustom = Get-InputList -Name 'clamav_signaturesignore_custom'
[string[]]$ClamAVSignaturesIgnorePresets = Get-InputList -Name 'clamav_signaturesignore_presets'
[bool]$ClamAVSubcursive = [bool]::Parse((Get-GitHubActionsInput -Name 'clamav_subcursive' -Require -Trim))
[string[]]$ClamAVUnofficialSignatures = Get-InputList -Name 'clamav_unofficialsignatures'
[bool]$YARAEnable = [bool]::Parse((Get-GitHubActionsInput -Name 'yara_enable' -Require -Trim))
[string[]]$YARAFilesFilterList = Get-InputList -Name 'yara_filesfilter_list'
[FilterMode]$YARAFilesFilterMode = Get-GitHubActionsInput -Name 'yara_filesfilter_mode' -Require -Trim
[string[]]$YARARulesFilterList = Get-InputList -Name 'yara_rulesfilter_list'
[FilterMode]$YARARulesFilterMode = Get-GitHubActionsInput -Name 'yara_rulesfilter_mode' -Require -Trim
[bool]$YARAToolWarning = [bool]::Parse((Get-GitHubActionsInput -Name 'yara_toolwarning' -Require -Trim))
Write-OptimizePSFormatDisplay -InputObject ([pscustomobject]@{
	Targets_List = $LocalTarget ? 'Local' : ($NetworkTargets -join ', ')
	Targets_Count = $LocalTarget ? 1 : $NetworkTargets.Count
	Git_Deep = $GitDeep
	Git_ReverseSession = $GitReverseSession
	ClamAV_Enable = $ClamAVEnable
	ClamAV_Daemon = $ClamAVDaemon
	ClamAV_FilesFilter_List = $ClamAVFilesFilterList -join ', '
	ClamAV_FilesFilter_Count = $ClamAVFilesFilterList.Count
	ClamAV_FilesFilter_Mode = $ClamAVFilesFilterMode
	ClamAV_MultiScan = $ClamAVMultiScan
	ClamAV_ReloadPerSession = $ClamAVReloadPerSession
	ClamAV_SignaturesIgnore_Custom_List = $ClamAVSignaturesIgnoreCustom -join ', '
	ClamAV_SignaturesIgnore_Custom_Count = $ClamAVSignaturesIgnoreCustom.Count
	ClamAV_SignaturesIgnore_Presets_List = $ClamAVSignaturesIgnorePresets -join ', '
	ClamAV_SignaturesIgnore_Presets_Count = $ClamAVSignaturesIgnorePresets.Count
	ClamAV_Subcursive = $ClamAVSubcursive
	YARA_Enable = $YARAEnable
	YARA_FilesFilter_List = $YARAFilesFilterList -join ', '
	YARA_FilesFilter_Count = $YARAFilesFilterList.Count
	YARA_FilesFilter_Mode = $YARAFilesFilterMode
	YARA_RulesFilter_List = $YARARulesFilterList -join ', '
	YARA_RulesFilter_Count = $YARARulesFilterList.Count
	YARA_RulesFilter_Mode = $YARARulesFilterMode
	YARA_ToolWarning = $YARAToolWarning
} | Format-List | Out-String)
Exit-GitHubActionsLogGroup
if (($LocalTarget -eq $false) -and ($NetworkTargets.Count -eq 0)) {
	Write-GitHubActionsFail -Message 'Input `targets` does not have valid target!'
}
if ($true -notin @($ClamAVEnable, $YARAEnable)) {
	Write-GitHubActionsFail -Message 'No anti virus software enable!'
}
[pscustomobject[]]$ClamAVSignaturesIgnorePresetsApply = $ClamAVSignaturesIgnorePresetsIndex | Where-Object -FilterScript {
	return Test-InputFilter -Target $_.Name -FilterList $ClamAVSignaturesIgnorePresets -FilterMode 'Include'
} | Sort-Object -Property 'Name'
[pscustomobject[]]$ClamAVUnofficialSignaturesApply = $ClamAVUnofficialSignaturesIndex | Where-Object -FilterScript {
	return Test-InputFilter -Target $_.Name -FilterList $ClamAVUnofficialSignatures -FilterMode 'Include'
} | Sort-Object -Property 'Name'
[pscustomobject[]]$YARARulesApply = $YARARulesIndex | Where-Object -FilterScript {
	return Test-InputFilter -Target $_.Name -FilterList $YARARulesFilterList -FilterMode $YARARulesFilterMode
} | Sort-Object -Property 'Name'
if ($ClamAVEnable) {
	[string[]]$ClamAVSignaturesIgnore = $ClamAVSignaturesIgnoreCustom
	[pscustomobject[]]$ClamAVSignaturesIgnorePresetsDisplay = @()
	[string[]]$ClamAVSignaturesIgnorePresetsInvalid = @()
	$ClamAVSignaturesIgnorePresetsIndex | ForEach-Object -Process {
		[string]$ClamAVSignaturesIgnorePresetFullName = Join-Path -Path $ClamAVSignaturesIgnorePresetsRoot -ChildPath $_.Location
		[bool]$ClamAVSignaturesIgnorePresetExist = Test-Path -LiteralPath $ClamAVSignaturesIgnorePresetFullName
		[bool]$ClamAVSignaturesIgnorePresetApply = $_.Name -in $ClamAVSignaturesIgnorePresetsApply.Name
		[hashtable]$ClamAVSignaturesIgnorePresetDisplay = @{
			Name = $_.Name
			Exist = $ClamAVSignaturesIgnorePresetExist
			Apply = $ClamAVSignaturesIgnorePresetApply
		}
		$ClamAVSignaturesIgnorePresetsDisplay += [pscustomobject]$ClamAVSignaturesIgnorePresetDisplay
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
		Set-Content -LiteralPath $ClamAVSignaturesIgnoreFileFullName -Value ($ClamAVSignaturesIgnore -join "`n") -Confirm:$false -NoNewline -Encoding 'UTF8NoBOM'
		$RequireCleanUpFiles += $ClamAVSignaturesIgnoreFileFullName
	}
	Exit-GitHubActionsLogGroup
	[pscustomobject[]]$ClamAVUnofficialSignaturesDisplay = @()
	[string[]]$ClamAVUnofficialSignaturesInvalid = @()
	$ClamAVUnofficialSignaturesIndex | ForEach-Object -Process {
		[string]$ClamAVUnofficialSignatureFullName = Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath $_.Location
		[bool]$ClamAVUnofficialSignatureExist = Test-Path -LiteralPath $ClamAVUnofficialSignatureFullName
		[bool]$ClamAVUnofficialSignatureApply = $_.Name -in $ClamAVUnofficialSignaturesApply.Name
		[hashtable]$ClamAVUnofficialSignatureDisplay = @{
			Name = $_.Name
			Exist = $ClamAVUnofficialSignatureExist
			Apply = $ClamAVUnofficialSignatureApply
		}
		$ClamAVUnofficialSignaturesDisplay += [pscustomobject]$ClamAVUnofficialSignatureDisplay
		if ($ClamAVUnofficialSignatureExist) {
			if ($ClamAVUnofficialSignatureApply) {
				[string]$ClamAVUnofficialSignatureDestination = Join-Path -Path $ClamAVDatabaseRoot -ChildPath ($_.Location -replace '\/', '_')
				Copy-Item -LiteralPath $ClamAVUnofficialSignatureFullName -Destination $ClamAVUnofficialSignatureDestination -Confirm:$false
				$RequireCleanUpFiles += $ClamAVUnofficialSignatureDestination
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
	[pscustomobject[]]$YARARulesDisplay = @()
	[string[]]$YARARulesInvalid = @()
	$YARARulesIndex | ForEach-Object -Process {
		[string]$YARARuleFullName = Join-Path -Path $YARARulesRoot -ChildPath $_.Location
		[bool]$YARARuleExist = Test-Path -LiteralPath $YARARuleFullName
		[bool]$YARARuleApply = $_.Name -in $YARARulesApply.Name
		[hashtable]$YARARuleDisplay = @{
			Name = $_.Name
			Exist = $YARARuleExist
			Apply = $YARARuleApply
		}
		$YARARulesDisplay += [pscustomobject]$YARARuleDisplay
		if ($YARARuleExist -eq $false) {
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
		[Parameter(Mandatory = $true, Position = 0)][string]$Session
	)
	Write-Host -Object "Begin of session `"$Session`"."
	[pscustomobject[]]$Elements = Get-ChildItem -LiteralPath $env:GITHUB_WORKSPACE -Recurse -Force
	if (
		($null -eq $Elements) -or
		($Elements.Count -eq 0)
	) {
		Write-GitHubActionsError -Message "Unable to scan session `"$Session`" due to it is empty! If this is incorrect, probably someone forgot to put files in there."
		if ($Session -notin $script:IssuesOther) {
			$script:IssuesOther += $Session
		}
	} else {
		[string[]]$ElementsListClamAV = @()
		[string[]]$ElementsListYARA = @()
		[pscustomobject[]]$ElementsListDisplay = @()
		[uint]$ElementsIsDirectoryCount = 0
		$Elements | Sort-Object | ForEach-Object -Process {
			[bool]$ElementIsDirectory = Test-Path -LiteralPath $_.FullName -PathType 'Container'
			[string]$ElementName = $_.FullName -replace "^$RegExpGitHubActionsWorkspaceRoot", ''
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
				($ElementIsDirectory -eq $false)
			) -and (
				($LocalTarget -eq $false) -or
				(Test-InputFilter -Target $ElementName -FilterList $ClamAVFilesFilterList -FilterMode $ClamAVFilesFilterMode)
			)) {
				$ElementsListClamAV += $_.FullName
				$ElementListDisplay.Flags += 'C'
				if ($ElementIsDirectory -eq $false) {
					$script:TotalSizesClamAV += $ElementSizes
				}
			}
			if ($YARAEnable -and ($ElementIsDirectory -eq $false) -and (
				($LocalTarget -eq $false) -or
				(Test-InputFilter -Target $ElementName -FilterList $YARAFilesFilterList -FilterMode $YARAFilesFilterMode)
			)) {
				$ElementsListYARA += $_.FullName
				$ElementListDisplay.Flags += 'Y'
				$script:TotalSizesYARA += $ElementSizes
			}
			$ElementListDisplay.Flags = ($ElementListDisplay.Flags | Sort-Object) -join ''
			$ElementsListDisplay += [pscustomobject]$ElementListDisplay
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
			[string]$ElementsListClamAVFullName = (New-TemporaryFile).FullName
			Set-Content -LiteralPath $ElementsListClamAVFullName -Value ($ElementsListClamAV -join "`n") -Confirm:$false -NoNewline -Encoding 'UTF8NoBOM'
			Enter-GitHubActionsLogGroup -Title "ClamAV result of session `"$Session`":"
			[string]$ClamAVExpression = ''
			if ($ClamAVDaemon) {
				$ClamAVExpression = "clamdscan --fdpass --file-list=`"$ElementsListClamAVFullName`"$($ClamAVMultiScan ? ' --multiscan' : '')$($ClamAVReloadPerSession ? ' --reload' : '')"
			} else {
				$ClamAVExpression = "clamscan --detect-broken=yes --file-list=`"$ElementsListClamAVFullName`" --follow-dir-symlinks=0 --follow-file-symlinks=0 --recursive"
			}
			[string[]]$ClamAVOutput = Invoke-Expression -Command $ClamAVExpression
			[uint]$ClamAVExitCode = $LASTEXITCODE
			[string[]]$ClamAVResultError = @()
			[hashtable]$ClamAVResultFound = @{}
			for ($ClamAVOutputLineIndex = 0; $ClamAVOutputLineIndex -lt $ClamAVOutput.Count; $ClamAVOutputLineIndex++) {
				[string]$ClamAVOutputLineContent = $ClamAVOutput[$ClamAVOutputLineIndex] -replace "^$RegExpGitHubActionsWorkspaceRoot", ''
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
					[string]$ClamAVElementIssue = $ClamAVOutputLineContent -replace ' FOUND$', ''
					Write-GitHubActionsDebug -Message $ClamAVElementIssue
					[string]$Element, [string]$Signature = $ClamAVElementIssue -split '(?<=^.+?): '
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
					[string[]]$IssueSignatures = $_.Value | Sort-Object -Unique -CaseSensitive
					return [pscustomobject]@{
						Element = $_.Name
						Signatures_List = $IssueSignatures -join ', '
						Signatures_Count = $IssueSignatures.Count
					}
				} | Sort-Object -Property 'Element' | Format-List | Out-String))"
				if ($Session -notin $script:IssuesClamAV) {
					$script:IssuesClamAV += $Session
				}
			}
			if ($ClamAVResultError.Count -gt 0) {
				Write-GitHubActionsError -Message "Unexpected ClamAV result ``$ClamAVExitCode`` in session `"$Session`":`n$($ClamAVResultError -join "`n")"
				if ($Session -notin $script:IssuesClamAV) {
					$script:IssuesClamAV += $Session
				}
			}
			Exit-GitHubActionsLogGroup
			Remove-Item -LiteralPath $ElementsListClamAVFullName -Force -Confirm:$false
		}
		if ($YARAEnable -and ($ElementsListYARA.Count -gt 0)) {
			[string]$ElementsListYARAFullName = (New-TemporaryFile).FullName
			Set-Content -LiteralPath $ElementsListYARAFullName -Value ($ElementsListYARA -join "`n") -Confirm:$false -NoNewline -Encoding 'UTF8NoBOM'
			Enter-GitHubActionsLogGroup -Title "YARA result of session `"$Session`":"
			[hashtable]$YARAResult = @{}
			foreach ($YARARule in $YARARulesApply) {
				[string[]]$YARAOutput = Invoke-Expression -Command "yara --scan-list$($YARAToolWarning ? '' : ' --no-warnings') `"$(Join-Path -Path $YARARulesRoot -ChildPath $YARARule.Location)`" `"$ElementsListYARAFullName`""
				if ($LASTEXITCODE -eq 0) {
					$YARAOutput | ForEach-Object -Process {
						if ($_ -match "^.+? $RegExpGitHubActionsWorkspaceRoot.+$") {
							[string]$Rule, [string]$IssueElement = $_ -split "(?<=^.+?) $RegExpGitHubActionsWorkspaceRoot"
							[string]$YARARuleName = "$($YARARule.Name)/$Rule"
							[string]$YARAElementIssue = "$YARARuleName>$IssueElement"
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
					if ($Session -notin $script:IssuesYARA) {
						$script:IssuesYARA += $Session
					}
				}
			}
			if ($YARAResult.Count -gt 0) {
				Write-GitHubActionsError -Message "Found issues in session `"$Session`" via YARA ($($YARAResult.Count)):`n$(Optimize-PSFormatDisplay -InputObject ($YARAResult.GetEnumerator() | ForEach-Object -Process {
					[string[]]$IssueRules = $_.Value | Sort-Object -Unique -CaseSensitive
					return [pscustomobject]@{
						Element = $_.Name
						Rules_List = $IssueRules -join ', '
						Rules_Count = $IssueRules.Count
					}
				} | Sort-Object -Property 'Element' | Format-List | Out-String))"
				if ($Session -notin $script:IssuesYARA) {
					$script:IssuesYARA += $Session
				}
			}
			Exit-GitHubActionsLogGroup
			Remove-Item -LiteralPath $ElementsListYARAFullName -Force -Confirm:$false
		}
	}
	Write-Host -Object "End of session `"$Session`"."
}
if ($LocalTarget) {
	Invoke-ScanVirusSession -Session 'Current'
	if ($GitDeep) {
		if (Test-Path -LiteralPath (Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath '.git') -PathType 'Container') {
			Write-Host -Object 'Import Git information.'
			[string[]]$GitCommits = [string[]](Invoke-Expression -Command "git --no-pager log --all --format=%H$($GitReverseSession ? '' : ' --reverse')") | Select-Object -Unique
			if ($GitCommits.Count -le 1) {
				Write-GitHubActionsWarning -Message "Current Git repository has only $($GitCommits.Count) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run ________`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex++) {
				[string]$GitCommitHash = $GitCommits[$GitCommitsIndex]
				[string]$GitSession = "Commit Hash $GitCommitHash (#$($GitReverseSession ? ($GitCommits.Count - $GitCommitsIndex) : ($GitCommitsIndex + 1))/$($GitCommits.Count))"
				Enter-GitHubActionsLogGroup -Title "Git checkout for session `"$GitSession`"."
				try {
					Invoke-Expression -Command "git checkout $GitCommitHash --force --quiet"
				} catch {  }
				if ($LASTEXITCODE -eq 0) {
					Exit-GitHubActionsLogGroup
					Invoke-ScanVirusSession -Session $GitSession
				} else {
					Write-GitHubActionsError -Message "Unexpected Git checkout result ``$LASTEXITCODE`` in session `"$GitSession`"!"
					if ($GitSession -notin $IssuesOther) {
						$IssuesOther += $GitSession
					}
					Exit-GitHubActionsLogGroup
				}
			}
		} else {
			Write-GitHubActionsWarning -Message 'Unable to scan deeper due to it is not a Git repository! If this is incorrect, probably Git data is broken and/or invalid.'
		}
	}
} else {
	[pscustomobject[]]$UselessElements = Get-ChildItem -LiteralPath $env:GITHUB_WORKSPACE -Recurse -Force
	if ($UselessElements.Count -gt 0) {
		Write-GitHubActionsWarning -Message 'Require a clean workspace when target is network!'
		Write-Host -Object 'Clean workspace.'
		$UselessElements | Remove-Item -Force -Confirm:$false
	}
	$NetworkTargets | ForEach-Object -Process {
		Enter-GitHubActionsLogGroup -Title "Fetch file `"$_`"."
		[string]$NetworkTemporaryFileFullPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath (New-Guid).Guid
		try {
			Invoke-WebRequest -Uri $_ -UseBasicParsing -Method Get -OutFile $NetworkTemporaryFileFullPath
		} catch {
			Write-GitHubActionsError -Message "Unable to fetch file `"$_`"!"
			continue
		}
		Exit-GitHubActionsLogGroup
		Invoke-ScanVirusSession -Session $_
		Remove-Item -LiteralPath $NetworkTemporaryFileFullPath -Force -Confirm:$false
	}
}
if ($ClamAVEnable -and $ClamAVDaemon) {
	Enter-GitHubActionsLogGroup -Title 'Stop ClamAV daemon.'
	Get-Process -Name '*clamd*' | Stop-Process
	Exit-GitHubActionsLogGroup
}
if ($RequireCleanUpFiles.Count -gt 0) {
	$RequireCleanUpFiles | ForEach-Object -Process {
		Remove-Item -LiteralPath $_ -Force -Confirm:$false
	}
}
Enter-GitHubActionsLogGroup -Title 'Statistics:'
[UInt64]$TotalIssues = $IssuesClamAV.Count + $IssuesOther.Count + $IssuesYARA.Count
Write-OptimizePSFormatDisplay -InputObject ([pscustomobject[]]@(
	[pscustomobject]@{
		Name = 'TotalElements_Count'
		All = $TotalElementsAll
		ClamAV = $TotalElementsClamAV
		YARA = $TotalElementsYARA
	},
	[pscustomobject]@{
		Name = 'TotalElements_Percentage'
		ClamAV = ($TotalElementsAll -eq 0) ? 0 : ($TotalElementsClamAV / $TotalElementsAll * 100)
		YARA = ($TotalElementsAll -eq 0) ? 0 : ($TotalElementsYARA / $TotalElementsAll * 100)
	},
	[pscustomobject]@{
		Name = 'TotalIssuesSessions_Count'
		All = $TotalIssues
		ClamAV = $IssuesClamAV.Count
		YARA = $IssuesYARA.Count
		Other = $IssuesOther.Count
	},
	[pscustomobject]@{
		Name = 'TotalIssuesSessions_Percentage'
		ClamAV = ($TotalIssues -eq 0) ? 0 : ($IssuesClamAV.Count / $TotalIssues * 100)
		YARA = ($TotalIssues -eq 0) ? 0 : ($IssuesYARA.Count / $TotalIssues * 100)
		Other = ($TotalIssues -eq 0) ? 0 : ($IssuesOther.Count / $TotalIssues * 100)
	},
	[pscustomobject]@{
		Name = 'TotalSizes_B'
		All = $TotalSizesAll
		ClamAV = $TotalSizesClamAV
		YARA = $TotalSizesYARA
	},
	[pscustomobject]@{
		Name = 'TotalSizes_KB'
		All = $TotalSizesAll / 1KB
		ClamAV = $TotalSizesClamAV / 1KB
		YARA = $TotalSizesYARA / 1KB
	},
	[pscustomobject]@{
		Name = 'TotalSizes_MB'
		All = $TotalSizesAll / 1MB
		ClamAV = $TotalSizesClamAV / 1MB
		YARA = $TotalSizesYARA / 1MB
	},
	[pscustomobject]@{
		Name = 'TotalSizes_GB'
		All = $TotalSizesAll / 1GB
		ClamAV = $TotalSizesClamAV / 1GB
		YARA = $TotalSizesYARA / 1GB
	},
	[pscustomobject]@{
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
	Write-OptimizePSFormatDisplay -InputObject ([pscustomobject]@{
		ClamAV = $IssuesClamAV -join ', '
		YARA = $IssuesYARA -join ', '
		Other = $IssuesOther -join ', '
	} | Format-List | Out-String)
	Exit-GitHubActionsLogGroup
}
$ErrorActionPreference = $ErrorActionOriginalPreference
if ($TotalIssues -gt 0) {
	exit 1
}
exit 0
