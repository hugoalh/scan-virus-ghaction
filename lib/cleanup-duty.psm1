#Requires -PSEdition Core
#Requires -Version 7.3
Class ScanVirusCleanupDuty {
	[String[]]$Pending = @()
	[Void]Cleanup() {
		[String[]]$Failed = @()
		While ($This.Pending.Count -igt 0) {
			[String]$ElementPop, [String]$ElementRest = $This.Pending
			$This.Pending = $ElementRest
			Try {
				Remove-Item -LiteralPath $ElementPop -Recurse:$(Test-Path -LiteralPath $ElementPop -PathType 'Container') -Force -Confirm:$False
			}
			Catch {
				$Failed += $ElementPop
			}
		}
		$This.Pending = $Failed
	}
}
