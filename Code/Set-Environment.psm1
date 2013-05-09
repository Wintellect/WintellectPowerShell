#requires -version 2.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2013 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -version Latest


function Set-Environment
{
<#
.SYNOPSIS
Brings the CMD SET command back to PowerShell.

.DESCRIPTION
PowerShell has a powerfull way to set environment variables, but many of us 
have the DOS SET command burned into our fingers. This function keeps us
productive. :) 

Full credit to Wes Haggard at http://weblogs.asp.net/whaggard for this gem. 

To replace the default set alias with the one provided by WintellectPowerShell, 
execute the following command before importing the this module.

Remove-Item alias:set -Force -ErrorAction SilentlyContinue


.PARAMETER Var
The environment variable in SET format, "var=value". If you want to clear an 
environment variable, use "var=". If no parameter is specified, this will dump
all environment variables currently defined.

.LINK
http://weblogs.asp.net/whaggard/archive/2007/02/08/powershell-version-of-cmd-set.aspx
https://github.com/Wintellect/WintellectPowerShell

#>

	[string]$var = $Args
	if ($var -eq "")
	{
		get-childitem env: | sort-object name
	}
	else
	{
		if ($var -match "^(\S*?)\s*=\s*(.*)$")
		{
			set-item -force -path "env:$($matches[1])" -value $matches[2];		
		}
		else
		{
			write-error "ERROR Usage: VAR=VALUE"
		}
	}	
}

Set-Alias -Name set -Value Set-Environment -Description "WintellectPowerShell alias" -Option AllScope -Force

Export-ModuleMember -Alias * -Function *