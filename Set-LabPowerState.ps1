<#
.Synopsis
    Provides the ability to power on and power off virtual machines within a vSphere environment, based on a priority grouping
.DESCRIPTION
    This script provides the ability to either power on, or power off (gracefully followed by forcefully if desired) virtual machines within a vSphere environment
    The script requires the user to first use the -ConfigurePriority parameter, which allows the user to specify a priority group for each virtual machine in the environment, from 1-5.
    The priority group setting is defined on a virtual machine by adding an advanced setting to the VM object
.EXAMPLE
    Set-LabPowerState -ConfigurePriority
    This will get all VMs in the envionment and prompt the user to specify a priority group for the virtual machines, from 1-5
.EXAMPLE
    Set-LabPowerState -ConfigurePriority -SkipConfiguredVMs
    This will get all VMs in the envionment that have not yet had their priority grouping defined, and will prompt the user to specify a priority group, from 1-5
.EXAMPLE
    Set-LabPowerState -PowerOn -PoweronSleep 20
    This will power on all virtual machines in the target environment that have had their priority group defined, starting with VMs in prirority group 1 and working through to priority group 5
    The PowerOnSleep parameter is defined in seconds and is a buffer used between powering on each VM as to no cause a boot storm
.EXAMPLE
    Set-LabPowerState -PowerOff -PowerOffWaitTime 60
    This will power off all virtual machines in the target environment that have had their priority group defined, starting with VMs in priority group 5 and working through to priority group 1
    The script will wait for 60 seconds between attempting to gracefully shut down all VMs in the current priority group before moving on to the next priority group
    Virtual machines that are not able to be shut down gracefully will be left running
.EXAMPLE
    Set-LobPowerState -PowerOff -PoweroffWaitTime 60 -ForcePowerOff
    This will power off all virtual machines in the target environment that have had their priority group defined, starting with VMs in priority group 5 and working through to priority group 1
    The script will wait for 60 seconds between attempting to gracefully shut down all vms in a priority group, before it forcefully powers off any VMs still running in the current priority group and moving on to the next priority group
#>

[CmdletBinding()]
Param
(
    # Param help description
    [Parameter(ParameterSetName='PowerOn')][switch]$PowerOn,

    # Param help description
    [Parameter(Mandatory=$true,ParameterSetName='PowerOn')][int]$PowerOnSleep,

    # Param help description
    [Parameter(ParameterSetName='PowerOff')][switch]$PowerOff,

    # Param help description
    [Parameter(Mandatory=$true,ParameterSetName='PowerOff')][int]$PowerOffWaitTime,

    # Param help description
    [Parameter(ParameterSetName='PowerOff')][Switch]$ForcePowerOff,

    # Param help description
    [Parameter(ParameterSetName='Configure')][switch]$ConfigurePriority,

    # Param help description
    [Parameter(ParameterSetName='Configure')][switch]$SkipConfiguredVMs,

    # Param help description
    [Parameter(Mandatory=$True)]$TargetESXiHost

)

function Configure-VMPriorityAdvancedSetting{

    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Param help description
        [switch]$SkipConfiguredVMS
    )

    if ($SkipConfiguredVMS){
        #Foreach loop to add the advanced setting to VMs that don't have it configured yet
        foreach ($VM in $StartupPrioritySettingNotExist){
            #Prompt the user to enter a startup priority for the VM with a value between 1 and 5
            $SetVMPriority = Read-Host "Do you want to set the power priority group for $($VM.name)? (y/n)"
            if ($SetVMPriority -eq "y"){
                do{
                    $StartupPriority = read-host "Enter startup prioirty for $($VM.name) from 1 - 5"
                }
                while(1..5 -notcontains $StartupPriority)
            #Add a new advanced setting to the VM with the startup priority specified
            New-AdvancedSetting -Name Lab.PowerPriorityGroup -Value $StartupPriority -Entity $VM.Name -Confirm:$false | Out-Null
            }
        }
    }ELSE{
        #Foreach loop to add the advanced setting to VMs that don't have it configured yet
        foreach ($VM in $StartupPrioritySettingNotExist){
            #Prompt the user to enter a startup priority for the VM with a value between 1 and 5
            $SetVMPriority = Read-Host "Do you want to set the power priority group for $($VM.name)? (y/n)"
            if ($SetVMPriority -eq "y"){
                do{
                    $StartupPriority = read-host "Enter startup prioirty for $($VM.name) from 1 - 5"
                }
                while(1..5 -notcontains $StartupPriority)
            #Add a new advanced setting to the VM with the startup priority specified
            New-AdvancedSetting -Name Lab.PowerPriorityGroup -Value $StartupPriority -Entity $VM.Name -Confirm:$false | Out-Null
            }
        }
        #Foreach loop to show the user what the priority is currently set to for VMs that have the advanced setting, and give them the option to change it
        foreach ($VM in $StartUpPrioritySettingExists){
        $StartupPriority = Get-AdvancedSetting -Entity $VM.name -Name Lab.PowerPriorityGroup
        $ChangePriority = Read-Host "Startup Priority for $($VM.name) is set to $($StartupPriority.Value). Do you want to change this? (y/n)"
            if ($ChangePriority -eq "y"){
                do{
                    $StartupPriority = read-host "Enter startup prioirty for $($VM.name) from 1 - 5"
                }
                while(1..5 -notcontains $StartupPriority)

                #Add a new advanced setting to the VM with the startup priority entered by the user
                Get-AdvancedSetting -Name Lab.PowerPriorityGroup -Entity $VM.Name | Set-AdvancedSetting -Value $StartupPriority -Confirm:$false | Out-Null
            }Elseif ($ChangePriority -eq "n"){
            Write-output "No changes made to $($VM.Name)"
            }
        }
    }#End Else
}#End Configure-VMPriorityAdvancedSetting Function

