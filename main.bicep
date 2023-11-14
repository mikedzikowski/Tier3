targetScope = 'subscription'

// REQUIRED PARAMETERS

@description('Required. Subscription GUID.')
param spokeSubscriptionId string

@description('Required. Subscription GUID.')
param hubSubscriptionId string

@description('Required. ResourceGroup location.')
param location string = deployment().location

@description('Required. Azure Firewall Name.')
param azureFirewallName string

@description('Required. ResourceGroup Name.')
param hubResourceGroup string

@description('Required. ResourceGroup Name.')
param spokeResourceGroup string

@description('Required. Creating UTC for deployments.')
param deploymentNameSuffix string = utcNow()

@description('Required. An Array of 1 or more IP Address Prefixes for the Virtual Network.')
param vNetAddressPrefixes array

@description('Required. The Address Prefix of ASE.')
param aseSubnetAddressPrefix string

@description('Required. The Address Prefix of AppGw.')
param appGwSubnetAddressPrefix string

@description('Required. The Address Prefix of AppGw.')
param managementVirtualMachineSubnetAddressPrefix string

// If peering update this value
@description('Required. Exisisting Virtual Network Name for Peering.')
param hubVirtualNetworkName string

// DNS Zone Parameters
@description('Optional:Global DNS Zone Name')
param dnsZoneName string

// APPLICATION GATEWAY PARAMETERS

@description('Capacity (instance count) of application gateway')
@minValue(1)
@maxValue(32)
param capacity int = 2

@description('Autoscale capacity (instance count) of application gateway')
@minValue(1)
@maxValue(32)
param autoScaleMaxCapacity int = 10

param applicationGatewaySslCertificateFilename string

// APPLICATION SERVICE ENVIRONMENT

@allowed([
  'development'
  'test'
  'staging'
  'production'
])
param env string = 'development'

// FUNCTION or GOAL OF ENVIRONMENT

param function string = 'app'

// STARTING INDEX NUMBER

param index int = 8

// APP NAME

param appName string = 'tier3'

@description('The certificate password value.')
@secure()
param applicationGatewaySslCertificatePassword string

@description('The local administrator password of the management virtual machine.')
@secure()
param localAdministratorPassword string

@description('Hub storage account where certificate artifacts are uploaded.')
param hubStorageAccountName string

@description('Hub storage account container where certificate artifacts are uploaded.')
param hubStorageAccountContainerName string

// RESOURCE NAME CONVENTIONS WITH ABBREVIATIONS
var publicIpAddressNamingConvention = replace(names.outputs.resourceName, '[PH]', 'pip')
var gwUdrAddressNamingConvention = replace(names.outputs.resourceName, '[PH]', 'udr-gw')
var privateDNSZoneNamingConvention = appServiceEnvironment.outputs.dnssuffix
var virtualNetworkNamingConvention = replace(names.outputs.resourceName, '[PH]', 'vnet')
var managedIdentityNamingConvention = replace(names.outputs.resourceName, '[PH]', 'mi')
var aseSubnetNamingConvention = replace(names.outputs.resourceName, '[PH]', 'ase-snet')
var appGwSubnetNamingConvention = replace(names.outputs.resourceName, '[PH]', 'appgw-snet')
var mgmtSubnetNamingConvention = replace(names.outputs.resourceName, '[PH]', 'mgmtvm-snet')
var aseNamingConvention = replace(names.outputs.resourceName, '[PH]', 'ase')
var appServicePlanNamingConvention = replace(names.outputs.resourceName, '[PH]', 'app-sp')
var applicationGatewayNamingConvention = replace(names.outputs.resourceName, '[PH]', 'gw')
var networkSecurityGroupNamingConvention = replace(names.outputs.resourceName, '[PH]', 'nsg')
var appNamingConvention = replace(names.outputs.resourceName, '[PH]', 'web')
var webAppFqdnNamingConvention = replace(names.outputs.resourceName, '[PH]', 'web')
var managementVirtualMachineName = replace(names.outputs.virtualMachineName, '[PH]', 'vm')

