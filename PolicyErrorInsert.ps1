function PolicyErrorInsert($sqlServerVariable, $sqlDatabaseVariable, $EvaluatedServer, $EvaluatedPolicy, $EvaluationResultsEscape) 
{
    $sqlQueryText = "INSERT INTO policy.EvaluationErrorHistory (EvaluatedServer, EvaluatedPolicy, EvaluationResults) VALUES(N'$EvaluatedServer', N'$EvaluatedPolicy', N'$EvaluationResultsEscape')"
    try
	{
		Invoke-Sqlcmd -ServerInstance $sqlServerVariable -Database $sqlDatabaseVariable -Query $sqlQueryText -QueryTimeout 65535 -ErrorAction Stop
	}
	catch
	{
	    $ExceptionText = $_.Exception.Message -replace "'", ""
		return $ExceptionText
	}
}
