function LoadAssemblies {
    [CmdletBinding()]
    param (
        $CentralManagementServer
    )

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
