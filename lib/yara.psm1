#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Function Invoke-Yara {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 1)][Alias('Elements', 'File', 'Files')][String[]]$Element,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Rules')][PSCustomObject[]]$Rule
	)
	$ElementScanPath = New-TemporaryFile
	Set-Content -LiteralPath $ElementScanPath -Value (
		$Element |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	[Hashtable]$ResultFound = @{}
	ForEach ($RuleEntry In $Rule) {
		Try {
			[String[]]$Output = Invoke-Expression -Command "yara --scan-list `"$(Join-Path -Path $YaraRulesAssetsRoot -ChildPath $RuleEntry.Location)`" `"$($ElementScanPath.FullName)`""
			[UInt32]$ExitCode = $LASTEXITCODE
		}
		Catch {
			Write-GitHubActionsError -Message "Unexpected issues when invoke YARA (SessionID: $SessionId): $_"
			Exit-GitHubActionsLogGroup
			Exit 1
		}
	}
	Remove-Item -LiteralPath $ElementScanPath -Force -Confirm:$False
}
