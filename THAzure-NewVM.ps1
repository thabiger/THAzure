function New-AzureVM{
    [CmdletBinding(
        SupportsShouldProcess=$True
    )]
    param (
        [Parameter(            
            Mandatory = $true
        )]   
        [PSCustomObject] $AzureEnv,
        [System.Management.Automation.PSCredential] $VMcred,
        [Parameter(
            ValueFromPipeline = $true
        )]   
        [PSCustomObject] $Config
    )

    if ($vm = Get-AzureRmVM -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName | ? { $_.Name -eq $Config.VMname}) {
        Write-Verbose "$($Config.VMname) already exists!"
        $vm
    } else {

        #Set VMcred if not provided
        if (!($Config.VMuser -and $Config.VMpass) -and !$VMcred){
            # Prompt for credentials if not provided
            $VMcred = Get-Credential -Message "Enter admin credentials for the VM: $($Config.VMname)" 
            $VMuser = $VMcred.UserName
            $VMpass = $VMcred.GetNetworkCredential().Password 
        } elseif (($Config.VMuser) -and ($Config.VMpass)){
            $VMcred = Get-THAzureCredentials $Config.VMuser $Config.VMpass
        }
    
        #Prepare VM config
        $vm = New-AzureRmVMConfig -VMName $Config.VMname -VMSize $Config.VMsize
        if ($Config.Image.Offer -in @("CentOS", "Ubuntu")){
           if ($Config.SSHPubKey){
              $vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $Config.VMname -Credential $VMcred -DisablePasswordAuthentication
              $vm = Add-AzureRmVMSshPublicKey -VM $vm -KeyData $Config.SSHPubKey -Path "/home/$($Config.VMuser)/.ssh/authorized_keys"
           } else {
              $vm = Set-AzureRmVMOperatingSystem -VM $vm -Linux -ComputerName $Config.VMname -Credential $VMcred
           }
        } else {
           Write-Error "$($Config.Image.Offer) is not supported at this time"
           break
        }

        #Get VM Image
        if($Config.Image -is [System.Collections.Hashtable]) {
           $vm = Get-AzureRmVMImage -Location $AzureEnv.Location.Name.DisplayName `
                   -PublisherName $Config.Image.PublisherName `
                   -Offer $Config.Image.Offer `
                   -Skus $Config.Image.Skus |
           Set-AzureRmVMSourceImage -VM $vm
        }
        #TODO Custom Image

        #Networking
        $VNET = Get-AzureRmVirtualNetwork | ? { $_.Name -eq $Config.VNET }
        $Subnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VNET -Name $Config.SubnetName

        if ($Config.PublicIP) {
           $PublicIp = New-AzureRmPublicIpAddress -Name "$($Config.VMname)_PublicIp" -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName `
              -Location $AzureEnv.Location.Name.DisplayName -AllocationMethod Dynamic
           $myNIC = New-AzureRmNetworkInterface -Name "$($Config.VMname)_PubNIC" -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName `
              -Location $AzureEnv.Location.Name.DisplayName -SubnetId $Subnet.Id -PublicIpAddressId $PublicIp.Id
           $myVM = Add-AzureRmVMNetworkInterface -VM $vm -Id $myNIC.Id
        }

        #Prepare OS disk
        $osDiskUri = $AzureEnv.StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/$($Config.VMname)_disk1.vhd"
        $vm = Set-AzureRmVMOSDisk -VM $vm -Name "$($Config.VMname)_OsDisk1" -VhdUri $osDiskUri -CreateOption FromImage

        #Create
        $result = New-AzureRmVM -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName -Location $AzureEnv.Location.Name.DisplayName -VM $vm

        if($result.IsSuccessStatusCode) {
            Get-AzureRmVM -Name $Config.VMname -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName
        } else {
            Write-Error "VM creation failed"
        }
    }
}
