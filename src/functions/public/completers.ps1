Register-ArgumentCompleter -CommandName Get-GoogleFont, Install-GoogleFont -ParameterName Name -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    $null = $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter
    Get-GoogleFont -Verbose:$false | Select-Object -ExpandProperty Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new("'$_'", $_, 'ParameterValue', $_) }
}
