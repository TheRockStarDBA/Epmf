function PolicyHistoryInsert($sqlServerVariable, $sqlDatabaseVariable, $EvaluatedServer, $EvaluatedPolicy, $EvaluationResults) 
{
    $sqlQueryText = "INSERT INTO policy.PolicyHistory (EvaluatedServer, EvaluatedPolicy, EvaluationResults) VALUES (N'$EvaluatedServer', N'$EvaluatedPolicy', N'$EvaluationResults')"
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
