<#
    .NOTES
        ===========================================================================
        Created with:    Visual Studio Code
        Created on:      2025-05-28
        Created by:      Scott L Howell
        Filename:        Import-EQInventory.ps1
        Version:         0.1.3 - 2025-09-15
        Change log:
            0.1.3 - 2025-09-15 - Converted to use settings.json for paths
            0.1.2 - 2025-09-08 - Added Global Inventory summary and velious gems summary
            0.1.1 - 2025-05-30 - Added support for checking for epics in inventory
            0.1.0 - 2025-05-28 - Initial version
        ===========================================================================

    .DESCRIPTION
        This script processes EverQuest inventory text files and generates markdown files
        suitable for use in Obsidian. It summarizes equipped items, bank contents, general
        slots, important items, PoM cards, keys, flowers of functionality, and velious gems.
        It also creates a global inventory summary across all characters.
    .EXAMPLE
        Import-EQInventory.ps1
        This will run the script using the default directories defined in the script.
#>

param(
    [switch]$UpdateSettings
)
# Reference the parameter to avoid 'declared but not used' error
$null = $UpdateSettings

# --- Settings JSON Integration ---
$settingsPath = Join-Path $PSScriptRoot "settings.json"
$wikiBaseUrl = "https://wiki.project1999.com/" # Still hardcoded

function Show-Setting {
    Add-Type -AssemblyName System.Windows.Forms

    $eqFolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $eqFolderBrowser.Description = "Select EverQuest Log Directory"
    $null = $eqFolderBrowser.ShowDialog()
    $eqDir = $eqFolderBrowser.SelectedPath

    if (-not $eqDir) { throw "EverQuest directory not selected." }

    $obsidianFolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $obsidianFolderBrowser.Description = "Select Obsidian Vault Path"
    $null = $obsidianFolderBrowser.ShowDialog()
    $obsidianDir = $obsidianFolderBrowser.SelectedPath

    if (-not $obsidianDir) { throw "Obsidian vault path not selected." }

    $settings = @{
        everquest_log_directory = $eqDir
        obsidian_vault_path     = $obsidianDir
    }
    $settings | ConvertTo-Json | Set-Content $settingsPath
    return $settings
}

function Get-Setting {
    if ($UpdateSettings -or -not (Test-Path $settingsPath)) {
        return Show-Setting
    } else {
        return Get-Content $settingsPath | ConvertFrom-Json
    }
}

$settings = Get-Setting
$EverQuestDirectory = $settings.everquest_log_directory
$ObsidianVaultPath = $settings.obsidian_vault_path


# --- Config ---
$pomCardPatterns = @("Squire", "Knight", "Crown", "Throne")
$pomCardRegex = [regex]::new("(?i)(\w+)\s+(Squire|Knight|Crown|Throne)$")
$pomColors = @("Red", "Blue", "Black", "White")
$pomTypes = @("Squire", "Knight", "Crown", "Throne")
$allPoMCards = foreach ($color in $pomColors) { foreach ($type in $pomTypes) { "A $color $type" } }
$epicItems = @(
    "Singing Short Sword",
    "Water Sprinkler of Nem Ankh",
    "Nature Walkers Scimitar",
    "Staff of the Serpent"
    "Orb of Mastery",
    "Celestial Fists",
    "Scythe of the Shadowed Soul",
    "Fiery Defender",
    "Earthcaller",
    "Ragebringer",
    "Innoruuk's Curse",
    "Spear of Fate",
    "Blade of Strategy",
    "Blade of Tactics",
    "Staff of the Four"
)
$importantItems = @(
    "Journeyman's Boots",
    "Pegasus Feather Cloak",
    "Worker Sledgemallet",
    "Bracer of the Hidden"
    "Reaper of the Dead",
    "Crystallized Pumice", # Special case for counting
    "Flight Arrow" # Special case for counting
)
$keysList = @(
    "Tooth of the Cobalt Scar",
    "Trakanon Idol", "Hole Key",
    "Bone Crafted Key",
    "Key to Charasis",
    "Shrine Key",
    "Key of Veeshan",
    "Sleeper's key"
)
$flowerColors = @("Red", "Blue", "Green", "Black", "White")

