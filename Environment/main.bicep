targetScope = 'subscription'

@description('Required. Subscription GUID.')
param subscriptionId string

@description('Required. ResourceGroup Name.')
param resourceGroupName string

@description('Required. ResourceGroup location.')
param resourceGroupLocation string = 'usgovvirginia'

@description('Required. Use existing virtual network and subnet.')
param useExistingVnetandSubnet bool = false

@description('Required. Resource Group name of virtual network if using existing vnet and subnet.')
param vNetResourceGroupName string = 'existing-vNet'

@description('Required. An Array of 1 or more IP Address Prefixes for the Virtual Network.')
param vNetAddressPrefixes array = [
  '172.17.0.0/16'
]

@description('Required. The subnet Name of ASEv3.')
param subnetAddressPrefix string = '172.17.0.0/24'

@description('Required. Secret Name in KeyVault')
param secretName string =  'Secret001'

@description('Required. Secret Value in KeyVault')
@secure()
param secretValue string = newGuid()

@description('Required. Array of Security Rules to deploy to the Network Security Group.')
param networkSecurityGroupSecurityRules array = []

@description('Required. Storage Account SKU.')
param storageAccountType string =  'Premium_LRS'

@description('Required. Creating UTC for deployments.')
param deploymentNameSuffix string = utcNow()

// If peering update this value
@description('Required. Exisisting vNet Name for Peering.')
param existingRemoteVirtualNetworkName string = ''

// If peering update this value
@description('Required. Exisisting vNet Resource Group for Peering.')
param existingRemoteVirtualNetworkResourceGroupName string = ''

// If peering update this value 
@description('Required. Setup Peering.')
param usePeering bool = false

// Object Id for access policy on keyvault -- add this GUID during deployment 
param objectId string = '00000000-0000-0000-0000-000000000000'

@description('Required. SQL Admin Username')
param sqlAdministratorLogin string  

@description('Required. SQL Password ')
@secure()
param sqlAdministratorPassword string = newGuid()

@description('Required. SQL Location')
param sqlLocation string

var privateDNSZoneName = asev3.outputs.dnssuffix
var storageAccountName = names.outputs.storageAccountName
var dbName = names.outputs.dbName
var virtualNetworkName = replace(names.outputs.resourceName, '[PH]', 'vnet')  
var managedIdentityName = replace(names.outputs.resourceName, '[PH]', 'mi')
var keyVaultName = replace(names.outputs.resourceName, '[PH]', 'kv')
var aseSubnetName = replace(names.outputs.resourceName, '[PH]', 'snet')
var aseName = replace(names.outputs.resourceName, '[PH]', 'ase')
var appServicePlanName = replace(names.outputs.resourceName, '[PH]', 'app-sp')
var networkSecurityGroupName = replace(names.outputs.resourceName, '[PH]', 'nsg')

var aseSubnet = [
  {
    name: replace(names.outputs.resourceName, '[PH]', 'snet')
    addressPrefix: subnetAddressPrefix
    delegations: [
      {
        name: 'Microsoft.Web.hostingEnvironments'
        properties: {
          serviceName: 'Microsoft.Web/hostingEnvironments'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroupName: networkSecurityGroupName 
  }
]

module rg 'modules/resourceGroup.bicep' = {
  name: 'resourceGroup-deployment-${deploymentNameSuffix}'
  scope: subscription(subscriptionId) 
  params: {
    name: resourceGroupName
    location: resourceGroupLocation
    tags: {}
  }
}

module names 'Modules/NamingConvention.bicep' = {
  name: 'naming-convention-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    environment: 'test'
    function: 'app'
    index: 1
    appName: 'aad'
  }
  dependsOn: [
    rg
  ]
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    keyVaultName:keyVaultName
    secretName: secretName
    secretValue: secretValue
    objectId: objectId
  }
  dependsOn: [
    rg
    names
  ]
}

module nsg 'modules/nsg.bicep' = if (!useExistingVnetandSubnet) {
  name: 'nsg-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    nsgName: networkSecurityGroupName
    networkSecurityGroupSecurityRules: networkSecurityGroupSecurityRules
  }
  dependsOn: [
    rg
    names
  ]
}

module virtualnetwork 'modules/virtualNetwork.bicep' = if (!useExistingVnetandSubnet) {
  name: 'vnet-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName 
    vNetAddressPrefixes : vNetAddressPrefixes
    subnets: aseSubnet
  }
  dependsOn: [
    rg
    names
    nsg
  ]
}
module subnet 'modules/subnet.bicep' = if (useExistingVnetandSubnet) {
  name: 'subnet-delegation-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, vNetResourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    subnetName: aseSubnetName
    subnetAddressPrefix: subnetAddressPrefix
  }
  dependsOn: [
    virtualnetwork
    rg
    names
    nsg
  ]
}

module asev3 'modules/appserviceevironment.bicep' = {
  name: 'ase-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    aseName: aseName
    aseVnetId: virtualnetwork.outputs.vNetId
    aseSubnetName: aseSubnetName
  }
  dependsOn: [
    virtualnetwork
    rg
    names
    nsg
  ]
}

module appserviceplan 'modules/appserviceplan.bicep' = {
  name: 'app-serviceplan-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    appServicePlanName: appServicePlanName
    hostingEnvironmentId: asev3.outputs.hostingid
  }
  dependsOn: [
    asev3
    rg
    names
    nsg
  ]
}

module privatednszone 'modules/privatednszone.bicep' = {
  name: 'private-dns-zone-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    privateDNSZoneName: privateDNSZoneName
    virtualNetworkId: virtualnetwork.outputs.vNetId
    aseName: aseName
  }
  dependsOn: [
    rg
    names
  ]
}

module web 'modules/webappsql.bicep' = {
  name: 'web-app-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    managedIdentityName: managedIdentityName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
    aseName: aseName
    hostingPlanName: appServicePlanName
    sqllocation: sqlLocation
    databaseName: dbName
  }
  dependsOn: [
    appserviceplan
    rg
    names
    nsg
  ]
}

module sa 'modules/storageaccount.bicep' = {
  name: 'storageaccount-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    storageAccountType: storageAccountType
    storageAccountName: storageAccountName
  }

  dependsOn: [
    rg
    names
  ]
}

module peeringToHub 'modules/vNetPeering.bicep' = if (usePeering) {
  name: 'hub-peering-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    existingLocalVirtualNetworkName: virtualnetwork.outputs.name
    existingRemoteVirtualNetworkName: existingRemoteVirtualNetworkName
    existingRemoteVirtualNetworkResourceGroupName: existingRemoteVirtualNetworkResourceGroupName
  }

  dependsOn: [
    rg
    names
    virtualnetwork
    nsg
  ]
}

module peeringToSpoke 'modules/vNetPeering.bicep' = if (usePeering) {
  name: 'spoke-peering-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, existingRemoteVirtualNetworkResourceGroupName)
  params: {
    existingLocalVirtualNetworkName: existingRemoteVirtualNetworkName
    existingRemoteVirtualNetworkName: virtualnetwork.outputs.name
    existingRemoteVirtualNetworkResourceGroupName: resourceGroupName
  }

  dependsOn: [
    rg
    names
    virtualnetwork
    nsg
    peeringToHub 
  ]
}

