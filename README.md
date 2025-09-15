# EverQuest → Obsidian Inventory Importer

PowerShell script that parses exported EverQuest inventory files and generates Markdown for your Obsidian vault.

(Note: This is designed for Project P99 https://www.project1999.com)

It creates:
- Per-character inventory pages
- A Planes of Mischief (PoM) cards summary
- A global inventory summary (who owns what, with counts)
- A Velious gems summary

> Script file: `Import-EQInventory.ps1`

## Requirements

- Windows PowerShell 5.1 **or** PowerShell 7+
- Inventory text files named like `CharacterName-Inventory.txt` (tab-separated with columns: Slot, Item, ItemId, Count)
- Obsidian vault path where the Markdown files will be written

## Setup

1. **First Run:**  
   When you run the script for the first time, it will prompt you with a GUI to select your EverQuest directory and your Obsidian vault path. These settings are saved to `settings.json` in the script folder for future runs.

2. **Changing Settings:**  
   To change the EverQuest or Obsidian paths later, you can either:
   - Run the script with the `-UpdateSettings` switch to reprompt for new directories:
     ```powershell
     .\Import-EQInventory.ps1 -UpdateSettings
     ```
   - Or, delete `settings.json` and re-run the script.

> **Tip:** If your execution policy blocks running scripts, launch a new PowerShell session and run:
>
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

## Usage

From PowerShell, run:
```powershell
.\Import-EQInventory.ps1
```
or, to update your EverQuest and Obsidian vault paths:
```powershell
.\Import-EQInventory.ps1 -UpdateSettings
```

The script will scan your configured EverQuest directory for `*-Inventory.txt` files and write Markdown files to your Obsidian vault:
- `_PoM Cards.md`
- `_Global Inventory.md`
- `_Velious Gems.md`
- `{CharacterName}.md` for each character found

## Example Input Row (tab-separated)

```
General1	Crystallized Pumice	12345	2
```

## Roadmap / Ideas

These are common next steps if you want to evolve the script (PRs welcome):
- [x] Parameterization of top-level settings is now handled via `settings.json` and a first-run GUI prompt
- [ ] Add `[CmdletBinding(SupportsShouldProcess)]`, `-WhatIf` / `-Confirm`, and `Write-Verbose`
- [ ] Expose helper functions for **unit testing** (Pester)
- [ ] Add data validation & improved error handling for missing/empty files
- [ ] Optional: publish as a small **module**

> **Note:** Refactoring the static item lists (epics, keys, important items) into a config file is not planned, as these values are stable and rarely change.

## Contributing

- Run static analysis: `Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse`
- (Optional) Run unit tests: `Invoke-Pester` (a basic scaffold exists; tests are currently skipped until the script is parameterized)
- Open issues/PRs with clear repro steps and expected behavior

## License

MIT — see [LICENSE](LICENSE).