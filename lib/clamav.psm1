#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'internal',
		'splat-parameter'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
Function Invoke-ClamAVScan {
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
	Try {
		$Output += Invoke-Expression -Command "clamdscan --fdpass --file-list=`"$($TargetListFile.FullName)`" --multiscan" |
			Write-GitHubActionsDebug -PassThru
	}
	Catch {
		$Result.ErrorMessage += $_
	}
	Finally {
		Remove-Item -LiteralPath $TargetListFile -Force -Confirm:$False
	}
	<#
	If ($Output.Count -gt 0) {
		Write-GitHubActionsDebug -Message (
			$Output |
				Join-String -Separator "`n"
		)
	}
	#>
	ForEach ($OutputLine In (
		$Output |
			ForEach-Object -Process { $_ -ireplace "^$GitHubActionsWorkspaceRootRegEx", '' }
	)) {
		If ($OutputLine -imatch '^[-=]+\s*SCAN SUMMARY\s*[-=]+$') {
			Break
		}
		If (
			($OutputLine -imatch ': OK$') -or
			($OutputLine -imatch '^\s*$')
		) {
			Continue
		}
		If ($OutputLine -imatch ': .+ FOUND$') {
			[String]$Element, [String]$Symbol = ($OutputLine -ireplace ' FOUND$', '') -isplit '(?<=^.+?): '
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
Function Register-ClamAVUnofficialAsset {
	[CmdletBinding()]
	[OutputType([Hashtable])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][AllowEmptyCollection()][Alias('Selections')][RegEx[]]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath (Join-Path -Path $Env:GHACTION_SCANVIRUS_PROGRAM_ASSET_CLAMAV -ChildPath $UnofficialAssetIndexFileName) @TsvParameters |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Path.Length -gt 0 } |
		ForEach-Object -Process { [PSCustomObject]@{
			Type = $_.Type
			Name = $_.Name
			FilePath = Join-Path -Path $Env:GHACTION_SCANVIRUS_PROGRAM_ASSET_CLAMAV -ChildPath $_.Path
			DatabaseFileName = $_.Path -ireplace '\/', '_'
			ApplyIgnores = $_.ApplyIgnores
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
		Write-Host
	$IndexTable |
		Format-Table -Property @(
			@{ Name = ''; Expression = { $_.Select ? '+' : '' } },
			'Type',
			'Name'
		) -AutoSize:$False -Wrap |
		Out-String -Width 120 |
		Write-Host
	[String[]]$AssetsApplyPaths = @()
	[String[]]$AssetsApplyIssues = @()
	ForEach ($IndexApply In (
		$IndexTable |
			Where-Object -FilterScript { $_.Select }
	)) {
		[String]$DestinationFilePath = Join-Path -Path $Env:GHACTION_SCANVIRUS_CLAMAV_DATA -ChildPath $IndexApply.DatabaseFileName
		Try {
			Copy-Item -LiteralPath $IndexApply.FilePath -Destination $DestinationFilePath -Confirm:$False
			$AssetsApplyPaths += $DestinationFilePath
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial asset ``$($IndexApply.Name)``: $_"
			$AssetsApplyIssues += $IndexApply.Name
		}
	}
	ForEach ($ApplyIgnoreRaw In (
		$IndexTable |
			Where-Object -FilterScript { $_.Select -and $_.ApplyIgnores.Length -gt 0 } |
			Select-Object -ExpandProperty 'ApplyIgnores' |
			ForEach-Object -Begin {
				[String[]]$Result = @()
			} -Process {
				$Result += $_ -isplit ',|;' |
					ForEach-Object -Process { $_.Trim() } |
					Where-Object -FilterScript { $_.Length -gt 0 }
			} -End {
				$Result |
					Sort-Object -Unique |
					Write-Output
			}
	)) {
		[PSCustomObject]$IndexApplyIgnore = $IndexTable |
			Where-Object -FilterScript { $_.Name -ieq $ApplyIgnoreRaw }
			Select-Object -Index 0
		[String]$DestinationFilePath = Join-Path -Path $Env:GHACTION_SCANVIRUS_CLAMAV_DATA -ChildPath $IndexApplyIgnore.DatabaseFileName
		If (
			$DestinationFilePath -iin $AssetsApplyPaths -or
			$IndexApplyIgnore.Name -iin $AssetsApplyIssues
		) {
			Continue
		}
		Try {
			Copy-Item -LiteralPath $IndexApplyIgnore.FilePath -Destination $DestinationFilePath -Confirm:$False
			$AssetsApplyPaths += $DestinationFilePath
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to apply ClamAV unofficial asset ``$($IndexApplyIgnore.Name)``: $_"
			$AssetsApplyIssues += $IndexApplyIgnore.Name
		}
	}
	Write-Output -InputObject @{
		ApplyIssues = $AssetsApplyIssues
		ApplyPaths = $AssetsApplyPaths
		IndexTable = $IndexTable
	}
}
Function Start-ClamAVDaemon {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Host -Object 'Start ClamAV daemon.'
	Try {
		clamd |
			Write-GitHubActionsDebug -SkipEmptyLine
	}
	Catch {
		Write-GitHubActionsFail -Message "Unexpected issues when start ClamAV daemon: $_"
	}
}
Function Stop-ClamAVDaemon {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Host -Object 'Stop ClamAV daemon.'
	Get-Process -Name 'clamd' -ErrorAction 'Continue' |
		Stop-Process -ErrorAction 'Continue'
}
Function Update-ClamAV {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Host -Object 'Update ClamAV via FreshClam.'
	Try {
		freshclam --verbose |
			Write-GitHubActionsDebug
		If ($LASTEXITCODE -ne 0) {
			Throw "Exit code is ``$LASTEXITCODE``"
		}
	}
	Catch {
		Write-GitHubActionsWarning -Message @"
Unexpected issues when update ClamAV via FreshClam: $_
This is fine, but the local assets maybe outdated.
"@
	}
}
Export-ModuleMember -Function @(
	'Invoke-ClamAVScan',
	'Register-ClamAVUnofficialAsset',
	'Start-ClamAVDaemon',
	'Stop-ClamAVDaemon',
	'Update-ClamAV'
)
