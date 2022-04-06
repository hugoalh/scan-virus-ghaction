Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local' -ErrorAction Stop
[string[]]$ElementsHashStorage = @()
[bool]$TargetIsLocal = $false
[string[]]$TargetList = @()
function Test-StringIsURL {
	[CmdletBinding()][OutputType([bool])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$InputObject
	)
	$URIObject = $InputObject -as [System.URI]
	return (($null -ne $URIObject.AbsoluteURI) -and ($InputObject -match '^https?:\/\/'))
}
Enter-GHActionsLogGroup -Title 'Import inputs.'
[string]$Target = Get-GHActionsInput -Name 'target' -Require -Trim
if ($Target -match '^\.\/$') {
	Write-GHActionsDebug -Message 'Target: Local'
	$TargetIsLocal = $true
} else {
	[string[]]$TargetListFault = @()
	[string[]]$TargetListRaw = $Target -split "\s*;\s*|\s*\r?\n\s*"
	$TargetListRaw | ForEach-Object -Process {
		[string]$TargetListRawCurrent = $_.Trim()
		if ($TargetListRawCurrent.Length -gt 0) {
			if (Test-StringIsURL -InputObject $TargetListRawCurrent) {
				$TargetList += $TargetListRawCurrent
			} else {
				$TargetListFault += $TargetListRawCurrent
			}
		}
	}
	if ($TargetList.Length -eq 0) {
		Write-GHActionsDebug -Message 'Target: Network * 0'
	} else {
		Write-GHActionsDebug -Message "Target: Network * $($TargetList.Length) ($($TargetList -join '; '))"
	}
	$TargetListFault | ForEach-Object -Process {
		Write-GHActionsWarning -Message "Input ``target``'s value ``$_`` is not a valid target!"
	}
	if ($TargetList.Length -eq 0) {
		Write-GHActionsFail -Message "Input ``target`` has no valid target!"
	}
}
[bool]$Deep = [bool]::Parse((Get-GHActionsInput -Name 'deep' -Require -Trim))
Exit-GHActionsLogGroup
Enter-GHActionsLogGroup -Title 'Update image software.'
Invoke-Expression -Command 'apk update' -ErrorAction Stop
Invoke-Expression -Command 'apk upgrade' -ErrorAction Stop
Exit-GHActionsLogGroup
Enter-GHActionsLogGroup -Title 'Update ClamAV via FreshClam.'
Invoke-Expression -Command 'freshclam' -ErrorAction Stop
Exit-GHActionsLogGroup
Enter-GHActionsLogGroup -Title 'Start ClamAV daemon.'
Invoke-Expression -Command 'clamd' -ErrorAction Stop
Exit-GHActionsLogGroup
[bool]$ConclusionFail = $false
[string]$ElementsScanListPath = (New-TemporaryFile).FullName
[uint]$TotalScanElements = 0
function Invoke-ScanVirus {
	[CmdletBinding()][OutputType([void])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Session
	)
	Write-Host -Object "Begin session $Session."
	[string[]]$Elements = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Recurse -Force -Name
	[pscustomobject[]]$ElementsListDisplay = @()
	[string[]]$ElementsListScan = @()
	foreach ($Element in ($Elements | Sort-Object)) {
		[string]$ElementFullPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $Element
		[bool]$ElementIsDirectory = Test-Path -Path $ElementFullPath -PathType Container
		[hashtable]$ElementListDisplay = @{
			Path = $Element
			Directory = $ElementIsDirectory
		}
		if ($ElementIsDirectory) {
			$ElementListDisplay.Scan = $true
			$ElementsListScan += $ElementFullPath
		} else {
			[string]$ElementHash = ''
			foreach ($Algorithm in @('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')) {
				$ElementHash += (Get-FileHash -Path $Element -Algorithm $Algorithm).Hash
			}
			$ElementListDisplay.Hash = $ElementHash
			if ($ElementsHashStorage -contains $ElementHash) {
				$ElementListDisplay.Scan = $false
			} else {
				$ElementListDisplay.Scan = $true
				$ElementsListScan += $ElementFullPath
			}
			$ElementsHashStorage += $ElementHash
		}
		$ElementsListDisplay += [pscustomobject]$ElementListDisplay
	}
	Enter-GHActionsLogGroup -Title "Elements ($Session) - $($Elements.Length):"
	$ElementsListDisplay | Format-Table -Property @('Path', 'Directory', 'Scan', 'Hash') -AutoSize -Wrap
	Exit-GHActionsLogGroup
	if ($ElementsListScan.Length -gt 0) {
		Set-Content -Path $ElementsScanListPath -Value ($ElementsListScan -join "`n") -NoNewline -Encoding UTF8NoBOM
		$script:TotalScanElements += $ElementsListScan.Length
		Enter-GHActionsLogGroup -Title "ClamAV result ($Session):"
		Invoke-Expression -Command "clamdscan --fdpass --file-list $ElementsScanListPath --multiscan"
		if ($LASTEXITCODE -eq 1) {
			Write-GHActionsError -Message "Found virus in $Session via ClamAV!"
			$script:ConclusionFail = $true
		} elseif ($LASTEXITCODE -gt 1) {
			Write-GHActionsError -Message "Unexpected ClamAV result ``$LASTEXITCODE`` in $Session!"
			$script:ConclusionFail = $true
		}
		Exit-GHActionsLogGroup
	}
	Write-Host -Object "End session $Session."
}
if ($TargetIsLocal) {
	Invoke-ScanVirus -Session 'current workspace'
	if ($Deep) {
		if (Test-Path -Path '.\.git') {
			Write-Host -Object 'Import Git information.'
			[string[]]$GitCommits = Invoke-Expression -Command 'git --no-pager log --all --format=%H --reflog --reverse' -ErrorAction Stop
			if ($GitCommits.Length -le 1) {
				Write-GHActionsWarning -Message "Current Git repository has only $($GitCommits.Length) commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run all jobs`` or ``Re-run this workflow`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommits.Length; $GitCommitsIndex++) {
				[string]$GitCommit = $GitCommits[$GitCommitsIndex]
				[string]$GitCurrentSession = "commit #$($GitCommitsIndex + 1)/$($GitCommits.Length) ($GitCommit)"
				Enter-GHActionsLogGroup -Title "Checkout Git $GitCurrentSession."
				Invoke-Expression -Command "git checkout $GitCommit --force --quiet"
				if ($LASTEXITCODE -eq 0) {
					Exit-GHActionsLogGroup
					Invoke-ScanVirus -Session $GitCurrentSession
				} else {
					Write-GHActionsError -Message "Unexpected Git checkout result ``$LASTEXITCODE`` in $GitCurrentSession!"
					$ConclusionFail = $true
					Exit-GHActionsLogGroup
				}
			}
		} else {
			Write-GHActionsWarning -Message 'Unable to deep scan workspace due to current workspace is not a Git repository! If this is incorrect, probably Git file is broken.'
		}
	}
} else {
	[string[]]$UselessElements = Get-ChildItem -Path $env:GITHUB_WORKSPACE -Force -Name
	if ($UselessElements.Length -gt 0) {
		Write-GHActionsWarning -Message 'Require a clean workspace when target is network!'
		Write-Host -Object 'Clean workspace.'
		$UselessElements | ForEach-Object -Process {
			Remove-Item -Path (Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $_) -Recurse -Force -Confirm:$false
		}
	}
	foreach ($Target in ($TargetList | Sort-Object)) {
		Enter-GHActionsLogGroup -Title "Fetch file $Target."
		[string]$NetworkTemporaryFileFullPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath (New-Guid).Guid
		try {
			Invoke-WebRequest -Uri $Target -UseBasicParsing -Method Get -OutFile $NetworkTemporaryFileFullPath
		} catch {
			Write-GHActionsError -Message "Unable to fetch file $Target!"
			continue
		}
		Exit-GHActionsLogGroup
		Invoke-ScanVirus -Session $Target
		Remove-Item -Path $NetworkTemporaryFileFullPath -Force -Confirm:$false
	}
}
Write-Host -Object "Total scan elements: $TotalScanElements"
Remove-Item -Path $ElementsScanListPath -Force -Confirm:$false
Write-Host -Object 'Stop ClamAV daemon.'
Get-Process -Name '*clamd*' | Stop-Process
if ($ConclusionFail) {
	exit 1
}
exit 0