// Networking Variables
var subnets = [
  {
    name: aseSubnetNamingConvention
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
  {
    name: mgmtSubnetNamingConvention
    addressPrefix: managementVirtualMachineSubnetAddressPrefix
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroupName: networkSecurityGroupNamingConvention
  }
  {
    name: appGwSubnetNamingConvention
    addressPrefix: appGwSubnetAddressPrefix
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroupName: networkSecurityGroupNamingConvention
  }
]

var networkSecurityGroupSecurityRules = [
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
  {
    name: 'Application_Gateway_Traffic'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '65200-65535'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: '101'
      direction: 'Inbound'
      sourcePortRanges: []
      destinationPortRanges: []
      sourceAddressPrefixes: []
      destinationAddressPrefixes: []
    }
  }
]

var webApplicationFirewall = {
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

// Application Service Environment Variables | https://learn.microsoft.com/en-us/azure/templates/microsoft.network/applicationgateways?pivots=deployment-language-bicep#property-values 
var http2Enabled = true

var aseKind = 'ASEV3'

var aseLbMode = 'Web, Publishing'

// Application Gateway Variables | https://learn.microsoft.com/en-us/azure/templates/microsoft.network/applicationgateways?pivots=deployment-language-bicep#property-values 
@description('Required. Route Table. Select to true, to prevent the propagation of on-premises routes to the network interfaces in associated subnets')
var disableBgpRoutePropagation = true

@description('Integer containing port number')
var port = 443

@description('Private IP Allocation Method')
var privateIPAllocationMethod = 'Dynamic'

@description('Backend http setting protocol')
var protocol = 'Https'

@description('Enabled/Disabled. Configures cookie based affinity.')
var cookieBasedAffinity = 'Disabled'

@description('Hostnames for DNS')
var hostnames = ['*.${dnsZoneName}']

@description('Pick Hostname From BackEndAddress Setting')
var pickHostNameFromBackendAddress = true

@description('Integer containing backend http setting request timeout')
var requestTimeout = 20

var requireServerNameIndication = true

@description('Public IP Sku')
var publicIpSku = 'Standard'

@description('Public IP Applocation Method.')
var publicIPAllocationMethod = 'Static'

@description('local admin used on the management virtual machnine.')
var localAdministratorName = 'xadmin'

var requestRoutingRuleType = 'Basic'

var sku = 'WAF_v2'

@description('Tier of an application gateway.')
var tier = 'WAF_v2'

var applicationGatewaySslCertificateName = 'cert${appName}'

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  name: hubVirtualNetworkName
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-05-01' existing = {
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  name: azureFirewallName
}

resource storageAccount 'Microsoft.Network/azureFirewalls@2023-05-01' existing = {
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  name: hubStorageAccountName
}

module rg 'modules/resourceGroup.bicep' = {
  name: 'resourceGroup-deployment-${deploymentNameSuffix}'
  scope: subscription(spokeSubscriptionId)
  params: {
    location: location
    name: spokeResourceGroup
    tags: {}
  }
}

module names 'modules/namingConvention.bicep' = {
  name: 'naming-convention-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    appName: appName
    deploymentNameSuffix: deploymentNameSuffix
    environment: env
    function: function
    index: index
  }
  dependsOn: [
    rg
  ]
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'keyvault-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    keyVaultName: 'kv-${uniqueString(spokeSubscriptionId, spokeResourceGroup)}'
    location: location
    skuName: 'standard'
    subnetResourceId: spokeVirtualNetwork.outputs.subnets[1].Id
    virtualNetworkId:spokeVirtualNetwork.outputs.vNetId
  }
  dependsOn: [
    rg
  ]
}

