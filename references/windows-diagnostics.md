# Windows diagnostics and application lifecycle

Start with the symptom and inspect the smallest relevant state. Each repair should follow an observed cause, then an outcome check.

| Symptom | Useful evidence | Next decision |
| --- | --- | --- |
| Command not found or wrong version | `Get-Command <name> -All`, known installation path, process PATH versus user/machine PATH | Invoke the intended executable; refresh the affected process if PATH changed |
| Native program reports failure | Executable path, argument boundaries, working directory, immediate exit code, relevant stderr | Reproduce the failing boundary with harmless data |
| Port already in use | Listening address/port and owning PID, then executable path and start time | Identify the service before changing a port or stopping anything |
| Permission denied | Exact path/resource, ACL or service privileges, process elevation, file lock | Correct the specific access/lifecycle issue within authorization |
| File changed but app ignores it | App's actual config path, parser result, load/reload behavior, current app process | Verify the app loaded the edited file |
| Windows module/COM behavior differs | PowerShell 7 minor version, 32-bit versus 64-bit, available module version | Use a compatible PowerShell 7 host/API; report dependencies that require 5.1 |

## Return readable diagnostic evidence

For mixed diagnostic results, collect each category under a named property and serialize one result object. Default table formatting can reuse the first object's columns and hide fields on later objects. Project CIM, scheduled-task, and process objects to the needed properties before serialization; do not increase JSON depth just to dump their entire object graphs. Use `-WarningAction Stop` to catch truncation.

Distinguish an empty query result from an access error, hidden display fields, or truncated tool output before concluding a resource is absent.

## Processes and ports

Query a specific resource and keep machine-readable objects:

```powershell
$listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop |
    Where-Object { $_.LocalPort -eq $port })
$ownerIds = @($listeners | Select-Object -ExpandProperty OwningProcess | Sort-Object -Unique)
$owners = @(foreach ($ownerId in $ownerIds) {
    Get-CimInstance Win32_Process -Filter "ProcessId = $ownerId" -ErrorAction Stop |
        Select-Object ProcessId, Name, ExecutablePath, CreationDate
})
$result = [pscustomobject]@{
    Listeners = @($listeners | Select-Object LocalAddress, LocalPort, OwningProcess)
    Owners = $owners
}
ConvertTo-Json -InputObject $result -Depth 4 -WarningAction Stop
```

Inspect a command line only when needed to distinguish instances, and redact sensitive arguments. A PID can be reused: before stopping a process, re-check its path/start time against the identified process. Prefer the application's shutdown API or `Stop-Service` for a service. Do not stop every process with the same name to release one port. After stopping or restarting, re-query the target process/service/port.

Use `Get-Service` and a filtered `Get-CimInstance Win32_Service` for services. Check current state, executable, dependencies, and whether startup type is relevant before changing it. Use `Get-WinEvent -FilterHashtable` with a narrow log/provider/time range for failures; do not dump all event logs.

## Installs and removals

Resolve the requested product using installed package metadata, its registry uninstall entry, or its official installer. Avoid `Win32_Product`, which can trigger MSI consistency checks and repairs. For desktop apps, relevant registry views include:

- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall`
- `HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall`
- `HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`

Use `Get-AppxPackage` for MSIX packages and an already installed package manager's exact package identity when appropriate. Do not guess silent flags or execute an uninstall registry string through `Invoke-Expression`; resolve the executable and arguments according to the installer type. A source repository, profile data, and an installed application are different resources. Remove the resources needed for the requested uninstall; do not infer that its source project or unrelated shared runtime should be deleted.

MCPs may be config entries that launch a program on demand. Inspect the client and scope, remove the intended entry using a structured edit, and identify a remaining service or separate installation before claiming a full removal. A cached plugin manifest does not prove that its MCP is active.

## Packaged app paths and reloads

MSIX applications can see redirected application data under a package's `LocalCache`. A write reported as successful from one process does not prove another app reads those same physical bytes. When app behavior contradicts a file check, identify the app's configuration location and package context; inspect the final path through a file handle if necessary. Do not solve uncertainty by copying credentials into several guessed locations.

Some integrations are loaded at startup, others are watched. Prefer the app's refresh/reload mechanism. Restart only the relevant application when needed, accounting for active work. Verify with its skill list, MCP status, or the resulting behavior.
