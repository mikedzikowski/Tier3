targetScope = 'subscription'

@description('Required. Subscription GUID.')
param subscriptionId string = 'f4972a61-1083-4904-a4e2-a790107320bf'

@description('Required. ResourceGroup location.')
param location string = 'usgovvirginia'

@description('Required. ResourceGroup Name.')
param resourceGroupName string = 'rg-aad-dev-01'

@description('Required. Use existing virtual network and subnet.')
param useExistingVnetandSubnet bool = false

@description('Required. Resource Group name of virtual network if using existing vnet and subnet.')
param vNetResourceGroupName string = 'rg-aad-dev-01'

@description('Required. An Array of 1 or more IP Address Prefixes for the Virtual Network.')
param vNetAddressPrefixes array = [
  '172.18.0.0/16'
]

@description('Required. The subnet Name of ASEv3.')
param aseSubnetAddressPrefix string = '172.18.0.0/24'

@description('Required. The subnet Name of ASEv3.')
param appGwsubnetAddressPrefix string = '172.18.1.0/24'

@description('Required. Secret Name in KeyVault')
param secretName string = 'Secret001'

@description('Required. Secret Value in KeyVault')
@secure()
param secretValue string = newGuid()

@description('Required. Array of Security Rules to deploy to the Network Security Group.')
param networkSecurityGroupSecurityRules array = [
  {
    name: 'Port_443'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: '100'
      direction: 'Inbound'
      sourcePortRanges: []
      destinationPortRanges: []
      sourceAddressPrefixes: []
      destinationAddressPrefixes: []
    }
  }
]

@description('Required. Creating UTC for deployments.')
param deploymentNameSuffix string = utcNow()

// If peering update this value
@description('Required. Exisisting vNet Name for Peering.')
param existingRemoteVirtualNetworkName string = 'vnet-hub-til-usgovvirginia-001'

// If peering update this value
@description('Required. Exisisting vNet Resource Group for Peering.')
param existingRemoteVirtualNetworkResourceGroupName string = 'rg-hub-til-001'

// If peering update this value 
@description('Required. Setup Peering.')
param usePeering bool = false

param sslCertificateName string = 'cert'

param dnsZoneName string = 'mikedzikowski.com'

param hostnames array = [
  '*.${dnsZoneName}'
]
param port int = 443

@description('Application gateway tier')
@allowed([
  'Standard'
  'WAF'
  'Standard_v2'
  'WAF_v2'
])
param tier string = 'WAF_v2'

@description('Application gateway sku')
@allowed([
  'Standard_Small'
  'Standard_Medium'
  'Standard_Large'
  'WAF_Medium'
  'WAF_Large'
  'Standard_v2'
  'WAF_v2'
])
param sku string = 'WAF_v2'

@description('Capacity (instance count) of application gateway')
@minValue(1)
@maxValue(32)
param capacity int = 2

@description('Autoscale capacity (instance count) of application gateway')
@minValue(1)
@maxValue(32)
param autoScaleMaxCapacity int = 10

param privateIPAllocationMethod string = 'Dynamic'
param protocol string = 'Https'
param cookieBasedAffinity string = 'Disabled'
param pickHostNameFromBackendAddress bool = true
param requestTimeout int = 20
param requireServerNameIndication bool = true
param publicIpSku string = 'Standard'
param publicIPAllocationMethod string = 'Static'

@description('Enable HTTP/2 support')
param http2Enabled bool = true
param requestRoutingRuleType string = 'Basic'
param webApplicationFirewall object = {
  enabled: true
  firewallMode: 'Detection'
  ruleSetType: 'OWASP'
  ruleSetVersion: '3.2'
  disabledRuleGroups: []
  exclusions: []
  requestBodyCheck: true
  maxRequestBodySizeInKb: 128
  fileUploadLimitInMb: 100
}

param buildKeyVault bool = false
param buildAppGateway bool = true

