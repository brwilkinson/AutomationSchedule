# AzureRM Virtual Machine and Virtual Machine Gateway Schedule
# This is a solution for Automation of turning VM's and Gateways on and off

#region Authenticate
# set up your runas account first
# https://azure.microsoft.com/en-us/documentation/articles/automation-sec-configure-azure-runas-account/
try
{
    $connectionName = "AzureRunAsConnection"
    $SubId = Get-AutomationVariable -Name 'SubscriptionMSFT'
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    echo "Logging in to Azure..."
    
    $ServicePrincipalAccount = @{
     ServicePrincipal      = $true
     TenantId              = $servicePrincipalConnection.TenantId
     ApplicationId         = $servicePrincipalConnection.ApplicationId
     CertificateThumbprint = $servicePrincipalConnection.CertificateThumbprint
     }
   
    Add-AzureRmAccount @ServicePrincipalAccount

    echo "Setting context to a specific subscription"  
   
    Set-AzureRmContext -SubscriptionId $SubId 
            
}
catch {
    if (!$servicePrincipalConnection)
    {
       $ErrorMessage = "Connection $connectionName not found."
       throw $ErrorMessage
     } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
     }
}
#endregion

#region Determine Schedule
$ScheduleURI = 'https://raw.githubusercontent.com/brwilkinson/AutomationSchedule/master/AutomationSchedule.json'
$Schedule = Invoke-WebRequest -Uri $ScheduleURI -UseBasicParsing | foreach content | ConvertFrom-Json


$Now = [Datetime]::Now
$Hour = $Now.ToString('HH') -as [Int]
$Period = Switch ($Hour)
{
    { $_ -in ((23..24) + (0..6)) } {'Night'}
    { $_ -in 7..14 }               {'Morning'}
    { $_ -in 15..22 }              {'Afternoon'}
    Default                        {Write-Error -Message "$_ Not in schedule"}
} 

$State = $Schedule.($Now.dayofweek).($Period)
#endregion

#region Correct VM State
Get-AzureRmVM -PipelineVariable vm | Get-AzureRmVM -Status | ForEach-Object {
    
    Write-Warning -Message $VM.Name
    $environment = $VM.Tags.Environment
    $VMName = $_.Name
    $Status = $_.Statuses | select -Property Code -Last 1
    $ScheduledState=$State.($environment).State

    $VMStatus = Switch ($Status)
    {
        'VM deallocated' {[pscustomobject]@{Name=$VMNAME;State="Off";Environment=$environment;ScheduledState=$ScheduledState}}
        'VM running'     {[pscustomobject]@{Name=$VMNAME;State="On";Environment=$environment;ScheduledState=$ScheduledState}}
        Default          {Write-Error -Message "$_ Not in Expected State"}
    }

    if ($VMStatus.State -eq $VMStatus.ScheduledState)
    {
        Write-Verbose -Message "$($VMStatus.Name) already in correct state" -Verbose
    }
    elseif ($VMStatus.ScheduledState -eq 'Off')
    {
        Get-AzureRmVM -Name $VMStatus.Name -ResourceGroupName $vm.ResourceGroupName | Stop-AzureRmVM -Force -Verbose
    }
    elseif ($VMStatus.ScheduledState -eq 'On') 
    { 
        Get-AzureRmVM -Name $VMStatus.Name -ResourceGroupName $vm.ResourceGroupName | Start-AzureRmVM -Verbose
    }
    else
    {
        Write-Error -Message "$VMName not in Schedule"
    }

}
#endregion