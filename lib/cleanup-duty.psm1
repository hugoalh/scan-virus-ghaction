#Requires -PSEdition Core -Version 7.3
Class ScanVirusCleanupDuty {
	Hidden [String[]]$List = @()
	[Void]Add([String]$LiteralPath) {
		If (
			![System.IO.Path]::IsPathFullyQualified($LiteralPath) -or
			!(Test-Path -LiteralPath $LiteralPath -PathType 'Leaf')
		) {
			Write-Error -Message "``$LiteralPath`` is not a exist and valid file absolute literal path!" -ErrorAction 'Stop'
		}
		$This.List += $LiteralPath
	}
	[Void]Cleanup() {
		$This.List |
			ForEach-Object -Process {
				Remove-Item -LiteralPath $_ -Force -Confirm:$False -ErrorAction 'Continue'
			}
		$This.List = @()
	}
}
