#Requires -PSEdition Core
#Requires -Version 7.3
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (
	@(
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
	@{ Name = 'GPGSignatureSigner'; Placeholder = '%GS' },
	@{ Name = 'GPGSignatureStatus'; Placeholder = '%G?' },
	@{ Name = 'GPGSignatureTrustLevel'; Placeholder = '%GP' },
	@{ Name = 'Notes'; Placeholder = '%N'; IsMultipleLine = $True },
	@{ Name = 'ParentHashes'; Placeholder = '%P'; IsArraySpace = $True },
	@{ Name = 'ReflogIdentityEmail'; Placeholder = '%ge' },
	@{ Name = 'ReflogIdentityName'; Placeholder = '%gn' },
	@{ Name = 'ReflogSelector'; Placeholder = '%gD' },
	@{ Name = 'ReflogSubject'; Placeholder = '%gs' },
	@{ Name = 'Subject'; Placeholder = '%s' },
	@{ Name = 'TreeHash'; Placeholder = '%T' }
) |
	Sort-Object -Property 'Name'
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
		[Alias('IncludeAllBranches')][Switch]$AllBranches,
		[Alias('IncludeReflogs')][Switch]$Reflogs
	)
	Try {
		[String]$IsGitRepositoryResult = git rev-parse --is-inside-work-tree |
			Join-String -Separator "`n"
	}
	Catch {
		Write-GitHubActionsError -Message @"
Unable to integrate with Git!
$_
If this is incorrect, probably Git database is broken and/or invalid.
"@
		Return
	}
	If ($IsGitRepositoryResult -ine 'True') {
		Write-GitHubActionsError -Message 'Workspace is not a Git repository!'
		Return
	}
	[String[]]$GitCommitsIds = Invoke-Expression -Command "git --no-pager log --format=`"$($GitCommitsPropertyIndexer.Placeholder)`" --no-color$($AllBranches.IsPresent ? ' --all' : '')$($Reflogs.IsPresent ? ' --reflog' : '')"
	[PSCustomObject[]]$GitCommitsMeta = @()
	ForEach ($GitCommitId In $GitCommitsIds) {
		Do {
			Try {
				[String]$DelimiterToken = "=====$(New-RandomToken -Length 32)====="
				[String[]]$GitCommitMetaRaw0 = Invoke-Expression -Command "git --no-pager show --format=`"$(
				$GitCommitsProperties |
					Select-Object -ExpandProperty 'Placeholder' |
					Join-String -Separator "%n$DelimiterToken%n"
			)`" --no-color --no-patch $GitCommitId"
				If ($LASTEXITCODE -ine 0) {
					Throw (
						$GitCommitMetaRaw0 |
							Join-String -Separator "`n"
					)
				}
			}
			Catch {
				Write-GitHubActionsError -Message @"
Unexpected Git database issue!
$_
"@
				Return
			}
			[UInt64]$DelimiterTokenCount = (
				$GitCommitMetaRaw0 |
					Where-Object -FilterScript { $_ -ieq $DelimiterToken }
			).Count
		}
		While ($DelimiterTokenCount -ine $DelimiterTokenCountPerCommit)
		[String[]]$GitCommitMetaRaw1 = (
			$GitCommitMetaRaw0 |
				Join-String -Separator "`n"
		) -isplit ([RegEx]::Escape("`n$DelimiterToken`n"))
		If ($GitCommitsProperties.Count -ine $GitCommitMetaRaw1.Count) {
			Write-GitHubActionsError -Message @'
Unexpected Git database issue!
Columns are not match!
'@
			Return
		}
		[Hashtable]$GitCommitMeta = @{}
		For ([UInt64]$Line = 0; $Line -ilt $GitCommitMetaRaw1.Count; $Line++) {
			[Hashtable]$GitCommitsPropertiesCurrent = $GitCommitsProperties[$Line]
			[String]$Value = $GitCommitMetaRaw1[$Line]
			If ($GitCommitsPropertiesCurrent.IsArraySpace) {
				$GitCommitMeta[$GitCommitsPropertiesCurrent.Name] = $Value -isplit ' '
			}
			ElseIf ($GitCommitsPropertiesCurrent.AsType) {
				$GitCommitMeta[$GitCommitsPropertiesCurrent.Name] = $Value -as $GitCommitsPropertiesCurrent.AsType
			}
			Else {
				$GitCommitMeta[$GitCommitsPropertiesCurrent.Name] = $Value
			}
		}
		$GitCommitsMeta += [PSCustomObject]$GitCommitMeta
	}
	$GitCommitsMeta |
		Sort-Object -Property $GitCommitsPropertySorter.Name |
		Write-Output
}
Export-ModuleMember -Function @(
	'Get-GitCommits'
)
