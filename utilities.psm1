[hashtable]$GitCommitsInformationToken = @{
	Name = 'CommitHash'
	Placeholder = '%H'
}
[hashtable[]]$GitCommitsInformations = @(
	@{
		Name = 'AbbreviatedCommitHash'
		Placeholder = '%h'
	},
	@{
		Name = 'TreeHash'
		Placeholder = '%T'
	},
	@{
		Name = 'AbbreviatedTreeHash'
		Placeholder = '%t'
	},
	@{
		Name = 'ParentHashes'
		Placeholder = '%P'
		IsArray = $true
	},
	@{
		Name = 'AbbreviatedParentHashes'
		Placeholder = '%p'
		IsArray = $true
	},
	@{
		Name = 'AuthorName'
		Placeholder = '%an'
	},
	@{
		Name = 'AuthorEmail'
		Placeholder = '%ae'
	},
	@{
		Name = 'AuthorDate'
		Placeholder = '%aI'
		Type = [datetime]
	},
	@{
		Name = 'CommitterName'
		Placeholder = '%cn'
	},
	@{
		Name = 'CommitterEmail'
		Placeholder = '%ce'
	},
	@{
		Name = 'CommitterDate'
		Placeholder = '%cI'
		Type = [datetime]
	},
	@{
		Name = 'Encoding'
		Placeholder = '%e'
	},
	@{
		Name = 'Subject'
		Placeholder = '%s'
	},
	@{
		Name = 'Body'
		Placeholder = '%b'
		IsMultipleLine = $true
	},
	@{
		Name = 'Notes'
		Placeholder = '%N'
		IsMultipleLine = $true
	},
	@{
		Name = 'GPGSignatureStatus'
		Placeholder = '%G?'
	},
	@{
		Name = 'GPGSignatureSigner'
		Placeholder = '%GS'
	},
	@{
		Name = 'GPGSignatureKey'
		Placeholder = '%GK'
	},
	@{
		Name = 'GPGSignatureKeyFingerprint'
		Placeholder = '%GF'
	},
	@{
		Name = 'GPGSignaturePrimaryKeyFingerprint'
		Placeholder = '%GP'
	},
	@{
		Name = 'GPGSignatureTrustLevel'
		Placeholder = '%GP'
	},
	@{
		Name = 'ReflogSelector'
		Placeholder = '%gD'
	},
	@{
		Name = 'ShortenedReflogSelector'
		Placeholder = '%gd'
	},
	@{
		Name = 'ReflogIdentityName'
		Placeholder = '%gn'
	},
	@{
		Name = 'ReflogIdentityEmail'
		Placeholder = '%ge'
	},
	@{
		Name = 'ReflogSubject'
		Placeholder = '%gs'
	}
)
[string]$GitLogExpressionSingleLine = "git --no-pager log --all --format=`"{0}`""
[string]$GitLogExpressionMultipleLine = 'git --no-pager show --format="{1}" {0}'
function Get-GitCommits {
	[CmdletBinding()][OutputType([pscustomobject[]])]
	param ()
	[hashtable[]]$GitCommits = [string[]](Invoke-Expression -Command ($GitLogExpressionSingleLine -f $GitCommitsInformationToken.Placeholder)) | ForEach-Object -Process {
		return @{
			"$($GitCommitsInformationToken.Name)" = $_
		}
	}
	foreach ($GitCommitsInformation in $GitCommitsInformations) {
		if ($GitCommitsInformation.IsMultipleLine) {
			for ($GitCommitIndex = 0; $GitCommitIndex -lt $GitCommits.Count; $GitCommitIndex++) {
				$GitCommits[$GitCommitIndex][$GitCommitsInformation.Name] = [string[]](Invoke-Expression -Command ($GitLogExpressionMultipleLine -f @($GitCommits[$GitCommitIndex][$GitCommitsInformationToken.Name], $GitCommitsInformation.Placeholder))) -join "`n" -replace '^(?:\s*\r?\n)+|(?:\s*\r?\n)+$', ''
			}
		} else {
			[string[]]$Results = Invoke-Expression -Command ($GitLogExpressionSingleLine -f "$($GitCommitsInformationToken.Placeholder) $($GitCommitsInformation.Placeholder)")
			if ($GitCommits.Count -ne $Results.Count) {
				throw 'Git database was modified during process!'
			}
			for ($ResultsIndex = 0; $ResultsIndex -lt $Results.Count; $ResultsIndex++) {
				[string[]]$ResultRaw = $Results[$ResultsIndex] -split ' '
				[string]$ResultToken = $ResultRaw[0]
				[string[]]$ResultContentRaw = $ResultRaw[1..$ResultRaw.Count]
				if ($GitCommits[$ResultsIndex][$GitCommitsInformationToken.Name] -ne $ResultToken) {
					throw 'Git database was modified during process!'
				}
				$ResultContent = $null
				if ($GitCommitsInformation.IsArray) {
					$ResultContent = $ResultContentRaw
				} elseif ($null -ne $GitCommitsInformation.Type) {
					$ResultContent = $ResultContentRaw -join ' ' -as $GitCommitsInformation.Type
				} else {
					$ResultContent = $ResultContentRaw -join ' '
				}
				$GitCommits[$ResultsIndex][$GitCommitsInformation.Name] = $ResultContent
			}
		}
	}
	return $GitCommits
}
function Get-TSVTable {
	[CmdletBinding()][OutputType([pscustomobject[]])]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Path
	)
	[string[]]$Raw = Get-Content -Path $Path -Encoding UTF8NoBOM
	return ConvertFrom-Csv -InputObject $Raw[1..$Raw.Count] -Delimiter "`t" -Header ($Raw[0] -split "`t")
}
Export-ModuleMember -Function @('Get-GitCommits', 'Get-TSVTable')
