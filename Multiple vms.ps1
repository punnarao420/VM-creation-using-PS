Import-Module AzureRM.Compute
. ".\\Invoke-Parallel-master.zip\Invoke-Parallel-master\Invoke-Parallel\Invoke-Parallel.ps1"
# Create variables to store the location and resource group names.
$location = "South Central US"
$ResourceGroupName = "MigrationRgcleas"

New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location

# Create variables to store the storage account name and the storage account SKU information
$StorageAccountName = "mystorageaccount9919"
$SkuName = "Standard_LRS"

# Create a new storage account
$StorageAccount = New-AzureRMStorageAccount -Location $location -ResourceGroupName $ResourceGroupName -Type $SkuName -Name $StorageAccountName

Set-AzureRmCurrentStorageAccount -StorageAccountName $storageAccountName -ResourceGroupName $resourceGroupName

# Create a storage container to store the virtual machine image
$containerName = 'osdisks'
$container = New-AzureStorageContainer -Name $containerName -Permission Blob

# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name mySubnet -AddressPrefix 192.168.1.0/24

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName -Location $location -Name MyVnet -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig


$VirtualMachineConfig = @()
$outfilesdata=Get-Content ".\vmnames.txt"
foreach ($file in $outfilesdata) {


# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $location -AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "mypublicdns$(Get-Random)"

# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name $file-RDP -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix *  -DestinationPortRange 3389 -Access Allow

# Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name $file-WWW -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $location -Name $file-Group -SecurityRules $nsgRuleRDP,$nsgRuleWeb

# Create a virtual network card and associate it with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name $file-Nic -ResourceGroupName $ResourceGroupName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# Define a credential object to store the username and password for the virtual machine
$UserName='demouser'
$Password='Password@123'| ConvertTo-SecureString -Force -AsPlainText
$Credential=New-Object PSCredential($UserName,$Password)

# Create the virtual machine configuration object
$VmName = $file
$VmSize = "Standard_A1"
$VirtualMachine = New-AzureRmVMConfig -VMName $VmName -VMSize $VmSize

$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName "MainComputer" -Credential $Credential

$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2016-Datacenter" -Version "latest"

$osDiskName = "OsDisk"
$osDiskUri = '{0}vhds/{1}-{2}.vhd' -f $StorageAccount.PrimaryEndpoints.Blob.ToString(), $vmName.ToLower(), $osDiskName

# Sets the operating system disk properties on a virtual machine.
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $osDiskName -VhdUri $OsDiskUri -CreateOption FromImage | Add-AzureRmVMNetworkInterface -Id $nic.Id

 $VirtualMachineConfig += ,($VirtualMachine)

}
$VirtualMachineConfig | Invoke-Parallel -ImportVariables -ScriptBlock  {
    New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $location -VM $_
}
