# Files, Unicode, and structured configuration

## Resolve the real target

Use `Join-Path` to compose filesystem paths and `-LiteralPath` to operate on existing names containing spaces, brackets, or wildcard characters. Single-quoted strings treat `$` and backticks literally; an apostrophe inside them is doubled. Variable-held paths are data and do not need repeated hand escaping.

```powershell
$inputItem = Get-Item -LiteralPath $inputPath -ErrorAction Stop
if ($inputItem.PSProvider.Name -ne 'FileSystem' -or $inputItem.PSIsContainer) {
    throw 'Expected a filesystem file'
}
$text = Get-Content -LiteralPath $inputItem.FullName -Raw -Encoding UTF8 -ErrorAction Stop
```

Use absolute filesystem paths with `[IO.File]` and `[IO.Directory]`; .NET's process current directory need not match PowerShell's current location. `Resolve-Path` requires an existing path. For a new file, resolve the existing parent and validate the intended leaf name.

Before a recursive move/delete, resolve the exact root and target, reject an empty path, the root itself, and targets outside the authorized directory. Compare a complete path with a separator boundary, not a raw prefix (`work-old` is not under `work`). Inspect reparse points in the target and its ancestors: `GetFullPath` only normalizes text and does not resolve junctions. Use a native PowerShell operation end to end; do not enumerate paths in PowerShell and pass constructed deletion commands to another shell. Avoid destructive directory mirroring unless that behavior was requested.

## Choose encoding for the consumer

| Boundary | Practical choice |
| --- | --- |
| New JSON consumed by other tools | Explicit UTF-8 without BOM, unless its format requires otherwise |
| New `.ps1` with Chinese literals | UTF-8; PowerShell 7 reads it with or without a BOM |
| Existing text or CSV | Determine and preserve its actual encoding and newline convention |
| CSV intended for Excel | Explicit delimiter and an Excel-compatible encoding; UTF-8 with BOM is often useful |
| Native command output | Determine the program's encoding separately from file encoding |

PowerShell 7 generally defaults to UTF-8 without BOM. Files created by older Windows PowerShell tools may instead contain UTF-16LE, a BOM, or a legacy code page. When an existing file has no BOM, do not assume that makes it UTF-8; inspect its consumer, repository convention, or decode strictly. `chcp 65001` alone does not fix every encoding boundary.

For known UTF-8 data, this explicitly writes UTF-8 without BOM:

```powershell
$utf8NoBom = [System.Text.UTF8Encoding]::new($false, $true)
[IO.File]::WriteAllText($absoluteOutputPath, $text, $utf8NoBom)
```

If a native program supports UTF-8 output and the process needs it, configure `[Console]::OutputEncoding` and `$OutputEncoding` for that execution scope. Do not permanently modify the user's profile to repair a single command. Binary content belongs in byte/file APIs, never a text pipeline.

### Python text I/O

PowerShell 7 does not set Python's file or standard-stream encoding. When the task uses UTF-8 text, invoke the resolved Python interpreter with `-X utf8`. For known UTF-8 files, specify `encoding='utf-8'` in `open()` or `Path.read_text()` / `write_text()`; use `utf-8-sig` for reading UTF-8 inputs that may have a BOM. Preserve an existing file's actual encoding rather than forcing every input to UTF-8.

`PYTHONIOENCODING=utf-8` controls Python's standard streams; it does not set the encoding of `Path.read_text()`. Match the subprocess's emitted bytes to the caller's decoder as well. For example, setting `ProcessStartInfo.StandardOutputEncoding` changes the reader, not the child's encoding. Prefer process-local settings; if changing environment variables or console encoding in a persistent session, save and restore their previous values in `finally`.

## Modify configuration structurally

Use a parser for JSON, TOML, YAML, XML, and other structured formats. Read the current configuration and change only the requested keys. JSON is not JSONC; do not discard comments by silently parsing a different format. For case-distinct JSON keys or empty property names, use PowerShell 7's `ConvertFrom-Json -AsHashtable` or an appropriate existing parser; conversion to a `PSCustomObject` cannot represent every valid JSON object faithfully. Preserve date-like strings as strings when their exact representation matters: use `-DateKind String` when that parameter is available, or a parser with equivalent behavior.

For an object-shaped, known UTF-8 JSON configuration:

```powershell
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 -ErrorAction Stop |
    ConvertFrom-Json -ErrorAction Stop
# Apply only the requested property change to $config here.
$serialized = ConvertTo-Json -InputObject $config -Depth 50 -WarningAction Stop
$null = ConvertFrom-Json -InputObject $serialized -ErrorAction Stop
```

Choose a sufficient depth for the actual document; serialization's default depth is too shallow for many configurations. Treat a truncation warning as a failed edit.

For JSON with a top-level array, preserve its shape at both boundaries: parse with `-NoEnumerate` and serialize with `-InputObject`. Default parsing can turn `[]` into `$null` and `[1]` into a scalar during assignment; adding `-InputObject` afterward cannot restore that lost distinction.

```powershell
$data = ConvertFrom-Json -InputObject $jsonText -NoEnumerate -ErrorAction Stop
$serialized = ConvertTo-Json -InputObject $data -Depth 50 -WarningAction Stop
```

Use the depth and key/date-preservation options appropriate to the document. For array edits, verify the root remains an array, including when it has zero or one element.

When practical, write the new content to a temporary file beside the target, parse it back, and verify the requested value and unrelated fields before replacing the original. For an existing local file, `[IO.File]::Replace` can replace it while retaining a backup; it requires an existing destination and a supporting filesystem. For a new file, rename/move the staged file into place with overwrite disabled. Check for concurrent changes before replacement when another application may write the file. If the host requires a dedicated editing tool, use it and perform the same structural verification afterward.

Do not print whole configuration files or environments when selected keys, names, or redacted values suffice. Credential values, connection strings, and tokens do not belong in diagnostic transcripts or bundled skills.

## CSV and batch operations

Use `Import-Csv`/`Export-Csv` or the appropriate parser, never a simple comma split. Specify the delimiter and encoding explicitly. Preserve column order deliberately. Keep row values as data; do not evaluate spreadsheet formulas or embedded shell fragments.

For bulk renames or moves, first calculate the source-to-destination mapping. Check missing inputs, duplicate destinations, existing outputs, and whether a source is another row's destination. Use a two-stage rename for cycles or case-only renames when required. Keep the mapping and verify counts and names afterward. A second run should either be idempotent or clearly report that the operation is already complete.

## Sources

- [Microsoft: PowerShell character encoding](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding)
- [Microsoft: ConvertFrom-Json array preservation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json#example-5-round-trip-a-single-element-array)
- [Python: UTF-8 mode and standard-stream encoding](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONIOENCODING)
