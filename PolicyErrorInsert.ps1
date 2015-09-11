function PolicyErrorInsert {
    [CmdletBinding()]
    param (
        $sqlServerVariable, 
        $sqlDatabaseVariable, 
        $EvaluatedServer, 
        $EvaluatedPolicy, 
        $EvaluationResults
    )

    $sqlQueryText = "INSERT INTO policy.EvaluationErrorHistory (EvaluatedServer, EvaluatedPolicy, EvaluationResults) VALUES(@p0, @p1, @p2)"
    try {
        New-SqlConnectionString $sqlServerVariable $sqlDatabaseVariable | 
        New-SqlCommand $sqlQueryText `@p0 $EvaluatedServer `@p1 $EvaluatedPolicy `@p2 $EvaluationResultsEscape -QueryTimeout  65535
    } catch {
	    $_.Exception.Message
	}
}
