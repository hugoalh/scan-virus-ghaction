function Write-GHActionDebug {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][AllowEmptyString()][string]$Message
	)
	foreach ($Line in ($Message -split "`n")) {
		Write-Output -InputObject "::debug::$Line"
	}
}
function Write-GHActionLog {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][AllowEmptyString()][string]$Message
	)
	foreach ($Line in ($Message -split "`n")) {
		Write-Output -InputObject $Line
	}
}
Write-Output -InputObject "::group::Update ClamAV via FreshClam."
$FreshClamResult = $null
try {
	$FreshClamResult = $(freshclam) -join "`n"
} catch {
	Write-Output -InputObject "::error::Unable to execute FreshClam!"
	Exit 1
}
if ($LASTEXITCODE -ne 0) {
	$FreshClamErrorCode = $LASTEXITCODE
	$FreshClamErrorMessage = $null
	switch ($FreshClamErrorCode) {
		40 { $FreshClamErrorMessage = ": Unknown option passed" }
		50 { $FreshClamErrorMessage = ": Cannot change directory" }
		51 { $FreshClamErrorMessage = ": Cannot check MD5 sum" }
		52 { $FreshClamErrorMessage = ": Connection (network) problem" }
		53 { $FreshClamErrorMessage = ": Cannot unlink file" }
		54 { $FreshClamErrorMessage = ": MD5 or digital signature verification error" }
		55 { $FreshClamErrorMessage = ": Error reading file" }
		56 { $FreshClamErrorMessage = ": Config file error" }
		57 { $FreshClamErrorMessage = ": Cannot create new file" }
		58 { $FreshClamErrorMessage = ": Cannot read database from remote server" }
		59 { $FreshClamErrorMessage = ": Mirrors are not fully synchronized (try again later)" }
		60 { $FreshClamErrorMessage = ": Cannot get information about user from /etc/passwd" }
		61 { $FreshClamErrorMessage = ": Cannot drop privileges" }
		62 { $FreshClamErrorMessage = ": Cannot initialize logger" }
	}
	Write-Output -InputObject "::error::Unexpected FreshClam result {$($FreshClamErrorCode)$($FreshClamErrorMessage)}!"
	Write-GHActionLog -Message $FreshClamResult
	Exit 1
}
Write-GHActionDebug -Message $FreshClamResult
Write-Output -InputObject "::endgroup::"
Write-Output -InputObject "::group::Start ClamAV daemon."
$ClamDStartResult = $null
try {
	$ClamDStartResult = $(clamd) -join "`n"
} catch {
	Write-Output -InputObject "::error::Unable to execute ClamD!"
	Exit 1
}
if ($LASTEXITCODE -ne 0) {
	Write-Output -InputObject "::error::Unexpected ClamD result {$LASTEXITCODE}!"
	Write-GHActionLog -Message $ClamDStartResult
	Exit 1
}
Write-GHActionDebug -Message $ClamDStartResult
Write-Output -InputObject "::endgroup::"
$GitDepth = [bool]::Parse($env:INPUT_GITDEPTH)
$SetFail = $false
$TemporaryFile = (New-TemporaryFile).FullName
$TotalScanElements = 0
function Execute-Scan {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Session
	)
	Write-Output -InputObject "::group::Scan $Session."
	$Elements = (Get-ChildItem -Force -Name -Path $env:GITHUB_WORKSPACE -Recurse | Sort-Object)
	$ElementsLength = $Elements.Longlength
	Write-GHActionDebug -Message "Elements list ($Session - $ElementsLength):`n$($Elements -join "`n")"
	$ElementsRaw = ""
	foreach ($Element in $Elements) {
		$ElementsRaw += "$(Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $Element)`n"
	}
	Set-Content -Encoding utf8NoBOM -NoNewLine -Path $TemporaryFile -Value $ElementsRaw
	$script:TotalScanElements += ($ElementsLength + 1)
	$ClamDScanResult = $null
	try {
		$ClamDScanResult = $(clamdscan --fdpass --file-list $TemporaryFile --multiscan) -join "`n"
	} catch {
		Write-Output -InputObject "::error::Unable to execute ClamDScan ($Session)!"
		Write-Output -InputObject "::endgroup::"
		Exit 1
	}
	if (($LASTEXITCODE -eq 0) -and ($ClamDScanResult -notmatch "found")) {
		Write-GHActionDebug -Message $ClamDScanResult
	} else {
		$script:SetFail = $true
		if (($LASTEXITCODE -eq 1) -or ($ClamDScanResult -match "found")) {
			Write-Output -InputObject "::error::Found virus in $Session from ClamAV!"
		} else {
			Write-Output -InputObject "::error::Unexpected ClamDScan result ($Session){$LASTEXITCODE}!"
		}
		Write-GHActionLog -Message $ClamDScanResult
	}
	Write-Output -InputObject "::endgroup::"
}
Execute-Scan -Session "current workspace"
if ($GitDepth -eq $true) {
	if ($(Test-Path -Path $(Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath ".git")) -eq $true) {
		$GitCommitsRaw = $null
		try {
			$GitCommitsRaw = $(git --no-pager log --all --format=%H --reflog --reverse) -join "`n"
		} catch {
			Write-Output -InputObject "::error::Unable to execute Git-Log!"
			Exit 1
		}
		if (($LASTEXITCODE -eq 0) -and ($GitCommitsRaw -notmatch "error") -and ($GitCommitsRaw -notmatch "fatal")) {
			$GitCommits = ($GitCommitsRaw -split "`n")
			$GitCommitsLength = $GitCommits.Longlength
			if ($GitCommitsLength -le 1) {
				Write-Output -InputObject "::warning::Current Git repository has only $GitCommitsLength commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-run. (IMPORTANT: ``Re-run all jobs`` or ``Re-run this workflow`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommitsLength; $GitCommitsIndex++) {
				$GitCommit = $GitCommits[$GitCommitsIndex]
				Write-Output -InputObject "Checkout commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)."
				$GitCheckoutResult = $null
				try {
					$GitCheckoutResult = $(git checkout "$GitCommit" --quiet) -join "`n"
				} catch {
					Write-Output -InputObject "::error::Unable to execute Git-Checkout (commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit))!"
					Exit 1
				}
				if ($LASTEXITCODE -eq 0) {
					Execute-Scan -Session "commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)"
				} else {
					Write-Output -InputObject "::error::Unexpected Git-Checkout result (commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)){$LASTEXITCODE}!"
					Write-GHActionLog -Message $($GitCheckoutResult -join "`n")
				}
			}
		} else {
			Write-Output -InputObject "::error::Unexpected Git-Log result {$LASTEXITCODE}!"
			Write-GHActionLog -Message $GitCommitsRaw
		}
	} else {
		Write-Output -InputObject "::warning::Current workspace is not a Git repository!"
	}
}
Write-Output -InputObject "Total scan elements: $TotalScanElements"
Remove-Item -Path $TemporaryFile
if ($SetFail -eq $true) {
	Exit 1
}
Write-Output -InputObject "Stop ClamAV daemon."
Exit 0
