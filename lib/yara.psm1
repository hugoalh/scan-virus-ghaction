#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'splat-parameter'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[PSCustomObject[]]$UnofficialAssetIndexTable = @()
Function Invoke-Yara {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Targets')][String[]]$Target
	)
	[Hashtable]$Result = @{
		ErrorMessage = @()
		Found = @()
	}
	$TargetListFile = New-TemporaryFile
	Set-Content -LiteralPath $TargetListFile -Value (
		$Target |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	[String[]]$Output = @()
	ForEach ($_A In (
		$UnofficialAssetIndexTable |
			Where-Object -FilterScript { $_.Select }
	)) {
		Try {
			$Output += Invoke-Expression -Command "yara --no-warnings --scan-list `"$($_A.FilePath)`" `"$($TargetListFile.FullName)`"" |
				Write-GitHubActionsDebug -PassThru
		}
		Catch {
			$Result.ErrorMessage += $_
		}
	}
	Remove-Item -LiteralPath $TargetListFile -Force -Confirm:$False
	<#
	If ($Output.Count -gt 0) {
		Write-GitHubActionsDebug -Message (
			$Output |
				Join-String -Separator "`n"
		)
	}
	#>
	ForEach ($OutputLine In $Output) {
		If ($OutputLine -imatch "^.+? $GitHubActionsWorkspaceRootRegEx.+$") {
			[String]$Symbol, [String]$Element = $OutputLine -isplit "(?<=^.+?) $GitHubActionsWorkspaceRootRegEx"
			$Result.Found += [PSCustomObject]@{
				Element = $Element
				Symbol = $Symbol
			}
			Continue
		}
		If ($OutputLine.Length -gt 0) {
			$Result.ErrorMessage += $OutputLine
			Continue
		}
	}
	Write-Output -InputObject $Result
}
Function Register-YaraUnofficialAsset {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyCollection()][Alias('Selections')][RegEx[]]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath (Join-Path -Path $Env:GHACTION_SCANVIRUS_PROGRAM_ASSET_YARA -ChildPath $UnofficialAssetIndexFileName) @TsvParameters |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Path.Length -gt 0 } |
		ForEach-Object -Process { [PSCustomObject]@{
			Type = $_.Type
			Name = $_.Name
			FilePath = Join-Path -Path $Env:GHACTION_SCANVIRUS_PROGRAM_ASSET_YARA -ChildPath $_.Path
			Select = Test-StringMatchRegEx -Item $_.Name -Matcher $Selection
		} } |
		Sort-Object -Property @('Type', 'Name')
	[PSCustomObject]@{
		All = $IndexTable.Count
		Select = $IndexTable |
			Where-Object -FilterScript { $_.Select } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	} |
		Format-List |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	$IndexTable |
		Format-Table -Property @(
			@{ Name = ''; Expression = { $_.Select ? '+' : '' } },
			'Type',
			'Name'
		) -AutoSize:$False -Wrap |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	$Script:UnofficialAssetIndexTable += $IndexTable
}
Export-ModuleMember -Function @(
	'Invoke-Yara',
	'Register-YaraUnofficialAsset'
)
