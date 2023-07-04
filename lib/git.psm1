#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'datetime',
		'token'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[Hashtable[]]$GitCommitsProperties = @(
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; AsType = [DateTime] },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b'; IsMultipleLine = $True },
	@{ Name = 'CommitHash'; Placeholder = '%H'; AsIndex = $True },
	@{ Name = 'CommitterDate'; Placeholder = '%cI'; AsType = [DateTime] },
	@{ Name = 'CommitterEmail'; Placeholder = '%ce' },
	@{ Name = 'CommitterName'; Placeholder = '%cn' },
	@{ Name = 'Encoding'; Placeholder = '%e' },
	@{ Name = 'Notes'; Placeholder = '%N'; IsMultipleLine = $True },
	@{ Name = 'ParentHashes'; Placeholder = '%P'; IsArraySpace = $True },
	@{ Name = 'ReflogIdentityEmail'; Placeholder = '%ge' },
	@{ Name = 'ReflogIdentityName'; Placeholder = '%gn' },
	@{ Name = 'ReflogSelector'; Placeholder = '%gD' },
	@{ Name = 'ReflogSubject'; Placeholder = '%gs' },
	@{ Name = 'Subject'; Placeholder = '%s' },
	@{ Name = 'TreeHash'; Placeholder = '%T' }
)
[Hashtable]$GitCommitsPropertyIndexer = $GitCommitsProperties |
	Where-Object -FilterScript { $_.AsIndex } |
	Select-Object -Index 0