module managementVirtualMachine 'modules/managementVirtualMachine.bicep' = {
  name: 'mgmt-vm-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    applicationGatewaySslCertificateFilename: applicationGatewaySslCertificateFilename
    applicationGatewaySslCertificateName: applicationGatewaySslCertificateName
    applicationGatewaySslCertificatePassword: applicationGatewaySslCertificatePassword
    hubStorageAccountContainerName: hubStorageAccountContainerName
    keyVaultName: keyVault.outputs.keyVaultName
    localAdministratorPassword: localAdministratorPassword
    localAdministratorUsername:localAdministratorName
    location: location
    hubStorageAccountName: storageAccount.name
    subnetName: mgmtSubnetNamingConvention
    userAssignedIdentityClientId: userAssignedManagedIdentity.outputs.uamiClienId
    userAssignedIdentityId: userAssignedManagedIdentity.outputs.uamiId
    userAssignedIdentityPrincipalId: userAssignedManagedIdentity.outputs.uamiPrincipalId
    virtualMachineName: managementVirtualMachineName
    virtualNetworkName: virtualNetworkNamingConvention
  }
  dependsOn: [
    rg
    spokeVirtualNetwork
  ]
}

module userDefinedRoutes 'modules/userDefinedRoute.bicep' = {
  name: 'udr-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    appGwSubnetAddressPrefix: appGwSubnetAddressPrefix
    aseSubnetAddressPrefix: aseSubnetAddressPrefix
    azureFirewallIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
    disableBgpRoutePropagation: disableBgpRoutePropagation
    location: location
    udrName: gwUdrAddressNamingConvention
  }
  dependsOn: [
    rg
  ]
}

module userAssignedManagedIdentity 'modules/managedIdentity.bicep' = {
  name: 'uami-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    location: location
    managedIdentityName: managedIdentityNamingConvention
  }
  dependsOn:[
    rg
    names
  ]
}

module networkSecurityGroup 'modules/networkSecurityGroup.bicep' = {
  name: 'networkSecurityGroup-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    location: location
    networkSecurityGroupName: networkSecurityGroupNamingConvention
    networkSecurityGroupSecurityRules: networkSecurityGroupSecurityRules
  }
  dependsOn: [
    rg
    names
  ]
}

module spokeVirtualNetwork 'modules/virtualNetwork.bicep' = {
  name: 'spoke-vnet-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    location: location
    subnets: subnets
    udrName: userDefinedRoutes.outputs.name
    virtualNetworkName: virtualNetworkNamingConvention
    vNetAddressPrefixes: vNetAddressPrefixes
  }
  dependsOn: [
    rg
    names
    networkSecurityGroup
  ]
}

module appServiceEnvironment 'modules/appServiceEnvironment.bicep' = {
  name: 'ase-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    aseLbMode: aseLbMode
    aseName: aseNamingConvention
    aseSubnetName: aseSubnetNamingConvention
    aseVnetId: spokeVirtualNetwork.outputs.vNetId
    kind: aseKind
    location: location
  }
  dependsOn: [
    rg
    names
    networkSecurityGroup
    managementVirtualMachine
    keyVault
  ]
}

module appServicePlan 'modules/appServicePlan.bicep' = {
  name: 'app-serviceplan-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    appServicePlanName: appServicePlanNamingConvention
    hostingEnvironmentId: appServiceEnvironment.outputs.hostingid
    location: location
  }
  dependsOn: [
    rg
    names
    networkSecurityGroup
  ]
}

module privateDnsZone 'modules/privateDnsZone.bicep' = {
  name: 'private-dns-zone-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    aseName: aseNamingConvention
    privateDNSZoneName: privateDNSZoneNamingConvention
    virtualNetworkId: spokeVirtualNetwork.outputs.vNetId
  }
  dependsOn: [
    rg
    names
  ]
}

