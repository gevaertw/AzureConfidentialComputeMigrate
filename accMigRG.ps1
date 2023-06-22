# This script will migrate the virtual machines in a specific resource group to confidential compute VM's
# This operation is non distructive as it creates the resources in a new resource group and optionaly in a new subscription
# This script is written to migrate linux VM's,  It assumes that you don't need to change anything inside the VM.  

# In order to run this script you need to meet the following pre requisites
#   run Windows 10 or 11
#   Have the lateste VS code on your PC (optional, but easier to fine tune the script)
#   Have powershell terminal installed in VS Code
#   Have the latest AZCLI in your PC
#   Have AZCOPY installed on your PC

##############################Do not change these variables#######################################

# new VM's will get a console for troubleshooting purposes, this requires a storage account.
$destinationImageStorage = "saimgstore" + [string](Get-Random)  #this generates a 24 character thing (12 hex).
#$destinationImageStorage = "saimgstore197694224" (you can use an existing one if you like, in that case comment the above and uncomment this one)
$destinationImageStorageContainerName = "imagescontainer"
$myPublicIP = curl ifconfig.me # this gets the public IP from the pc you are working on, and will be used to later secure the blob storage a bit.


##############################Customize these variables to your need##############################
#region where we work in
$regionName = "northeurope"

#tags we want to add
$tagList = @("CostCenter=AccmigExperiment", "Environment=DEV01")

# In what subscription & resource group can you find the VM that needs to become confidential
$sourceSubscriptionName = "ME-MngEnvMCAP376337-wgevaert-1"
$sourceRGName = "rg-dev02-myexistingVMs"

# In what subscription & resource groups will you land the confidential VM (its advised that at least different RG's are used.)
$destinationSubscriptionName = "ME-MngEnvMCAP376337-wgevaert-2"
$destinationVMRGName = "rg-dev02-myNewConfidentialVM"
$destinationNetworkRGName = "rg-dev02-myNewConfidentialNetwork"
$destinationImagesRGName = "rg-dev02-myNewConfidentialImages"

# The script needs to know your preferred SKU conversion, names must be exact and are case sensitive.  Update as required
$skuConversionTable = @{
    Standard_D2_v5 = 'Standard_DC2as_v5' ;
    Standard_D4_v5 = 'Standard_DC4as_v5' ;
    Standard_D8_v5 = 'Standard_DC8as_v5' ;
    Standard_D2s_v5 = 'Standard_DC2as_v5' ;
    Standard_D4s_v5 = 'Standard_DC4as_v5' ;
    Standard_D8s_v5 = 'Standard_DC8as_v5' ;
}

$vmConfidentialSkuNameDefault = "Standard_DC2as_v5" # in case a sku is not found, this confidential sku will be used

# Path to azcopy on your PC.  Make your life easy, put the comand in a path without spaces (or find out yourself how to handle spaces in path names :)) 
$azcopyPath = "c:\azcopy\azcopy.exe"

# The name of the boot diagniostic storage accounts
# new VM's will get a console for troubleshooting purposes, this requires a storage account.
$destinationBootdiagStorage = "sabootconsole" + [string](Get-Random)


# The nework where the VM will land
$destinationvNetName = "vnet-myNewConfidentialNetwork"
$destinationvNetAddressSpace = "10.0.0.0/16"
$bastionAddressPrefix = "10.0.254.0/24"
$vmConfidentialSubnetName = "snet-ConfidentialVM"
$vmConfidentialAddressPrefix = "10.0.0.0/24"
$bastionPublicIPName = "pip-Bastion"
$bastionName = "bas-azureacc"

# Image galery variables
$destinationGalleryName = "galVMtoConfidentialVMGalery"
$sigPublisherName = "Wouter"
$osType = "Linux" # make sure this matches your environment.
$galleryImageVersion = '1.0.0' #make sure change this for each new version
$imageOfffer = "RHEL" # make sure this matches your environment.


##############################Script ##############################

###################################################################
#####PART 1, prepare the destination to recieve the VM's
###################################################################
# Logon
#az Login
az account set --subscription $destinationSubscriptionName

