#Requires -PSEdition Core -Version 7.3
Class ScanVirusCleanupDuty {
	[String[]]$Storage = @()
	[Void]Cleanup() {
		$This.Storage |
			ForEach-Object -Process {
				Remove-Item -LiteralPath $_ -Force -Confirm:$False -ErrorAction 'Continue'
			}
		$This.Storage = @()
	}
}
