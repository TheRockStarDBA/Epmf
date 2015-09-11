# Evaluate specific Policies against a Server List
# Uses the Invoke-PolicyEvaluation Cmdlet
# v4.12

param([string]$ConfigurationGroup=$(Throw `
"Parameter missing: -ConfigurationGroup ConfigGroup"),`
[string]$PolicyCategoryFilter=$(Throw "Parameter missing: `
-PolicyCategoryFilter Category"), `
[string]$EvalMode=$(Throw "Parameter missing: -EvalMode EvalMode"))

# Parameter -ConfigurationGroup specifies the 
# Central Management Server group to evaluate
# Parameter -PolicyCategoryFilter specifies the 
# category of policies to evaluate
# Parameter -EvalMode accepts "Check" to report policy
# results, "Configure" to reconfigure any violations 

# Declare variables to define the central warehouse
# in which to write the output, store the policies
$CentralManagementServer = "SQL2012"
$HistoryDatabase = "MDW"
# Define the location to write the results of the policy evaluation
$ResultDir = "D:\Results\"
# End of variables

# Function to load assemblies and Snapins - http://msdn.microsoft.com/en-us/library/hh245202.aspx
function LoadAssemblies()
{
	$Error.Clear()
	$assemblylist = "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.SmoExtended", "Microsoft.SqlServer.Dmf", "Microsoft.SqlServer.Facets", "Microsoft.SqlServer.Management.RegisteredServers", "Microsoft.SqlServer.Management.Sdk.Sfc", "Microsoft.SqlServer.Management.Collector", "Microsoft.SqlServer.Management.CollectorEnum"

	if ($host.Name -eq "ConsoleHost")
	{
		Write-Host -ForegroundColor green "  Loading Assemblies"
	}
	
	foreach ($assembly in $assemblylist)
	{
		$assembly = [Reflection.Assembly]::LoadWithPartialName($assembly)
	}

    $sqlVerText = "SELECT CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff)"
    $TestVer = (Invoke-Sqlcmd -ServerInstance $CentralManagementServer -Query $sqlVerText -QueryTimeout 65535)
    
    if ($TestVer.ItemArray[0] -eq 10)
	{
	    # Load SqlServerProviderSnapin100
	    if (-not (Get-PSSnapin | ?{$_.name -eq 'SqlServerProviderSnapin100'}))
	    {
		    if (Get-PSSnapin -registered | ?{$_.name -ne 'SqlServerProviderSnapin100'})
		    {
			    Add-PSSnapin SqlServerProviderSnapin100 | Out-Null 
			    if ($host.Name -eq "ConsoleHost")
			    {
				    Write-Host -ForegroundColor green "  Loading SqlServerProviderSnapin100 in session"
			    }
		    }
	    }
	    else
	    {
		    if ($host.Name -eq "ConsoleHost")
		    {
			    Write-Host -ForegroundColor green "  SqlServerProviderSnapin100 already loaded"
		    }
	    }

	    # Load SqlServerCmdletSnapin100
	    if (-not (Get-PSSnapin | ?{$_.name -eq 'SqlServerCmdletSnapin100'}))
	    {
		    if (Get-PSSnapin -registered | ?{$_.name -ne 'SqlServerCmdletSnapin100'})
		    {
			    Add-PSSnapin SqlServerCmdletSnapin100 | Out-Null 
			    if ($host.Name -eq "ConsoleHost")
			    {
				    Write-Host -ForegroundColor green "  Loading SqlServerCmdletSnapin100 in session"
			    }
		    }
	    }
	    else 
	    {
		    if ($host.Name -eq "ConsoleHost")
		    {
			    Write-Host -ForegroundColor green "  SqlServerCmdletSnapin100 already loaded"
		    }
	    }
    }
}

# Function to load module
function LoadModule($modname)
{
	$Error.Clear()
	if (-not(${env:programfiles(x86)})) 
    {
        $PrgFilePath = ${env:programfiles}.ToString()
    }
    else 
    {
        $PrgFilePath = ${env:programfiles(x86)}.ToString()
    }
	
	$env:PSModulePath = "$PrgFilePath\Microsoft SQL Server\120\Tools\PowerShell\Modules\;" + $env:PSModulePath
	
	if (-not(Get-Module -Name $modname)) 
	{
		if (Get-Module -ListAvailable | Where-Object { $_.name -eq $modname }) 
		{
			if ($host.Name -eq "ConsoleHost")
			{
				Write-Host -ForegroundColor green "  Loading SQLPS module"
			}
			try 
			{
				Import-Module -Name $modname –DisableNameChecking -Force -WarningAction SilentlyContinue -ErrorAction Stop 
			}
			catch
			{
				if ($Error -notlike "A drive with the name *SQLSERVER* already exists.")
				{
					Write-Host $Error
				}
			}
		}
	}
	else 
	{
		if ($host.Name -eq "ConsoleHost")
		{
			Write-Host -ForegroundColor green "  SQLPS module already loaded"
		}
	}
}

#Function to insert policy evaluation results into SQL Server - table policy.PolicyHistory
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

#Function to insert policy evaluation errors into SQL Server - table policy.EvaluationErrorHistory
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

#Function to delete files from this policy only
function PolicyFileDelete($File) 
{
	# Delete evaluation files in the directory.
	try
	{
		Remove-Item -Path $File -Force
	}
	catch 
	{
	    $ExceptionText = $_.Exception.Message -replace "'", ""
		return $ExceptionText
		continue
	}
}

if ($host.Name -eq "ConsoleHost")
{
	Write-Host -ForegroundColor green "EPM Framework v4.1.2"
	Write-Host -ForegroundColor green "Starting policy category evaluation - $(Get-Date -Format G)"
}

# Load Assemblies
LoadAssemblies
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