# --- Helper Functions ---
function Get-Number($name, $prefix) {
    if ($name -match "^$prefix(\d+)$") { return [int]$Matches[1] }
    return 0
}

function Convert-InventoryLine($line) {
    $columns = $line -split "`t"
    if ($columns.Count -ge 4) {
        return @{
            Slot = $columns[0].Trim()
            Item = $columns[1].Trim()
            # ItemId = $columns[2].Trim() # Not used
            Count = $columns[3].Trim()
        }
    }
    return $null
}

function Add-PoMCard($item, $characterName, [ref]$pomCardsByType) {
    if ($pomCardRegex.IsMatch($item) -and $item -match '^A\s') {
        $pomMatch = $pomCardRegex.Match($item)
        $color = $pomMatch.Groups[1].Value
        $type = $pomMatch.Groups[2].Value
        $cardName = "$color $type" -replace '\s+', ' '
        $cardName = $cardName.Trim()
        if (-not $pomCardsByType.Value[$type].ContainsKey($cardName)) {
            $pomCardsByType.Value[$type][$cardName] = @()
        }
        $pomCardsByType.Value[$type][$cardName] += $characterName
    }
}

function Test-Item($inventoryLines, $itemName) {
    foreach ($line in $inventoryLines) {
        $parsed = Convert-InventoryLine $line
        if ($parsed -and $parsed.Item -eq $itemName) { return $true }
    }
    return $false
}

function Get-ItemCount($inventoryLines, $itemName) {
    $count = 0
    foreach ($line in $inventoryLines) {
        $parsed = Convert-InventoryLine $line
        if ($parsed -and $parsed.Item -eq $itemName) {
            $count += [int]$parsed.Count
        }
    }
    return $count
}

function Write-MarkdownFile($path, $lines) {
    $content = $lines -join "`n"
    Set-Content -Path $path -Value $content -Encoding utf8
}

function Get-ItemLink($item, $wikiBaseUrl) {
    if ($item -like "Spell:*") {
        $spellName = $item -replace "^Spell:\s*", ""
        return "[$item]($($wikiBaseUrl + ($spellName -replace ' ', '_')))"

    } elseif ($item -eq "Empty") {
        return "Empty"
    } else {
        return "[$item]($($wikiBaseUrl + ($item -replace ' ', '_')))"

    }
}

# --- Main ---
$inventoryFiles = Get-ChildItem -Path $EverQuestDirectory -Filter '*-Inventory.txt' | Where-Object { -not $_.PSIsContainer }
if ($inventoryFiles.Count -eq 0) {
    Write-Error "No inventory files found matching '*-Inventory.txt' in $EverQuestDirectory"
    exit 1
}

# PoM Cards structure
$pomCardsByType = @{ Squire=@{}; Knight=@{}; Crown=@{}; Throne=@{} }

# Global Inventory structure
$globalInventory = @{}

