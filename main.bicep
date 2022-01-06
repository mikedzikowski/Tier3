targetScope = 'subscription'

/*
  PARAMETERS
  Here are all the parameters a user can override.
  These are the required parameters that Mission LZ does not provide a default for:
    - resourcePrefix
*/

// REQUIRED PARAMETERS

@description('Required. Subscription GUID.')
param subscriptionId string = 'f4972a61-1083-4904-a4e2-a790107320bf'

@description('Required. ResourceGroup location.')
param location string = 'usgovvirginia'

@description('Required. ResourceGroup Name.')
param resourceGroupName string = 'rg-app-gateway-example-01'

@description('Required. Use existing virtual network and subnet.')
param useExistingVnetandSubnet bool = false

@description('Required. Resource Group name of virtual network if using existing vnet and subnet.')
param vNetResourceGroupName string = 'rg-app-gateway-example-01'

@description('Required. An Array of 1 or more IP Address Prefixes for the Virtual Network.')
param vNetAddressPrefixes array = [
  '172.19.0.0/16'
]

@description('Required. The subnet Name of ASEv3.')
param aseSubnetAddressPrefix string = '172.19.0.0/24'

@description('Required. The subnet Name of ASEv3.')
param appGwSubnetAddressPrefix string = '172.19.1.0/24'

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

param buildKeyVault bool = true
param buildAppGateway bool = false

// RESOURCE NAME CONVENTIONS WITH ABBREVIATIONS1
var publicIpAddressNamingConvention = replace(names.outputs.resourceName, '[PH]', 'pip')
var privateDNSZoneNamingConvention = asev3.outputs.dnssuffix
var virtualNetworkNamingConvention = replace(names.outputs.resourceName, '[PH]', 'vnet')
var managedIdentityNamingConvention = replace(names.outputs.resourceName, '[PH]', 'mi')
var keyVaultNamingConvention= replace(names.outputs.resourceName, '[PH]', 'kv')
var aseSubnetNamingConvention = replace(names.outputs.resourceName, '[PH]', 'snet')
var appGwSubnetNamingConvention = replace(names.outputs.resourceName, '[PH]', 'appgw-snet')
var aseNamingConvention = replace(names.outputs.resourceName, '[PH]', 'ase')
var appServicePlanNamingConvention = replace(names.outputs.resourceName, '[PH]', 'sp')
var applicationGatewayNamingConvention = replace(names.outputs.resourceName, '[PH]', 'gw')
var networkSecurityGroupNamingConvention = replace(names.outputs.resourceName, '[PH]', 'nsg')
var appNamingConvention= replace(names.outputs.resourceName, '[PH]', 'web')
var webAppFqdnNamingConvention = '${appNamingConvention}.${aseNamingConvention}.appserviceenvironment.us'
var keyVaultSecretIdNamingConvention = 'https://${keyVaultNamingConvention}.vault.usgovcloudapi.net/secrets/${sslCertificateName}'

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
    networkSecurityGroupName: networkSecurityGroupNamingConvention
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
    function: 'environment'
    index: 1
    appName: 'tier3'
  }
  dependsOn: [
    rg
  ]
}

module msi 'modules/managedIdentity.bicep' = {
  name: 'managed-identity-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    managedIdentityName:managedIdentityNamingConvention
    location: location
  }
}

module keyvault 'modules/keyvault.bicep' = if (buildKeyVault) {
  name: 'keyvault-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    keyVaultName: keyVaultNamingConvention
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
    nsgName: networkSecurityGroupNamingConvention
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
    virtualNetworkName: virtualNetworkNamingConvention
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
    virtualNetworkName: virtualNetworkNamingConvention
    subnetName: aseSubnetNamingConvention
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
    virtualNetworkName: virtualNetworkNamingConvention
    subnetName: appGwSubnetNamingConvention
    subnetAddressPrefix: appGwSubnetAddressPrefix
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
    aseName: aseNamingConvention
    aseVnetId: virtualnetwork.outputs.vNetId
    aseSubnetName: aseSubnetNamingConvention
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
    appServicePlanName: appServicePlanNamingConvention
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
    privateDNSZoneName: privateDNSZoneNamingConvention
    virtualNetworkId: virtualnetwork.outputs.vNetId
    aseName: aseNamingConvention
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
    managedIdentityName: managedIdentityNamingConvention
    aseName: aseNamingConvention
    hostingPlanName: appServicePlanNamingConvention
    appName: appNamingConvention
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
    appName: appNamingConvention
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
    applicationGatewayName: applicationGatewayNamingConvention
    vNetName: virtualNetworkNamingConvention
    subnetName: appGwSubnetNamingConvention
    webAppFqdn: webAppFqdnNamingConvention
    keyVaultSecretid: keyVaultSecretIdNamingConvention
    sslCertificateName: sslCertificateName
    managedIdentityName: managedIdentityNamingConvention
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
    publicIpAddressName: publicIpAddressNamingConvention
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
