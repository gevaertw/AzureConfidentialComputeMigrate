#script creates a lab environment to demonstrate the script

$subscriptionName = "XXXX"
$rgName = "rg-dev02-myexistingVMs"
$regionName = "northeurope"
$tagList = @("CostCenter=AccmigExperiment", "Environment=DEV01")
$vmNamePrefix = "RHELVM"
$vmImage = "RedHat:RHEL:8-lvm-gen2:8.5.2022032206" #see vmimages on how to get this urn / vmImage
$adminUserName = "azureuser"
$dataDiskNamePrefix = "DataDisk"
$dataDiskSize = 128
$bootdiagStorage = "sabootdiag486643486"
$vNetName = "vnet-RedHatUpgrade"
$vNetAddressSpace = "10.0.0.0/16"
$bastionAddressPrefix = "10.0.254.0/24"
$vmSubnetName = "snet-VM"
$vmAddressPrefix = "10.0.0.0/24"
$bastionPublicIPName = "pip-Bastion"
$bastionName = "bas-fastDeploy"

# Logon
# az Login
az account set --subscription $subscriptionName

# create the RG
az group create --name $rgName --location $regionName --tags $tagList

# create the vNet
az network vnet create `
    --name $vNetName `
    --tags $tagList `
    --resource-group $rgName `
    --location $regionName `
    --address-prefix $vNetAddressSpace

#create VM subnet
az network vnet subnet create `
    --name $vmSubnetName `
    --resource-group $rgName `
    --vnet-name $vNetName `
    --address-prefixes $vmAddressPrefix

<# UNCOMMENT THIS BLOCK IF YOU WANT A BASTION TO BE CREATED
#create bastion subnet in vnet
az network vnet subnet create `
    --name AzureBastionSubnet `
    --resource-group $rgName `
    --vnet-name $vNetName `
    --address-prefixes $bastionAddressPrefix

#Bastion needs a public IP
az network public-ip create `
    --resource-group $rgName `
    --tags $tagList `
    --name $bastionPublicIPName `
    --sku Standard `
    --location $regionName

 #Create The bastion
az network bastion create `
    --name $bastionName `
    --tags $tagList `
    --public-ip-address $bastionPublicIPName `
    --resource-group $rgName `
    --vnet-name $vNetName `
    --location $regionName `
    --enable-tunneling true `
    --sku Standard #>


#create boot diag sa
az storage account create `
    --name $bootdiagStorage `
    --tags $tagList `
    --resource-group $rgName `
    --location $regionName `
    --sku Standard_LRS


###--------------VM1 simple type----------------------#####
#create the VM
$vmName = $vmNamePrefix + "01"
Write-Host $vmName
az vm create `
    --resource-group $rgName `
    --tags $tagList `
    --name $vmName `
    --image $vmImage `
    --size "Standard_D2s_v5" `
    --boot-diagnostics-storage $bootdiagStorage `
    --admin-username $adminUserName `
    --generate-ssh-keys `
    --security-type TrustedLaunch `
    --vnet-name $vNetName `
    --subnet $vmSubnetName `
    --public-ip-address '""'

#add a NEW disk to the vm
$dataDiskName = $vmName + $dataDiskNamePrefix + "01"
az vm disk attach `
    --resource-group $rgName `
    --vm-name $vmName `
    --name $dataDiskName `
    --size-gb $dataDiskSize `
    --sku Premium_LRS `
    --new

###--------------VM2 multiple disk type----------------------#####
#create the VM
$vmName = $vmNamePrefix + "02"
Write-Host $vmName
az vm create `
    --resource-group $rgName `
    --tags $tagList `
    --name $vmName  `
    --image $vmImage `
    --size "Standard_D4s_v5" `
    --boot-diagnostics-storage $bootdiagStorage `
    --admin-username $adminUserName `
    --generate-ssh-keys `
    --security-type TrustedLaunch `
    --vnet-name $vNetName `
    --subnet $vmSubnetName `
    --public-ip-address '""'

#add a NEW disk to the vm
$dataDiskName = $vmName + $dataDiskNamePrefix + "01"
az vm disk attach `
    --resource-group $rgName `
    --vm-name $vmName `
    --name $dataDiskName `
    --size-gb $dataDiskSize `
    --sku Premium_LRS `
    --new

#add a NEW disk to the vm
$dataDiskName = $vmName + $dataDiskNamePrefix + "02"
az vm disk attach `
    --resource-group $rgName `
    --vm-name $vmName `
    --name $dataDiskName `
    --size-gb 1024 `
    --sku Standard_LRS `
    --new

###--------------VM3 slower type ----------------------#####
#create the VM
$vmName = $vmNamePrefix + "03"
Write-Host $vmName
az vm create `
    --resource-group $rgName `
    --tags $tagList `
    --name $vmName  `
    --image $vmImage `
    --size  "Standard_D2_v5" `
    --boot-diagnostics-storage $bootdiagStorage `
    --admin-username $adminUserName `
    --generate-ssh-keys `
    --security-type TrustedLaunch `
    --vnet-name $vNetName `
    --subnet $vmSubnetName `
    --public-ip-address '""'

#add a NEW disk to the vm
$dataDiskName = $vmName + $dataDiskNamePrefix + "01"
az vm disk attach `
    --resource-group $rgName `
    --vm-name $vmName `
    --name $dataDiskName `
    --size-gb 2048 `
    --sku Standard_LRS `
    --new

$dataDiskName = $vmName + $dataDiskNamePrefix + "02"
az vm disk attach `
    --resource-group $rgName `
    --vm-name $vmName `
    --name $dataDiskName `
    --size-gb 4096 `
    --sku Standard_LRS `
    --new

