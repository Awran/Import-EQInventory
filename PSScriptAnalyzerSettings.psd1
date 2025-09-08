@{
    Severity     = @('Error','Warning')
    ExcludeRules = @(
        # Enable/disable rules here as the project evolves.
        # 'PSAvoidUsingWriteHost'
    )
    Rules        = @{
        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationAfterEveryPipeline'
        }
    }
}