foreach ($file in $inventoryFiles) {
    $characterName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) -replace '-Inventory$', '' -replace '[\\\/:\*\?"<>\|]', ''
    $lines = Get-Content $file.FullName
    if ($lines.Count -eq 0) { Write-Warning "Input file is empty: $($file.FullName)"; continue }
    $lastModified = $file.LastWriteTime
    $inventoryLines = $lines | Select-Object -Skip 1

    # --- Parse Inventory for Markdown ---
    $bankItems = @{}
    $generalItems = @{}
    $equippedItems = @{}

    foreach ($line in $inventoryLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parsed = Convert-InventoryLine $line
        if (-not $parsed) { continue }
        $slot = $parsed.Slot; $item = $parsed.Item; $count = $parsed.Count

        # Ignore Shared Bank, charm, held
        if ($slot -like "Shared Bank*" -or $slot -like "charm" -or $slot -like "held" -or $slot -like "sharedbank*") { continue }

        $itemDisplay = Get-ItemLink $item $wikiBaseUrl

        if ($slot -match "^Bank\d+$") {
            $bankItems[$slot] = @{"main" = "| $slot | $itemDisplay | $count |"; "subs" = @()}
        } elseif ($slot -match "^(Bank\d+)-(.+)$") {
            $bank = $Matches[1]
            if (-not $bankItems.ContainsKey($bank)) { $bankItems[$bank] = @{"main" = ""; "subs" = @()} }
            $bankItems[$bank]["subs"] += "| $slot | $itemDisplay | $count |"
        } elseif ($slot -match "^General\d+$") {
            $generalItems[$slot] = @{"main" = "| $slot | $itemDisplay | $count |"; "subs" = @()}
        } elseif ($slot -match "^(General\d+)-(.+)$") {
            $general = $Matches[1]
            if (-not $generalItems.ContainsKey($general)) { $generalItems[$general] = @{"main" = ""; "subs" = @()} }
            $generalItems[$general]["subs"] += "| $slot | $itemDisplay | $count |"
        } else {
            $equippedItems[$slot] = "| $slot | $itemDisplay | $count |"
        }

        Add-PoMCard -item $item -characterName $characterName -pomCardsByType ([ref]$pomCardsByType)

        # --- Global Inventory aggregation ---
        if ($item -ne "Empty") {
            if (-not $globalInventory.ContainsKey($item)) {
                $globalInventory[$item] = @{}
            }
            if ($globalInventory[$item].ContainsKey($characterName)) {
                $globalInventory[$item][$characterName] += [int]$count
            } else {
                $globalInventory[$item][$characterName] = [int]$count
            }
        }
    }

    # --- Markdown Output ---
    $markdown = @("# EverQuest Inventory for **$characterName**")
    $markdown += "_Inventory file last updated:_ $lastModified"

    # Equipped Items
    if ($equippedItems.Count -gt 0) {
        $markdown += "# Equipped Items"
        $markdown += "| Slot | Item | Count |"
        $markdown += "| --- | --- | :---: |"
        foreach ($slot in ($equippedItems.Keys | Sort-Object)) { $markdown += $equippedItems[$slot] }
    }

    # Epic Table
    $hasEpic = $inventoryLines | Where-Object {
        $parsed = Convert-InventoryLine $_
        $parsed -and $epicItems -contains $parsed.Item
    }
    $epicResult = if ($hasEpic) { "✔️" } else { "❌" }
    $markdown += "# Has Epic?"
    $markdown += "| Has Epic? | $epicResult |"
    $markdown += "| --- | :---: |"

    # Flowers Table
    $markdown += "# Flowers of Functionality"
    $markdown += "| Flower Color | Has Flower |"
    $markdown += "| --- | :---: |"
    foreach ($color in $flowerColors) {
        $flowerName = "$color Flower of Functionality"
        $hasFlower = $inventoryLines | Where-Object { $_ -match [regex]::Escape($flowerName) }
        $markdown += "| $color | $(if ($hasFlower) { '✔️' } else { '❌' }) |"
    }

    # PoM Cards Summary
    $markdown += "# PoM Cards Summary"
    foreach ($type in $pomCardPatterns) {
        $markdown += "## $type"
        $markdown += "| Card Name | Has Card |"
        $markdown += "| --- | :---: |"
        $cardsOfType = $allPoMCards | Where-Object { $_ -match "A\s+\w+\s+$type$" }
        foreach ($card in $cardsOfType) {
            $cardKey = $card -replace "^A\s+", ""
            $hasCard = $pomCardsByType[$type].ContainsKey($cardKey) -and ($pomCardsByType[$type][$cardKey] -contains $characterName)
            $markdown += "| $card | $(if ($hasCard) { '✔️' } else { '❌' }) |"
        }
    }

    # Important Items Table
    $markdown += "# Important Items"
    $markdown += "| Item | Has Item |"
    $markdown += "| --- | :---: |"
    foreach ($itemName in $importantItems) {
        if ($itemName -in @("Crystallized Pumice", "Flight Arrow")) {
            $itemCount = Get-ItemCount $inventoryLines $itemName
            $markdown += "| $itemName$(if ($itemCount -gt 0) { ' (' + $itemCount + ')' } else { '' }) | $(if ($itemCount -gt 0) { '✔️' } else { '❌' }) |"
        } else {
            $markdown += "| $itemName | $(if (Test-Item $inventoryLines $itemName) { '✔️' } else { '❌' }) |"
        }
    }

    # Keys Table
    $markdown += "# Keys"
    $markdown += "| Key Name | Has Key |"
    $markdown += "| --- | :---: |"
    foreach ($keyName in $keysList) {
        $markdown += "| $keyName | $(if (Test-Item $inventoryLines $keyName) { '✔️' } else { '❌' }) |"
    }

    # General Slots
    if ($generalItems.Count -gt 0) {
        $markdown += "# General Slots"
        foreach ($general in ($generalItems.Keys | Sort-Object { Get-Number $_ "General" })) {
            $markdown += "### $general"
            $markdown += "| Slot | Item | Count |"
            $markdown += "| --- | --- | :---: |"
            if ($generalItems[$general]["main"] -ne "") { $markdown += $generalItems[$general]["main"] }
            foreach ($sub in $generalItems[$general]["subs"]) { $markdown += $sub }
        }
    }

    # Bank Slots
    $markdown += "# Bank Slots"
    foreach ($bank in ($bankItems.Keys | Sort-Object { Get-Number $_ "Bank" })) {
        $bankNum = Get-Number $bank "Bank"
        if ($bankNum -ge 9) { continue }
        $markdown += "### $bank"
        $markdown += "| Slot | Item | Count |"
        $markdown += "| --- | --- | :---: |"
        if ($bankItems[$bank]["main"] -ne "") { $markdown += $bankItems[$bank]["main"] }
        foreach ($sub in $bankItems[$bank]["subs"]) { $markdown += $sub }
    }

    # Write Markdown file
    $outputFile = Join-Path $ObsidianVaultPath "$characterName.md"
    Write-MarkdownFile $outputFile $markdown
    Write-Output "Inventory file created: $outputFile"
}