function PowerOff-PriorityGroup{

    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Param help description
        $PriorityGroup,

        # Param help description
        [Switch]$ForcePowerOff
    )

        Foreach ($VM in $PriorityGroup){
            if($VM.PowerState -eq "Poweredon"){
                write-output "Attempting to cleanly shut down $VM"
                try{
                $VM | Shutdown-VMGuest -Confirm:$false -ErrorAction Stop | out-null
                }
                catch
                {
                Write-Output "Clean shutdown for $VM failed. VMtools may not be installed. If -ForcePowerOff was specified, this VM will be hard powered off"
                }
            }ELSE{
                Write-Output "$VM is already Powered Off"
            }
        }

        Write-output "Pausing for $PowerOffWaitTime seconds to allow VMs to shutdown cleanly"
        Start-Sleep -Seconds $PowerOffWaitTime

        $VMSStillPoweredOn = Get-VM $PriorityGroup | Where-Object {$_.PowerState -eq "PoweredOn"}
        if ($VMSStillPoweredOn){
            if ($ForcePowerOff){
                foreach ($VM in $VMSStillPoweredOn){
                    write-Output "ForcePowerOff was specified. Hard powering off $VM"
                    $VM | Stop-VM -Confirm:$false | out-null
                }
            }ELSE{
                foreach ($VM in $VMSStillPoweredOn){
                Write-Output "$VM is still powered on, but ForcePoweredOff parameter was not used. Moving on to next VM / priority group"
                }
            }
        }
}#End PowerOff-PriorityGroup

