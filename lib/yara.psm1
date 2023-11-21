#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name @(
	(Join-Path -Path $PSScriptRoot -ChildPath 'control.psm1')
) -Scope 'Local'
[String[]]$AllowExtensions = @(
	'*.yar',
	'*.yara'
)
[String[]]$RulesPath = @()
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
			$Output += $_
		}
		Finally {
			$LASTEXITCODE = 0
		}
	}
	Remove-Item -LiteralPath $ScanListFile -Force -Confirm:$False
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
Function Register-YaraCustomAssets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$RootPath,
		[Parameter(Mandatory = $True, Position = 1)][String]$Selection
	)
	[String]$RootPathRegExEscape = "^$([RegEx]::Escape($RootPath))[\\/]"
	[PSCustomObject[]]$Elements = Get-ChildItem -LiteralPath $RootPath -Include $AllowExtensions -Recurse -Force -File |
		Sort-Object -Property @('FullName') |
		ForEach-Object -Process {
			[Hashtable]$ElementObject = @{
				FullName = $_.FullName
				Path = $_.FullName -ireplace $RootPathRegExEscape, ''
				Size = $_.Length
			}
			$ElementObject.IsSelect = $ElementObject.Path -imatch $Selection
			Write-Output -InputObject ([PSCustomObject]$ElementObject)
		}
	[PSCustomObject]@{
		All = $Elements.Count
		Select = $Elements |
			Where-Object -FilterScript { $_.IsSelect } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	} |
		Format-List |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	$Elements |
		Format-Table -Property @(
			@{ Name = ''; Expression = { $_.IsSelect ? '+' : '' } },
			@{ Expression = 'Size'; Alignment = 'Right' },
			'Path'
		) -AutoSize:$False -Wrap |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	$Script:RulesPath += $Elements |
		Where-Object -FilterScript { $_.IsSelect } |
		Select-Object -ExpandProperty 'FullName'
}
Function Register-YaraUnofficialAssets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSETS_YARA -ChildPath 'index.tsv') @TsvParameters |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Type -ine 'Unusable' -and $_.Path.Length -gt 0 } |
		Sort-Object -Property @('Type', 'Name')
	[PSCustomObject[]]$IndexTableSelect = $IndexTable |
		Where-Object -FilterScript { $_.Name -imatch $Selection }
	[PSCustomObject]@{
		All = $IndexTable.Count
		Select = $IndexTableSelect.Count
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
		ForEach-Object -Process { Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSETS_YARA -ChildPath $_.Path }
}
Function Register-YaraUnofficialAssetsFallback {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	If ($RulesPath.Count -eq 0) {
		Register-YaraUnofficialAssets -Selection '.+'
	}
}
Export-ModuleMember -Function @(
	'Invoke-Yara',
	'Register-YaraCustomAssets',
	'Register-YaraUnofficialAssets',
	'Register-YaraUnofficialAssetsFallback'
)
