﻿function Invoke-Epmf {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ConfigurationGroup, # Group to evaluate
        [Parameter(Mandatory = $true)]
        [string] $PolicyCategoryFilter, # Policies to evaluate
        [Parameter(Mandatory = $true)]
        [string] $EvalMode, # Check or Configure

        [string] $CentralManagementServer = "SQL2012",
        [string] $HistoryDatabase = "MDW",
        [string] $ResultDir = "D:\Results\"
    )

    if ($host.Name -eq "ConsoleHost")
    {
	    Write-Host -ForegroundColor green "EPM Framework v4.1.2"
	    Write-Host -ForegroundColor green "Starting policy category evaluation - $(Get-Date -Format G)"
    }

    # Load Assemblies
    LoadAssemblies $CentralManagementServer 
    LoadModule -modname "SQLPS"

    if ($host.Name -eq "ConsoleHost")
    {
	    Write-Host -ForegroundColor green "  Connecting to the policy store"
    }
    # Connection to the policy store
    $conn = new-object Microsoft.SQlServer.Management.Sdk.Sfc.SqlStoreConnection("server=$CentralManagementServer;Trusted_Connection=true")
    $PolicyStore = new-object Microsoft.SqlServer.Management.DMF.PolicyStore($conn)

    if ($host.Name -eq "ConsoleHost")
    {
	    Write-Host -ForegroundColor green "  Get list of servers to evaluate"
    }
    # Create recordset of servers to evaluate
    $sconn = new-object System.Data.SqlClient.SqlConnection("server=$CentralManagementServer;Trusted_Connection=true")
    $q = "SELECT DISTINCT server_name FROM $HistoryDatabase.[policy].[pfn_ServerGroupInstances]('$ConfigurationGroup');"

    $sconn.Open()
    $cmd = new-object System.Data.SqlClient.SqlCommand ($q, $sconn)
    $cmd.CommandTimeout = 0
    $dr = $cmd.ExecuteReader()

    # Handle PS4 or above
    if ($PSVersionTable.PSVersion.Major -ge 4)
    {
        if ($CentralManagementServer -like "*\*")
        {
            sl "SQLSERVER:\SQLPolicy\$CentralManagementServer\Policies"
        }
        else
        {
	        sl "SQLSERVER:\SQLPolicy\$CentralManagementServer\DEFAULT\Policies"
        }
    }

    if ($host.Name -eq "ConsoleHost")
    {
	    Write-Host -ForegroundColor green "  Starting server loop"
    }
    # Loop through the servers and then loop through
    # the policies. For each server and policy,
    # call cmdlet to evaluate policy on server and delete xml file afterwards
    while ($dr.Read()) { 
	    $ServerName = $dr.GetValue(0);
	    foreach ($Policy in $PolicyStore.Policies)
	    {
		    if (($Policy.PolicyCategory -eq $PolicyCategoryFilter) -or ($PolicyCategoryFilter -eq ""))
		    {
                # Remove illegal characters in file names
                $PolicyName = $Policy.Name
			    # Done in several lines for v2 compatibility
			    $PolicyName = $PolicyName -replace "\\", "" 
			    $PolicyName = $PolicyName -replace "\/", "" 
			    $PolicyName = $PolicyName -replace "\?", "" 
			    $PolicyName = $PolicyName -replace "\:", "" 
			    $PolicyName = $PolicyName -replace "\*", "" 
			    $PolicyName = $PolicyName -replace "\<", "" 
			    $PolicyName = $PolicyName -replace "\>", "" 
			    $PolicyName = $PolicyName -replace " ", ""
			
			    $OutputFile = $ResultDir + ("{0}_{1}.xml" -f (Encode-SqlName $ServerName), ($PolicyName))
			    if (-not ($OutputFile))
			    {
				    $ServerName = $ServerName -replace "\\", "_"
				    $OutputFile = $ResultDir + ("{0}_{1}.xml" -f ($ServerName), ($PolicyName))
			    }
			
			    try
			    {
				    if ($PSVersionTable.PSVersion.Major -ge 4)
				    {
					    Get-ChildItem | Where-Object {$_.Name -eq $Policy.Name} | Invoke-PolicyEvaluation -TargetServerName $ServerName -AdHocPolicyEvaluationMode $EvalMode -OutputXML > $OutputFile
				    }
				    else
				    {
					    Invoke-PolicyEvaluation -Policy $Policy -TargetServerName $ServerName -AdHocPolicyEvaluationMode $EvalMode -OutputXML > $OutputFile
				    }
				    $PolicyResult = Get-Content $OutputFile -encoding UTF8
				    $PolicyResult = $PolicyResult -replace "'", ""
				    PolicyHistoryInsert $CentralManagementServer $HistoryDatabase $ServerName $Policy.Name $PolicyResult
				    $File = $ResultDir + ("*_{0}.xml" -f ($PolicyName))
				    PolicyFileDelete $File
			    }
			    catch
			    { 
				    $File = $ResultDir + ("*_{0}.xml" -f ($PolicyName))
				    PolicyFileDelete $File
				    $ExceptionText = $_.Exception.Message -replace "'", "" 
				    $ExceptionMessage = $_.Exception.GetType().FullName + ", " + $ExceptionText
				    PolicyErrorInsert $CentralManagementServer $HistoryDatabase $ServerName $Policy.Name $ExceptionMessage
				    continue
			    }
		    }
	    } 
    }

    if ($host.Name -eq "ConsoleHost")
    {
	    Write-Host -ForegroundColor green "  Finished server loop"
    }

    $dr.Close()
    $sconn.Close()

    #Shred the XML results to PolicyHistoryDetails
    Invoke-Sqlcmd -ServerInstance $CentralManagementServer -Database $HistoryDatabase -Query "EXEC policy.epm_LoadPolicyHistoryDetail `$(PolicyCategory)" -Variable "PolicyCategory='${PolicyCategoryFilter}'" -QueryTimeout 65535 -Verbose -ErrorAction Stop

    if ($host.Name -eq "ConsoleHost")
    {
	    Write-Host -ForegroundColor green "Finished policy category evaluation - $(Get-Date -Format G)"
    }
}
