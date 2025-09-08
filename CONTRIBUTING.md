# Contributing

Thanks for considering a contribution! Please:

1. Open an issue first describing the change.
2. Keep PRs focused and small.
3. Run static analysis before pushing:
   ```powershell
   Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse
   ```
4. If/when tests are enabled, run:
   ```powershell
   Invoke-Pester -CI
   ```

## Development tips

- Prefer parameters over hard-coded paths.
- Use `[CmdletBinding(SupportsShouldProcess)]` and `Write-Verbose` for transparency.
- Favor `Try/Catch` with `-ErrorAction Stop` around file I/O.
- Use `Join-Path`, `Resolve-Path`, and `Test-Path` for robust path handling.
