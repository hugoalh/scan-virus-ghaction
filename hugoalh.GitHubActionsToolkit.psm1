<#
.SYNOPSIS
GitHub Actions - Internal - Escape Characters
.DESCRIPTION
An internal function to escape characters that could cause issues.
.PARAMETER InputObject
String that need to escape characters.
.PARAMETER Command
Also escape command properties characters.
.OUTPUTS
String
#>
function Format-GHActionsEscapeCharacters {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][AllowEmptyString()][string]$InputObject,
		[switch]$Command
	)
	begin {}
	process {
		[string]$Result = $InputObject -replace '%', '%25' -replace "`n", '%0A' -replace "`r", '%0D'
		if ($Command) {
			$Result = $Result -replace ',', '%2C' -replace ':', '%3A'
		}
		return $Result
	}
	end {}
}
<#
.SYNOPSIS
GitHub Actions - Internal - Write Workflow Command
.DESCRIPTION
An internal function to write workflow command.
.PARAMETER Command
Workflow command.
.PARAMETER Message
Message.
.PARAMETER Properties
Workflow command properties.
.OUTPUTS
Void
#>
function Write-GHActionsCommand {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)][string]$Command,
		[Parameter(Mandatory = $true, Position = 1)][AllowEmptyString()][string]$Message,
		[Parameter(Position = 2)][hashtable]$Properties = @{}
	)
	[string]$Result = "::$Command"
	if ($Properties.Count -gt 0) {
		$Result += " $($($Properties.GetEnumerator() | ForEach-Object -Process {
			"$($_.Name)=$(Format-GHActionsEscapeCharacters -InputObject $_.Value -Command)"
		}) -join ',')"
	}
	$Result += "::$(Format-GHActionsEscapeCharacters -InputObject $Message)"
	Write-Host -Object $Result
}
<#
.SYNOPSIS
GitHub Actions - Internal - Test Environment Variable
.DESCRIPTION
An internal function to validate environment variable.
.PARAMETER InputObject
Environment variable that need to validate.
.OUTPUTS
Boolean -or Void
#>
function Test-GHActionsEnvironmentVariable {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$InputObject
	)
	if (($InputObject -match '^[\da-z_]+=.+$') -and (($InputObject -split '=').Count -eq 2)) {
		return $true
	}
	Write-Error -Message "Input `"$InputObject`" is not match the require environment variable pattern." -Category SyntaxError
}
<#
.SYNOPSIS
GitHub Actions - Add Environment Variable
.DESCRIPTION
Add environment variable to the system environment variables and automatically makes it available to all subsequent actions in the current job; The currently running action cannot access the updated environment variables.
.PARAMETER InputObject
Environment variables.
.PARAMETER Name
Environment variable name.
.PARAMETER Value
Environment variable value.
.OUTPUTS
Void
#>
function Add-GHActionsEnvironmentVariable {
	[CmdletBinding(DefaultParameterSetName = 'single')]
	param(
		[Parameter(Mandatory = $true, ParameterSetName = 'multiple', Position = 0, ValueFromPipeline = $true)]$InputObject,
		[Parameter(Mandatory = $true, ParameterSetName = 'single', Position = 0)][ValidatePattern('^[\da-z_]+$')][string]$Name,
		[Parameter(Mandatory = $true, ParameterSetName = 'single', Position = 1)][ValidatePattern('^.+$')][string]$Value
	)
	begin {
		[hashtable]$Result = @{}
	}
	process {
		switch ($PSCmdlet.ParameterSetName) {
			'multiple' {
				switch ($InputObject.GetType().Name) {
					'Hashtable' {
						$InputObject.GetEnumerator() | ForEach-Object -Process {
							if (Test-GHActionsEnvironmentVariable -InputObject "$($_.Name)=$($_.Value)") {
								$Result[$_.Name] = $_.Value
							}
						}
					}
					{$_ -in @('PSObject', 'PSCustomObject')} {
						$InputObject.PSObject.Properties | ForEach-Object -Process {
							if (Test-GHActionsEnvironmentVariable -InputObject "$($_.Name)=$($_.Value)") {
								$Result[$_.Name] = $_.Value
							}
						}
					}
					'String' {
						if (Test-GHActionsEnvironmentVariable -InputObject $InputObject) {
							[string[]]$InputObjectSplit = $InputObject.Split('=')
							$Result[$InputObjectSplit[0]] = $InputObjectSplit[1]
						}
					}
					default {
						Write-Error -Message 'Parameter `InputObject` must be hashtable, object, or string!' -Category InvalidType
					}
				}
			}
			'single' {
				$Result[$Name] = $Value
			}
		}
	}
	end {
		Add-Content -Encoding utf8NoBOM -Path $env:GITHUB_ENV -Value "$($($Result.GetEnumerator() | ForEach-Object -Process {
			"$($_.Name)=$($_.Value)"
		}) -join "`n")"
	}
}
<#
.SYNOPSIS
GitHub Actions - Add PATH
.DESCRIPTION
Add directory to the system `PATH` variable and automatically makes it available to all subsequent actions in the current job; The currently running action cannot access the updated path variable.
.PARAMETER Path
System path.
.OUTPUTS
Void
#>
function Add-GHActionsPATH {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][string[]]$Path
	)
	begin {
		[string[]]$Result = @()
	}
	process {
		$Path.GetEnumerator() | ForEach-Object -Process {
			if (Test-Path -Path $_ -IsValid) {
				$Result += $_
			} else {
				Write-Error -Message "Input `"$_`" is not match the require path pattern." -Category SyntaxError
			}
		}
	}
	end {
		Add-Content -Encoding utf8NoBOM -Path $env:GITHUB_PATH -Value "$($Result -join "`n")"
	}
}
<#
.SYNOPSIS
GitHub Actions - Add Secret Mask
.DESCRIPTION
Make a secret will get masked from the log.
.PARAMETER Value
The secret.
.OUTPUTS
Void
#>
function Add-GHActionsSecretMask {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Value
	)
	begin {}
	process {
		Write-GHActionsCommand -Command 'add-mask' -Message $Value
	}
	end {}
}
<#
.SYNOPSIS
GitHub Actions - Disable Command Echo
.DESCRIPTION
Disable echoing of workflow commands, the workflow run's log will not show the command itself; A workflow command is echoed if there are any errors processing the command; Secret `ACTIONS_STEP_DEBUG` will ignore this.
.OUTPUTS
Void
#>
function Disable-GHActionsCommandEcho {
	[CmdletBinding()]
	param()
	Write-GHActionsCommand -Command 'echo' -Message 'off'
}
<#
.SYNOPSIS
GitHub Actions - Disable Processing Command
.DESCRIPTION
Stop processing any workflow commands to allow log anything without accidentally running workflow commands.
.OUTPUTS
String
#>
function Disable-GHActionsProcessingCommand {
	[CmdletBinding()]
	param()
	[string]$EndToken = (New-Guid).Guid
	Write-GHActionsCommand -Command 'stop-commands' -Message $EndToken
	return $EndToken
}
<#
.SYNOPSIS
GitHub Actions - Enable Command Echo
.DESCRIPTION
Enable echoing of workflow commands, the workflow run's log will show the command itself; The `add-mask`, `debug`, `warning`, and `error` commands do not support echoing because their outputs are already echoed to the log; Secret `ACTIONS_STEP_DEBUG` will ignore this.
.OUTPUTS
Void
#>
function Enable-GHActionsCommandEcho {
	[CmdletBinding()]
	param()
	Write-GHActionsCommand -Command 'echo' -Message 'on'
}
<#
.SYNOPSIS
GitHub Actions - Enable Processing Command
.DESCRIPTION
Resume processing any workflow commands to allow running workflow commands.
.PARAMETER EndToken
Token from `Disable-GHActionsProcessingCommand`.
.OUTPUTS
Void
#>
function Enable-GHActionsProcessingCommand {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$EndToken
	)
	Write-GHActionsCommand -Command $EndToken -Message ''
}
<#
.SYNOPSIS
GitHub Actions - Enter Log Group
.DESCRIPTION
Create an expandable group in the log; Anything write to the log between `Enter-GHActionsLogGroup` and `Exit-GHActionsLogGroup` commands are inside an expandable group in the log.
.PARAMETER Title
Title of the log group.
.OUTPUTS
Void
#>
function Enter-GHActionsLogGroup {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Title
	)
	Write-GHActionsCommand -Command 'group' -Message $Title
}
<#
.SYNOPSIS
GitHub Actions - Exit Log Group
.DESCRIPTION
End an expandable group in the log.
.OUTPUTS
Void
#>
function Exit-GHActionsLogGroup {
	[CmdletBinding()]
	param ()
	Write-GHActionsCommand -Command 'endgroup' -Message ''
}
<#
.SYNOPSIS
GitHub Actions - Get Input
.DESCRIPTION
Get input.
.PARAMETER Name
Name of the input.
.PARAMETER Require
Whether the input is require. If required and not present, will throw an error.
.PARAMETER Trim
Trim the input's value.
.OUTPUTS
Hashtable -or String
#>
function Get-GHActionsInput {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string[]]$Name,
		[switch]$Require,
		[switch]$Trim
	)
	begin {
		[hashtable]$Result = @{}
	}
	process {
		$Name.GetEnumerator() | ForEach-Object -Process {
			[string]$InputValue = Get-ChildItem -Path "Env:\INPUT_$($_.ToUpper() -replace '[ \n\r]','_')" -ErrorAction SilentlyContinue
			if ($InputValue -eq $null) {
				if ($Require) {
					throw "Input ``$_`` is not defined!"
				}
				$Result[$_] = $InputValue
			} else {
				if ($Trim) {
					$Result[$_] = $InputValue.Value.Trim()
				} else {
					$Result[$_] = $InputValue.Value
				}
			}
		}
	}
	end {
		if ($Result.Count -eq 1) {
			return $Result.Values[0]
		}
		return $Result
	}
}
<#
.SYNOPSIS
GitHub Actions - Get Debug Status
.DESCRIPTION
Get debug status.
.OUTPUTS
Boolean
#>
function Get-GHActionsIsDebug {
	[CmdletBinding()]
	param ()
	if ($env:RUNNER_DEBUG -eq 'true') {
		return $true
	}
	return $false
}
<#
.SYNOPSIS
GitHub Actions - Get State
.DESCRIPTION
Get state.
.PARAMETER Name
Name of the state.
.PARAMETER Trim
Trim the state's value.
.OUTPUTS
Hashtable -or String
#>
function Get-GHActionsState {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string[]]$Name,
		[switch]$Trim
	)
	begin {
		[hashtable]$Result = @{}
	}
	process {
		$Name.GetEnumerator() | ForEach-Object -Process {
			[string]$StateValue = Get-ChildItem -Path "Env:\STATE_$($_.ToUpper() -replace '[ \n\r]','_')" -ErrorAction SilentlyContinue
			if ($StateValue -eq $null) {
				$Result[$_] = $StateValue
			} else {
				if ($Trim) {
					$Result[$_] = $StateValue.Value.Trim()
				} else {
					$Result[$_] = $StateValue.Value
				}
			}
		}
	}
	end {
		if ($Result.Count -eq 1) {
			return $Result.Values[0]
		}
		return $Result
	}
}
<#
.SYNOPSIS
GitHub Actions - Get Webhook Event Payload
.DESCRIPTION
Get the complete webhook event payload.
.OUTPUTS
PSCustomObject
#>
function Get-GHActionsWebhookEventPayload {
	[CmdletBinding()]
	param ()
	return (Get-Content -Encoding utf8NoBOM -Path $env:GITHUB_EVENT_PATH -Raw | ConvertFrom-Json -Depth 100)
}
<#
.SYNOPSIS
Execute script block in a log group.
.PARAMETER Title
Title of the log group.
.PARAMETER ScriptBlock
Script block to execute in the log group.
.OUTPUTS
Any
#>
function Invoke-GHActionsScriptGroup {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Title,
		[Parameter(Mandatory = $true, Position = 1)][scriptblock]$ScriptBlock
	)
	Enter-GHActionsLogGroup -Title $Title
	try {
		return $ScriptBlock.Invoke()
	} finally {
		Exit-GHActionsLogGroup
	}
}
<#
.SYNOPSIS
GitHub Actions - Set Output
.DESCRIPTION
Set output.
.PARAMETER Name
Name of the output.
.PARAMETER Value
Value of the output.
.OUTPUTS
Void
#>
function Set-GHActionsOutput {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Name,
		[Parameter(Mandatory = $true, Position = 1)][string]$Value
	)
	Write-GHActionsCommand -Command 'set-output' -Message $Value -Properties @{'name' = $Name }
}
<#
.SYNOPSIS
GitHub Actions - Set State
.DESCRIPTION
Set state.
.PARAMETER Name
Name of the state.
.PARAMETER Value
Value of the state.
.OUTPUTS
Void
#>
function Set-GHActionsState {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)][string]$Name,
		[Parameter(Mandatory = $true, Position = 1)][string]$Value
	)
	Write-GHActionsCommand -Command 'save-state' -Message $Value -Properties @{'name' = $Name }
}
<#
.SYNOPSIS
GitHub Actions - Write Debug
.DESCRIPTION
Prints a debug message to the log.
.PARAMETER Message
Message that need to log at debug level.
.OUTPUTS
Void
#>
function Write-GHActionsDebug {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Message
	)
	begin {}
	process {
		Write-GHActionsCommand -Command 'debug' -Message $Message
	}
	end {}
}
<#
.SYNOPSIS
GitHub Actions - Write Error
.DESCRIPTION
Prints an error message to the log.
.PARAMETER Message
Message that need to log at error level.
.PARAMETER File
Issue file path.
.PARAMETER Line
Issue file line start.
.PARAMETER Col
Issue file column start.
.PARAMETER EndLine
Issue file line end.
.PARAMETER EndColumn
Issue file column end.
.PARAMETER Title
Issue title.
.OUTPUTS
Void
#>
function Write-GHActionsError {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Message,
		[Parameter()][string]$File,
		[Parameter()][uint]$Line,
		[Parameter()][uint]$Col,
		[Parameter()][uint]$EndLine,
		[Parameter()][uint]$EndColumn,
		[Parameter()][string]$Title
	)
	begin {
		[hashtable]$Properties = @{}
		if ($File.Length -gt 0) {
			$Properties.'file' = $File
		}
		if ($Line -gt 0) {
			$Properties.'line' = $Line
		}
		if ($Col -gt 0) {
			$Properties.'col' = $Col
		}
		if ($EndLine -gt 0) {
			$Properties.'endLine' = $EndLine
		}
		if ($EndColumn -gt 0) {
			$Properties.'endColumn' = $EndColumn
		}
		if ($Title.Length -gt 0) {
			$Properties.'title' = $Title
		}
	}
	process {
		Write-GHActionsCommand -Command 'error' -Message $Message -Properties $Properties
	}
	end {}
}
<#
.SYNOPSIS
GitHub Actions - Write Fail
.DESCRIPTION
Prints an error message to the log and end the process.
.PARAMETER Message
Message that need to log at error level.
.OUTPUTS
Void
#>
function Write-GHActionsFail {
	[CmdletBinding()]
	param(
		[Parameter(Position = 0)][string]$Message = ''
	)
	Write-GHActionsCommand -Command 'error' -Message $Message
	exit 1
}
<#
.SYNOPSIS
GitHub Actions - Write Notice
.DESCRIPTION
Prints a notice message to the log.
.PARAMETER Message
Message that need to log at notice level.
.PARAMETER File
Issue file path.
.PARAMETER Line
Issue file line start.
.PARAMETER Col
Issue file column start.
.PARAMETER EndLine
Issue file line end.
.PARAMETER EndColumn
Issue file column end.
.PARAMETER Title
Issue title.
.OUTPUTS
Void
#>
function Write-GHActionsNotice {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Message,
		[Parameter()][string]$File,
		[Parameter()][uint]$Line,
		[Parameter()][uint]$Col,
		[Parameter()][uint]$EndLine,
		[Parameter()][uint]$EndColumn,
		[Parameter()][string]$Title
	)
	begin {
		[hashtable]$Properties = @{}
		if ($File.Length -gt 0) {
			$Properties.'file' = $File
		}
		if ($Line -gt 0) {
			$Properties.'line' = $Line
		}
		if ($Col -gt 0) {
			$Properties.'col' = $Col
		}
		if ($EndLine -gt 0) {
			$Properties.'endLine' = $EndLine
		}
		if ($EndColumn -gt 0) {
			$Properties.'endColumn' = $EndColumn
		}
		if ($Title.Length -gt 0) {
			$Properties.'title' = $Title
		}
	}
	process {
		Write-GHActionsCommand -Command 'notice' -Message $Message -Properties $Properties
	}
	end {}
}
<#
.SYNOPSIS
GitHub Actions - Write Warning
.DESCRIPTION
Prints a warning message to the log.
.PARAMETER Message
Message that need to log at warning level.
.PARAMETER File
Issue file path.
.PARAMETER Line
Issue file line start.
.PARAMETER Col
Issue file column start.
.PARAMETER EndLine
Issue file line end.
.PARAMETER EndColumn
Issue file column end.
.PARAMETER Title
Issue title.
.OUTPUTS
Void
#>
function Write-GHActionsWarning {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)][string]$Message,
		[Parameter()][string]$File,
		[Parameter()][uint]$Line,
		[Parameter()][uint]$Col,
		[Parameter()][uint]$EndLine,
		[Parameter()][uint]$EndColumn,
		[Parameter()][string]$Title
	)
	begin {
		[hashtable]$Properties = @{}
		if ($File.Length -gt 0) {
			$Properties.'file' = $File
		}
		if ($Line -gt 0) {
			$Properties.'line' = $Line
		}
		if ($Col -gt 0) {
			$Properties.'col' = $Col
		}
		if ($EndLine -gt 0) {
			$Properties.'endLine' = $EndLine
		}
		if ($EndColumn -gt 0) {
			$Properties.'endColumn' = $EndColumn
		}
		if ($Title.Length -gt 0) {
			$Properties.'title' = $Title
		}
	}
	process {
		Write-GHActionsCommand -Command 'warning' -Message $Message -Properties $Properties
	}
	end {}
}
Export-ModuleMember -Function Add-GHActionsEnvironmentVariable, Add-GHActionsPATH, Add-GHActionsSecretMask, Disable-GHActionsCommandEcho, Disable-GHActionsProcessingCommand, Enable-GHActionsCommandEcho, Enable-GHActionsProcessingCommand, Enter-GHActionsLogGroup, Exit-GHActionsLogGroup, Get-GHActionsInput, Get-GHActionsIsDebug, Get-GHActionsState, Get-GHActionsWebhookEventPayload, Invoke-GHActionsScriptGroup, Set-GHActionsOutput, Set-GHActionsState, Write-GHActionsDebug, Write-GHActionsError, Write-GHActionsFail, Write-GHActionsNotice, Write-GHActionsWarning
