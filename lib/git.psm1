#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
		'datetime',
		'internal',
		'token'
	) |
		ForEach-Object -Process { Join-Path -Path $PSScriptRoot -ChildPath "$_.psm1" }
) -Scope 'Local'
[Hashtable[]]$GitCommitsProperties = @(
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; AsSort = $True; AsType = [DateTime] },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b'; IsMultipleLine = $True },
	@{ Name = 'CommitHash'; Placeholder = '%H'; AsIndex = $True },
	@{ Name = 'CommitterDate'; Placeholder = '%cI'; AsType = [DateTime] },
	@{ Name = 'CommitterEmail'; Placeholder = '%ce' },
	@{ Name = 'CommitterName'; Placeholder = '%cn' },
	@{ Name = 'Encoding'; Placeholder = '%e' },
	@{ Name = 'GPGSignatureKey'; Placeholder = '%GK' },
	@{ Name = 'GPGSignatureKeyFingerprint'; Placeholder = '%GF' },
	@{ Name = 'GPGSignaturePrimaryKeyFingerprint'; Placeholder = '%GP' },
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
	Select-Object -First 1
[Hashtable]$GitCommitsPropertySorter = $GitCommitsProperties |
	Where-Object -FilterScript { $_.AsSort } |
	Select-Object -First 1
[UInt16]$DelimiterTokenCountPerCommit = $GitCommitsProperties.Count - 1
Function Get-GitCommits {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param (
		[Switch]$SortFromOldest
	)
	Try {
		$Null = git config --global --add 'safe.directory' '/github/workspace'
		[String]$IsGitRepositoryResult = git rev-parse --is-inside-work-tree |
			Join-String -Separator "`n"
		If ($IsGitRepositoryResult -ine 'True') {
			Throw 'Workspace is not a Git repository!'
		}
	}
	Catch {
		Write-GitHubActionsError -Message @"
Unable to integrate with Git: $_
If this is incorrect, probably Git database is broken and/or invalid.
"@
		Return
	}
	Invoke-Expression -Command "git --no-pager log --format=`"$($GitCommitsPropertyIndexer.Placeholder)`" --no-color --all --reflog" |
		ForEach-Object -Process {
			[String]$GitCommitId = $_# This reassign aims to prevent `$_` got overwrite.
			Do {
				Try {
					[String]$DelimiterToken = "=====$(New-RandomToken)====="
					[String[]]$GitCommitMetaRaw0 = Invoke-Expression -Command "git --no-pager show --format=`"$(
						$GitCommitsProperties |
							Select-Object -ExpandProperty 'Placeholder' |
							Join-String -Separator "%n$DelimiterToken%n"
					)`" --no-color --no-patch `"$GitCommitId`""
					If ($LASTEXITCODE -ne 0) {
						Throw (
							$GitCommitMetaRaw0 |
								Join-String -Separator "`n"
						)
					}
				}
				Catch {
					Write-GitHubActionsError -Message "Unexpected Git database issue: $_"
					Return
				}
				[UInt64]$DelimiterTokenCount = $GitCommitMetaRaw0 |
					Where-Object -FilterScript { $_ -ieq $DelimiterToken } |
					Measure-Object |
					Select-Object -ExpandProperty 'Count'
			}
			While ($DelimiterTokenCount -ine $DelimiterTokenCountPerCommit)
			[String[]]$GitCommitMetaRaw1 = (
				$GitCommitMetaRaw0 |
					Join-String -Separator "`n"
			) -isplit ([RegEx]::Escape("`n$DelimiterToken`n"))
			If ($GitCommitsProperties.Count -ne $GitCommitMetaRaw1.Count) {
				Write-GitHubActionsError -Message 'Unexpected Git database issue: Columns are not match!'
				Return
			}
			[Hashtable]$GitCommitMeta = @{}
			For ([UInt64]$Line = 0; $Line -lt $GitCommitMetaRaw1.Count; $Line++) {
				[Hashtable]$GitCommitsPropertiesCurrent = $GitCommitsProperties[$Line]
				[String]$Value = $GitCommitMetaRaw1[$Line]
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
		} |
		Sort-Object -Property $GitCommitsPropertySorter.Name -Descending:(!$SortFromOldest.IsPresent) |
		Write-Output
}
Function Test-GitCommitIsIgnore {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][PSCustomObject]$GitCommit,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][Alias('Ignores')][PSCustomObject[]]$Ignore
	)
	ForEach ($IgnoreItem In $Ignore) {
		[UInt16]$IgnoreMatchCount = 0
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
	'Get-GitCommits',
	'Test-GitCommitIsIgnore'
)
