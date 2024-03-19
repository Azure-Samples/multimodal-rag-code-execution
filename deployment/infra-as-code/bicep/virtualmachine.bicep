@description('The name of the Virtual Network (VNet) where resources will be deployed')
param vnetName string

@description('The location/region where the resources will be deployed')
param location string

@description('The name of the Virtual Machine (VM)')
param vmName string

@description('The name of the subnet where the VM will be located')
param vmSubnet string

@description('The name of the subnet where the bastion host will be located')
param bastionSubnet string

@description('A unique identifier that will be appended to resource names')
param uniqueid string

@description('A prefix that will be prepended to resource names')
param namePrefix string

@secure()
param adminUserPassword string = ''
param adminUserName string = 'azureuser'

@description('The name of the Bastion host')
var varBastionName = '${namePrefix}-bastion-${uniqueid}'
var bastionPublicIpName = 'pip-${varBastionName}'
var varVmName = 'vm${uniqueid}' 
var varNicName = 'nic-${vmName}'

// existing resource name params 
param keyVaultName string

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing =  {
  name: vnetName  
}

resource subnetBastion 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' existing = {
  parent: vnet
  name: bastionSubnet
}

resource subnetVM 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' existing = {
  parent: vnet
  name: vmSubnet
}

// resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing =  {
//   name: keyVaultName  
// }

resource VMnsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = {
  name: 'nsg-agentsSubnet' 
}

//External IP for the VM
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: bastionPublicIpName
  location: location
  zones: null
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4    
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: varBastionName  
  location: location
  properties: {        
    scaleUnits: 2
    enableTunneling: true
    enableIpConnect: true
    disableCopyPaste: false
    enableShareableLink: false
    enableKerberos: false
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: subnetBastion.id
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]    
  }
  sku: {
    name: 'Standard'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: varNicName
  location: location
  properties: {
    networkSecurityGroup: {
      id: VMnsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {          
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetVM.id
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: varVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: varVmName
      adminUsername: adminUserName
      adminPassword: adminUserPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}


output vmName string = virtualMachine.name
output vmId string = virtualMachine.id
output vmAdminUserName string = adminUserName
output vmUserPassword string = adminUserPassword
output bastionName string = bastionHost.name



