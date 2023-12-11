#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name @(
	(Join-Path -Path $PSScriptRoot -ChildPath 'control.psm1')
) -Scope 'Local'
[Hashtable[]]$GitCommitPropertiesMeta = @(
	@{ Name = 'AuthorDate'; Placeholder = '%aI'; Transform = {
		Param ([String]$Item)
		Return ([DateTime]::Parse($Item))
	} },
	@{ Name = 'AuthorEmail'; Placeholder = '%ae' },
	@{ Name = 'AuthorName'; Placeholder = '%an' },
	@{ Name = 'Body'; Placeholder = '%b' },
	@{ Name = 'CommitHash'; Placeholder = '%H'; AsIndex = $True },
	@{ Name = 'CommitterDate'; Placeholder = '%cI'; Transform = {
		Param ([String]$Item)
		Return ([DateTime]::Parse($Item))
	} },
	@{ Name = 'CommitterEmail'; Placeholder = '%ce' },
	@{ Name = 'CommitterName'; Placeholder = '%cn' },
	@{ Name = 'Encoding'; Placeholder = '%e' },
	@{ Name = 'Notes'; Placeholder = '%N' },
	@{ Name = 'ParentHashes'; Placeholder = '%P'; Transform = {
		Param ([String]$Item)
		Write-Output -InputObject ($Item -isplit ' ') -NoEnumerate
		Return
	} },
	@{ Name = 'ReflogIdentityEmail'; Placeholder = '%ge' },
	@{ Name = 'ReflogIdentityName'; Placeholder = '%gn' },
	@{ Name = 'ReflogSelector'; Placeholder = '%gD' },
	@{ Name = 'ReflogSubject'; Placeholder = '%gs' },
	@{ Name = 'Subject'; Placeholder = '%s' },
	@{ Name = 'TreeHash'; Placeholder = '%T' }
)
[Hashtable]$GitCommitsPropertyIndexer = $GitCommitPropertiesMeta |
	Where-Object -FilterScript { $_.AsIndex } |
	Select-Object -Index 0
$Null = git --no-pager config --global --add safe.directory $CurrentWorkingDirectory
Function Disable-GitLfsProcess {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	Try {
		git --no-pager config --global filter.lfs.process 'git-lfs filter-process --skip' *>&1 |
			Write-GitHubActionsDebug
		git --no-pager config --global filter.lfs.smudge 'git-lfs smudge --skip -- %f' *>&1 |
			Write-GitHubActionsDebug
	}
	Catch {
		Write-GitHubActionsWarning -Message "Unable to disable Git LFS process: $_"
	}
}
Function Get-GitCommitsIndex {
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
		Write-Output -InputObject $Result -NoEnumerate
	}
	Catch {
		Write-GitHubActionsError -Message "Unable to get Git commit index: $_"
		Write-Output -InputObject @() -NoEnumerate
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
			[String]$DelimiterToken = (New-Guid).Guid.ToUpper() -ireplace '-', ''
			[String]$Output = Invoke-Expression -Command "git --no-pager show --format=`"$(
				$GitCommitPropertiesMeta |
					Select-Object -ExpandProperty 'Placeholder' |
					Join-String -Separator "%n$DelimiterToken%n"
			)`" --no-color --no-patch `"$Index`"" |
				Join-String -Separator "`n"
			If ($LASTEXITCODE -ne 0) {
				Throw $Output
			}
			[String[]]$Result = $Output -csplit "\r?\n$($DelimiterToken)\r?\n"
		}
		Catch {
			Write-GitHubActionsError -Message "Unable to get Git commit meta $($Index): $_"
			Return
		}
	}
	While ($Result.Count -ine $GitCommitPropertiesMeta.Count)
	[Hashtable]$GitCommitMeta = @{}
	For ([UInt64]$Line = 0; $Line -lt $ResultResolve.Count; $Line += 1) {
		[Hashtable]$GitCommitPropertiesMetaCurrent = $GitCommitPropertiesMeta[$Line]
		[String]$Value = $ResultResolve[$Line]
		If ($GitCommitPropertiesMetaCurrent.Transform) {
			$GitCommitMeta.($GitCommitPropertiesMetaCurrent.Name) = Invoke-Command -ScriptBlock $GitCommitPropertiesMetaCurrent.Transform -ArgumentList @($Value)
		}
		Else {
			$GitCommitMeta.($GitCommitPropertiesMetaCurrent.Name) = $Value
		}
	}
	Write-Output -InputObject ([PSCustomObject]$GitCommitMeta)
}
Function Test-IsGitRepository {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param ()
	Try {
		[String]$Result = git --no-pager rev-parse --is-inside-work-tree *>&1 |
			Join-String -Separator "`n"
		If ($Result -ine 'True') {
			Throw 'Current working directory is not a Git repository!'
		}
		Write-Output -InputObject $True
	}
	Catch {
		Write-GitHubActionsError -Message @"
Unable to integrate with Git: $_
$Result
If this is incorrect, probably Git database is broken and/or invalid.
"@
		Write-Output -InputObject $False
	}
}
Export-ModuleMember -Function @(
	'Disable-GitLfsProcess',
	'Get-GitCommitsIndex',
	'Get-GitCommitMeta',
	'Test-IsGitRepository'
)
