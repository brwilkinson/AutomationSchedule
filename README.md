# AutomationSchedule

This is a schedule for Stopping and Starting Virtual Machines in Azure Resource Manager

The Schedule is defined in the JSON file __AutomationSchedule.json__

__Here is a sample:__

    "Monday": {
        "Night": {
            "Dev"  : { "State" : "Off" },
            "QA"   : { "State" : "Off" },
            "Prod" : { "State" : "On"  },
            "Test" : { "State" : "Off" }
        }

It relies on Tags to be defined on your virtual machines.

    $Environment = 'Dev'
    New-AzureRmVM -Tags @{Name='Environment';Value=$Environment}

    $environment = $VM.Tags.Environment

The tag named __Environment__ will be read and the value is the classification from the JSON

The default Environments are: __Dev__, __QA__ & __Prod__

The script __AutomationSchedule.ps1__ contains the code to Schedule in Automation.

I schedule the Job to run every 1 hour at 5 minutes past the hour.

The job will either leave the VM in it's current state, turn it off or turn it on based on the schedule.

By default the script breaks down the day into 3 parts: Night, Morning and Afternoon.

    { $_ -in ((23..24) + (0..6)) } {'Night'}
    { $_ -in 7..14 }               {'Morning'}
    { $_ -in 15..22 }              {'Afternoon'}

You can define the hours that match each of those definitions.

VM's tagged as __Prod__: 
* Will not be switched off during the weekdays
* Will be switched off over the weekend, until Monday at 7.05am, when they will be switched on 

VM's tagged as __QA__ or __Dev__  
* Will be switched off between 11.05pm to 7.05am during the weekdays
* Will be switched off over the weekend, until Monday at 7.05am, when they will be switched on

VM's tagged as __Test__
* Will be switched off at 11.05pm
* Will not be switched on, they have to be manually started
