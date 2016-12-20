<#
.SYNOPSIS

Function creates Azure Virtual Network with Virtual Subnets and IPSEC VPN to the local site location

.DESCRIPTION

.EXAMPLE 

$VNetwork =  New-Object –TypeName PSObject –Prop @{
    'Name' = "VNET Name"
    'Address' = "10.100.1.0/24" #Virtual site network address
    'LocalSite' = 'LocalSite001'
    'GatewayIpAddress' = "GW Public IP"
    'LocalNetworks' = @('192.168.1.0/24', '192.168.2.0/24') #Local site subnets
    'VPNType' = "PolicyBased"
    'Subnets' =  @{  #Virtual network subnets
                    'Name' = "Net1 (Tier1)"
                    'Address' = "10.100.1.0/26"
                 },
                 @{
                    'Name' = "Net2 (Tier2)"
                    'Address' = "10.100.1.64/26"
                 },
                 @{
                    'Name' = "GatewaySubnet"
                    'Address' = "10.100.1.128/28"
                 }
}

$VNetwork | New-THAzureVNet -AzureEnv $AzureEnv -Verbose

.NOTES

Author: Tomasz Habiger <tomasz.habiger@gmail.com>
Date: Dec 2016

The content of this script is copyrighted to the author. It is provided AS IS, and no warranty of ANY kind is provided. Use it at your own risk!

#>

function New-AzureVNet{
    [CmdletBinding(
        SupportsShouldProcess=$True
    )]
    param (
        [Parameter(            
            Mandatory = $true
        )]   
        [PSCustomObject] $AzureEnv,
        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]   
        [String] $Name,
        [Parameter(            
            ValueFromPipelineByPropertyName = $true
        )]   
        [String] $Address,
        [Parameter(            
            ValueFromPipelineByPropertyName = $true
        )]   
        [hashtable[]] $Subnets,
        [Parameter(            
            ValueFromPipelineByPropertyName = $true
        )]   
        [String] $LocalSite,
        [Parameter(            
            ValueFromPipelineByPropertyName = $true
        )]   
        [String] $GatewayIpAddress,
        [Parameter(            
            ValueFromPipelineByPropertyName = $true
        )]   
        [String[]] $LocalNetworks,
        [Parameter(            
            ValueFromPipelineByPropertyName = $true
        )]   
        [String] $VPNType
    )

    process {
    
        if ((Get-AzureRmVirtualNetwork).Name -notcontains $name) {
            $vnet = New-AzureRmVirtualNetwork `
                -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName `
                -Name $Name `
                -AddressPrefix $Address `
                -Location $AzureEnv.Location.Name.DisplayName
        } else {
            Write-Verbose "VNET $name already exists!"   
            $vnet = Get-AzureRmVirtualNetwork | ? { $_.Name -eq $name }
        } 

        foreach ($s in $Subnets){
            if ((Get-AzureRmVirtualNetwork -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName).Name -notcontains $s.Name) {
               Try {
                  Add-AzureRmVirtualNetworkSubnetConfig -Name $s.Name -VirtualNetwork $vnet -AddressPrefix $s.Address -ErrorAction Stop
               }
               Catch {
                 if ($_.Exception.Message -eq "Subnet with the specified name already exists") {
                    Write-Verbose $_.Exception.Message
                  } else {
                    throw $_
                  }
               }
            }
        }

        Set-AzureRmVirtualNetwork -VirtualNetwork $vnet 
        # if i don't get it once again, network IDs are empty
        $vnet = Get-AzureRmVirtualNetwork | ? { $_.Name -eq $name }

        if ($LocalSite){
            $lgw = New-AzureRmLocalNetworkGateway `
                -Name $LocalSite `
                -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName `
                -Location $AzureEnv.Location.Name.DisplayName `
                -GatewayIpAddress $GatewayIpAddress `
                -AddressPrefix $LocalNetworks

            $GWip= New-AzureRmPublicIpAddress `
                -Name "$($name)_gwip" `
                -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName `
                -Location $AzureEnv.Location.Name.DisplayName `
                -AllocationMethod Dynamic

            $GWsubnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet
            $GWipconfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name "$($name)_gwipconfig" -SubnetId $GWsubnet.Id -PublicIpAddressId $GWip.Id 
            
            $vgw = New-AzureRmVirtualNetworkGateway `
                -Name "$($name)_gw" `
                -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName `
                -Location $AzureEnv.Location.Name.DisplayName `
                -IpConfigurations $GWipconfig `
                -GatewayType Vpn `
                -VpnType $VPNType

            $sharedPass = Get-THARandomString 20 -type sharedKey
            write-verbose "Shared password: $sharedPass"
            New-AzureRmVirtualNetworkGatewayConnection `
                -Name "$($name)_sitecon" `
                -ResourceGroupName $AzureEnv.ResourceGroup.ResourceGroupName `
                -Location $AzureEnv.Location.Name.DisplayName `
                -VirtualNetworkGateway1 $vgw `
                -LocalNetworkGateway2 $lgw `
                -ConnectionType IPsec `
                -RoutingWeight 10 `
                -SharedKey $sharedPass
        }
    }
}