function PowerOn-Lab{

    [CmdletBinding()]
    [Alias()]
    Param
    (
        # Param help description
        [int]$SleepTime
    )
    #Create emptry arrays for the 5 priority groups and sort the VMs into relevant priority groups
    $PriorityGroup1 = @()
    $PriorityGroup2 = @()
    $PriorityGroup3 = @()
    $PriorityGroup4 = @()
    $PriorityGroup5 = @()

    foreach ($VM in $VMS){

        if ((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "1"){
        $PriorityGroup1 += $VM
        }
        ELSEIF((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "2"){
        $PriorityGroup2 += $VM
        }
        ELSEIF((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "3"){
        $PriorityGroup3 += $VM
        }
        ELSEIF((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "4"){
        $PriorityGroup4 += $VM
        }
        ELSEIF((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "5"){
        $PriorityGroup5 += $VM
        }
    }#End Foreach

    #Power on Prioriry Group 1
    foreach ($VM in $PriorityGroup1){
        if ($VM.PowerState -eq "PoweredOn"){
        Write-Output "$VM in priority group 1 is already powered on, moving on ..."
        }ELSE{
        Write-Output "Powering on $($VM.name) in priority group 1"
        Start-VM $VM | Out-Null
        Start-Sleep -Seconds $SleepTime
        }
    }

    #Power on Prioriry Group 2
    foreach ($VM in $PriorityGroup2){
        if ($VM.PowerState -eq "PoweredOn"){
        Write-Output "$VM in priority group 2 is already powered on, moving on ..."
        }ELSE{
        Write-Output "Powering on $($VM.name) in priority group 2"
        Start-VM $VM | Out-Null
        Start-Sleep -Seconds $SleepTime
        }
    }

    #Power on Prioriry Group 3
    foreach ($VM in $PriorityGroup3){
        if ($VM.PowerState -eq "PoweredOn"){
        Write-Output "$VM in priority group 3 is already powered on, moving on ..."
        }ELSE{
        Write-Output "Powering on $($VM.name) in priority group 3"
        Start-VM $VM | Out-Null
        Start-Sleep -Seconds $SleepTime
        }
    }

    #Power on Prioriry Group 4
    foreach ($VM in $PriorityGroup4){
        if ($VM.PowerState -eq "PoweredOn"){
        Write-Output "$VM in priority group 4 is already powered on, moving on ..."
        }ELSE{
        Write-Output "Powering on $($VM.name) in priority group 4"
        Start-VM $VM | Out-Null
        Start-Sleep -Seconds $SleepTime
        }
    }

    #Power on Prioriry Group 5
    foreach ($VM in $PriorityGroup5){
        if ($VM.PowerState -eq "PoweredOn"){
        Write-Output "$VM in priority group 5 is already powered on, moving on ..."
        }ELSE{
        Write-Output "Powering on $($VM.name) in priority group 5"
        Start-VM $VM | Out-Null
        Start-Sleep -Seconds $SleepTime
        }
    }
}#End PowerOn-Lab Function

function PowerOff-Lab{

    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param help description
        [int]$PowerOffWaitTime

    )
    #Sort the VMs into priority groups
    $PriorityGroup1 = @()
    $PriorityGroup2 = @()
    $PriorityGroup3 = @()
    $PriorityGroup4 = @()
    $PriorityGroup5 = @()

    foreach ($VM in $VMS){

        if ((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "1"){
        $PriorityGroup1 += $VM
        }
        ELSEIF((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "2"){
        $PriorityGroup2 += $VM
        }
        ELSEIF((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "3"){
        $PriorityGroup3 += $VM
        }
        ELSEIF((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "4"){
        $PriorityGroup4 += $VM
        }
        ELSEIF((Get-AdvancedSetting -Entity $VM -Name Lab.PowerPriorityGroup).value -eq "5"){
        $PriorityGroup5 += $VM
        }
    }#End Foreach

    if($PriorityGroup5.PowerState -contains "PoweredOn"){
        if($ForcePowerOff){
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup5 -ForcePowerOff
            }ELSE{
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup5
        }
    }ELSE{
    Write-Output "No VMs in Priority Group 5 are powered on. Nothing to power off"
    }

    if($PriorityGroup4.PowerState -contains "PoweredOn"){
        if($ForcePowerOff){
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup4 -ForcePowerOff
            }ELSE{
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup4
        }
    }ELSE{
    Write-Output "No VMs in Priority Group 4 are powered on. Nothing to power off"
    }

    if($PriorityGroup3.PowerState -contains "PoweredOn"){
        if($ForcePowerOff){
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup3 -ForcePowerOff
            }ELSE{
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup3
        }
    }ELSE{
    Write-Output "No VMs in Priority Group 3 are powered on. Nothing to power off"
    }

    if($PriorityGroup2.PowerState -contains "PoweredOn"){
        if($ForcePowerOff){
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup2 -ForcePowerOff
            }ELSE{
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup2
        }
    }ELSE{
    Write-Output "No VMs in Priority Group 2 are powered on. Nothing to power off"
    }

    if($PriorityGroup1.PowerState -contains "PoweredOn"){
        if($ForcePowerOff){
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup1 -ForcePowerOff
            }ELSE{
            PowerOff-PriorityGroup -PriorityGroup $PriorityGroup1
        }
    }ELSE{
    Write-Output "No VMs in Priority Group 1 are powered on. Nothing to power off"
    }

}#End PowerOff-Lab Function

#Import the VMware PowerCLI module
Get-Module -ListAvailable vmware* | Import-Module

#Prompt the user for the credentials to connect to the target ESXi server
$ESXiCreds = Get-Credential -Message "Enter the username and password to connect to $($TargetESXiHost)"

#Connect PowerCLI to the target ESXi Server
Connect-VIServer $TargetESXiHost -Credential $ESXiCreds -WarningAction SilentlyContinue

#Gather all VMs in the environment
$VMS = Get-VM

if ($ConfigurePriority){
    Write-Verbose "Parameter Used to Configure the priority setting on VMs. Executing Configure-VMPriorityAdvancedSetting"

    #Create empty arrays. VMs will be added into an array depending if the advanced setting exists or not
    $StartUpPrioritySettingExists = @()
    $StartupPrioritySettingNotExist = @()

    #Check to see if the advanced setting exists on all VMs in the environment and place the VM into the appropriate variable
    Foreach ($VM in $VMS){
        if (Get-AdvancedSetting -Entity $VM.Name -Name Lab.PowerPriorityGroup){
        Write-Verbose "Priority is set on $($VM.name)"
        $StartUpPrioritySettingExists += $VM
        }ELSE{
        Write-Verbose "Priority is not set on $($VM.Name)"
        $StartupPrioritySettingNotExist +=$VM
        }
    }

    #Call the configure-VMPriorityAdvancedSetting function
    if ($SkipConfiguredVMs){
    Configure-VMPriorityAdvancedSetting -SkipConfiguredVMS
    }ELSE{
    Configure-VMPriorityAdvancedSetting
    }
}

#If the user has specified the PowerOn parameter, run the PowerOn-Lab function to start VMs
if ($PowerOn){
    Write-Verbose "Parameter used to Power on the Lab Environment"
    PowerOn-Lab -SleepTime $PowerOnSleep
}

#If the user has specified the PowerOff parameter, run the Poweroff-Lab function to power off VMs
if ($PowerOff){
    Write-Verbose "Parameter used to Power off the Lab Environment"
    PowerOff-Lab -PowerOffWaitTime $PowerOffWaitTime
}