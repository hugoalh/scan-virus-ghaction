[string]$OriginalPreference_ErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'utilities.psm1') -Scope 'Local'
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
	return [string[]]($InputObject -split ";|\r?\n") | ForEach-Object -Process {
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
	return Format-InputList -InputObject (Get-GHActionsInput -Name $Name -Trim)
}
function Test-InputFilter {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Target,
		[Parameter(Mandatory = $true, Position = 1)][AllowEmptyCollection()][string[]]$FilterList,
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
function Write-OptimizePSList {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	[string]$OutputObject = $InputObject -replace '(?:\r?\n)+$', ''
	if ($OutputObject.Length -gt 0) {
		Write-Host -Object $OutputObject
	}
}
function Write-OptimizePSTable {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	[string]$OutputObject = $InputObject -replace '^(?:\r?\n)+|(?:\r?\n)+$', ''
	if ($OutputObject.Length -gt 0) {
		Write-Host -Object $OutputObject
	}
}
[string]$ClamAVDatabaseRoot = '/var/lib/clamav'
[string]$ClamAVSignaturesIgnoreFileFullName = Join-Path -Path $ClamAVDatabaseRoot -ChildPath 'ignore_list.ign2'
[string]$ClamAVSignaturesIgnorePresetsRoot = Join-Path -Path $PSScriptRoot -ChildPath 'clamav-signatures-ignore-presets'
[pscustomobject[]]$ClamAVSignaturesIgnorePresetsIndex = Get-TSVTable -Path (Join-Path -Path $ClamAVSignaturesIgnorePresetsRoot -ChildPath 'index.tsv')
[string]$ClamAVUnofficialSignaturesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'clamav-unofficial-signatures'
[pscustomobject[]]$ClamAVUnofficialSignaturesIndex = Get-TSVTable -Path (Join-Path -Path $ClamAVUnofficialSignaturesRoot -ChildPath 'index.tsv')
[string[]]$IssuesClamAV = @()
[string[]]$IssuesOther = @()
[string[]]$IssuesYARA = @()
[bool]$LocalTarget = $false
[string[]]$NetworkTargets = @()
[string]$RegExp_GHActionsWorkspaceRoot = "$([regex]::Escape($env:GITHUB_WORKSPACE))\/"
[UInt64]$TotalElementsAll = 0
[UInt64]$TotalElementsClamAV = 0
[UInt64]$TotalElementsYARA = 0
[UInt64]$TotalSizesAll = 0
[UInt64]$TotalSizesClamAV = 0
[UInt64]$TotalSizesYARA = 0
[string]$YARARulesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'yara-rules'
[pscustomobject[]]$YARARulesIndex = Get-TSVTable -Path (Join-Path -Path $YARARulesRoot -ChildPath 'index.tsv')
<#
Enter-GHActionsLogGroup -Title 'ClamAV database index:'
Write-OptimizePSTable -InputObject (Get-ChildItem -Path $ClamAVDatabaseRoot -Recurse -File | Sort-Object | Format-Table -Property @('FullName', 'Mode', @{Expression = 'Length'; Alignment = 'Right'}) -AutoSize -Wrap | Out-String)
Exit-GHActionsLogGroup
Enter-GHActionsLogGroup -Title 'ClamAV signatures ignore presets index:'
Write-OptimizePSTable -InputObject (Get-ChildItem -Path $ClamAVSignaturesIgnorePresetsRoot -Include '*.ign2' -Recurse -File | Sort-Object | Format-Table -Property @('FullName', 'Mode', @{Expression = 'Length'; Alignment = 'Right'}) -AutoSize -Wrap | Out-String)
Exit-GHActionsLogGroup
Enter-GHActionsLogGroup -Title 'ClamAV unofficial signatures index:'
Write-OptimizePSTable -InputObject (Get-ChildItem -Path $ClamAVUnofficialSignaturesRoot -Include @('*.cbc', '*.cdb', '*.gdb', '*.hdb', '*.hdu', '*.hsb', '*.hsu', '*.idb', '*.ldb', '*.ldu', '*.mdb', '*.mdu', '*.msb', '*.msu', '*.ndb', '*.ndu', '*.pdb', '*.wdb') -Recurse -File | Sort-Object | Format-Table -Property @('FullName', 'Mode', @{Expression = 'Length'; Alignment = 'Right'}) -AutoSize -Wrap | Out-String)
Exit-GHActionsLogGroup
Enter-GHActionsLogGroup -Title 'YARA rules index:'
Write-OptimizePSTable -InputObject (Get-ChildItem -Path $YARARulesRoot -Include @('*.yar', '*.yara') -Recurse -File | Sort-Object | Format-Table -Property @('FullName', 'Mode', @{Expression = 'Length'; Alignment = 'Right'}) -AutoSize -Wrap | Out-String)
Exit-GHActionsLogGroup
#>
Enter-GHActionsLogGroup -Title 'Import inputs.'
[string]$Targets = Get-GHActionsInput -Name 'targets' -Trim
if ($Targets -match '^\.\/$') {
	$LocalTarget = $true
} else {
	Format-InputList -InputObject $Targets | ForEach-Object -Process {
		if (Test-StringIsURL -InputObject $_) {
			$NetworkTargets += $_
		} else {
			Write-GHActionsWarning -Message "Input ``targets``'s value ``$_`` is not a valid target!"
		}
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
[pscustomobject[]]$ClamAVSignaturesIgnorePresetsApply = $ClamAVSignaturesIgnorePresetsIndex | Where-Object -FilterScript {
	Test-InputFilter -Target $_.Name -FilterList $ClamAVSignaturesIgnorePresets -FilterMode 'Include'
} | Sort-Object -Property 'Name'
[string[]]$ClamAVSignaturesIgnore = $ClamAVSignaturesIgnoreCustom
$ClamAVSignaturesIgnorePresetsApply | ForEach-Object -Process {
	$ClamAVSignaturesIgnore += Get-Content -Path (Join-Path -Path $ClamAVSignaturesIgnorePresetsRoot -ChildPath $_.Location) -Encoding UTF8NoBOM
}
$ClamAVSignaturesIgnore | Sort-Object -Unique -CaseSensitive
[bool]$ClamAVSubcursive = [bool]::Parse((Get-GHActionsInput -Name 'clamav_subcursive' -Require -Trim))
[string[]]$ClamAVUnofficialSignatures = Get-InputList -Name 'clamav_unofficialsignatures'
[pscustomobject[]]$ClamAVUnofficialSignaturesApply = $ClamAVUnofficialSignaturesIndex | Where-Object -FilterScript {
	Test-InputFilter -Target $_.Name -FilterList $ClamAVUnofficialSignatures -FilterMode 'Include'
} | Sort-Object -Property 'Name'
[bool]$YARAEnable = [bool]::Parse((Get-GHActionsInput -Name 'yara_enable' -Require -Trim))
[string[]]$YARAFilesFilterList = Get-InputList -Name 'yara_filesfilter_list'
[FilterMode]$YARAFilesFilterMode = Get-GHActionsInput -Name 'yara_filesfilter_mode' -Require -Trim
[string[]]$YARARulesFilterList = Get-InputList -Name 'yara_rulesfilter_list'
[FilterMode]$YARARulesFilterMode = Get-GHActionsInput -Name 'yara_rulesfilter_mode' -Require -Trim
[bool]$YARAToolWarning = [bool]::Parse((Get-GHActionsInput -Name 'yara_toolwarning' -Require -Trim))
[pscustomobject[]]$YARARulesApply = $YARARulesIndex | Where-Object -FilterScript {
	Test-InputFilter -Target $_.Name -FilterList $YARARulesFilterList -FilterMode $YARARulesFilterMode
} | Sort-Object -Property 'Name'
Write-OptimizePSTable -InputObject ([ordered]@{
	Targets_Count = $LocalTarget ? 1 : ($NetworkTargets.Count)
	Git_Deep = $GitDeep
	Git_ReverseSession = $GitReverseSession
	ClamAV_Enable = $ClamAVEnable
	ClamAV_Daemon = $ClamAVDaemon
	ClamAV_FilesFilter_Count = $ClamAVFilesFilterList.Count
	ClamAV_FilesFilter_Mode = $ClamAVFilesFilterMode
	ClamAV_MultiScan = $ClamAVMultiScan
	ClamAV_ReloadPerSession = $ClamAVReloadPerSession
	ClamAV_SignaturesIgnore_Custom_Count = $ClamAVSignaturesIgnoreCustom.Count
	ClamAV_SignaturesIgnore_Presets_Count = $ClamAVSignaturesIgnorePresets.Count
	ClamAV_Subcursive = $ClamAVSubcursive
	YARA_Enable = $YARAEnable
	YARA_FilesFilter_Count = $YARAFilesFilterList.Count
	YARA_FilesFilter_Mode = $YARAFilesFilterMode
	YARA_RulesIndex_Count = $YARARulesIndex.Count
	YARA_RulesFilter_Count = $YARARulesFilterList.Count
	YARA_RulesFilter_Mode = $YARARulesFilterMode
	YARA_RulesApply_Count = $YARARulesApply.Count
	YARA_ToolWarning = $YARAToolWarning
} | Format-Table -Property @(
	'Name',
	@{Expression = 'Value'; Alignment = 'Right'}
) -AutoSize -Wrap | Out-String)
Write-OptimizePSList -InputObject ([ordered]@{
	Targets_List = $LocalTarget ? 'Local' : ($NetworkTargets -join ',')
	ClamAV_FilesFilter_List = $ClamAVFilesFilterList -join ', '
	ClamAV_SignaturesIgnore_Custom_List = $ClamAVSignaturesIgnoreCustom -join ', '
	ClamAV_SignaturesIgnore_Presets_List = $ClamAVSignaturesIgnorePresets -join ', '
	YARA_FilesFilter_List = $YARAFilesFilterList -join ', '
	YARA_RulesIndex_List = $YARARulesIndex.Name -join ', '
	YARA_RulesFilter_List = $YARARulesFilterList -join ', '
	YARA_RulesApply_List = $YARARulesApply.Name -join ', '
} | Format-List -Property 'Value' -GroupBy 'Name' | Out-String)
Exit-GHActionsLogGroup
if (($LocalTarget -eq $false) -and ($NetworkTargets.Count -eq 0)) {
	Write-GHActionsFail -Message 'Input `targets` does not have valid target!'
}
if ($true -notin @($ClamAVEnable, $YARAEnable)) {
	Write-GHActionsFail -Message 'No anti virus software enable!'
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
	if ($ClamAVSignaturesIgnoreCustom.Count -gt 0) {
		Set-Content -Path $ClamAVSignaturesIgnoreFileFullName -Value ($ClamAVSignaturesIgnoreCustom -join "`n") -NoNewline -Encoding UTF8NoBOM
	}
	Enter-GHActionsLogGroup -Title 'Start ClamAV daemon.'
	Invoke-Expression -Command 'clamd'
	Exit-GHActionsLogGroup
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
		$Elements | Sort-Object | ForEach-Object {
			[bool]$ElementIsDirectory = Test-Path -Path $_.FullName -PathType Container
			[string]$ElementName = $_.FullName -replace "^$RegExp_GHActionsWorkspaceRoot", ''
			[UInt64]$ElementSizes = $_.Length
			[hashtable]$ElementListDisplay = @{
				Element = $ElementName
				Flags = @(
					$ElementIsDirectory ? 'D' : ''
				)
			}
			if ($ElementIsDirectory -eq $false) {
				$ElementListDisplay.Sizes = $ElementSizes
				$script:TotalSizesAll += $ElementSizes
			}
			if (
				($LocalTarget -eq $false) -or
				(Test-InputFilter -Target $ElementName -FilterList $ClamAVFilesFilterList -FilterMode $ClamAVFilesFilterMode)
			) {
				$ElementsListClamAV += $_.FullName
				$ElementListDisplay.Flags += 'C'
				if ($ElementIsDirectory -eq $false) {
					$script:TotalSizesClamAV += $ElementSizes
				}
			}
			if (($ElementIsDirectory -eq $false) -and (
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
		Enter-GHActionsLogGroup -Title "Elements ($Session) - $($Elements.Count):"
		Write-OptimizePSTable -InputObject ($ElementsListDisplay | Format-Table -Property @('Element', 'Flags', @{Expression = 'Sizes'; Alignment = 'Right'}) -AutoSize -Wrap | Out-String)
		Exit-GHActionsLogGroup
		if ($ClamAVEnable -and ($ElementsListClamAV.Count -gt 0)) {
			[string]$ElementsListClamAVPath = (New-TemporaryFile).FullName
			Set-Content -Path $ElementsListClamAVPath -Value ($ElementsListClamAV -join "`n") -NoNewline -Encoding UTF8NoBOM
			Enter-GHActionsLogGroup -Title "ClamAV result ($Session):"
			[string[]]$ClamAVOutput = Invoke-Expression -Command "clamdscan --fdpass --file-list `"$ElementsListClamAVPath`"$($ClamAVMultiScan ? ' --multiscan' : '')"
			[uint]$ClamAVExitCode = $LASTEXITCODE
			[string[]]$ClamAVResultRaw = @()
			$ClamAVOutput | ForEach-Object -Process {
				if ($_ -notmatch ': OK$') {
					$ClamAVResultRaw += $_ -replace "^\s*$RegExp_GHActionsWorkspaceRoot", ''
				}
			}
			[string]$ClamAVResult = $ClamAVResultRaw -join "`n" -replace '^\s*\n', ''
			if ($ClamAVResult.Length -gt 0) {
				Write-Host -Object $ClamAVResult
			}
			if ($ClamAVExitCode -eq 1) {
				Write-GHActionsError -Message "Found issues in session `"$Session`" via ClamAV!"
				$script:IssuesClamAV += $Session
			} elseif ($ClamAVExitCode -gt 1) {
				Write-GHActionsError -Message "Unexpected ClamAV result ``$ClamAVExitCode`` in session `"$Session`"!"
				$script:IssuesClamAV += $Session
			}
			Exit-GHActionsLogGroup
			Remove-Item -Path $ElementsListClamAVPath -Force -Confirm:$false
		}
		if ($YARAEnable -and ($ElementsListYARA.Count -gt 0)) {
			[string]$ElementsListYARAPath = (New-TemporaryFile).FullName
			Set-Content -Path $ElementsListYARAPath -Value ($ElementsListYARA -join "`n") -NoNewline -Encoding UTF8NoBOM
			Enter-GHActionsLogGroup -Title "YARA result ($Session):"
			[hashtable]$YARAResultRaw = @{}
			foreach ($YARARule in $YARARulesApply) {
				[string[]]$YARAOutput = Invoke-Expression -Command "yara --scan-list$($YARAToolWarning ? '' : ' --no-warnings') `"$(Join-Path -Path $YARARulesRoot -ChildPath $YARARule.Location)`" `"$ElementsListYARAPath`""
				if ($LASTEXITCODE -eq 0) {
					$YARAOutput | ForEach-Object -Process {
						if ($_ -match "^.+? $RegExp_GHActionsWorkspaceRoot.+$") {
							[string]$Rule, [string]$Element = $_ -split "(?<=^.+?) $RegExp_GHActionsWorkspaceRoot"
							[string]$YARARuleName = "$($YARARule.Name)/$Rule"
							Write-GHActionsDebug -Message "$YARARuleName>$Element"
							if ((Test-InputFilter -Target "$YARARuleName>$Element" -FilterList $YARARulesFilterList -FilterMode $YARARulesFilterMode) -eq $false) {
								Write-GHActionsDebug -Message '  > Skip'
							} else {
								if ($null -eq $YARAResultRaw[$Element]) {
									$YARAResultRaw[$Element] = @()
								}
								$YARAResultRaw[$Element] += $YARARuleName
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
			if ($YARAResultRaw.Count -gt 0) {
				[hashtable]$YARAResult = @{}
				$YARAResultRaw.GetEnumerator() | ForEach-Object -Process {
					$YARAResult[$_.Name] = ($_.Value | Sort-Object) -join ', '
				}
				Write-OptimizePSList -InputObject ($YARAResult.GetEnumerator() | Sort-Object -Property 'Name' | Format-List -Property 'Value' -GroupBy 'Name' | Out-String)
				Write-GHActionsError -Message "Found issues in session `"$Session`" via YARA!"
				$script:IssuesYARA += $Session
			}
			Exit-GHActionsLogGroup
			Remove-Item -Path $ElementsListYARAPath -Force -Confirm:$false
		}
	}
	Write-Host -Object "End of session $Session."
}
if ($LocalTarget) {
	Invoke-ScanVirusSession -Session 'Current'
	if ($GitDeep) {
		if (Test-Path -Path '.\.git') {
			Write-Host -Object 'Import Git information.'
			[string[]]$GitCommits = Invoke-Expression -Command "git --no-pager log --all --format=%H --reflog$($GitReverseSession ? '' : ' --reverse')"
			if ($GitCommits.Count -le 1) {
				Write-GHActionsWarning -Message "Current Git repository has only $($GitCommits.Count) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run all jobs`` or ``Re-run this workflow`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Count; $GitCommitsIndex++) {
				[string]$GitCommit = $GitCommits[$GitCommitsIndex]
				[string]$GitSession = "Commit #$($GitReverseSession ? ($GitCommits.Count - $GitCommitsIndex) : ($GitCommitsIndex + 1))/$($GitCommits.Count) - $GitCommit"
				Enter-GHActionsLogGroup -Title "Git checkout for session `"$GitSession`"."
				try {
					Invoke-Expression -Command "git checkout $GitCommit --force --quiet"
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
if ($ClamAVEnable) {
	Enter-GHActionsLogGroup -Title 'Stop ClamAV daemon.'
	Get-Process -Name '*clamd*' | Stop-Process
	Exit-GHActionsLogGroup
	if ($ClamAVSignaturesIgnoreCustom.Count -gt 0) {
		Remove-Item -Path $ClamAVSignaturesIgnoreFileFullName -Force -Confirm:$false
	}
}
Enter-GHActionsLogGroup -Title "Statistics:"
[UInt64]$TotalIssuesAll = $IssuesClamAV.Count + $IssuesOther.Count + $IssuesYARA.Count
Write-OptimizePSTable -InputObject ([pscustomobject[]]@(
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
		All = $TotalIssuesAll
		ClamAV = $IssuesClamAV.Count
		YARA = $IssuesYARA.Count
		Other = $IssuesOther.Count
	},
	[pscustomobject]@{
		Name = 'TotalIssues_Percentage'
		ClamAV = ($TotalIssuesAll -eq 0) ? 0 : ($IssuesClamAV.Count / $TotalIssuesAll * 100)
		YARA = ($TotalIssuesAll -eq 0) ? 0 : ($IssuesYARA.Count / $TotalIssuesAll * 100)
		Other = ($TotalIssuesAll -eq 0) ? 0 : ($IssuesOther.Count / $TotalIssuesAll * 100)
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
	@{Expression = 'All'; Alignment = 'Right'},
	@{Expression = 'ClamAV'; Alignment = 'Right'},
	@{Expression = 'YARA'; Alignment = 'Right'},
	@{Expression = 'Other'; Alignment = 'Right'}
) -AutoSize -Wrap | Out-String)
if ($TotalIssuesAll -gt 0) {
	Write-OptimizePSList -InputObject ([ordered]@{
		Issues_ClamAV = $IssuesClamAV -join ', '
		Issues_YARA = $IssuesYARA -join ', '
		Issues_Other = $IssuesOther -join ', '
	} | Format-List -Property 'Value' -GroupBy 'Name' | Out-String)
}
Exit-GHActionsLogGroup
$ErrorActionPreference = $OriginalPreference_ErrorAction
if ($TotalIssuesAll -gt 0) {
	exit 1
}
exit 0
