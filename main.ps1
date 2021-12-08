function Write-GHActionDebug {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][AllowEmptyString()][string]$Message
	)
	foreach ($Line in ($Message.Trim() -split "`n")) {
		Write-Output -InputObject "::debug::$Line"
	}
}
function Write-GHActionError {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][AllowEmptyString()][string]$Message
	)
	foreach ($Line in ($Message.Trim() -split "`n")) {
		Write-Output -InputObject "::error::$Line"
	}
}
function Write-GHActionLog {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][AllowEmptyString()][string]$Message
	)
	foreach ($Line in ($Message.Trim() -split "`n")) {
		Write-Output -InputObject $Line
	}
}
function Write-GHActionWarning {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][AllowEmptyString()][string]$Message
	)
	foreach ($Line in ($Message.Trim() -split "`n")) {
		Write-Output -InputObject "::warning::$Line"
	}
}
function Convert-GHActionListInput {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Name,
		[Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)][AllowEmptyString()]$Value
	)
	switch ($Value.GetType().Name) {
		"Int32" {
			if (($Value -ge 0) -and ($Value -le 2)) {
				return $Value
			}
		}
		"String" {
			switch ($Value) {
				"none" { return 0 }
				"debug" { return 1 }
				"log" { return 2 }
			}
		}
	}
	Write-GHActionError -Message "SyntaxError: Input ``$Name``'s value is not in the list!"
	Exit 1
}
function Publish-GHActionRawLog {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][uInt16]$Condition,
		[Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)][AllowEmptyString()][string]$Message
	)
	switch ($Condition) {
		1 { Write-GHActionDebug -Message $Message }
		2 { Write-GHActionLog -Message $Message }
	}
}
$GitDepth = [bool]::Parse($env:INPUT_GITDEPTH)
$ListElements = Convert-GHActionListInput -Name "list_elements" -Value $env:INPUT_LIST_ELEMENTS
$ListElementsHashes = Convert-GHActionListInput -Name "list_elementshashes" -Value $env:INPUT_LIST_ELEMENTSHASHES
$ListMiscellaneousResults = Convert-GHActionListInput -Name "list_miscellaneousresults" -Value $env:INPUT_LIST_MISCELLANEOUSRESULTS
$ListScanResults = Convert-GHActionListInput -Name "list_scanresults" -Value $env:INPUT_LIST_SCANRESULTS
if ($ListElementsHashes -gt $ListElements) {
	$ListElementsHashes = $ListElements
}
Write-Output -InputObject "::group::Update ClamAV via FreshClam."
$FreshClamResult = $null
try {
	$FreshClamResult = $(freshclam) -join "`n"
} catch {
	Write-GHActionError -Message "Unable to execute FreshClam!"
	Exit 1
}
if ($LASTEXITCODE -ne 0) {
	$FreshClamErrorCode = $LASTEXITCODE
	$FreshClamErrorMessage = ""
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
	Write-GHActionLog -Message $FreshClamResult
	Write-GHActionError -Message "Unexpected FreshClam result {$($FreshClamErrorCode)$($FreshClamErrorMessage)}!"
	Exit 1
}
Publish-GHActionRawLog -Condition $ListMiscellaneousResults -Message $FreshClamResult
Write-Output -InputObject "::endgroup::"
Write-Output -InputObject "::group::Start ClamAV daemon."
$ClamDStartResult = $null
try {
	$ClamDStartResult = $(clamd) -join "`n"
}
catch {
	Write-Output -InputObject "::error::Unable to execute ClamD!"
	Exit 1
}
if ($LASTEXITCODE -ne 0) {
	Write-GHActionLog -Message $ClamDStartResult
	Write-Output -InputObject "::error::Unexpected ClamD result {$LASTEXITCODE}!"
	Exit 1
}
Publish-GHActionRawLog -Condition $ListMiscellaneousResults -Message $ClamDStartResult
Write-Output -InputObject "::endgroup::"
$SetFail = $false
$TemporaryFile = (New-TemporaryFile).FullName
$TotalScanElements = 0
function Invoke-ScanVirus {
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Session
	)
	Write-Output -InputObject "::group::Scan $Session."
	$Elements = (Get-ChildItem -Force -Name -Path $env:GITHUB_WORKSPACE -Recurse | Sort-Object)
	$ElementsLength = $Elements.Longlength
	Publish-GHActionRawLog -Condition $ListElements -Message "Elements ($Session - $ElementsLength):"
	$ElementsRaw = ""
	foreach ($Element in $Elements) {
		$ElementsRaw += "$(Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath $Element)`n"
		Publish-GHActionRawLog -Condition $ListElements -Message "- $Element"
		if (($ListElementsHashes -gt 0) -and (Test-Path -Path $Element -PathType Leaf)) {
			foreach ($Algorithm in @("MD5", "SHA1", "SHA256", "SHA384", "SHA512")) {
				Publish-GHActionRawLog -Condition $ListElementsHashes -Message "  - $($Algorithm): $((Get-FileHash -Algorithm $Algorithm -Path $Element).Hash)"
			}
		}
	}
	Set-Content -Encoding utf8NoBOM -NoNewline -Path $TemporaryFile -Value $ElementsRaw.Trim()
	$script:TotalScanElements += $ElementsLength
	$ClamDScanResult = $null
	try {
		$ClamDScanResult = $(clamdscan --fdpass --file-list $TemporaryFile --multiscan) -join "`n"
	} catch {
		Write-GHActionError -Message "Unable to execute ClamDScan ($Session)!"
		Write-Output -InputObject "::endgroup::"
		Exit 1
	}
	if ($LASTEXITCODE -eq 0) {
		Publish-GHActionRawLog -Condition $ListScanResults -Message "ClamDScan Result ($Session):`n$ClamDScanResult"
	} else {
		$ClamDScanErrorCode = $LASTEXITCODE
		$script:SetFail = $true
		Write-GHActionLog -Message "ClamDScan Result ($Session):`n$ClamDScanResult"
		if ($ClamDScanErrorCode -eq 1) {
			Write-GHActionError -Message "Found virus in $Session via ClamAV!"
		} else {
			Write-GHActionError -Message "Unexpected ClamDScan result ($Session){$ClamDScanErrorCode}!"
		}
	}
	Write-Output -InputObject "::endgroup::"
}
Invoke-ScanVirus -Session "current workspace"
if ($GitDepth) {
	Write-Output -InputObject "Import Git information."
	if (Test-Path -Path .\.git) {
		$GitCommitsRaw = $null
		try {
			$GitCommitsRaw = $(git --no-pager log --all --format=%H --reflog --reverse) -join "`n"
		} catch {
			Write-GHActionError -Message "Unable to execute Git-Log!"
			Exit 1
		}
		if (($LASTEXITCODE -eq 0) -and ($GitCommitsRaw -notmatch "error") -and ($GitCommitsRaw -notmatch "fatal")) {
			$GitCommits = ($GitCommitsRaw -split "`n")
			$GitCommitsLength = $GitCommits.Longlength
			if ($GitCommitsLength -le 1) {
				Write-GHActionWarning -Message "Current Git repository has only $GitCommitsLength commits! If this is incorrect, please define ``actions/checkout`` input ``fetch-depth`` to ``0`` and re-trigger the workflow. (IMPORTANT: ``Re-run all jobs`` or ``Re-run this workflow`` cannot apply the modified workflow!)"
			}
			for ($GitCommitsIndex = 0; $GitCommitsIndex -lt $GitCommitsLength; $GitCommitsIndex++) {
				$GitCommit = $GitCommits[$GitCommitsIndex]
				Write-Output -InputObject "Checkout commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)."
				$GitCheckoutResult = $null
				try {
					$GitCheckoutResult = $(git checkout "$GitCommit" --quiet) -join "`n"
				} catch {
					Write-GHActionError -Message "Unable to execute Git-Checkout (commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit))!"
					Exit 1
				}
				if ($LASTEXITCODE -eq 0) {
					Invoke-ScanVirus -Session "commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)"
				} else {
					$GitCheckoutErrorCode = $LASTEXITCODE
					Write-GHActionLog -Message $GitCheckoutResult
					Write-GHActionError -Message "Unexpected Git-Checkout result (commit #$($GitCommitsIndex + 1)/$($GitCommitsLength) ($GitCommit)){$GitCheckoutErrorCode}!"
				}
			}
		} else {
			Write-GHActionLog -Message $GitCommitsRaw
			Write-GHActionError -Message "Unexpected Git-Log result {$LASTEXITCODE}!"
		}
	} else {
		Write-GHActionWarning -Message "Current workspace is not a Git repository!"
	}
}
Publish-GHActionRawLog -Condition $ListMiscellaneousResults -Message "Total scan elements: $TotalScanElements"
Remove-Item -Path $TemporaryFile
Write-Output -InputObject "Stop ClamAV daemon."
Get-Process -Name *clamd* | Stop-Process
if ($SetFail) {
	Exit 1
}
Exit 0
