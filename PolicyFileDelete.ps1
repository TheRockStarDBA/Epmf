function PolicyFileDelete {
    [CmdletBinding()]
    param (
        $File
    )

	# Delete evaluation files in the directory.
	try
	{
		Remove-Item -Path $File -Force
	}
	catch 
	{
	    $_.Exception.Message
	}
}
