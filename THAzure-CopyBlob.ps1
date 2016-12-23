function Copy-AzureBlob{
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
        [String] $filePath
    )

    $storageAccountKey = (Get-AzureRmStorageAccountKey -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName)[0].Value
    $blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

    $file = Get-Item $filePath
    
    Write-Verbose "Copying $fileName to $blobName"
    Set-AzureStorageBlobContent -File $filePath -Container $containerName -Blob $file.Name -Context $blobContext -Force
}