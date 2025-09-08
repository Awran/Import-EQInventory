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

1. Open `Import-EQInventory.ps1` and update the **Config** section near the top:
   - `$EverQuestDirectory` — folder containing your `*-Inventory.txt` files
   - `$ObsidianVaultPath` — your Obsidian vault root (or a subfolder inside it)
   - `$wikiBaseUrl` — base URL for item links (defaults to Project 1999 wiki)

2. Save the script.

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

The script will scan `$EverQuestDirectory` for `*-Inventory.txt` files and write Markdown files to `$ObsidianVaultPath`:
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
- [ ] Convert top-level settings into **parameters** (e.g., `-EverQuestDirectory`, `-ObsidianVaultPath`, `-WikiBaseUrl`)
- [ ] Add `[CmdletBinding(SupportsShouldProcess)]`, `-WhatIf` / `-Confirm`, and `Write-Verbose`
- [ ] Refactor lists (epics, keys, “important items”) into a JSON **config** file
- [ ] Expose helper functions for **unit testing** (Pester)
- [ ] Add data validation & improved error handling for missing/empty files
- [ ] Optional: publish as a small **module**

## Contributing

- Run static analysis: `Invoke-ScriptAnalyzer -Path . -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse`
- (Optional) Run unit tests: `Invoke-Pester` (a basic scaffold exists; tests are currently skipped until the script is parameterized)
- Open issues/PRs with clear repro steps and expected behavior

## License

MIT — see [LICENSE](LICENSE).

