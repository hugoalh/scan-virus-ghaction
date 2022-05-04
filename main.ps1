[string]$ErrorActionOriginalPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'get-csv.psm1') -Scope 'Local'
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
	return [string[]]($InputObject -split ";|\r?\n") | ForEach-Object -Process { return $_.Trim() } | Where-Object -FilterScript { return ($_.Length -gt 0) } | Sort-Object -Unique -CaseSensitive
}
function Get-InputList {
	[CmdletBinding()][OutputType([string[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Name
	)
	return Format-InputList -InputObject (Get-GHActionsInput -Name $Name -Trim)
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
function Test-StringIsURL {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	$URIObject = $InputObject -as [System.URI]
	return (($null -ne $URIObject.AbsoluteURI) -and ($InputObject -match '^https?:\/\/'))
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
[pscustomobject[]]$ClamAVSignaturesIgnorePresetsIndex = Get-Csv -Path (Join-Path -Path $ClamAVSignaturesIgnorePresetsRoot -ChildPath 'index.tsv') -Delimiter "`t"
[string]$ClamAVUnofficialSignaturesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'clamav-unofficial-signatures'
[pscustomobject[]]$ClamAVUnofficialSignaturesIndex = Get-Csv -Path (Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath 'index.tsv') -Delimiter "`t"
[string[]]$IssuesClamAV = @()
[string[]]$IssuesOther = @()
[string[]]$IssuesYARA = @()
[bool]$LocalTarget = $false
[string[]]$NetworkTargets = @()
[string]$RegExpGHActionsWorkspaceRoot = "$([regex]::Escape($env:GITHUB_WORKSPACE))\/"
[string[]]$RequireCleanUpFiles = @()
[UInt64]$TotalElementsAll = 0
[UInt64]$TotalElementsClamAV = 0
[UInt64]$TotalElementsYARA = 0
[UInt64]$TotalSizesAll = 0
[UInt64]$TotalSizesClamAV = 0
[UInt64]$TotalSizesYARA = 0
[string]$YARARulesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'yara-rules'
[pscustomobject[]]$YARARulesIndex = Get-Csv -Path (Join-Path -Path $YARARulesRoot -ChildPath 'index.tsv') -Delimiter "`t"
Enter-GHActionsLogGroup -Title 'Import inputs.'
[string]$Targets = Get-GHActionsInput -Name 'targets' -Trim
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
		Write-GHActionsWarning -Message "Input ``targets`` included invalid targets ($($TargetsInvalid.Count)): $($TargetsInvalid -join ', ')"
	}
}
[bool]$GitDeep = [bool]::Parse((Get-GHActionsInput -Name 'git_deep' -Require -Trim))
[bool]$GitReverseSession = [bool]::Parse((Get-GHActionsInput -Name 'git_reversesession' -Require -Trim))
[bool]$ClamAVEnable = [bool]::Parse((Get-GHActionsInput -Name 'clamav_enable' -Require -Trim))
[bool]$ClamAVDaemon = [bool]::Parse((Get-GHActionsInput -Name 'clamav_daemon' -Require -Trim))
[string[]]$ClamAVFilesFilterList = Get-InputList -Name 'clamav_filesfilter_list'
[FilterMode]$ClamAVFilesFilterMode = Get-GHActionsInput -Name 'clamav_filesfilter_mode' -Require -Trim
[bool]$ClamAVMultiScan = [bool]::Parse((Get-GHActionsInput -Name 'clamav_multiscan' -Require -Trim))
[bool]$ClamAVReloadPerSession = [bool]::Parse((Get-GHActionsInput -Name 'clamav_reloadpersession' -Require -Trim))
[string[]]$ClamAVSignaturesIgnoreCustom = Get-InputList -Name 'clamav_signaturesignore_custom'
[string[]]$ClamAVSignaturesIgnorePresets = Get-InputList -Name 'clamav_signaturesignore_presets'
[bool]$ClamAVSubcursive = [bool]::Parse((Get-GHActionsInput -Name 'clamav_subcursive' -Require -Trim))
[string[]]$ClamAVUnofficialSignatures = Get-InputList -Name 'clamav_unofficialsignatures'
[bool]$YARAEnable = [bool]::Parse((Get-GHActionsInput -Name 'yara_enable' -Require -Trim))
[string[]]$YARAFilesFilterList = Get-InputList -Name 'yara_filesfilter_list'
[FilterMode]$YARAFilesFilterMode = Get-GHActionsInput -Name 'yara_filesfilter_mode' -Require -Trim
[string[]]$YARARulesFilterList = Get-InputList -Name 'yara_rulesfilter_list'
[FilterMode]$YARARulesFilterMode = Get-GHActionsInput -Name 'yara_rulesfilter_mode' -Require -Trim
[bool]$YARAToolWarning = [bool]::Parse((Get-GHActionsInput -Name 'yara_toolwarning' -Require -Trim))
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
Exit-GHActionsLogGroup
if (($LocalTarget -eq $false) -and ($NetworkTargets.Count -eq 0)) {
	Write-GHActionsFail -Message 'Input `targets` does not have valid target!'
}
if ($true -notin @($ClamAVEnable, $YARAEnable)) {
	Write-GHActionsFail -Message 'No anti virus software enable!'
}
[pscustomobject[]]$ClamAVSignaturesIgnorePresetsApply = $ClamAVSignaturesIgnorePresetsIndex | Where-Object -FilterScript { Test-InputFilter -Target $_.Name -FilterList $ClamAVSignaturesIgnorePresets -FilterMode 'Include' } | Sort-Object -Property 'Name'
[pscustomobject[]]$ClamAVUnofficialSignaturesApply = $ClamAVUnofficialSignaturesIndex | Where-Object -FilterScript { Test-InputFilter -Target $_.Name -FilterList $ClamAVUnofficialSignatures -FilterMode 'Include' } | Sort-Object -Property 'Name'
[pscustomobject[]]$YARARulesApply = $YARARulesIndex | Where-Object -FilterScript { Test-InputFilter -Target $_.Name -FilterList $YARARulesFilterList -FilterMode $YARARulesFilterMode } | Sort-Object -Property 'Name'
if ($ClamAVEnable) {
	[string[]]$ClamAVSignaturesIgnore = $ClamAVSignaturesIgnoreCustom
	[pscustomobject[]]$ClamAVSignaturesIgnorePresetsDisplay = @()
	[string[]]$ClamAVSignaturesIgnorePresetsInvalid = @()
	$ClamAVSignaturesIgnorePresetsIndex | ForEach-Object -Process {
		[string]$ClamAVSignaturesIgnorePresetFullName = Join-Path -Path $ClamAVSignaturesIgnorePresetsRoot -ChildPath $_.Location
		[bool]$ClamAVSignaturesIgnorePresetExist = Test-Path -Path $ClamAVSignaturesIgnorePresetFullName
		[bool]$ClamAVSignaturesIgnorePresetApply = $_.Name -in $ClamAVSignaturesIgnorePresetsApply.Name
		[hashtable]$ClamAVSignaturesIgnorePresetDisplay = @{
			Name = $_.Name
			Exist = $ClamAVSignaturesIgnorePresetExist
			Apply = $ClamAVSignaturesIgnorePresetApply
		}
		$ClamAVSignaturesIgnorePresetsDisplay += [pscustomobject]$ClamAVSignaturesIgnorePresetDisplay
		if ($ClamAVSignaturesIgnorePresetExist) {
			if ($ClamAVSignaturesIgnorePresetApply) {
				$ClamAVSignaturesIgnore += Get-Content -Path $ClamAVSignaturesIgnorePresetFullName -Encoding UTF8NoBOM
			}
		} else {
			$ClamAVSignaturesIgnorePresetsInvalid += $_.Name
		}
	}
	Enter-GHActionsLogGroup -Title "ClamAV signatures ignore presets index (I: $($ClamAVSignaturesIgnorePresetsIndex.Count); A: $($ClamAVSignaturesIgnorePresetsApply.Count); S: $($ClamAVSignaturesIgnorePresetsApply.Count - $ClamAVSignaturesIgnorePresetsInvalid.Count)):"
	if ($ClamAVSignaturesIgnorePresetsInvalid.Count -gt 0) {
		Write-GHActionsWarning -Message "Some of the ClamAV signatures ignore presets are indexed but not exist ($($ClamAVSignaturesIgnorePresetsInvalid.Count)): $($ClamAVSignaturesIgnorePresetsInvalid -join ', ')"
	}
	Write-OptimizePSFormatDisplay -InputObject ($ClamAVSignaturesIgnorePresetsDisplay | Format-Table -Property @(
		'Name',
		@{ Expression = 'Exist'; Alignment = 'Right' },
		@{ Expression = 'Apply'; Alignment = 'Right' }
	) -AutoSize -Wrap | Out-String)
	Exit-GHActionsLogGroup
	$ClamAVSignaturesIgnore = $ClamAVSignaturesIgnore | ForEach-Object -Process { return $_.Trim() } | Where-Object -FilterScript { return ($_.Length -gt 0) } | Sort-Object -Unique -CaseSensitive
	Enter-GHActionsLogGroup -Title "ClamAV signatures ignore ($($ClamAVSignaturesIgnore.Count)):"
	if ($ClamAVSignaturesIgnore.Count -gt 0) {
		Write-Host -Object ($ClamAVSignaturesIgnore -join ', ')
		Set-Content -Path $ClamAVSignaturesIgnoreFileFullName -Value ($ClamAVSignaturesIgnore -join "`n") -NoNewline -Encoding UTF8NoBOM
		$RequireCleanUpFiles += $ClamAVSignaturesIgnoreFileFullName
	}
	Exit-GHActionsLogGroup
	[pscustomobject[]]$ClamAVUnofficialSignaturesDisplay = @()
	[string[]]$ClamAVUnofficialSignaturesInvalid = @()
	$ClamAVUnofficialSignaturesIndex | ForEach-Object -Process {
		[string]$ClamAVUnofficialSignatureFullName = Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath $_.Location
		[bool]$ClamAVUnofficialSignatureExist = Test-Path -Path $ClamAVUnofficialSignatureFullName
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
				Copy-Item -Path $ClamAVUnofficialSignatureFullName -Destination $ClamAVUnofficialSignatureDestination -Confirm:$false
				$RequireCleanUpFiles += $ClamAVUnofficialSignatureDestination
			}
		} else {
			$ClamAVUnofficialSignaturesInvalid += $_.Name
		}
	}
	Enter-GHActionsLogGroup -Title "ClamAV unofficial signatures index (I: $($ClamAVUnofficialSignaturesIndex.Count); A: $($ClamAVUnofficialSignaturesApply.Count); S: $($ClamAVUnofficialSignaturesApply.Count - $ClamAVUnofficialSignaturesInvalid.Count)):"
	if ($ClamAVUnofficialSignaturesInvalid.Count -gt 0) {
		Write-GHActionsWarning -Message "Some of the ClamAV unofficial signatures are indexed but not exist ($($ClamAVUnofficialSignaturesInvalid.Count)): $($ClamAVUnofficialSignaturesInvalid -join ', ')"
	}
	Write-OptimizePSFormatDisplay -InputObject ($ClamAVUnofficialSignaturesDisplay | Format-Table -Property @(
		'Name',
		@{ Expression = 'Exist'; Alignment = 'Right' },
		@{ Expression = 'Apply'; Alignment = 'Right' }
	) -AutoSize -Wrap | Out-String)
	Exit-GHActionsLogGroup
}
if ($YARAEnable) {
	[pscustomobject[]]$YARARulesDisplay = @()
	[string[]]$YARARulesInvalid = @()
	$YARARulesIndex | ForEach-Object -Process {
		[string]$YARARuleFullName = Join-Path -Path $YARARulesRoot -ChildPath $_.Location
		[bool]$YARARuleExist = Test-Path -Path $YARARuleFullName
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
	Enter-GHActionsLogGroup -Title "YARA rules index (I: $($YARARulesIndex.Count); A: $($YARARulesApply.Count); S: $($YARARulesApply.Count - $YARARulesInvalid.Count)):"
	if ($YARARulesInvalid.Count -gt 0) {
		Write-GHActionsWarning -Message "Some of the YARA rules are indexed but not exist ($($YARARulesInvalid.Count)): $($YARARulesInvalid -join ', ')"
	}
	Write-OptimizePSFormatDisplay -InputObject ($YARARulesDisplay | Format-Table -Property @(
		'Name',
		@{ Expression = 'Exist'; Alignment = 'Right' },
		@{ Expression = 'Apply'; Alignment = 'Right' }
	) -AutoSize -Wrap | Out-String)
	Exit-GHActionsLogGroup
}
Enter-GHActionsLogGroup -Title 'Update software.'
try {
	Invoke-Expression -Command 'apt-get --assume-yes update'
	Invoke-Expression -Command 'apt-get --assume-yes upgrade'
} catch {  }
Exit-GHActionsLogGroup
if ($ClamAVEnable) {
	Enter-GHActionsLogGroup -Title 'Update ClamAV via FreshClam.'
	try {
		Invoke-Expression -Command 'freshclam'
	} catch {  }
	Exit-GHActionsLogGroup
	if ($ClamAVDaemon) {
		Enter-GHActionsLogGroup -Title 'Start ClamAV daemon.'
		Invoke-Expression -Command 'clamd'
		Exit-GHActionsLogGroup
	}
}
function Invoke-ScanVirusSession {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Session
	)
	Write-Host -Object "Begin of session `"$Session`"."
	[pscustomobject[]]$Elements = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Recurse -Force
	if (
		($null -eq $Elements) -or
		($Elements.Count -eq 0)
	) {
		Write-GHActionsError -Message "Unable to scan session `"$Session`" due to it is empty! If this is incorrect, probably someone forgot to put files in there."
		$script:IssuesOther += $Session
	} else {
		[string[]]$ElementsListClamAV = @()
		[string[]]$ElementsListYARA = @()
		[pscustomobject[]]$ElementsListDisplay = @()
		[uint]$ElementsIsDirectoryCount = 0
		$Elements | Sort-Object | ForEach-Object -Process {
			[bool]$ElementIsDirectory = Test-Path -Path $_.FullName -PathType Container
			[string]$ElementName = $_.FullName -replace "^$RegExpGHActionsWorkspaceRoot", ''
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
		Enter-GHActionsLogGroup -Title "Elements of session `"$Session`" (E: $($Elements.Count); FC: $($ElementsListClamAV.Count); FD: $ElementsIsDirectoryCount; FY: $($ElementsListYARA.Count)):"
		Write-OptimizePSFormatDisplay -InputObject ($ElementsListDisplay | Format-Table -Property @(
			'Element',
			'Flags',
			@{ Expression = 'Sizes'; Alignment = 'Right' }
		) -AutoSize -Wrap | Out-String)
		Exit-GHActionsLogGroup
		if ($ClamAVEnable -and ($ElementsListClamAV.Count -gt 0)) {
			[string]$ElementsListClamAVFullName = (New-TemporaryFile).FullName
			Set-Content -Path $ElementsListClamAVFullName -Value ($ElementsListClamAV -join "`n") -NoNewline -Encoding UTF8NoBOM
			Enter-GHActionsLogGroup -Title "ClamAV result of session `"$Session`":"
			[string]$ClamAVExpression = ''
			if ($ClamAVDaemon) {
				$ClamAVExpression = "clamdscan --fdpass --file-list=`"$ElementsListClamAVFullName`"$($ClamAVMultiScan ? ' --multiscan' : '')$($ClamAVReloadPerSession ? ' --reload' : '')"
			} else {
				$ClamAVExpression = "clamscan --detect-broken=yes --file-list=`"$ElementsListClamAVFullName`" --follow-dir-symlinks=0 --follow-file-symlinks=0 --recursive"
			}
			[string[]]$ClamAVOutput = Invoke-Expression -Command $ClamAVExpression
			[uint]$ClamAVExitCode = $LASTEXITCODE
			[string[]]$ClamAVResultErrorRaw = @()
			[string[]]$ClamAVResultFoundRaw = @()
			for ($ClamAVOutputLineIndex = 0; $ClamAVOutputLineIndex -lt $ClamAVOutput.Count; $ClamAVOutputLineIndex++) {
				[string]$ClamAVOutputLineContent = $ClamAVOutput[$ClamAVOutputLineIndex]
				if ($ClamAVOutputLineContent -cmatch '^\s*[-=]+ SCAN SUMMARY [-=]+\s*$') {
					Write-Host -Object ($ClamAVOutput[$ClamAVOutputLineIndex..($ClamAVOutput.Count - 1)] -join "`n")
					break
				}
				if (
					($ClamAVOutputLineContent -cmatch ': OK$') -or
					($ClamAVOutputLineContent -match '^\s*$')
				) {
					continue
				}
				if ($ClamAVOutputLineContent -cmatch ': .+ FOUND$') {
					$ClamAVResultFoundRaw += $ClamAVOutputLineContent -replace "^\s*$RegExpGHActionsWorkspaceRoot", ''
				} else {
					$ClamAVResultErrorRaw += $ClamAVOutputLineContent -replace "^\s*$RegExpGHActionsWorkspaceRoot", ''
				}
			}
			[string]$ClamAVResultError = $ClamAVResultErrorRaw -join "`n"
			[string]$ClamAVResultFound = ($ClamAVResultFoundRaw | Sort-Object -Unique -CaseSensitive) -join "`n"
			if (
				($ClamAVExitCode -eq 1) -or
				($ClamAVResultFound.Length -gt 0)
			) {
				Write-GHActionsError -Message "Found issues in session `"$Session`" via ClamAV:$(($ClamAVResultError.Length -gt 0) ? "`n$ClamAVResultError" : '')`n$ClamAVResultFound"
				$script:IssuesClamAV += $Session
			} elseif (
				($ClamAVExitCode -gt 1) -or
				($ClamAVResultError.Length -gt 0)
			) {
				Write-GHActionsError -Message "Unexpected ClamAV result ``$ClamAVExitCode`` in session `"$Session`":`n$ClamAVResultError$(($ClamAVResultFound.Length -gt 0) ? "`n$ClamAVResultFound" : '')"
				$script:IssuesClamAV += $Session
			}
			Exit-GHActionsLogGroup
			Remove-Item -Path $ElementsListClamAVFullName -Force -Confirm:$false
		}
		if ($YARAEnable -and ($ElementsListYARA.Count -gt 0)) {
			[string]$ElementsListYARAFullName = (New-TemporaryFile).FullName
			Set-Content -Path $ElementsListYARAFullName -Value ($ElementsListYARA -join "`n") -NoNewline -Encoding UTF8NoBOM
			Enter-GHActionsLogGroup -Title "YARA result of session `"$Session`":"
			[hashtable]$YARAResult = @{}
			foreach ($YARARule in $YARARulesApply) {
				[string[]]$YARAOutput = Invoke-Expression -Command "yara --scan-list$($YARAToolWarning ? '' : ' --no-warnings') `"$(Join-Path -Path $YARARulesRoot -ChildPath $YARARule.Location)`" `"$ElementsListYARAFullName`""
				if ($LASTEXITCODE -eq 0) {
					$YARAOutput | ForEach-Object -Process {
						if ($_ -match "^.+? $RegExpGHActionsWorkspaceRoot.+$") {
							[string]$Rule, [string]$Element = $_ -split "(?<=^.+?) $RegExpGHActionsWorkspaceRoot"
							[string]$YARARuleName = "$($YARARule.Name)/$Rule"
							Write-GHActionsDebug -Message "$YARARuleName>$Element"
							if ((Test-InputFilter -Target "$YARARuleName>$Element" -FilterList $YARARulesFilterList -FilterMode $YARARulesFilterMode) -eq $false) {
								Write-GHActionsDebug -Message '  > Skip'
							} else {
								if ($null -eq $YARAResult[$Element]) {
									$YARAResult[$Element] = @()
								}
								$YARAResult[$Element] += $YARARuleName
							}
						} elseif ($_.Length -gt 0) {
							Write-Host -Object $_
						}
					}
				} else {
					Write-GHActionsError -Message "Unexpected YARA `"$($YARARule.Name)`" result ``$LASTEXITCODE`` in session `"$Session`"!`n$YARAOutput"
					$script:IssuesYARA += $Session
				}
			}
			if ($YARAResult.Count -gt 0) {
				Write-GHActionsError -Message "Found issues in session `"$Session`" via YARA:`n$(Optimize-PSFormatDisplay -InputObject ($YARAResult.GetEnumerator() | ForEach-Object -Process {
					[string[]]$ElementRules = $_.Value | Sort-Object -Unique -CaseSensitive
					return [pscustomobject]@{
						Element = $_.Name
						Rules_List = $ElementRules -join ', '
						Rules_Count = $ElementRules.Count
					}
				} | Sort-Object -Property 'Element' | Format-List | Out-String))"
				$script:IssuesYARA += $Session
			}
			Exit-GHActionsLogGroup
			Remove-Item -Path $ElementsListYARAFullName -Force -Confirm:$false
		}
	}
	Write-Host -Object "End of session `"$Session`"."
}
if ($LocalTarget) {
	Invoke-ScanVirusSession -Session 'Current'
	if ($GitDeep) {
		if (Test-Path -Path '.\.git') {
			Write-Host -Object 'Import Git information.'
			[string[]]$GitCommits = [string[]](Invoke-Expression -Command "git --no-pager log --all --format=`"%aI %cI %H`"$($GitReverseSession ? '' : ' --reverse')") | Select-Object -Unique
			if ($GitCommits.Count -le 1) {
				Write-GHActionsWarning -Message "Current Git repository has only $($GitCommits.Count) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run ________`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex++) {
				[datetime]$GitCommitAuthorTimestamp, [datetime]$GitCommitCommitterTimestamp, [string]$GitCommitHash = $GitCommits[$GitCommitsIndex] -split ' '
				[string]$GitSession = "Commit $GitCommitHash (#$($GitReverseSession ? ($GitCommits.Count - $GitCommitsIndex) : ($GitCommitsIndex + 1))/$($GitCommits.Count))"
				Enter-GHActionsLogGroup -Title "Git checkout for session `"$GitSession`"."
				try {
					Invoke-Expression -Command "git checkout $GitCommitHash --force --quiet"
				} catch {  }
				if ($LASTEXITCODE -eq 0) {
					Exit-GHActionsLogGroup
					Invoke-ScanVirusSession -Session $GitSession
				} else {
					Write-GHActionsError -Message "Unexpected Git checkout result ``$LASTEXITCODE`` in session `"$GitSession`"!"
					$IssuesOther += $GitSession
					Exit-GHActionsLogGroup
				}
			}
		} else {
			Write-GHActionsWarning -Message 'Unable to scan deeper due to it is not a Git repository! If this is incorrect, probably Git data is broken and/or invalid.'
		}
	}
} else {
	[string[]]$UselessElements = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Force -Name
	if ($UselessElements.Count -gt 0) {
		Write-GHActionsWarning -Message 'Require a clean workspace when target is network!'
		Write-Host -Object 'Clean workspace.'
		$UselessElements | ForEach-Object -Process {
			Remove-Item -Path (Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $_) -Recurse -Force -Confirm:$false
		}
	}
	$NetworkTargets | ForEach-Object -Process {
		Enter-GHActionsLogGroup -Title "Fetch file `"$_`"."
		[string]$NetworkTemporaryFileFullPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath (New-Guid).Guid
		try {
			Invoke-WebRequest -Uri $_ -UseBasicParsing -Method Get -OutFile $NetworkTemporaryFileFullPath
		} catch {
			Write-GHActionsError -Message "Unable to fetch file `"$_`"!"
			continue
		}
		Exit-GHActionsLogGroup
		Invoke-ScanVirusSession -Session $_
		Remove-Item -Path $NetworkTemporaryFileFullPath -Force -Confirm:$false
	}
}
if ($ClamAVEnable -and $ClamAVDaemon) {
	Enter-GHActionsLogGroup -Title 'Stop ClamAV daemon.'
	Get-Process -Name '*clamd*' | Stop-Process
	Exit-GHActionsLogGroup
}
if ($RequireCleanUpFiles.Count -gt 0) {
	$RequireCleanUpFiles | ForEach-Object -Process {
		Remove-Item -Path $_ -Force -Confirm:$false
	}
}
Enter-GHActionsLogGroup -Title "Statistics:"
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
		Name = 'TotalIssues_Count'
		All = $TotalIssues
		ClamAV = $IssuesClamAV.Count
		YARA = $IssuesYARA.Count
		Other = $IssuesOther.Count
	},
	[pscustomobject]@{
		Name = 'TotalIssues_Percentage'
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
Exit-GHActionsLogGroup
if ($TotalIssues -gt 0) {
	Enter-GHActionsLogGroup -Title "Issues:"
	Write-OptimizePSFormatDisplay -InputObject ([pscustomobject]@{
		ClamAV = $IssuesClamAV -join ', '
		YARA = $IssuesYARA -join ', '
		Other = $IssuesOther -join ', '
	} | Format-List | Out-String)
	Exit-GHActionsLogGroup
}
$ErrorActionPreference = $ErrorActionOriginalPreference
if ($TotalIssues -gt 0) {
	exit 1
}
exit 0