[Byte]$DelimiterTokenCountPerCommit = $GitCommitsProperties.Count - 1
$Null = git --no-pager config --global --add 'safe.directory' '/github/workspace'
Function Disable-GitLfsProcess {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Write-Host -Object 'Config Git LFS.'
	Try {
		git --no-pager config --global 'filter.lfs.process' 'git-lfs filter-process --skip' |
			Write-GitHubActionsDebug -SkipEmptyLine
		git --no-pager config --global 'filter.lfs.smudge' 'git-lfs smudge --skip -- %f' |
			Write-GitHubActionsDebug -SkipEmptyLine
	}
	Catch {
		Write-GitHubActionsWarning -Message "Unable to config Git LFS: $_"
	}
}
Function Get-GitCommitIndex {
	[CmdletBinding()]
	[OutputType([String[]])]
	Param (
		[Switch]$SortFromOldest
	)
	Try {
		[String[]]$Result = Invoke-Expression -Command "git --no-pager log --format=`"$($GitCommitsPropertyIndexer.Placeholder)`" --no-color --all --reflog$($SortFromOldest.IsPresent ? ' --reverse' : '')"
		If ($LASTEXITCODE -ne 0) {
			Throw (
				$Result |
					Join-String -Separator "`n"
			)
		}
		Write-Output -InputObject $Result
	}
	Catch {
		Write-GitHubActionsError -Message "Unexpected Git database issue: $_"
		Write-Output -InputObject @()
	}
}
Function Get-GitCommitMeta {
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Index
	)
	Do {
		Try {
			[String]$DelimiterToken = "=====$(New-RandomToken)====="
			[String[]]$Result = Invoke-Expression -Command "git --no-pager show --format=`"$(
				$GitCommitsProperties |
					Select-Object -ExpandProperty 'Placeholder' |
					Join-String -Separator "%n$DelimiterToken%n"
			)`" --no-color --no-patch `"$Index`""
			If ($LASTEXITCODE -ne 0) {
				Throw (
					$Result |
						Join-String -Separator "`n"
				)
			}
		}
		Catch {
			Write-GitHubActionsError -Message "Unexpected Git database issue: $_"
			Return
		}
	}
	While ((
		$Result |
			Where-Object -FilterScript { $_ -ieq $DelimiterToken } |
			Measure-Object |
			Select-Object -ExpandProperty 'Count'
	) -ine $DelimiterTokenCountPerCommit)
	[String[]]$ResultResolve = (
		$Result |
			Join-String -Separator "`n"
	) -isplit ([RegEx]::Escape("`n$DelimiterToken`n"))
	If ($GitCommitsProperties.Count -ne $ResultResolve.Count) {
		Write-GitHubActionsError -Message 'Unexpected Git database issue: Columns are not match!'
		Return
	}
	[Hashtable]$GitCommitMeta = @{}
	For ([UInt64]$Line = 0; $Line -lt $ResultResolve.Count; $Line += 1) {
		[Hashtable]$GitCommitsPropertiesCurrent = $GitCommitsProperties[$Line]
		[String]$Value = $ResultResolve[$Line]
		If ($GitCommitsPropertiesCurrent.IsArraySpace) {
			$GitCommitMeta.($GitCommitsPropertiesCurrent.Name) = $Value -isplit ' '
		}
		ElseIf ($GitCommitsPropertiesCurrent.AsType) {
			$GitCommitMeta.($GitCommitsPropertiesCurrent.Name) = $Value -as $GitCommitsPropertiesCurrent.AsType
		}
		Else {
			$GitCommitMeta.($GitCommitsPropertiesCurrent.Name) = $Value
		}
	}
	[PSCustomObject]$GitCommitMeta |
		Write-Output
}
Function Test-IsGitRepository {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param ()
	Try {
		[String]$Result = git --no-pager rev-parse --is-inside-work-tree *>&1 |
			Join-String -Separator "`n"
		If ($Result -ine 'True') {
			Throw 'Workspace is not a Git repository!'
		}
		Write-Output -InputObject $True
	}
	Catch {
		Write-GitHubActionsError -Message @"
Unable to integrate with Git: $_ $Result
If this is incorrect, probably Git database is broken and/or invalid.
"@
		Write-Output -InputObject $False
	}
}
Function Test-GitCommitIsIgnore {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][PSCustomObject]$GitCommit,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][Alias('Ignores')][PSCustomObject[]]$Ignore
	)
	ForEach ($IgnoreItem In $Ignore) {
		[UInt64]$IgnoreMatchCount = 0
		ForEach ($GitCommitsProperty In $GitCommitsProperties) {
			If ($Null -ieq $IgnoreItem.($GitCommitsProperty.Name)) {
				Continue
			}
			Try {
				If ($GitCommitsProperty.AsType -ieq [DateTime]) {
					If (($IgnoreItem.($GitCommitsProperty.Name) -as [String]) -imatch '^-[gl][et] \d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ$') {
						[String]$CompareOperator, [String]$IgnoreTimestampRaw = $IgnoreItem.($GitCommitsProperty.Name) -isplit ' '
						[DateTime]$IgnoreTimestamp = Get-Date -Date $IgnoreTimestampRaw
						Switch -Exact ($CompareOperator) {
							'-ge' {
								If ($GitCommit.($GitCommitsProperty.Name) -ge $IgnoreTimestamp) {
									$IgnoreMatchCount += 1
									Break
								}
							}
							'-gt' {
								If ($GitCommit.($GitCommitsProperty.Name) -gt $IgnoreTimestamp) {
									$IgnoreMatchCount += 1
									Break
								}
							}
							'-le' {
								If ($GitCommit.($GitCommitsProperty.Name) -le $IgnoreTimestamp) {
									$IgnoreMatchCount += 1
									Break
								}
							}
							'-lt' {
								If ($GitCommit.($GitCommitsProperty.Name) -lt $IgnoreTimestamp) {
									$IgnoreMatchCount += 1
									Break
								}
							}
						}
					}
					Else {
						If ((ConvertTo-DateTimeIsoString -InputObject $GitCommit.($GitCommitsProperty.Name)) -imatch $IgnoreItem.($GitCommitsProperty.Name)) {
							$IgnoreMatchCount += 1
						}
					}
				}
				ElseIf ($GitCommitsProperty.IsArraySpace) {
					If (($GitCommit.($GitCommitsProperty.Name) -isplit ' ') -inotmatch $IgnoreItem.($GitCommitsProperty.Name)) {
						$IgnoreMatchCount += 1
					}
				}
				Else {
					If ($GitCommit.($GitCommitsProperty.Name) -inotmatch $IgnoreItem.($GitCommitsProperty.Name)) {
						$IgnoreMatchCount += 1
					}
				}
			}
			Catch {}
		}
		If ($IgnoreMatchCount -ge $IgnoreItem.PSObject.Properties.Name.Count) {
			Write-Output -InputObject $True
			Return
		}
	}
	Write-Output -InputObject $False
}
Export-ModuleMember -Function @(
	'Disable-GitLfsProcess',
	'Get-GitCommitIndex',
	'Get-GitCommitMeta',
	'Test-IsGitRepository',
	'Test-GitCommitIsIgnore'
)