module web 'modules/webAppOnHostingEnvironment.bicep' = {
  name: 'web-app-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    appName: appNamingConvention
    aseName: appServiceEnvironment.outputs.hostingEnvironmentName
    hostingPlanName: appServicePlan.outputs.appServicePlanName
    location: location
    managedIdentityName: userAssignedManagedIdentity.outputs.uamiName
  }
  dependsOn: [
    rg
    names
    networkSecurityGroup
  ]
}

module virtualNetworkPeeringToHub 'modules/virtualNetworkPeering.bicep' = {
  name: 'hub-peering-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    existingLocalVirtualNetworkName: spokeVirtualNetwork.outputs.name
    existingRemoteVirtualNetworkName: hubVirtualNetwork.name
    existingRemoteVirtualNetworkResourceGroupName: hubResourceGroup
  }

  dependsOn: [
    rg
    names
  ]
}

module virtualNetworkPeeringToSpoke 'modules/virtualNetworkPeering.bicep' = {
  name: 'spoke-peering-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  params: {
    existingLocalVirtualNetworkName: hubVirtualNetwork.name
    existingRemoteVirtualNetworkName: spokeVirtualNetwork.outputs.name
    existingRemoteVirtualNetworkResourceGroupName: spokeResourceGroup
  }
  dependsOn: [
    names
    networkSecurityGroup
    rg
    virtualNetworkPeeringToHub
  ]
}

module roleAssignmentStorageAccount 'modules/roleAssignmentStorageAccount.bicep' = {
  name: 'rbac-sa-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, hubResourceGroup)
  params: {
    principalId: userAssignedManagedIdentity.outputs.uamiPrincipalId
    storageAccountResourceId: storageAccount.id
  }
}

module roleAssignmentKeyVault 'modules/roleAssignmentKeyVault.bicep' = {
  name: 'rbac-kv-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    principalId: userAssignedManagedIdentity.outputs.uamiPrincipalId
    keyVaultResourceId: keyVault.outputs.keyVaultResourceId
  }
}

module applicationGateway 'modules/applicationGateway.bicep' = {
  name: 'applicationGateway-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    applicationGatewayName: applicationGatewayNamingConvention
    applicationGatewaySslCertificateName: applicationGatewaySslCertificateName
    autoScaleMaxCapacity: autoScaleMaxCapacity
    capacity: capacity
    cookieBasedAffinity: cookieBasedAffinity
    hostnames: hostnames
    http2Enabled: http2Enabled
    keyVaultName: keyVault.outputs.keyVaultName
    location: location
    managedIdentityName: userAssignedManagedIdentity.outputs.uamiName
    pickHostNameFromBackendAddress: pickHostNameFromBackendAddress
    port: port
    privateIPAllocationMethod: privateIPAllocationMethod
    protocol: protocol
    publicIpAddressName: publicIpAddressNamingConvention
    publicIPAllocationMethod: publicIPAllocationMethod
    publicIpSku: publicIpSku
    requestRoutingRuleType: requestRoutingRuleType
    requestTimeout: requestTimeout
    requireServerNameIndication: requireServerNameIndication
    resourceGroup: spokeResourceGroup
    skuName: sku
    subnetName: appGwSubnetNamingConvention
    subscriptionId: spokeSubscriptionId
    tier: tier
    virtualNetworkName: spokeVirtualNetwork.outputs.name
    webAppFqdn: '${webAppFqdnNamingConvention}.${appServiceEnvironment.outputs.dnssuffix}'
    webApplicationFirewall: webApplicationFirewall
  }
  dependsOn: [
    managementVirtualMachine
    names
    networkSecurityGroup
    privateDnsZone
    rg
    virtualNetworkPeeringToHub
  ]
}

module dnsZone 'modules/dnsZone.bicep' = {
  name: 'dnsZone-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    appName: appNamingConvention
    dnsZoneName: dnsZoneName
    location: 'Global'
    publicIpAddress: applicationGateway.outputs.publicIpAddress
  }
  dependsOn: [
    appServiceEnvironment
    networkSecurityGroup
    privateDnsZone
    spokeVirtualNetwork
  ]
}