# create the RGs
az group create --name $destinationVMRGName --location $regionName --tags $tagList
az group create --name $destinationNetworkRGName --location $regionName --tags $tagList
az group create --name $destinationImagesRGName --location $regionName --tags $tagList

Write-Host -ForegroundColor Green "Create the vNet"
az network vnet create `
    --name $destinationvNetName `
    --resource-group $destinationNetworkRGName `
    --location $regionName `
    --tags $tagList `
    --address-prefix $destinationvNetAddressSpace

Write-Host -ForegroundColor Green "Create Confidential VM subnet"
az network vnet subnet create `
    --name $vmConfidentialSubnetName `
    --resource-group $destinationNetworkRGName `
    --vnet-name $destinationvNetName `
    --address-prefixes $vmConfidentialAddressPrefix

<# Write-Host -ForegroundColor Green "create bastion subnet in vnet (the name is fixed, you cannot change it)"
az network vnet subnet create `
    --name AzureBastionSubnet `
    --resource-group $destinationNetworkRGName `
    --vnet-name $destinationvNetName `
    --address-prefixes $bastionAddressPrefix

Write-Host -ForegroundColor Green Bastion needs a public IP
az network public-ip create `
    --resource-group $destinationNetworkRGName `
    --name $bastionPublicIPName `
    --tags $tagList `
    --sku Standard `
    --location $regionName

Write-Host -ForegroundColor Green Create The bastion
az network bastion create `
    --name $bastionName `
    --resource-group $destinationNetworkRGName `
    --vnet-name $destinationvNetName `
    --location $regionName `
    --tags $tagList `
    --enable-tunneling true `
    --public-ip-address $bastionPublicIPName `
    --sku Standard #>

Write-Host -ForegroundColor Green "Create boot diagnostics storage account"
az storage account create `
    --name $destinationBootdiagStorage `
    --resource-group $destinationVMRGName `
    --location $regionName `
    --tags $tagList `
    --sku Standard_LRS

az storage account network-rule add  `
    --account-name $destinationBootdiagStorage `
    --resource-group $resourceGroupName `
    --ip-address $myPublicIP

Write-Host -ForegroundColor Green "Create a storage account for the images"
az storage account create `
    --name $destinationImageStorage `
    --resource-group $destinationImagesRGName `
    --location $regionName `
    --tags $tagList `
    --sku Standard_LRS

az storage account network-rule add  `
    --account-name $destinationImageStorage `
    --resource-group $resourceGroupName `
    --ip-address $myPublicIP