# --- PoM Cards Summary File ---
$pomMarkdown = @("# PoM Cards")
$pomMarkdown += "_Updated:_ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
foreach ($type in $pomCardPatterns) {
    $pomMarkdown += "## $type"
    $pomMarkdown += "| Card Name | Total Count | Characters |"
    $pomMarkdown += "| --- | :---: | --- |"
    foreach ($card in ($pomCardsByType[$type].Keys | ForEach-Object { $_.Trim() } | Sort-Object -Unique)) {
        $characters = $pomCardsByType[$type][$card] | Sort-Object -Unique
        $totalCount = $pomCardsByType[$type][$card].Count
        $charLinks = $characters | ForEach-Object { "[[$_]]" }
        $pomMarkdown += "| $card | $totalCount | $($charLinks -join ', ') |"
    }
}
$pomCardsFile = Join-Path $ObsidianVaultPath "_PoM Cards.md"
Write-MarkdownFile $pomCardsFile $pomMarkdown
Write-Output "PoM Cards file created: $pomCardsFile"

# --- Global Inventory Summary ---
$globalMarkdown = @("# Global Inventory")
$globalMarkdown += "_Updated:_ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$globalMarkdown += "# Inventory Summary"
$globalMarkdown += "| Item | Characters |"
$globalMarkdown += "| --- | --- |"

foreach ($item in ($globalInventory.Keys | Sort-Object)) {
    $itemLink = Get-ItemLink $item $wikiBaseUrl
    $charLinks = $globalInventory[$item].Keys | Sort-Object | ForEach-Object {
        $count = $globalInventory[$item][$_]
        if ($count -gt 1) {
            "[[$_]] ($count)"
        } else {
            "[[$_]]"
        }
    }
    $globalMarkdown += "| $itemLink | $($charLinks -join ', ') |"
}

$globalFile = Join-Path $ObsidianVaultPath "_Global Inventory.md"
Write-MarkdownFile $globalFile $globalMarkdown
Write-Output "Global Inventory file created: $globalFile"

# --- Velious Gems Summary ---

