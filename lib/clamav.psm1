#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'control'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[String[]]$AllowExtensions = @(
	'*.cat',
	'*.cbc',
	'*.cdb',
	'*.crb',
	'*.fp',
	'*.ftm',
	'*.gdb',
	'*.hdb',
	'*.hdu',
	'*.hsb',
	'*.hsu',
	'*.idb',
	'*.ign',
	'*.ign2',
	'*.info',
	'*.ldb',
	'*.ldu',
	'*.mdb',
	'*.mdu',
	'*.msb',
	'*.msu',
	'*.ndb',
	'*.ndu',
	'*.pdb',
	'*.pwdb',
	'*.sfp',
	'*.wdb',
	'*.yar',
	'*.yara'
)
Function Invoke-ClamAVScan {
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
	Try {
		$Output += clamdscan --fdpass --file-list="$($ScanListFile.FullName)" --multiscan *>&1 |
			Write-GitHubActionsDebug -PassThru
	}
	Catch {
		$Result.Issues += $_
	}
	Finally {
		$LASTEXITCODE = 0
		Remove-Item -LiteralPath $ScanListFile -Force -Confirm:$False
	}
	ForEach ($OutputLine In (
		$Output |
			ForEach-Object -Process { $_ -ireplace "^$($CurrentWorkingDirectoryRegExEscape)[\\/]", '' }
	)) {
		If ($OutputLine -imatch '^[-=]+\s*SCAN SUMMARY\s*[-=]+$') {
			Break
		}
		If (
			$OutputLine -imatch ': OK$' -or
			$OutputLine -imatch '^\s*$'
		) {
			Continue
		}
		If ($OutputLine -imatch ': .+ FOUND$') {
			[String]$Element, [String]$Symbol = ($OutputLine -ireplace ' FOUND$', '') -isplit '(?<=^.+?): '
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
Function Register-ClamAVCustomAssets {
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
	[PSCustomObject[]]$Issues = @()
	ForEach ($Element In (
		$Elements |
			Where-Object -FilterScript { $_.IsSelect }
	)) {
		Try {
			Copy-Item -LiteralPath $Element.FullName -Destination (Join-Path -Path $Env:SCANVIRUS_GHACTION_CLAMAV_DATA -ChildPath ($Element.Path -ireplace '[\\/]', '__')) -Confirm:$False
		}
		Catch {
			$Issues += [PSCustomObject]@{
				Element = $Element.FullName
				Reason = $_
			}
		}
	}
	If ($Issues.Count -gt 0) {
		Write-GitHubActionsFail -Message @"
Unable to register ClamAV custom assets:

$(
$Issues |
	ForEach-Object -Process { "$($_.Element): $($_.Reason)" } |
	Join-String -Separator "`n" -FormatString '- {0}'
)
"@
	}
}
Function Register-ClamAVUnofficialAssets {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSETS_CLAMAV -ChildPath 'index.tsv') @TsvParameters |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Type -ine 'Unusable' -and $_.Path.Length -gt 0 } |
		Sort-Object -Property @('Type', 'Name')
	[String[]]$IndexRegister = @()
	ForEach ($Index In $IndexTable) {
		If ($Index.Name -imatch $Selection) {
			$IndexRegister += $Index.Name
			If ($Index.Dependencies.Length -gt 0) {
				$IndexRegister += $Index.Dependencies -isplit ','
			}
		}
	}
	[PSCustomObject[]]$IndexTableSelect = $IndexTable |
		Where-Object -FilterScript { $_.Name -iin $IndexRegister }
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
	[PSCustomObject[]]$Issues = @()
	ForEach ($IndexSelect In $IndexTableSelect) {
		[String]$PathSource = Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSETS_CLAMAV -ChildPath $IndexSelect.Path
		[String]$PathDestination = Join-Path -Path $Env:SCANVIRUS_GHACTION_CLAMAV_DATA -ChildPath ($IndexSelect.Path -ireplace '[\\/]', '__')
		Try {
			Copy-Item -LiteralPath $PathSource -Destination $PathDestination -Confirm:$False
		}
		Catch {
			$Issues += [PSCustomObject]@{
				Name = $IndexSelect.Name
				Reason = $_
			}
		}
	}
	If ($Issues.Count -gt 0) {
		Write-GitHubActionsError -Message @"
Unable to register ClamAV unofficial assets:

$(
$Issues |
	ForEach-Object -Process { "$($_.Name): $($_.Reason)" } |
	Join-String -Separator "`n" -FormatString '- {0}'
)
"@
	}
	Write-Output -InputObject ([PSCustomObject]@{
		Issues = $Issues |
			ForEach-Object -Process { "Unable to register ClamAV unofficial asset ``$($_.Name)``: $($_.Reason)" }
	})
}
Function Start-ClamAVDaemon {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		[String]$Result = clamd *>&1 |
			Join-String -Separator "`n"
		If ($LASTEXITCODE -ne 0) {
			Throw $Result
		}
		If ($Result.Length -gt 0) {
			Write-GitHubActionsWarning -Message $Result
		}
	}
	Catch {
		Write-GitHubActionsFail -Message "Unable to start ClamAV daemon: $_"
	}
}
Function Stop-ClamAVDaemon {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Get-Process -Name 'clamd' -ErrorAction 'Continue' |
		Stop-Process -ErrorAction 'Continue'
}
Function Update-ClamAV {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		freshclam --verbose *>&1 |
			Write-GitHubActionsDebug
	}
	Catch {
		Write-GitHubActionsWarning -Message @"
Unable to update ClamAV: $_
This is fine, but the local assets maybe outdated.
"@
	}
}
Export-ModuleMember -Function @(
	'Invoke-ClamAVScan',
	'Register-ClamAVCustomAssets',
	'Register-ClamAVUnofficialAssets',
	'Start-ClamAVDaemon',
	'Stop-ClamAVDaemon',
	'Update-ClamAV'
)
