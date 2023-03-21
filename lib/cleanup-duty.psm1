#Requires -PSEdition Core -Version 7.3
Class ScanVirusCleanupDuty {
	[String[]]$Pending = @()
	[Void]Cleanup() {
		$This.Pending = $This.Pending |
			Where-Object -FilterScript {
				Try {
					Remove-Item -LiteralPath $_ -Recurse:$(Test-Path -LiteralPath $_ -PathType 'Container') -Force -Confirm:$False
					Write-Output -InputObject $False
				}
				Catch {
					Write-Output -InputObject $True
				}
			}
	}
}
