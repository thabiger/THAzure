function Write-AzureObjects{
    [CmdletBinding()]
    param (
        [Parameter(            
            Mandatory = $true,            
            ValueFromPipelineByPropertyName = $true
        )]   
        [Alias('SubscriptionName')]
        [string] $name,
        [Parameter(ValueFromPipeline = $true)]
        [Alias('IO')]            
        [PSObject]$InputObject
    )

    begin {
        $i=1; $first = 1;
    }
    process { 
        if ($first){
            $msg = "Select " + $InputObject.GetType().Name + ":"
            Write-Host $msg
            $first = 0
        }
        Write-Host ($i++) $name
    }
    end {

        while ($objectPos -eq $null){
            $objectPos = read-host 
            if (!(isNumeric($objectPos) -and $objectPos -lt $i)){
                Write-Host "Invalid input, try again:"
                $objectPos = $null
            }
        }
        return $objectPos
    }
}

function Pick-AzureObject{
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "withoutName")]   
        [int] $cObjPos,
        [Parameter(ParameterSetName = "explicitName")]   
        [string] $cObjName,
        [Parameter(            
            Mandatory = $true,            
            ValueFromPipelineByPropertyName = $true
        )]   
        [Alias('SubscriptionName','StorageAccountName', 'ServiceName', 'DisplayName', 'ResourceGroupName')]
        [string] $name,
        [Parameter(ValueFromPipeline = $true)]
        [Alias('IO')]            
        [PSObject]$InputObject  
    )

    begin { $i=1 }
    process {
        if (($cObjName) -and ($name -eq $cObjName)) { $InputObject }
        if (($cObjPos) -and ($i -eq $cObjPos)) { $InputObject }
        $i++
    }
}

function Get-AzureObject{
    [CmdletBinding()]
    param (
        [Parameter()]   
        [System.Array]$oList,
        [Parameter()]   
        [String]$cObjName,
        [Parameter()]   
        [Switch]$valid
    )
    if ($oList -eq $null) { #jeśli nie ma jeszcze żadnych obiektów
        $obj = $null
    } else {
        if ($cObjName) {
            $obj = $oList | Pick-THAzureObject -cObjName $cObjName 
        } else {
            $pos = $oList | Write-THAzureObjects
            $obj = $oList | Pick-THAzureObject -cObjPos $pos
        }
    }
    if ($valid -and !$obj) { Write-Error "Invalid parameter $cObjName!"; break }
    return $obj
}

function Get-AzureVMCertificate{
    [CmdletBinding()]
    param (
        [Parameter(            
            Mandatory = $true
        )]   
        [string] $ServiceName,
        [Parameter(            
            Mandatory = $true
        )]   
        [string] $VMName
    )
    $winRMCert = (Get-AzureVM -ServiceName $ServiceName -Name $VMName | select -ExpandProperty VM).DefaultWinRMCertificateThumbprint
    if ($winRMCert) {
        $AzureX509cert = Get-AzureCertificate -ServiceName $ServiceName -Thumbprint $winRMCert -ThumbprintAlgorithm sha1

        $certTempFile = [IO.Path]::GetTempFileName()
        $AzureX509cert.Data | Out-File $certTempFile
    } else {
        write-Host ("**ERROR**: Unable to find WinRM Certificate for virtual machine '"+$VMName) 
    }
    $CertToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certTempFile

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $store.Add($CertToImport)
    $store.Close()

    Remove-Item $certTempFile
}

function Wait-AzureVMBoot(){
    [CmdletBinding()]
    param (
        [Parameter(            
            Mandatory = $true
        )]   
        [string] $ServiceName,
        [Parameter(            
            Mandatory = $true
        )]   
        [string] $VMName
    )

    #wait for VM to reboot 
    Write-Verbose "Checking status of $VMName"

    $VMStatus = Get-AzureVM -ServiceName $ServiceName -name $VMName
    if ($VMStatus -eq $null) {
        write-host "VM $VMname does not exists"
        exit
    }
    While ($VMStatus.InstanceStatus -ne "ReadyRole")
    {
      Write-Verbose "Waiting... Current Status =  $($VMStatus.Status)"
      Start-Sleep -Seconds 30
 
      $VMStatus = Get-AzureVM -ServiceName $ServiceName -name $VMName
    } 
}

