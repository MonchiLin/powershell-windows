#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string[]]$CommandName = @('pwsh', 'git', 'rg', 'python', 'node', 'uv'),
    [switch]$AsJson
)

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -ne 7) {
    throw 'PowerShell 7 is required. Run this script with pwsh.exe.'
}
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$onWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$issues = [System.Collections.Generic.List[string]]::new()
$elevated = $null
$enginePath = $null

if ($onWindows) {
    $identity = $null
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        $elevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        $issues.Add('Could not determine token elevation.')
    }
    finally {
        if ($null -ne $identity) { $identity.Dispose() }
    }
}

$currentProcess = [Diagnostics.Process]::GetCurrentProcess()
try { $enginePath = $currentProcess.MainModule.FileName }
catch { $issues.Add('Could not determine the current engine executable.') }
finally { $currentProcess.Dispose() }

$nativeMode = Get-Variable -Name PSNativeCommandArgumentPassing -ErrorAction SilentlyContinue
$nativeErrors = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
$commands = @(foreach ($commandToFind in $CommandName) {
    $resolved = @(Get-Command -Name $commandToFind -CommandType Application -All -ErrorAction SilentlyContinue)
    [pscustomobject][ordered]@{
        Name = $commandToFind
        Found = $resolved.Count -gt 0
        Paths = @($resolved | ForEach-Object { $_.Source } | Select-Object -Unique)
    }
})

$context = [pscustomobject][ordered]@{
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    Edition = $PSVersionTable.PSEdition
    Windows = $onWindows
    OSVersion = [Environment]::OSVersion.VersionString
    Is64BitProcess = [Environment]::Is64BitProcess
    Is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
    Elevated = $elevated
    EnginePath = $enginePath
    ShellLocation = (Get-Location).Path
    ProcessDirectory = [Environment]::CurrentDirectory
    ConsoleInputEncoding = [Console]::InputEncoding.WebName
    ConsoleOutputEncoding = [Console]::OutputEncoding.WebName
    NativePipeEncoding = $OutputEncoding.WebName
    NativeArgumentPassing = $(if ($null -ne $nativeMode) { [string]$nativeMode.Value } else { 'Legacy' })
    NativeExitCodeErrors = $(if ($null -ne $nativeErrors) { [bool]$nativeErrors.Value } else { $false })
    Commands = $commands
    Issues = @($issues.ToArray())
}

if ($AsJson) { ConvertTo-Json -InputObject $context -Depth 6 }
else { $context }
