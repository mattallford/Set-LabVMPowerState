# Set-LabPowerState

## Table of contents
[TOC]

## Description
Set-LabPowerState is a script that provides the ability to either power on or power off (gracefully followed by forcefully if desired) virtual machines within a vSphere environment, based on a priority grouping.

The script relies on an advanced parameter being set on each VM within the environment to determine which Power Priority group the VM belongs to. I was hoping to use tags or folders, but neither of these exist in the construct of a single nested ESXi lab running on 6.5, which is currently a common lab deployment method.

This has been designed with 5 prioirty groups in mind. A VM can be a member of one of the 5 prioirty groups. The advanced setting being configured is called **Lab.PowerPriorityGroup**.

Powering on the lab starts with VMs in prioirty group 1 and works through to prioirty group 5. Powering off the lab starts with VMs in priority group 5 and works through to priority group 1.

## Requirements

- Written using PowerCLI 6.5R1, not tested on previous versions but will likely work OK
- Target ESXi node or vCenter Server to connect to. I've tested against connecting to a physical ESXi 6.5 server as the target

## Parameters
**PowerOn**
This parameter tells the script that you want to power on the virtual machines inside the target environment, based on the prioirty group already assigned. Any VMs without the advanced setting defining the prioirty group will not be touched.

**PowerOnSleep**
Mandatory if using -PowerOn. Determines the time in seconds to sleep between powering on each VM as to not create a boot storm.

**PowerOff**
This parameter tells the script that you want to power off the virtual machines inside the target environment, based on the prioirty group already assigned. Any VMs without the advanced setting defining the prioirty group will not be touched.

Note: Be careful if you are targetting this against a vCenter Server where your VC node is a member, as you may power off the VC server causing the script to stop executing against the target.

**PowerOffWaitTime**
Mandatory if using -PowerOff. Determines the time in seconds to sleep between either:
1. If -ForcePowerOff is used (see below), this is the time between attemping to gracefully shut down VMs in a prioirty group and then hard powering them off
2. If -ForcePowerOff is not used (see below), this is the time between attemting to gracefully shut down VMs in a prioirty group before moving to the next prioirty group

**ForcePowerOff**
Only can be used if specifying -PowerOff. This will tell the script to hard power off the VMs if they have not shut down gracefull in the time window defined in PowerOffWaitTime.

**ConfigurePriority**
This option provides the user with the ability to set the prioirty group for all VMs in the target environment. First you will be asked if you want to configure a priority group for the current VM. If you do, you will then be prompted to enter a prioirty group between 1 and 5.

**SkipConfiguredVMs**
This is used with -ConfigurePriority. This option will skip prompting for any VMs in the target environment that already have the priority group configured. This is handy if you have a few new VMs and you just want to configure those

**TargetESXiHost**
Host name or IP address of the target ESXi server

## Example Usage
**Set-LabPowerState -ConfigurePriority**
This will get all VMs in the envionment and prompt the user to specify a priority group for the virtual machines, from 1-5

**Set-LabPowerState -ConfigurePriority -SkipConfiguredVMs**
This will get all VMs in the envionment that have not yet had their priority grouping defined, and will prompt the user to specify a priority group, from 1-5

**Set-LabPowerState -PowerOn -PoweronSleep 20**
This will power on all virtual machines in the target environment that have had their priority group defined, starting with VMs in prirority group 1 and working through to priority group 5. The PowerOnSleep parameter is defined in seconds and is a buffer used between powering on each VM as to no cause a boot storm

**Set-LabPowerState -PowerOff -PowerOffWaitTime 60**
This will power off all virtual machines in the target environment that have had their priority group defined, starting with VMs in priority group 5 and working through to priority group 1. The script will wait for 60 seconds between attempting to gracefully shut down all VMs in the current priority group before moving on to the next priority group. Virtual machines that are not able to be shut down gracefully will be left running

**Set-LobPowerState -PowerOff -PoweroffWaitTime 60 -ForcePowerOff**
This will power off all virtual machines in the target environment that have had their priority group defined, starting with VMs in priority group 5 and working through to priority group 1. The script will wait for 60 seconds between attempting to gracefully shut down all vms in a priority group, before it forcefully powers off any VMs still running in the current priority group and moving on to the next priority group
## Change Log

- 20170605
 - Initial version