function Probe-AzurePSSession{
        [CmdletBinding()]
        param (
            [Parameter(            
            )]   
            [string] $uri,
            [Parameter(            
                Mandatory = $true
            )]   
            [System.Management.Automation.PSCredential] $Cred
        )
    for($retry = 0; $retry -le 15; $retry++)
    {
      try
      {
        $session = New-PSSession -ConnectionUri $uri -Credential $cred -SessionOption(New-PSSessionOption -SkipCACheck -SkipCNCheck) -ErrorAction SilentlyContinue
        if ($session -ne $null)
        {
          $session
          break
        }
        Write-Host "Unable to create a PowerShell session . . . sleeping and trying again in 30 seconds."
        Start-Sleep -Seconds 30
      }
      catch
      {
        Write-Host "Unable to create a PowerShell session . . . sleeping and trying again in 30 seconds."
        Start-Sleep -Seconds 30
      }
    }
}

function Get-AzureCredentials(){
    [CmdletBinding()]
    param (
        [Parameter(
            ParameterSetName="fromArg",            
            position = 0,
            Mandatory = $true
        )]   
        [string] $user,
        [Parameter(            
            ParameterSetName="fromArg",
            position = 1,
            Mandatory = $true

        )]   
        [string] $pass,
        [Parameter(ParameterSetName="fromArg")]   
        [Parameter(ParameterSetName="fromCLI")]   
        [string] $NBTdomain,
        [Parameter(            
            ParameterSetName="fromCLI"
        )]   
        [switch] $cli
    )
    if ($PsCmdlet.ParameterSetName -eq "fromArg"){
        $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $user, $($pass | ConvertTo-SecureString -AsPlainText -Force)
    } else {
        $cred = Get-Credential -Message "Provide domain credentials in a form of: <user>@<domain.fqdn>"
    }
    #contains domain part
    $username = $cred.UserName.Split('@')[0]
    $domain = $cred.UserName.Split('@')[1]
    if (($domain) -and (-not $NBTdomain)){
        $NBTdomain = Invoke-Command -ComputerName $domain -Credential $cred -ScriptBlock { $env:userdomain }
    }
    if ($NBTdomain){
        $NBTcred = New-Object System.Management.Automation.PSCredential -ArgumentList "$($NBTDomain)\$($username)", $cred.Password
        $cred | Add-Member -MemberType NoteProperty -Name NBTcred -Value $NBTcred
    }
    $cred
}

function Get-AzureVMConnection(){
        [CmdletBinding()]
        param (
            [Parameter(            
                Mandatory = $true
            )]   
            [string] $Name,
            [Parameter(            
            )]   
            [string] $ServiceName,
            [Parameter(            
                Mandatory = $true
            )]   
            [System.Management.Automation.PSCredential] $Cred
        )

    if ($ServiceName) {
        $uri = Get-AzureWinRMUri -ServiceName $ServiceName -Name $Name
        write-host $uri
        Enter-PSSession -ConnectionUri $uri -Credential $cred -SessionOption(New-PSSessionOption -SkipCACheck -SkipCNCheck) 
    } else {
        Enter-PSSession -ComputerName $name -UseSSL -Credential $cred -SessionOption(New-PSSessionOption -SkipCACheck -SkipCNCheck)
    }
}

function Get-AzureUri(){
        [CmdletBinding()]
        param (
            [Parameter(            
                Mandatory = $true,
                Position = 1
            )]   
            [string] $Name,
            [Parameter(            
            )]   
            [string] $ServiceName,
            [Parameter(            
            )]   
            [switch] $PublicUri
        )

        if ((!$ServiceName) -and ($PublicUri -ne $true)){
            $uri = "https://$($Name):5986"
        } else {
            $uri = Get-AzureWinRMUri -ServiceName $ServiceName -Name $Name 
        }
        $uri
}

function Add-AzureToHosts(){
        [CmdletBinding()]
        param (
            [Parameter(            
                Mandatory = $true,
                Position=0
            )]   
            [string] $line
        )
        $hostsfilelocation = $env:SystemRoot + "\System32\Drivers\etc\hosts"
        $hostsfile = Get-Content $hostsfilelocation
        If ($Hostsfile -notcontains $line) {
                $hostsfile = $Hostsfile + $line
        }
        $hostsfile | Set-Content $hostsfilelocation –Force
}
