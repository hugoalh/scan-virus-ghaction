#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name @(
	(Join-Path -Path $PSScriptRoot -ChildPath 'control.psm1')
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
		[Parameter(Mandatory = $True, Position = 0)][String]$Session,
		[Parameter(Mandatory = $True, Position = 1)][Alias('Paths')][String[]]$Path
	)
	[PSCustomObject[]]$Founds = @()
	[String[]]$Issues = @()
	[String[]]$Output = @()
	Try {
		$ScanListFile = New-TemporaryFile
		Set-Content -LiteralPath $ScanListFile -Value (
			$Path |
				Join-String -Separator "`n"
		) -Confirm:$False -NoNewline -Encoding 'UTF8NoBOM'
		$Output += clamdscan --fdpass "--file-list=$($ScanListFile.FullName)" --multiscan *>&1 |
			Write-GitHubActionsDebug -PassThru
	}
	Catch {
		[String]$Message = "[$Session] Unable to invoke ClamAV: $_"
		Write-GitHubActionsError -Message $Message
		$Issues += $Message
	}
	Finally {
		$LASTEXITCODE = 0
		If ($ScanListFile) {
			Remove-Item -LiteralPath $ScanListFile -Force -Confirm:$False -ErrorAction 'Continue'
		}
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
			[String]$Element, [String]$Symbol = $OutputLine -ireplace ' FOUND$', '' -isplit '(?<=^.+?): '
			$Founds += [PSCustomObject]@{
				Element = $Element
				Symbol = $Symbol
			}
			Continue
		}
		If ($OutputLine.Length -gt 0) {
			[String]$Message = "[$Session] Unexpected issue from ClamAV: $OutputLine"
			Write-GitHubActionsError -Message $Message
			$Issues += $Message
			Continue
		}
	}
	Write-Output -InputObject ([PSCustomObject]@{
		Founds = $Founds
		Issues = $Issues
	})
}
Function Register-ClamAVCustomAssets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$RootPath,
		[Parameter(Mandatory = $True, Position = 1)][String]$Selection,
		[Parameter(Position = 2)][ValidateSet('Error', 'Stop', 'Warn')][String]$IssueAction = 'Stop'
	)
	If (!(Test-Path -LiteralPath $RootPath -PathType 'Container')) {
		[String]$Message = "``$RootPath`` is not a valid and exist ClamAV custom assets absolute directory path!"
		Switch ($IssueAction) {
			'Error' {
				Write-GitHubActionsError -Message $Message
			}
			'Stop' {
				Write-GitHubActionsFail -Message $Message
			}
			'Warn' {
				Write-GitHubActionsWarning -Message $Message
			}
		}
		Return
	}
	[String]$RootPathRegExEscape = "^$([RegEx]::Escape($RootPath))[\\/]"
	[UInt64]$ElementsCountAll = Get-ChildItem -LiteralPath $RootPath -Recurse -Force -File |
		Measure-Object |
		Select-Object -ExpandProperty 'Count'
	[PSCustomObject[]]$Elements = Get-ChildItem -LiteralPath $RootPath -Include $AllowExtensions -Recurse -Force -File |
		Sort-Object -Property @('FullName') |
		ForEach-Object -Process {
			[String]$Path = $_.FullName -ireplace $RootPathRegExEscape, ''
			Write-Output -InputObject ([PSCustomObject]@{
				FullName = $_.FullName
				Path = $Path
				IsSelect = $Path -imatch $Selection
			})
		}
	[PSCustomObject]@{
		Root = $RootPath
		All = $ElementsCountAll
		Known = $Elements.Count
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
			@{ Name = ' '; Expression = { $_.IsSelect ? '+' : '' } },
			'Path'
		) -AutoSize:$False -Wrap |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	[Boolean]$HasIssues = $False
	ForEach ($Element In (
		$Elements |
			Where-Object -FilterScript { $_.IsSelect }
	)) {
		Try {
			Copy-Item -LiteralPath $Element.FullName -Destination (Join-Path -Path $Env:SCANVIRUS_GHACTION_CLAMAV_DATA -ChildPath ($Element.Path -ireplace '[\\/]', '__')) -Confirm:$False
		}
		Catch {
			$HasIssues = $True
			[String]$Message = "Unable to register ClamAV custom asset ``$($Element.FullName)``: $_"
			Switch ($IssueAction) {
				'Error' {
					Write-GitHubActionsError -Message $Message
				}
				'Warn' {
					Write-GitHubActionsWarning -Message $Message
				}
			}
		}
	}
	If ($HasIssues -and $IssueAction -ieq 'Stop') {
		Exit 1
	}
}
Function Register-ClamAVUnofficialAssets {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Selection,
		[Parameter(Position = 1)][ValidateSet('Error', 'Stop', 'Warn')][String]$IssueAction = 'Stop'
	)
	[PSCustomObject[]]$IndexTable = Import-Csv -LiteralPath (Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSETS_CLAMAV -ChildPath 'index.tsv') @TsvParameters |
		Where-Object -FilterScript { $_.Type -ine 'Group' -and $_.Type -ine 'Unusable' -and $_.Path.Length -gt 0 } |
		Sort-Object -Property @('Type', 'Name')
	[String[]]$IndexRegister = @()
	ForEach ($Index In $IndexTable) {
		If ($Index.Name -imatch $Selection) {
			$IndexRegister += $Index.Name
			If ($Index.Dependencies.Length -gt 0) {
				$IndexRegister += $Index.Dependencies -isplit ',' |
					ForEach-Object -Process { $_.Trim() } |
					Where-Object -FilterScript { $_.Length -gt 0 }
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
			@{ Name = ' '; Expression = { ($_.Name -iin $IndexTableSelect.Name) ? '+' : '' } },
			'Type',
			'Name'
		) -AutoSize:$False -Wrap |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	[Boolean]$HasIssues = $False
	ForEach ($IndexSelect In $IndexTableSelect) {
		[String]$PathSource = Join-Path -Path $Env:SCANVIRUS_GHACTION_ASSETS_CLAMAV -ChildPath $IndexSelect.Path
		[String]$PathDestination = Join-Path -Path $Env:SCANVIRUS_GHACTION_CLAMAV_DATA -ChildPath ($IndexSelect.Path -ireplace '[\\/]', '__')
		Try {
			Copy-Item -LiteralPath $PathSource -Destination $PathDestination -Confirm:$False
		}
		Catch {
			$HasIssues = $True
			[String]$Message = "Unable to register ClamAV unofficial asset ``$($IndexSelect.Name)``: $_"
			Switch ($IssueAction) {
				'Error' {
					Write-GitHubActionsError -Message $Message
				}
				'Warn' {
					Write-GitHubActionsWarning -Message $Message
				}
			}
		}
	}
	If ($HasIssues -and $IssueAction -ieq 'Stop') {
		Exit 1
	}
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
