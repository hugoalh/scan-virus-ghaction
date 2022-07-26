[Hashtable[]]$CommitsProperties = @(
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; Type = [DateTime] },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b'; IsMultipleLine = $True },
	@{ Name = 'CommitHash'; Placeholder = '%H'; AsIndex = $True },
	@{ Name = 'CommitterDate'; Placeholder = '%cI'; Type = [DateTime] },
	@{ Name = 'CommitterEmail'; Placeholder = '%ce' },
	@{ Name = 'CommitterName'; Placeholder = '%cn' },
	@{ Name = 'Encoding'; Placeholder = '%e' },
	@{ Name = 'GPGSignatureKey'; Placeholder = '%GK' },
	@{ Name = 'GPGSignatureKeyFingerprint'; Placeholder = '%GF' },
	@{ Name = 'GPGSignaturePrimaryKeyFingerprint'; Placeholder = '%GP' },
	@{ Name = 'GPGSignatureSigner'; Placeholder = '%GS' },
	@{ Name = 'GPGSignatureStatus'; Placeholder = '%G?' },
	@{ Name = 'GPGSignatureTrustLevel'; Placeholder = '%GP' },
	@{ Name = 'Notes'; Placeholder = '%N'; IsMultipleLine = $True },
	@{ Name = 'ParentHashes'; Placeholder = '%P'; IsArray = $True },
	@{ Name = 'ReflogIdentityEmail'; Placeholder = '%ge' },
	@{ Name = 'ReflogIdentityName'; Placeholder = '%gn' },
	@{ Name = 'ReflogSelector'; Placeholder = '%gD' },
	@{ Name = 'ReflogSubject'; Placeholder = '%gs' },
	@{ Name = 'ShortenedReflogSelector'; Placeholder = '%gd' },
	@{ Name = 'Subject'; Placeholder = '%s' },
	@{ Name = 'TreeHash'; Placeholder = '%T' }
)
[String]$ExpressionSingleLine = 'git --no-pager log --all --format="{0}"'
[String]$ExpressionMultipleLine = 'git --no-pager show --format="{1}" {0}'
Function Get-GitCommitsInformation {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param ()
	[String[]]$DatabaseFilesFullNames = (Get-ChildItem -LiteralPath (Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath '.git') -Recurse -Force -File | Select-Object -ExpandProperty 'FullName')
	Try {
		[Object[]]$DatabaseFilesLocks = ($DatabaseFilesFullNames | ForEach-Object -Process {
			Return [System.IO.File]::Open($_, 'Open', 'Read', 'Read')
		})
	} Catch {
		Write-Error -Message 'Unable to lock Git database!' -Category 'OperationStopped'
		Throw
	}
	Try {
		[PSCustomObject]$PropertyToken = ($CommitsProperties | Where-Object -FilterScript {
			Return ($_.AsIndex -ieq $True)
		})[0]
		[Hashtable[]]$OutputObject = [String[]](Invoke-Expression -Command ($ExpressionSingleLine -f $PropertyToken.Placeholder)) | ForEach-Object -Process {
			Return @{ "$($PropertyToken.Name)" = $_ }
		}
		ForEach ($CommitsProperty In $CommitsProperties) {
			If ($CommitsProperty.Name -ieq $PropertyToken.Name) {
				Continue
			}
			If ($CommitsProperty.IsMultipleLine) {
				For ($CommitIndex = 0; $CommitIndex -ilt $OutputObject.Count; $CommitIndex++) {
					$OutputObject[$CommitIndex][$CommitsProperty.Name] = [String[]](Invoke-Expression -Command ($ExpressionMultipleLine -f @($Result[$CommitIndex][$PropertyToken.Name], $CommitsProperty.Placeholder))) -join "`n" -ireplace '^(?:\s*\r?\n)+|(?:\s*\r?\n)+$', ''
				}
			} Else {
				[String[]]$Results = Invoke-Expression -Command ($ExpressionSingleLine -f $CommitsProperty.Placeholder)
				For ($ResultsIndex = 0; $ResultsIndex -ilt $Results.Count; $ResultsIndex++) {
					[String]$Result = $Results[$ResultsIndex]
					If ($CommitsProperty.IsArray) {
						$OutputObject[$ResultsIndex][$CommitsProperty.Name] = $Result -isplit ' '
					} ElseIf ($Null -ine $CommitsProperty.Type) {
						$OutputObject[$ResultsIndex][$CommitsProperty.Name] = $Result -as $CommitsProperty.Type
					} Else {
						$OutputObject[$ResultsIndex][$CommitsProperty.Name] = $Result
					}
				}
			}
		}
		Return ($OutputObject | ForEach-Object -Process {
			Return [PSCustomObject]$_
		})
	} Catch {
		Write-Error -Message "Unexpected Git database error! $_" -Category 'OperationStopped'
		Throw
	} Finally {
		$DatabaseFilesLocks | ForEach-Object -Process {
			$_.Close() | Out-Null
		}
	}
}
Export-ModuleMember -Function @(
	'Get-GitCommitsInformation'
)
