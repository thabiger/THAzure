function Invoke-AzureVMExtensionScript{
    [CmdletBinding(
        SupportsShouldProcess=$True
    )]
    param (
        [Parameter(Mandatory = $true)]   
        [String] $resourceGroupName,
        [Parameter(Mandatory = $true)]   
        [String] $storageAccountName,
        [Parameter(Mandatory = $true)]   
        [String] $containerName,
        [Parameter(Mandatory = $true)]   
        [String] $locationName,
        [Parameter(Mandatory = $true)]
        [String] $filePath,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]   
        [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] $vm,
        [Parameter()]   
        [String] $ExtensionName = 'CustomScriptForLinux',
        [Parameter()]   
        [String] $Publisher = 'Microsoft.OSTCExtensions',
        [Parameter()]   
        [String] $Version = '1.5'
    )

    process{

    Copy-THAzureBlob -storageAccountName $storageAccountName `
        -resourceGroupName $resourceGroupName `
        -containerName $containerName `
        -filepath $filePath | Out-Null

    $file = Get-Item $filePath

    $Settings = @{"fileUris" = @("https://$($storageAccountName).blob.core.windows.net/$containerName/$($file.Name)"); "commandToExecute" = "sh $($file.Name)"};
    $ProtectedSettings = @{"storageAccountName" = $storageAccountName; 
                           "storageAccountKey"  = (Get-AzureRmStorageAccountKey -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName)[0].Value };
	
    Set-AzureRmVMExtension -Name $ExtensionName `
        -VMName $vm.Name `
        -ResourceGroupName $resourceGroupName `
        -Location $locationName `
        -Publisher $Publisher `
        -Type  $ExtensionName `
        -TypeHandlerVersion  $Version `
        -ProtectedSettings  $ProtectedSettings `
        -Settings  $Settings 
        }
}