# Velious gems and their slots (from https://wiki.project1999.com/Velious_Armor_Gems)
$veliousGems = @(
    @{ Name = "Black Marble"; Slot = "Priest Brestplate" },
    @{ Name = "Pristine Emerald"; Slot = "Caster Robe" },
    @{ Name = "Flawless Diamond"; Slot = "Melee Breastplate" }
    @{ Name = "Flawed Sea Sapphire"; Slot = "Melee Legs" },
    @{ Name = "Flawed Emerald"; Slot = "Melee Arms" },
    @{ Name = "Flawed Topaz"; Slot = "Caster Arms" },
    @{ Name = "Crushed Black Marble"; Slot = "Melee Boots" },
    @{ Name = "Crushed Coral"; Slot = "Melee Helm" },
    @{ Name = "Crushed Flame Emerald"; Slot = "Melee Bracer, Priest Boots" },
    @{ Name = "Crushed Flame Opal"; Slot = "Caster Helm" },
    @{ Name = "Crushed Jaundice Gem"; Slot = "Caster Boots" },
    @{ Name = "Crushed Lava Ruby"; Slot = "Priest Gloves" },
    @{ Name = "Crushed Onyx Sapphire"; Slot = "Caster Bracer, Priest Helm" },
    @{ Name = "Crushed Opal"; Slot = "Priest Bracer" },
    @{ Name = "Crushed Topaz"; Slot = "Melee Gloves, Caster Gloves" },
    @{ Name = "Chipped Onyx Sapphire"; Slot = "Priest Legs" },
    @{ Name = "Nephrite"; Slot = "Caster Legs" },
    @{ Name = "Jaundice Gem"; Slot = "Priest Arms" }

    # Add more if needed, or adjust for duplicates if you want to show all slots for a gem
)

# Build a lookup for gem slots (in case a gem is used for multiple slots)
$veliousGemSlots = @{}
foreach ($gem in $veliousGems) {
    if (-not $veliousGemSlots.ContainsKey($gem.Name)) {
        $veliousGemSlots[$gem.Name] = @()
    }
    if ($veliousGemSlots[$gem.Name] -notcontains $gem.Slot) {
        $veliousGemSlots[$gem.Name] += $gem.Slot
    }
}

# Aggregate gem counts per character
$veliousGemInventory = @{}
foreach ($file in $inventoryFiles) {
    $characterName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) -replace '-Inventory$', '' -replace '[\\\/:\*\?"<>\|]', ''
    $lines = Get-Content $file.FullName
    $inventoryLines = $lines | Select-Object -Skip 1
    foreach ($line in $inventoryLines) {
        $parsed = Convert-InventoryLine $line
        if ($parsed -and $veliousGemSlots.ContainsKey($parsed.Item)) {
            if (-not $veliousGemInventory.ContainsKey($parsed.Item)) {
                $veliousGemInventory[$parsed.Item] = @{}
            }
            if ($veliousGemInventory[$parsed.Item].ContainsKey($characterName)) {
                $veliousGemInventory[$parsed.Item][$characterName] += [int]$parsed.Count
            } else {
                $veliousGemInventory[$parsed.Item][$characterName] = [int]$parsed.Count
            }
        }
    }
}

# Build Markdown
$veliousMarkdown = @("# Velious Armor Gems")
$veliousMarkdown += "_Updated:_ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$veliousMarkdown += "# Gem Summary"
$veliousMarkdown += "| Gem | Slot(s) | Characters |"
$veliousMarkdown += "| --- | --- | --- |"

foreach ($gem in $veliousGems) {
    $gemName = $gem.Name
    $wikiLink = "[$gemName](${wikiBaseUrl}$($gemName -replace ' ', '_'))"
    $slots = $veliousGemSlots[$gemName] -join ", "
    if ($veliousGemInventory.ContainsKey($gemName)) {
        $charLinks = $veliousGemInventory[$gemName].Keys | Sort-Object | ForEach-Object {
            $count = $veliousGemInventory[$gemName][$_]
            if ($count -gt 1) {
                "[[$_]] ($count)"
            } else {
                "[[$_]]"
            }
        }
        $charCell = $charLinks -join ", "
    } else {
        $charCell = ""
    }
    $veliousMarkdown += "| $wikiLink | $slots | $charCell |"
}

$veliousFile = Join-Path $ObsidianVaultPath "_Velious Gems.md"
Write-MarkdownFile $veliousFile $veliousMarkdown
Write-Output "Velious Gems file created: $veliousFile"
# --- End of Script ---