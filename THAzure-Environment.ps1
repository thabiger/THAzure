<#
.SYNOPSIS

Function gets(and creates if needed) basic Azure environment variables for a deployment and returns them as an object

.DESCRIPTION

.EXAMPLE 

New-AzureEnvironment `
  -SubscriptionName "Microsoft Partner Network" `
  -LocationName "North Europe" `
  -ResourceGroupName "ResGroup01" `
  -StorageAccountName "SAcc01"

.NOTES

Author: Tomasz Habiger <tomasz.habiger@gmail.com>
Date: Mar 2016

The content of this script is copyrighted to the author. It is provided AS IS, and no warranty of ANY kind is provided. Use it at your own risk!

#>

function New-AzureEnvironment{
    [CmdletBinding()]
    param (
        [string] $SubscriptionName,
        [string] $LocationName,
        [string] $ResourceGroupName,
        [string] $ServiceName,
        [string] $StorageAccountName,
        [string] $StorageType = "Standard_LRS"
    )

    if ($ResourceGroupName){
    
        $subscription = Get-THAzureObject -oList (Get-AzureRMSubscription) -cObjName $SubscriptionName -valid | Select-AzureRMSubscription

        $locations = ((Get-AzureRmResourceProvider -ProviderNamespace Microsoft.ClassicCompute).ResourceTypes | Where-Object ResourceTypeName -eq virtualMachines).Locations
        $location = New-Object –TypeName PSObject –Prop @{ Name = Get-THAzureObject -oList (Get-AzureRmLocation) -cObjName $LocationName -valid }
        
        $resourceGroup = Get-THAzureObject -oList (Get-AzureRmResourceGroup) -cObjName $ResourceGroupName
        if (($ResourceGroupName) -and ($resourceGroup -eq $null)) {
            $resourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location.Name.DisplayName
        }

        $storageAccount = Get-THAzureObject -oList (Get-AzureRMStorageAccount) -cObjName $StorageAccountName
        if (($storageAccount -eq $null) -and ($resourceGroup)){
            $storageAccount = New-AzureRMStorageAccount -StorageAccountName $StorageAccountName -Location $location.Name.DisplayName -ResourceGroupName $resourceGroup.ResourceGroupName -Type $StorageType
        }
    } else {
        $subscription = Get-THAzureObject -oList (Get-AzureSubscription) -cObjName $SubscriptionName 
        $subscription | Select-AzureSubscription

        $location = Get-THAzureObject -oList (Get-AzureLocation) -cObjName $LocationName

        $service = Get-THAzureObject -oList (Get-AzureService) -cObjName $ServiceName
        if (($ServiceName) -and ($service -eq $null)) {
            $service = New-AzureService -ServiceName $ServiceName -Location $location.Name
        }

        $storageAccount = Get-THAzureObject -oList (Get-AzureStorageAccount) -cObjName $StorageAccountName
        if (($storageAccount -eq $null) -and ($ServiceName)){
            $storageAccount = New-AzureStorageAccount -StorageAccountName $StorageAccountName -Location $location.Name
        }

        Set-AzureSubscription -SubscriptionName $SubscriptionName -CurrentStorageAccountName $StorageAccountName
    }
    
    New-Object –TypeName PSObject –Prop @{
        'Subscription' = $subscription
        'Location' = $location
        'Service' = $service
        'StorageAccount' = $storageAccount
        'ResourceGroup' = $resourceGroup
    }
}
