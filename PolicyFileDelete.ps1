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
