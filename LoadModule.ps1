function LoadModule {
    [CmdletBinding()]
    param (
        $modname
    )

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
