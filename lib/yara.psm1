#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'internal',
		'splat-parameter'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Function Invoke-Yara {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][Alias('Targets')][String[]]$Target,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Assets')][PSCustomObject[]]$Asset,
		[Parameter(Mandatory = $True, Position = 2)][ValidateRange(1, [Byte]::MaxValue)][Alias('Threads')][Byte]$Thread
	)
	[Hashtable]$Result = @{
		ErrorMessage = @()
		ExitCode = 0
		Found = @()
		Output = @()
	}
	$TargetListFile = New-TemporaryFile
	Set-Content -LiteralPath $TargetListFile -Value (
		$Target |
			Join-String -Separator "`n"
	) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
	ForEach ($_A In (
		$Asset |
			Where-Object -FilterScript { $_.Select } |
			ForEach-Object -Parallel {
				[Hashtable]$ResultCurrent = @{
					ErrorMessage = @()
					ExitCode = 0
					Output = @()
				}
				Try {
					$ResultCurrent.Output += Invoke-Expression -Command "yara --no-warnings --scan-list `"$($_.FilePath)`" `"$(($Using:TargetListFile).FullName)`""
				}
				Catch {
					$ResultCurrent.ErrorMessage += $_
					$ResultCurrent.ExitCode = $LASTEXITCODE
				}
				Write-Output -InputObject $ResultCurrent
			} -ThrottleLimit $Thread
	)) {
		$Result.ErrorMessage += $_A.ErrorMessage
		$Result.Output += $_A.Output
	}
	<#
	ForEach ($_A In (
		$Asset |
			Where-Object -FilterScript { $_.Select }
	)) {
		Try {
			$Result.Output += Invoke-Expression -Command "yara --no-warnings --scan-list `"$($_A.FilePath)`" `"$($TargetListFile.FullName)`""
		}
		Catch {
			$Result.ErrorMessage += $_
			$Result.ExitCode = $LASTEXITCODE
		}
	}
	#>
	Remove-Item -LiteralPath $TargetListFile -Force -Confirm:$False
	If ($Result.Output.Count -gt 0) {
		Write-GitHubActionsDebug -Message (
			$Result.Output |
				Join-String -Separator "`n"
		)
	}
	ForEach ($OutputLine In $Result.Output) {
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
		ForEach-Object -Process {
			$SelectResolve = Test-StringMatchRegEx -Item $_.Name -Matcher $Selection
			[PSCustomObject]@{
				Type = $_.Type
				Name = $_.Name
				FilePath = Join-Path -Path $Env:GHACTION_SCANVIRUS_PROGRAM_ASSET_YARA -ChildPath $_.Path
				Select = $SelectResolve -ine $False
				SelectBy = $SelectResolve -ine $False ? $SelectResolve.ToString() : ''
			}
		} |
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
		Write-Host
	$IndexTable |
		Format-Table -Property @(
			'Type',
			'Name',
			@{ Expression = 'Select'; Alignment = 'Right' },
			'SelectBy'
		) -AutoSize -Wrap |
		Out-String -Width 120 |
		Write-Host
	Write-Output -InputObject $IndexTable
}
Export-ModuleMember -Function @(
	'Invoke-Yara',
	'Register-YaraUnofficialAsset'
)
