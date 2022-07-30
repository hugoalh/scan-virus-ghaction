[Hashtable[]]$GitCommitsProperties = @(
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
[String]$GitCommitsInformationExpressionMultipleLine = 'git --no-pager show --format="{1}" {0}'
[String]$GitCommitsInformationExpressionSingleLine = 'git --no-pager log --all --format="{0}"'
Function Get-GitCommitsInformation {
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	Param ()
	Try {
		[Object[]]$GitDatabaseLocks = ([Object[]](Get-ChildItem -LiteralPath (Join-Path -Path $Env:GITHUB_WORKSPACE -ChildPath '.git') -Recurse -Force -File) | Select-Object -ExpandProperty 'FullName' | ForEach-Object -Process {
			Return [System.IO.File]::Open($_, 'Open', 'Read', 'Read')
		})
	} Catch {
		Throw 'Unable to lock Git database!'
	}
	Try {
		[Hashtable]$GitCommitsPropertyToken = ($GitCommitsProperties | Where-Object -FilterScript {
			Return $_.AsIndex
		})[0]
		[Hashtable[]]$Result = [String[]](Invoke-Expression -Command ($GitCommitsInformationExpressionSingleLine -f $GitCommitsPropertyToken.Placeholder)) | ForEach-Object -Process {
			Return @{ "$($GitCommitsPropertyToken.Name)" = $_ }
		}
		ForEach ($GitCommitsProperty In $GitCommitsProperties) {
			If ($GitCommitsProperty.Name -ieq $GitCommitsPropertyToken.Name) {
				Continue
			}
			If ($GitCommitsProperty.IsMultipleLine) {
				For ([UInt32]$CommitIndex = 0; $CommitIndex -ilt $Result.Count; $CommitIndex++) {
					$Result[$CommitIndex][$GitCommitsProperty.Name] = [String[]](Invoke-Expression -Command ($GitCommitsInformationExpressionMultipleLine -f @($Result[$CommitIndex][$GitCommitsPropertyToken.Name], $GitCommitsProperty.Placeholder))) -join "`n" -ireplace '^(?:\s*\r?\n)+|(?:\s*\r?\n)+$', ''
				}
				Continue
			}
			[String[]]$ExpressionOutput = Invoke-Expression -Command ($GitCommitsInformationExpressionSingleLine -f $GitCommitsProperty.Placeholder)
			For ([UInt32]$Row = 0; $Row -ilt $ExpressionOutput.Count; $Row++) {
				[String]$Value = $ExpressionOutput[$Row]
				If ($GitCommitsProperty.IsArray) {
					$Result[$Row][$GitCommitsProperty.Name] = $Value -isplit ' '
				} ElseIf ($Null -ine $GitCommitsProperty.Type) {
					$Result[$Row][$GitCommitsProperty.Name] = $Value -as $GitCommitsProperty.Type
				} Else {
					$Result[$Row][$GitCommitsProperty.Name] = $Value
				}
			}
		}
		Return ($Result | ForEach-Object -Process {
			Return [PSCustomObject]$_
		} | Sort-Object -Property 'AuthorDate')
	} Catch {
		Throw "Unexpected Git database error: $_"
	} Finally {
		$GitDatabaseLocks | ForEach-Object -Process {
			$_.Close() | Out-Null
		}
	}
}
Export-ModuleMember -Function @(
	'Get-GitCommitsInformation'
)
