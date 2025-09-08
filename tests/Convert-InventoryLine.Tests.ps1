# Pester test scaffold
# NOTE: These are currently skipped because the script executes immediately when dot-sourced.
# Recommended next step: refactor the script into functions with parameters and a guarded 'main' entry point.

Describe 'Import-EQInventory helpers' -Skip:($true) {
    BeforeAll {
        # Once the script is refactored to support dot-sourcing without side effects, do:
        # . "$PSScriptRoot/../Import-EQInventory.ps1"
    }

    It 'Convert-InventoryLine parses a well-formed row' {
        $line = "General1`tCrystallized Pumice`t12345`t2"
        $parsed = Convert-InventoryLine $line
        $parsed.Slot  | Should -Be 'General1'
        $parsed.Item  | Should -Be 'Crystallized Pumice'
        $parsed.Count | Should -Be '2'
    }

    It 'Get-ItemLink links spells to wiki' {
        $link = Get-ItemLink -item 'Spell: Gate' -wikiBaseUrl 'https://wiki.project1999.com/'
        $link | Should -Be '[Spell: Gate](https://wiki.project1999.com/Gate)'
    }
}