Write-Host -ForegroundColor Green "Create a container in the storage account for the images"
az storage container create `
    --name $destinationImageStorageContainerName `
    --account-name $destinationImageStorage `
    --resource-group $destinationImagesRGName

Write-Host -ForegroundColor Green "Create the galery to store all images"
az sig create `
    --resource-group $destinationImagesRGName `
    --gallery-name $destinationGalleryName `
    --tags $tagList `
    --location $regionName
    

###################################################################
#####PART 2 Start working on the VM's
###################################################################

Write-Host -ForegroundColor Green "Getting all VMs from the source resource group"
az account set --subscription $sourceSubscriptionName
$sourceVMIDObj = az vm list --resource-group $sourceRGName --query "[].id" --output json | ConvertFrom-Json
$sourceVMIDList = @($sourceVMIDObj)


Write-Host -ForegroundColor Green "Create a SAS token for the destination container."
az account set --subscription $destinationSubscriptionName
$end = (Get-Date).ToUniversalTime().AddHours(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
$sas = $(az storage container generate-sas `
        --account-name $destinationImageStorage `
        --name $destinationImageStorageContainerName `
        --expiry $end `
        --permissions acdelmrw -o tsv)

## For each VM in the resource group
foreach ($sourceVMID in $sourceVMIDList) {
    az account set --subscription $sourceSubscriptionName
    $sourceVMName = (az vm show --id $sourceVMID --query "name")
    $sourceVMType = (az vm show --id $sourceVMID --query "hardwareProfile.vmSize")
    #$sourceVMOSDiskType = (az vm show --id $sourceVMID --query "storageProfile.osDisk.osType")
    Write-Host -ForegroundColor Green "Working on VM: "$sourceVMName", SKU: "$sourceVMType
    Write-Host -ForegroundColor Green stop the VM completly
    az vm deallocate --id $sourceVMID
    Write-Host -ForegroundColor Green "Get the OS Disk Name"
    $osDiskName = az vm show --id $sourceVMID --query "storageProfile.osDisk.name" --output tsv
    Write-Host -ForegroundColor Green "Working on OS disk: " + $osDiskName + " from VM: " + $sourceVMName

    Write-Host -ForegroundColor Green "Create a SAS token from the source disk in order to copy the disk"
    $osDiskAccessSasUnclean = az disk grant-access --resource-group $sourceRGName --name $osDiskName  --access-level Read --duration-in-seconds 36000 -o tsv
    $osDiskAccessSas = ($osDiskAccessSasUnclean -replace "None| ").Trim() #cut the "none" that is anoying us.)
    $sasToStorageAccountContainer = "https://" + $destinationImageStorage + ".blob.core.windows.net/" + $destinationImageStorageContainerName + "/" + $osDiskName + ".vhd?" + $sas

    Write-Host -ForegroundColor Green "Copy the OS Disk to the storage account"
    $azCopyCommand = $azcopyPath + " copy " + '"' + $osDiskAccessSas + '" "' + $sasToStorageAccountContainer + '" ' + "--from-to BlobBlob"
    Invoke-Expression $azCopyCommand

    az account set --subscription $destinationSubscriptionName
    Write-Host -ForegroundColor Green "Creating the image"
    $imageDefinitionName = "PreUpgrade" + $sourceVMName
    $sigSkuName = "PreUpgrade" + $sourceVMName

    az sig image-definition create `
        --resource-group  $destinationImagesRGName `
        --location $regionName `
        --tags $tagList `
        --gallery-name $destinationGalleryName `
        --gallery-image-definition $imageDefinitionName `
        --publisher $sigPublisherName `
        --offer $imageOfffer `
        --sku $sigSkuName `
        --os-type $osType `
        --os-state Specialized `
        --hyper-v-generation V2 `
        --features SecurityType=ConfidentialVMSupported

    $osDiskStorageAccountBlobUri = "https://" + $destinationImageStorage + ".blob.core.windows.net/" + $destinationImageStorageContainerName + "/" + $osDiskName + ".vhd"

    $storageAccountId = az storage account show --name $destinationImageStorage --resource-group $destinationImagesRGName --query "id" -o tsv

    az sig image-version create `
        --resource-group $destinationImagesRGName `
        --gallery-image-definition $imageDefinitionName `
        --gallery-name $destinationGalleryName `
        --gallery-image-version $galleryImageVersion `
        --os-vhd-storage-account $storageAccountId `
        --os-vhd-uri $osDiskStorageAccountBlobUri
    
    Write-Host -ForegroundColor Green "Creating the confidential VM: " + $sourceVMID
    
    # set new SKU, if not found in the conversion table, use default type
    if ($skuConversionTable.ContainsKey($sourceVMType)) {
        $vmConfidentialSkuName = $skuConversionTable[$sourceVMType]
        Write-Host -ForegroundColor Green "VM type match: " + $vmConfidentialSkuName
    }
    else {

        $vmConfidentialSkuName = $vmConfidentialSkuNameDefault
        Write-Host -ForegroundColor Yellow "Could not find matching VM type, default will be used."
    }
    # set new disk type
    $galleryImageId = az sig image-version show --gallery-image-definition $imageDefinitionName --gallery-image-version $galleryImageVersion --gallery-name $destinationGalleryName --resource-group $destinationImagesRGName --query "id" -o tsv

    Write-Host -ForegroundColor Green "Creating VM "$sourceVMName" with VM type: "$vmConfidentialSkuName 
    az vm create `
        --name $sourceVMName `
        --resource-group $destinationVMRGName `
        --location $regionName `
        --tags $tagList `
        --image $galleryImageId `
        --vnet-name destinationvNetName `
        --subnet $vmConfidentialSubnetName `
        --specialized `
        --size $vmConfidentialSkuName `
        --public-ip-address '""' `
        --enable-vtpm true `
        --enable-secure-boot true `
        --security-type ConfidentialVM `
        --os-disk-security-encryption-type VMGuestStateOnly `
        --nic-delete-option Delete `
        --os-disk-delete-option Delete 

    Write-Host -ForegroundColor Green "Get the data disks from the VM"
    az account set --subscription $sourceSubscriptionName
    $sourceVMDataDiskIDObj = az vm show --id $sourceVMID --query "storageProfile.dataDisks[].managedDisk.id" --output json | ConvertFrom-Json
    $sourceVMDataDiskIDList = @($sourceVMDataDiskIDObj)
    foreach ($sourceVMDataDiskID in $sourceVMDataDiskIDList) {
        az account set --subscription $sourceSubscriptionName
        Write-Host -ForegroundColor Green "Working on data disk: "$sourceVMDataDiskID", from VM:"  $sourceVMID
        $sourceVMDataDiskSize = az disk show --id $sourceVMDataDiskID --query "diskSizeGb" --output tsv
        $sourceVMDataDiskName = az disk show --id $sourceVMDataDiskID --query "name" --output tsv
        $sourceVMDataDiskSKUName = az disk show --id $sourceVMDataDiskID --query "sku.name" --output tsv
        $sourceVMDataDiskSKUTier = az disk show --id $sourceVMDataDiskID --query "sku.tier" --output tsv
        $sourceVMDataDiskLunID = az vm show --id $sourceVMID --query "storageProfile.dataDisks[?name=='$sourceVMDataDiskName'].lun" --output json | ConvertFrom-Json

        Write-Host -ForegroundColor Green "dataDiskName: "$sourceVMDataDiskName"`ndataDiskSize: "$sourceVMDataDiskSize"`ndataDiskLunID: "$sourceVMDataDiskLunID "`ndataDiskSKUName: "$sourceVMDataDiskSKUName "`ndataDiskSKUTier: "$sourceVMDataDiskSKUTier

        $dataDiskAccessSasUnclean = az disk grant-access --resource-group $sourceRGName --name $sourceVMDataDiskName --access-level Read --duration-in-seconds 36000 --output tsv
        Write-Host -ForegroundColor Green "dataDiskAccessSasUnclean: " $dataDiskAccessSasUnclean
        $dataDiskAccessSas = ($dataDiskAccessSasUnclean -replace "None| ").Trim() #cut the "none" that is anoying us.)
        Write-Host -ForegroundColor Green "dataDiskAccessSas: " $dataDiskAccessSas
        $sasToStorageAccountContainer = 'https://' + $destinationImageStorage + ".blob.core.windows.net/" + $destinationImageStorageContainerName + "/" + $sourceVMDataDiskName + ".vhd?" + $sas
        Write-Host -ForegroundColor Green "Copy the Data Disk to the target storage account"
        $azCopyCommand = $azcopyPath + " copy " + '"' + $dataDiskAccessSas + '" "' + $sasToStorageAccountContainer + '" ' + "--from-to BlobBlob"
        Invoke-Expression $azCopyCommand
        Write-Host -ForegroundColor Green "Attaching the data disk to the VM"
        $dataDiskSAURL = "https://$destinationImageStorage.blob.core.windows.net/$destinationImageStorageContainerName/$sourceVMDataDiskName.vhd"
        Write-Host $sourceVMDataDiskName
        Write-Host $dataDiskSAURL

        az account set --subscription $destinationSubscriptionName
        Write-Host -ForegroundColor Green "Creating the disk "$sourceVMDataDiskName
        az disk create `
            --name $sourceVMDataDiskName `
            --resource-group $destinationVMRGName `
            --location $regionName `
            --size-gb $sourceVMDataDiskSize `
            --source $dataDiskSAURL
        
        Write-Host -ForegroundColor Green "Attaching the datadisk " $sourceVMDataDiskName " to the VM "$sourceVMName
        az vm disk attach `
            --name $sourceVMDataDiskName `
            --resource-group $destinationVMRGName `
            --vm-name $sourceVMName `
            --size-gb $sourceVMDataDiskSize `
            --sku $sourceVMDataDiskSKUName `
            --lun $sourceVMDataDiskLunID
    }
}