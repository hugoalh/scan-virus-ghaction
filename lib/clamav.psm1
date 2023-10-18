#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'control'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
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
Function Register-ClamAVCustomAsset {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$RootPath,
		[Parameter(Mandatory = $True, Position = 1)][String]$Selection
	)
	[String]$RootPathRegExEscape = "^$([RegEx]::Escape($RootPath))[\\/]"
	[String[]]$RootChildItem = Get-ChildItem -LiteralPath $RootPath -Recurse -Force -File |
		Where-Object -FilterScript { $_.Extension -iin @(
			'.cat',
			'.cbc',
			'.cdb',
			'.crb',
			'.fp',
			'.ftm',
			'.gdb',
			'.hdb',
			'.hdu',
			'.hsb',
			'.hsu',
			'.idb',
			'.ign',
			'.ign2',
			'.info',
			'.ldb',
			'.ldu',
			'.mdb',
			'.mdu',
			'.msb',
			'.msu',
			'.ndb',
			'.ndu',
			'.pdb',
			'.pwdb',
			'.sfp',
			'.wdb',
			'.yar',
			'.yara'
		) } |
		ForEach-Object -Process { $_.FullName -ireplace $RootPathRegExEscape, '' }
	[String[]]$RootChildItemSelect = $RootChildItem |
		Where-Object -FilterScript { $_ -imatch $Selection }
	[String[]]$Issues = @()
	ForEach ($ItemSelect In $RootChildItemSelect) {
		[String]$PathSource = Join-Path -Path $RootPath -ChildPath $ItemSelect
		[String]$PathDestination = Join-Path -Path $Env:SCANVIRUS_GHACTION_CLAMAV_DATA -ChildPath ($ItemSelect -ireplace '[\\/]', '__')
		Try {
			Copy-Item -LiteralPath $PathSource -Destination $PathDestination -Confirm:$False
		}
		Catch {
			[String]$Message = "Unable to register ClamAV custom asset ``$($ItemSelect)``: $_"
			Write-GitHubActionsError -Message $Message
			$Issues += $Message
		}
	}
	Write-Output -InputObject ([PSCustomObject]@{
		Issues = $Issues
	})
}
Function Register-ClamAVUnofficialAsset {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Selection
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_CLAMAV -ChildPath 'index.tsv') @TsvParameters |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Path.Length -gt 0 } |
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
	[String[]]$Issues = @()
	ForEach ($IndexSelect In $IndexTableSelect) {
		[String]$PathSource = Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSET_CLAMAV -ChildPath $IndexSelect.Path
		[String]$PathDestination = Join-Path -Path $Env:SCANVIRUS_GHACTION_CLAMAV_DATA -ChildPath ($IndexSelect.Path -ireplace '[\\/]', '__')
		Try {
			Copy-Item -LiteralPath $PathSource -Destination $PathDestination -Confirm:$False
		}
		Catch {
			[String]$Message = "Unable to register ClamAV unofficial asset ``$($IndexSelect.Name)``: $_"
			Write-GitHubActionsError -Message $Message
			$Issues += $Message
		}
	}
	Write-Output -InputObject ([PSCustomObject]@{
		Issues = $Issues
	})
}
Function Start-ClamAVDaemon {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		clamd |
			Write-GitHubActionsDebug
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
		freshclam --verbose |
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
	'Register-ClamAVCustomAsset',
	'Register-ClamAVUnofficialAsset',
	'Start-ClamAVDaemon',
	'Stop-ClamAVDaemon',
	'Update-ClamAV'
)
