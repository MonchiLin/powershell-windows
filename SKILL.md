---
name: powershell-windows
description: Complete Windows automation and troubleshooting using PowerShell 7 only. Use for pwsh scripts, native CLI failures, Chinese text or special paths, JSON/CSV configuration edits, processes, ports, services, and application setup. Verify the execution host and never silently fall back to Windows PowerShell 5.1.
metadata:
  version: "2.1.0"
---

# PowerShell 7 on Windows

Complete the requested Windows task with a verifiable result. Choose the smallest useful commands, inspect their actual output, and repair the demonstrated failure. This skill supplies Windows execution knowledge; it does not grant access to the user's computer or add a shell tool.

## Required execution host: PowerShell 7

Run PowerShell work with `pwsh` / `pwsh.exe`, with `PSEdition = Core` and `PSVersion.Major = 7`. Verify these facts from the executing process, not its filename or terminal title. Do not invoke `powershell.exe`, silently fall back to Windows PowerShell 5.1, or use `Import-Module -UseWindowsPowerShell`, which starts a 5.1 compatibility process.

If the agent's default shell is not PowerShell 7, use its shell-selection option or launch a verified `pwsh.exe` with a script file. Check known host-provided runtimes and `Get-Command pwsh -All` before declaring it missing. If no PowerShell 7 runtime is available, report the missing prerequisite and prepare the script; do not install a runtime or change PATH unless authorized. If a dependency requires 5.1, explain that compatibility blocker and seek a PowerShell 7-compatible API/tool. A different engine requires a new explicit user instruction.

Every reusable `.ps1` produced by this skill should start with `#requires -Version 7.0` and reject an executing major version other than 7. The bundled helpers enforce this themselves.

## Establish where commands run

Use environment information already supplied by the host. When it is missing or a failure depends on it, check the actual shell, PowerShell version, working directory, executable resolution, and whether execution is on the user's Windows machine, WSL, a remote host, or a container.

- Prefer the installed, maintained PowerShell 7 runtime appropriate to the machine's architecture. Do not upgrade the machine just to run a small task.
- In Claude Desktop, a code execution container or Cowork environment is not automatically the Windows host. Use a connected Windows execution tool only when available. Otherwise create or review the `.ps1` artifact and state that host execution remains unverified. Running `pwsh` on Linux does not test Windows registry, COM, services, or drive paths.
- Keep the user's requested tool and scope. A file edit does not imply permission to change profiles, system PATH, execution policy, credentials, or unrelated installations.

For an uncertain environment, run [scripts/Get-WindowsContext.ps1](scripts/Get-WindowsContext.ps1). It returns selected runtime facts and command locations without running the discovered programs or printing environment variable values.

Resolve bundled files relative to this `SKILL.md`, not the project working directory. In the examples below, `$skillRoot` is that absolute directory:

```powershell
& (Join-Path $skillRoot 'scripts/Get-WindowsContext.ps1') -AsJson
& (Join-Path $skillRoot 'scripts/Test-PowerShellScript.ps1') -LiteralPath $scriptPath -AsJson
```

## Execute with predictable semantics

- When launching a separate PowerShell process, use `-NoLogo -NoProfile -NonInteractive -File <script>` for repeatable automation. Use a profile only if the task depends on it. Prefer a script file over deeply nested `-Command` quoting.
- Pass executable paths and argument arrays separately: `& $exe @commandArguments`. Treat dynamic text as data. JSON escaping is not shell escaping; never feed user values into `Invoke-Expression` or a constructed `cmd /c` command.
- Use `-ErrorAction Stop` or script-scoped `$ErrorActionPreference = 'Stop'` where a cmdlet failure must interrupt work. For native executables, capture `$LASTEXITCODE` immediately and interpret that program's documented exit codes. Check each command; the last success does not prove earlier steps succeeded. Stderr alone does not establish failure.
- Keep objects until the presentation boundary. `Format-Table` output is for display, not JSON, CSV, comparisons, or subsequent processing. Use named JSON fields for mixed diagnostic results; default table formatting can hide later objects' fields. Normalize variable-size results with `@(...)` when count or indexing matters.
- Preserve Unicode. Diagnose script encoding, data encoding, and console/native pipe encoding separately, including the child program's own encoding settings. Chinese text and subexpressions such as `"$($item.Name)"` are valid PowerShell. For Python text I/O or JSON array edits, read [Files and configuration](references/files-and-config.md).
- Use `-LiteralPath` for existing paths that may contain brackets or other wildcard characters. Use absolute filesystem paths for .NET file APIs; their working directory can differ from `Get-Location`.
- Honor the host's asynchronous validation rules. Use the background facility actually exposed by its tool, keep a task/session identifier, continue independent work, and collect the result when needed. Do not invent `async` flags or leave an untracked job running.

For nested shells, native argument handling, exit codes, or background jobs, read [references/execution.md](references/execution.md).

## Choose the relevant workflow

| Task | Read when needed | Completion evidence |
| --- | --- | --- |
| Edit configuration, batch files, text, CSV, or filesystem content | [Files and configuration](references/files-and-config.md) | Requested values changed; unrelated data preserved; output parses or round-trips |
| Diagnose a missing command, busy port, process, service, or installation | [Windows diagnostics](references/windows-diagnostics.md) | Resolved executable or resource owner; observed application/service state after the fix |
| Write or repair a reusable `.ps1` | [Execution](references/execution.md) | Parser check on the target engine, then a representative behavior check |

Read only the reference relevant to the current task. A simple command does not require a full machine inventory or every checklist in this skill.

## Verify the outcome

Before running a new script that changes data, use the bundled syntax checker with the intended PowerShell executable. It parses files without executing them and returns line/column diagnostics, JSON on request, and a nonzero exit code for parse or file errors. A parse pass does not prove runtime compatibility or correct behavior.

For consequential scripts, exercise the risky behavior in a task-specific temporary directory first: relevant examples include Chinese text, a path containing spaces and brackets, a missing input, an empty or singleton result, a native command failure, and a second run. Test only cases the script needs to support. Use `-WhatIf` when the command supports `ShouldProcess`; it does not replace outcome checks.

After a mutation, read the resulting file or resource state. For app integration, verify the app's loader or UI when possible; a file existing somewhere on disk is insufficient evidence of installation. Report what changed, the meaningful check, and any remaining environment limitation in the user's language. Redact secrets and unnecessary command-line details.
