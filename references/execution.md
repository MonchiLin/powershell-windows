# Execution and failure handling

## Select the interpreter deliberately

Use only a verified PowerShell 7 executable. `powershell.exe` is Windows PowerShell 5.1 and must not be used by this skill. Inspect `$PSVersionTable` and `Get-Command` instead of inferring a version from the terminal window. `Get-Command <name> -All` reveals aliases, scripts, shims, and executable precedence. Invoke the resolved executable when reproducibility matters.

Write for PowerShell 7; constructs such as `&&`, `||`, `??`, and the ternary operator are valid. For APIs introduced in a later 7.x release, check the installed minor version. Do not infer Windows API availability from a parser pass on PowerShell 7 for Linux. Use this guard in reusable scripts:

```powershell
#requires -Version 7.0
[CmdletBinding()]
param()
if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -ne 7) {
    throw 'PowerShell 7 is required. Run this script with pwsh.exe.'
}
$ErrorActionPreference = 'Stop'
```

Use parameters and splatting for scripts. Avoid using automatic/read-only variables such as `$PID`, `$HOME`, `$Host`, `$PSHOME`, `$Error`, `$Matches`, or `$args` as task variables. Use names such as `$processId`, `$taskRoot`, and `$commandArguments`.

## Cross one shell boundary at a time

In a tool already running PowerShell 7, submit PowerShell directly. If the only tool is Bash, create a `.ps1` through the host's file editing tool, then call a discovered `pwsh.exe` with `-File`. A Bash double-quoted string can expand `$variables`, `$(...)`, and backticks before PowerShell sees them. Single quoting at one layer does not automatically quote the next layer.

```powershell
$exe = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$commandArguments = @('-C', $repoRoot, 'status', '--short')
& $exe @commandArguments
$nativeExitCode = $LASTEXITCODE
if ($nativeExitCode -ne 0) {
    throw "git status failed with exit code $nativeExitCode"
}
```

`& $exe @commandArguments` prevents PowerShell from re-evaluating argument contents as code. It does not make the target program's own options safe. Use that program's end-of-options marker where appropriate; do not assume every executable accepts `--`.

PowerShell 7.3+ preserves native empty-string and embedded-quote arguments better than 5.1. On Windows, `.cmd`/`.bat` and selected Windows executables still use legacy handling by default. For complex JSON, quotes, or untrusted text, prefer the program's file/stdin input, or invoke its real executable rather than a batch shim. Test exact argument delivery when it matters. Do not switch `$PSNativeCommandArgumentPassing` globally to repair one command.

`Start-Process -ArgumentList` joins its arguments into a command-line string; supplying an array does not preserve every argument boundary automatically. `--%` is a Windows-native stop-parsing mechanism for literal commands, not a general-purpose quoting fix for dynamic data.

## Distinguish errors from exit codes

Cmdlet nonterminating errors become catchable with `-ErrorAction Stop`. Native program failures are a separate mechanism; `$ErrorActionPreference` alone is insufficient across versions. Capture `$LASTEXITCODE` before another executable changes it.

For multiple native commands, determine success for each step. A sequence such as `check; build` can continue after a native failure and report the final command's success. Stop dependent steps when their prerequisite fails. For independent checks, collect each exit code and summarize all failures. A wrapper script must return a nonzero exit code when any required check fails; a final logging or cleanup command must not erase that result.

Some nonzero exit codes are expected: `rg`/`git diff --exit-code` use 1 for a meaningful non-error result; `robocopy` uses codes below 8 for nonfatal outcomes. Check the specific program's contract. In a PowerShell version where `$PSNativeCommandUseErrorActionPreference` is enabled, disable it only inside the block that interprets such a command itself:

```powershell
& {
    $PSNativeCommandUseErrorActionPreference = $false
    & $rgExe '--files' $taskRoot
    $nativeExitCode = $LASTEXITCODE
    if ($nativeExitCode -notin @(0, 1)) {
        throw "File enumeration failed: $nativeExitCode"
    }
}
```

Use `try/finally` to dispose handles, restore a pushed location, or release a resource. `return` inside `try` is valid and still runs `finally`. Add `catch` when translating or recovering from a specific failure; do not swallow every exception or retry an irreversible action because the outcome is unknown. `Set-StrictMode` is useful for a maintained script, but should not be imposed on the caller's entire session as a repair.

## Long commands and child processes

Use the agent tool's supported background execution first. In a host exposing `bash async:true`, use it for long validation; another host may expose a task ID, `run_in_background`, or a process session instead. Track completion, exit status, and useful log output. Do independent work while it runs. Poll only when a result is needed or the tool requires polling for completion.

A PowerShell `Start-Job` belongs to its hosting PowerShell process and is unsuitable for surviving a short-lived tool invocation. A child service that must outlive the call needs a deliberate process lifecycle. With `Start-Process`, use `-PassThru`, an explicit working directory, distinct stdout/stderr files, and `-WindowStyle Hidden` for background Windows helpers. Preserve the returned process ID and start time. Use a visible window for a requested interactive application.

A timeout means the result may be incomplete. Establish whether the owned process is still running before retrying. Stop only the process or process tree created for the task, after confirming its identity. Never use a name-wide kill for shared runtimes such as Python, Node, or PowerShell.

## Sources

- [Microsoft: PowerShell parsing and native arguments](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing)
- [Microsoft: preference variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables)
- [Microsoft: Start-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process)
