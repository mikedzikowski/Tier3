targetScope = 'subscription'

/*
  PARAMETERS
  Here are all the parameters a user can override.
*/

// REQUIRED PARAMETERS

@description('Required. Subscription GUID.')
param subscriptionId string = '00000000-0000-0000-0000-000000000000'

@description('Required. ResourceGroup location.')
param location string = 'usgovvirginia'

@description('Required. ResourceGroup Name.')
param targetResourceGroup string = 'rg-app-gateway-example-01'

// VIRTUAL NETWORKING PARAMETERS
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
param existingRemoteVirtualNetworkName string = ''

// If peering update this value
@description('Required. Exisisting vNet Resource Group for Peering.')
param existingRemoteVirtualNetworkResourceGroupName string = ''

// If peering update this value 
@description('Required. Setup Peering.')
param usePeering bool = false

// Application Gateway Parameters 
param sslCertificateName string = 'cert'

// DNS Zone Parameters 
@description('DNS Zone Name')
param dnsZoneName string = 'mikedzikowski.com'

@description('Hostnames for DNS')
param hostnames array = [
  '*.${dnsZoneName}'
]

// APPLICATION GATEWAY PARAMETERS 
@description('Integer containing port number')
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

@description('Private IP Allocation Method')
param privateIPAllocationMethod string = 'Dynamic'

@description('Backend http setting protocol')
param protocol string = 'Https'

@description('Enabled/Disabled. Configures cookie based affinity.')
param cookieBasedAffinity string = 'Disabled'

@description('Pick Hostname From BackEndAddress Setting')
param pickHostNameFromBackendAddress bool = true

@description('Integer containing backend http setting request timeout')
param requestTimeout int = 20

param requireServerNameIndication bool = true

@description('Public IP Sku')
param publicIpSku string = 'Standard'

@description('Public IP Applocation Method')
param publicIPAllocationMethod string = 'Static'

@description('Enable HTTP/2 support')
param http2Enabled bool = true

@description('Request Routing Rule Type')
param requestRoutingRuleType string = 'Basic'

@description('Object containing Web Application Firewall configurations')
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

// APPLICATION SERVICE ENVIRONMENT
@description('ASE kind | ASEV3 | ASEV2')
param aseKind string = 'ASEV3'

// Build Options 
/*
  First build, set buildKeyVault to true. 

  After the initial build, import the required certificates to your keyvault. 
  Once the certificate is imported, set buildAppGateway value to true and buildKeyVault to false and run this deployment again. 

*/

param buildKeyVault bool = true 
param buildAppGateway bool = false

// NAMING CONVENTION RULES
/*
  These parameters are for the naming convention 

  environment // FUNCTION or GOAL OF ENVIRONMENT
  function // FUNCTION or GOAL OF ENVIRONMENT
  index // STARTING INDEX NUMBER
  appName // APP NAME 

  EXAMPLE RESULT: tier3-t-environment-vnet-01 // tier3{appName}, t[environment], environment{function}, VNET{abbreviation}, 01{index} 
  
*/

// ENVIRONMENT 

@allowed([
  'development'
  'test'
  'staging'
  'production'
])
param environment string = 'test'

// FUNCTION or GOAL OF ENVIRONMENT

param function string = 'env'

// STARTING INDEX NUMBER

param index int = 1

// APP NAME 

param appName string = 'tier3'

// RESOURCE NAME CONVENTIONS WITH ABBREVIATIONS

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
    name: targetResourceGroup
    location: location
    tags: {}
  }
}

module names 'Modules/NamingConvention.bicep' = {
  name: 'naming-convention-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, targetResourceGroup)
  params: {
    environment: environment
    function: function
    index: index
    appName: appName
  }
  dependsOn: [
    rg
  ]
}

module msi 'modules/managedIdentity.bicep' = {
  name: 'managed-identity-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, targetResourceGroup)
  params: {
    managedIdentityName:managedIdentityNamingConvention
    location: location
  }
}

module keyvault 'modules/keyvault.bicep' = if (buildKeyVault) {
  name: 'keyvault-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, targetResourceGroup)
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
  scope: resourceGroup(subscriptionId, targetResourceGroup)
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
  scope: resourceGroup(subscriptionId, targetResourceGroup)
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
module asev3 'modules/appserviceenvironment.bicep' = {
  name: 'ase-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, targetResourceGroup)
  params: {
    aseName: aseNamingConvention
    aseVnetId: virtualnetwork.outputs.vNetId
    aseSubnetName: aseSubnetNamingConvention
    kind: aseKind
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
  scope: resourceGroup(subscriptionId, targetResourceGroup)
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
  scope: resourceGroup(subscriptionId, targetResourceGroup)
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
  scope: resourceGroup(subscriptionId, targetResourceGroup)
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
  scope: resourceGroup(subscriptionId, targetResourceGroup)
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
    existingRemoteVirtualNetworkResourceGroupName: targetResourceGroup
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
  scope: resourceGroup(subscriptionId, targetResourceGroup)
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
  scope: resourceGroup(subscriptionId, targetResourceGroup)
  params: {
    subscriptionId: subscriptionId
    resourceGroup: targetResourceGroup
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
