#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'control'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[String[]]$RulesPath = @()
Function Invoke-Yara {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Elements')][String[]]$Element
	)
	[Hashtable]$Result = @{
		Errors = @()
		Founds = @()
	}
	$ScanListFile = New-TemporaryFile
	Set-Content -LiteralPath $ScanListFile -Value (
		$Element |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	[String[]]$Output = @()
	ForEach ($RulePath In (
		$RulesPath |
			Select-Object -Unique
	)) {
		Try {
			$Output += yara --no-warnings --scan-list $RulePath $ScanListFile.FullName *>&1 |
				Write-GitHubActionsDebug -PassThru
		}
		Catch {
			$Result.Errors += $_
		}
		Finally {
			$LASTEXITCODE = 0
		}
	}
	Remove-Item -LiteralPath $ScanListFile -Force -Confirm:$False
	ForEach ($OutputLine In $Output) {
		If ($OutputLine -imatch "^.+? $CurrentWorkingDirectoryRegExEscape.+$") {
			[String]$Symbol, [String]$Element = $OutputLine -isplit "(?<=^.+?) $CurrentWorkingDirectoryRegExEscape"
			$Result.Founds += [PSCustomObject]@{
				Element = $Element
				Symbol = $Symbol
			}
			Continue
		}
		If ($OutputLine.Length -gt 0) {
			$Result.Errors += $OutputLine
			Continue
		}
	}
	Write-Output -InputObject ([PSCustomObject]$Result)
}
Function Register-YaraUnofficialAsset {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][RegEx]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_YARA -ChildPath 'index.tsv') @TsvParameters |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Path.Length -gt 0 } |
		Sort-Object -Property @('Type', 'Name')
	[PSCustomObject[]]$IndexTableSelect = $IndexTable |
		Where-Object -FilterScript { $_.Name -imatch $Selection }
	[PSCustomObject]@{
		All = $IndexTable.Count
		Select = $IndexTableSelect |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	} |
		Format-List |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	$IndexTable |
		Format-Table -Property @(
			@{ Name = ''; Expression = { ($_.Name -iin $IndexTableSelect.Name) ? '+' : '' } },
			'Type',
			'Name'
		) -AutoSize:$False -Wrap |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	$Script:RulesPath += $IndexTableSelect |
		ForEach-Object -Process { Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_YARA -ChildPath $_.Path }
}
Export-ModuleMember -Function @(
	'Invoke-Yara',
	'Register-YaraUnofficialAsset'
)
