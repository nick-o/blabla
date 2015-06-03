function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."


	
	$returnValue = @{
		Name = [System.String]
		CheckFile = [System.String]
		TeamCityAPIBuild = [System.String]
		TeamCityUser = [System.String]
		TeamCityPass = [System.String]
		Ensure = [System.String]
	}

	$returnValue
	
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.String]
		$CheckFile,

		[System.String]
		$TeamCityAPIBuild,

		[System.String]
		$TeamCityUser,

		[System.String]
		$TeamCityPass,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."

	#Include this line if the resource requires a system reboot.
	#$global:DSCMachineStatus = 1
	if ($Ensure -like 'Present')
	{
		if(!(Test-Path -Path $CheckFile)) 
		{
			Write-Verbose "$CheckFile is not present, initiating build"
			$downloadtry = 1
			While ($attempt -lt 3)
				{
					try{
						$webclient = new-object System.Net.WebClient
						$webclient.Credentials = new-object System.Net.NetworkCredential($TeamCityUser, $TeamCityPass)
						$webpage = $webclient.DownloadString($TeamCityAPIBuild)
						$attempt = 3
					}
					catch{
						Write-Verbose "retrying"
						$downloadtry++
					}
				}
		}
		else
		{
			Write-Verbose "$CheckFile is present, no action needed."
		}
	}
	else
	{
		Write-Verbose "Ensure set to false, no action needed"
	}


}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.String]
		$CheckFile,

		[System.String]
		$TeamCityAPIBuild,

		[System.String]
		$TeamCityUser,

		[System.String]
		$TeamCityPass,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
$IsValid = $false
	
	if ($Ensure -like 'Present')
	{
		Write-Verbose "Checking for $CheckFile"
		if(!(Test-Path -Path $CheckFile))
		{
			Write-Verbose "$CheckFile is not present, build needed"
		}
		else
		{
			Write-Verbose "$CheckFile is present, build not needed"
			$IsValid = $true
		}
	}
	else
	{
		Write-Verbose "Ensure set to False, no action needed."
		$IsValid = $true
	}
	return $IsValid
}


Export-ModuleMember -Function *-TargetResource

