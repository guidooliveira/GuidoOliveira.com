<#
	.SYNOPSIS
		This function creates a new Dynamic Route Gateway for the specified Azure VNet

	.DESCRIPTION
		This function uses the Azure Web API to create, for the specified Azure VNet, a Dynamic Route Gateway

	.PARAMETER  VNetName
		The VNet name to create the Dynamic Route Gateway

	.EXAMPLE
		PS C:\> New-AzureVnetDynamicGateway -VNetName 'Value1'

		This example shows how to call the New-AzureVnetDynamicGateway function with named parameters with a single value.
	.EXAMPLE
		PS C:\> New-AzureVnetDynamicGateway -VNetName 'Value1','Value2','Value3' -Verbose
		'This is the output'
		This example shows how to call the New-AzureVnetDynamicGateway function with named parameters with multiple values.

     .EXAMPLE
		PS C:\> Get-AzureVNetSite | ForEach-Object -Process { New-AzureVnetDynamicGateway -VnetName $_.Name -Verbose }
		'This is the output'
		This example shows how to call the New-AzureVnetDynamicGateway function with named parameters with multiple values through pipeline input.


#>
function New-AzureVnetDynamicGateway
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
                    Position=0,
				   ValueFromPipeline = $true,
				   HelpMessage = 'Please provide the VNet name to create the Dynamic Route Gateway')]
        [Alias('Name')]
		[ValidateNotNull()]
		[ValidateNotNullOrEmpty()]
		[System.String[]]
		$VNetName
	)
	
	Begin
	{
		Write-Verbose -Message "$((Get-Date).ToString('h:mm:ss tt')) - Begin Operation: New-AzureVnetDynamicGateway"
		Write-Verbose -Message "Trying to load required Assemblies"
		Try
		{
			
			$loadStatus = $true
			
			Add-Type -AssemblyName System.Net.Http.WebRequest -ErrorAction Stop
			
		}
		catch
		{
			
			$loadStatus = $false
			
			Write-Error -Message "Error Loading the WebRequest Assembly"
			
			Break
			
		}
		
		
		if ($loadStatus)
		{
			
			Write-Verbose -Message "Assembly Sucessfully loaded"
			
		}
		
		
		try
		{
			
			$AzureSubscription = Get-AzureSubscription -Default -ErrorAction Stop
			
		}
		catch
		{
			
			Write-Error -Message "No Azure Subscrition Found"
			
			break
			
		}
		
		$Certificate = $AzureSubscription.Certificate
		
		$SubscriptionID = $AzureSubscription.SubscriptionId
		
	}
	
	Process
	{
		
		$WebRequestHandler = New-Object -TypeName System.Net.Http.WebRequestHandler
		
		$HttpClient = New-Object -TypeName System.Net.Http.HttpClient($WebRequestHandler)
		
		Try
		{
			
			Write-Verbose -Message "Add the management certificate to the client certificates collection"
			$addCertificate = $WebRequestHandler.ClientCertificates.Add($certificate)
			
		}
		Catch
		{
			
			
		}
		Try
		{
			Write-Verbose -Message "Defining service management API version"
			$httpClient.DefaultRequestHeaders.Add("x-ms-version", "2013-08-01")
		}
		catch
		{
			
			Write-Error -Message "Couldn't define the Management API version"
			
			Break
			
		}
		
		$MediaTypeWithQualityHeaderValue = New-Object -TypeName System.Net.Http.Headers.MediaTypeWithQualityHeaderValue("application/xml")
		
		$HttpClient.DefaultRequestHeaders.Accept.Add($MediaTypeWithQualityHeaderValue) | Out-Null
		
		foreach ($VNetName in $VNetName)
		{
			
			try
			{
				
				# Create Gateway URI
				# http://msdn.microsoft.com/en-us/library/windowsazure/jj154119.aspx
				$createGatewayUri = "https://management.core.windows.net/$subscriptionID/services/networking/$vnetName/gateway"
				
				# This is the POST payload that describes the gateway resource
				# Note the lower case g in <gatewayType - the documentation on MSDN is wrong here
				$postBody = @"
<?xml version="1.0" encoding="utf-8"?>
<CreateGatewayParameters xmlns="http://schemas.microsoft.com/windowsazure">
  <gatewayType>DynamicRouting</gatewayType>
</CreateGatewayParameters>
"@
				
				Write-Verbose "Creating Gateway for VNET $VNetName"
				
				$content = New-Object -TypeName System.Net.Http.StringContent($postBody, [System.Text.Encoding]::UTF8, "text/xml")
				
				$postGatewayTask = $httpClient.PostAsync($createGatewayUri, $content)
				
				$postGatewayTask.Wait()
				

				$GatewayCreation = $true
			}
			catch
			{
				$GatewayCreation = $false
				Write-Error -Message "$error[0]"
			}
			
			
		}
	}
	End
	{
		Write-Verbose -Message "$((Get-Date).ToString('h:mm:ss tt')) - Completed Operation: New-AzureVnetDynamicGateway"
	}

}