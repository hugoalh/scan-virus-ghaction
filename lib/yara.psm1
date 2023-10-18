#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'control'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[String[]]$RulesPath = @()
$InvokeYaraParallelScriptBlock = {
	Param ([String]$ScanListFilePath, [String]$RulePath)
	$ErrorActionPreference = 'Continue'
	[String[]]$Output = @()
	Try {
		$Output += yara --no-warnings --scan-list $RulePath $ScanListFilePath *>&1
	}
	Catch {
		$Output += $_
	}
	Finally {
		$LASTEXITCODE = 0
	}
	Write-Output -InputObject $Output -NoEnumerate
}
Function Invoke-Yara {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Elements')][String[]]$Element
	)
	[Hashtable]$Result = @{
		Issues = @()
		Founds = @()
	}
	$ScanListFile = New-TemporaryFile
	Set-Content -LiteralPath $ScanListFile -Value (
		$Element |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	ForEach ($RulePath In (
		$RulesPath |
			Select-Object -Unique
	)) {
		Start-Job -Name "Yara:$RulePath" -ScriptBlock $InvokeYaraParallelScriptBlock -ArgumentList @($ScanListFile.FullName, $RulePath)
	}
	Wait-Job -Name 'Yara:*'
	Remove-Item -LiteralPath $ScanListFile -Force -Confirm:$False
	[String[]]$Output = Get-Job -Name 'Yara:*' |
		Receive-Job -AutoRemoveJob |
		ForEach-Object -Process {
			$_ |
				Write-Output
		}
	ForEach ($OutputLine In $Output) {
		If ($OutputLine -imatch '^\s*$') {
			Continue
		}
		If ($OutputLine -imatch "^.+? $CurrentWorkingDirectoryRegExEscape[\\/].+$") {
			[String]$Symbol, [String]$Element = $OutputLine -isplit "(?<=^.+?) $CurrentWorkingDirectoryRegExEscape[\\/]"
			$Result.Founds += [PSCustomObject]@{
				Element = $Element
				Symbol = $Symbol
			}
			Continue
		}
		If ($OutputLine.Length -gt 0) {
			$Result.Issues += $OutputLine
			Continue
		}
	}
	Write-Output -InputObject ([PSCustomObject]$Result)
}
Function Register-YaraCustomAsset {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$RootPath,
		[Parameter(Mandatory = $True, Position = 1)][String]$Selection
	)
	[String]$RootPathRegExEscape = "^$([RegEx]::Escape($RootPath))[\\/]"
	[String[]]$RootChildItem = Get-ChildItem -LiteralPath $RootPath -Recurse -Force -File |
		Where-Object -FilterScript { $_.Extension -iin @(
			'.yar',
			'.yara',
			'.yarac',
			'.yarc'
		) } |
		ForEach-Object -Process { $_.FullName -ireplace $RootPathRegExEscape, '' }
	[String[]]$RootChildItemSelect = $RootChildItem |
		Where-Object -FilterScript { $_ -imatch $Selection }
	$Script:RulesPath += $RootChildItemSelect |
		ForEach-Object -Process { Join-Path -Path $RootPath -ChildPath $_ }
}
Function Register-YaraUnofficialAsset {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Selection
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
Function Register-YaraUnofficialAssetFallback {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	If ($RulesPath.Count -eq 0) {
		Register-YaraUnofficialAsset -Selection '.+'
	}
}
Export-ModuleMember -Function @(
	'Invoke-Yara',
	'Register-YaraCustomAsset',
	'Register-YaraUnofficialAsset',
	'Register-YaraUnofficialAssetFallback'
)