var publicIpAddressName = replace(names.outputs.resourceName, '[PH]', 'pip')
var privateDNSZoneName = asev3.outputs.dnssuffix
var virtualNetworkName = replace(names.outputs.resourceName, '[PH]', 'vnet')
var managedIdentityName = replace(names.outputs.resourceName, '[PH]', 'mi')
var keyVaultName = replace(names.outputs.resourceName, '[PH]', 'kv')
var aseSubnetName = replace(names.outputs.resourceName, '[PH]', 'snet')
var appGwSubnetName = replace(names.outputs.resourceName, '[PH]', 'appgw-snet')
var aseName = replace(names.outputs.resourceName, '[PH]', 'ase')
var appServicePlanName = replace(names.outputs.resourceName, '[PH]', 'sp')
var applicationGateways_app_gw_name = replace(names.outputs.resourceName, '[PH]', 'gw')
var networkSecurityGroupName = replace(names.outputs.resourceName, '[PH]', 'nsg')
var appName = replace(names.outputs.resourceName, '[PH]', 'web')
var webAppFqdn = '${appName}.${aseName}.appserviceenvironment.us'
var keyVaultSecretid = 'https://${keyVaultName}.vault.usgovcloudapi.net/secrets/${sslCertificateName}'

var aseSubnet = [
  {
    name: replace(names.outputs.resourceName, '[PH]', 'snet')
    addressPrefix: aseSubnetAddressPrefix
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
    location: location
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

module msi 'modules/managedIdentity.bicep' = {
  name: 'managed-identity-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    managedIdentityName:managedIdentityName
    location: location
  }
}

module keyvault 'modules/keyvault.bicep' = if (buildKeyVault) {
  name: 'keyvault-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    keyVaultName: keyVaultName
    secretName: secretName
    secretValue: secretValue
    objectId: msi.outputs.msiPrincipalId
  }
  dependsOn: [
    rg
    names
    msi
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
    vNetAddressPrefixes: vNetAddressPrefixes
    subnets: aseSubnet
  }
  dependsOn: [
    rg
    names
    nsg
  ]
}
module subnet 'modules/subnet.bicep' = if (!useExistingVnetandSubnet) {
  name: 'ase-subnet-delegation-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, vNetResourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    subnetName: aseSubnetName
    subnetAddressPrefix: aseSubnetAddressPrefix
    delegations: [
      {
        name: 'Microsoft.Web.hostingEnvironments'
        properties: {
          serviceName: 'Microsoft.Web/hostingEnvironments'
        }
      }
    ]
  }
  dependsOn: [
    virtualnetwork
    rg
    names
    nsg
  ]
}

module appgwSubnet 'modules/subnet.bicep' = if (!useExistingVnetandSubnet) {
  name: 'appgw-subnet-delegation-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, vNetResourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    subnetName: appGwSubnetName
    subnetAddressPrefix: appGwsubnetAddressPrefix
    delegations: []
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

module web 'modules/webAppBehindASE.bicep' = {
  name: 'web-app-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    managedIdentityName: managedIdentityName
    aseName: aseName
    hostingPlanName: appServicePlanName
    appName: appName
  }
  dependsOn: [
    appserviceplan
    rg
    names
    nsg
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

module dnsZone 'modules/dnsZone.bicep' = {
  name: 'dnsZone-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    dnsZoneName: dnsZoneName
    location: 'Global'
    appName: appName 
    publicIpAddress: applicationGateway.outputs.publicIpAddress
  }
  dependsOn: [
    asev3
    privatednszone
    virtualnetwork
    nsg
  ]
}

module applicationGateway 'modules/applicationGateway.bicep' = if (buildAppGateway) {
  name: 'applicationGateway-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    subscriptionId: subscriptionId
    resourceGroup: resourceGroupName
    location: location
    applicationGateways_app_gw_name: applicationGateways_app_gw_name
    vNetName: virtualNetworkName
    subnetName: appGwSubnetName
    webAppFqdn: webAppFqdn
    keyVaultSecretid: keyVaultSecretid
    sslCertificateName: sslCertificateName
    managedIdentityName: managedIdentityName
    hostnames: hostnames
    port: port
    tier: tier
    sku: sku
    capacity: capacity
    autoScaleMaxCapacity: autoScaleMaxCapacity
    privateIPAllocationMethod: privateIPAllocationMethod
    protocol: protocol
    cookieBasedAffinity: cookieBasedAffinity
    pickHostNameFromBackendAddress: pickHostNameFromBackendAddress
    requestTimeout: requestTimeout
    requireServerNameIndication: requireServerNameIndication
    publicIpAddressName: publicIpAddressName
    publicIpSku: publicIpSku
    publicIPAllocationMethod: publicIPAllocationMethod
    http2Enabled: http2Enabled
    requestRoutingRuleType: requestRoutingRuleType
    webApplicationFirewall: webApplicationFirewall
  }
  dependsOn: [
    rg
    names
    virtualnetwork
    subnet
    nsg
    peeringToHub
    appgwSubnet
    keyvault
    msi
  ]
}
