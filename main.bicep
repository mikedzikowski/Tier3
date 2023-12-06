targetScope = 'subscription'

// REQUIRED PARAMETERS
@description('Required. Available Ip Address for Application Gateway.')
param applicationGatewayPrivateIp string

@description('Required. Subscription GUID.')
param spokeSubscriptionId string

param guidValue string = newGuid()

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
param vNetAddressPrefixes string

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

// @description('Capacity (instance count) of application gateway')
// @minValue(1)
// @maxValue(32)
// param capacity int = 1

param applicationGatewaySslCertificateFilename string

// APPLICATION SERVICE ENVIRONMENT

@allowed([
  'development'
  'test'
  'staging'
  'production'
])
param env string

// FUNCTION or GOAL OF ENVIRONMENT

param function string

// STARTING INDEX NUMBER

param index int

// APP NAME

param appName string

@description('The certificate password value.')
@secure()
param applicationGatewaySslCertificatePassword string

@description('Hub storage account where certificate artifacts are uploaded.')
param hubStorageAccountName string

@description('Hub storage account container where certificate artifacts are uploaded.')
param hubStorageAccountContainerName string

@description('The address prefix of the gateway subnet.')
param gatewaySubnetAddressPrefix string

@description('The azure firewall policy name')
param azureFirewallPolicyName string

var localAdministratorPassword = '${toUpper(uniqueString(subscription().id))}-${guidValue}'

// RESOURCE NAME CONVENTIONS WITH ABBREVIATIONS
var appGwSubnetNamingConvention = replace(names.outputs.resourceName, '[PH]', 'appgw-snet')
var applicationGatewayNamingConvention = replace(names.outputs.resourceName, '[PH]', 'gw')
var appNamingConvention = replace(names.outputs.resourceName, '[PH]', 'web')
var appServicePlanNamingConvention = replace(names.outputs.resourceName, '[PH]', 'app-sp')
var aseNamingConvention = replace(names.outputs.resourceName, '[PH]', 'ase')
var aseSubnetNamingConvention = replace(names.outputs.resourceName, '[PH]', 'ase-snet')
var gwUdrAddressNamingConvention = replace(names.outputs.resourceName, '[PH]', 'udr-gw')
var hubUdrAddressNamingConvention = replace(names.outputs.resourceName, '[PH]', 'udr-hub-gw')
var managedIdentityNamingConvention = replace(names.outputs.resourceName, '[PH]', 'mi')
var managementVirtualMachineName = replace(names.outputs.virtualMachineName, '[PH]', 'vm')
var mgmtSubnetNamingConvention = replace(names.outputs.resourceName, '[PH]', 'mgmtvm-snet')
var networkSecurityGroupNamingConvention = replace(names.outputs.resourceName, '[PH]', 'nsg')
var privateDNSZoneNamingConvention = appServiceEnvironment.outputs.dnssuffix
var publicIpAddressNamingConvention = replace(names.outputs.resourceName, '[PH]', 'pip')
var virtualNetworkNamingConvention = replace(names.outputs.resourceName, '[PH]', 'vnet')
var webAppFqdnNamingConvention = replace(names.outputs.resourceName, '[PH]', 'web')

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

var hubRoutes = [
  {
    name: 'gatewayRoute'
    addressPrefix: appGwSubnetAddressPrefix
    hasBgpOverride: false
    nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
    nextHopType: 'VirtualAppliance'
  }
]

var spokeRoutes = [
  {
    name: 'appGwRoute'
    addressPrefix: appGwSubnetAddressPrefix
    hasBgpOverride: false
    nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
    nextHopType: 'VirtualAppliance'
  }
  {
    name: 'aseRoute'
    addressPrefix: aseSubnetAddressPrefix
    hasBgpOverride: false
    nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
    nextHopType: 'VirtualAppliance'
  }
]

// Application Service Environment Variables | https://learn.microsoft.com/en-us/azure/templates/microsoft.network/applicationgateways?pivots=deployment-language-bicep#property-values
@description('ASE Kind')
var aseKind = 'ASEV3'

@description('ASE Load Balancer Mode')
var aseLbMode = 'Web, Publishing'

// Application Gateway Variables | https://learn.microsoft.com/en-us/azure/templates/microsoft.network/applicationgateways?pivots=deployment-language-bicep#property-values 
@description('Required. Route Table. Select to true, to prevent the propagation of on-premises routes to the network interfaces in associated subnets')
var disableBgpRoutePropagation = true

@description('Integer containing port number')
var port = 443

@description('Private IP Allocation Method')
var privateIPAllocationMethod = 'Static'

@description('Backend http setting protocol')
var protocol = 'Https'

@description('Enabled/Disabled. Configures cookie based affinity.')
var cookieBasedAffinity = 'Disabled'

@description('Hostnames for DNS')
var hostnames = [ '*.${dnsZoneName}' ]

@description('Pick Hostname From BackEndAddress Setting')
var pickHostNameFromBackendAddress = true

@description('Integer containing backend http setting request timeout')
var requestTimeout = 20

@description('Enabled/Disabled. Configures server name indication (SNI) on application gateway.')
var requireServerNameIndication = true

@description('Public IP Sku')
var publicIpSku = 'Standard'

@description('Public IP Applocation Method.')
var publicIPAllocationMethod = 'Static'

@description('local admin used on the management virtual machnine.')
var localAdministratorName = 'xadmin'

@description('Protocol used for routing traffic to backends.')
var requestRoutingRuleType = 'Basic'

@description('Sku of an application gateway.')
var sku = 'Standard_v2'

@description('Tier of an application gateway.')
var tier = 'Standard_v2'

@description('The certificate name.')
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
    virtualNetworkId: spokeVirtualNetwork.outputs.vNetId
  }
  dependsOn: [
    rg
  ]
}

module gatewaySubnet 'modules/gatewaySubnet.bicep' = {
  name: 'gateway-subnet-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  params: {
    gatewaySubnetAddressPrefix: gatewaySubnetAddressPrefix
    gatewaySubnetName:'GatewaySubnet'
    gatewayUserDefinedRouteTableName: hubUdrAddressNamingConvention
    hubVnetName: hubVirtualNetwork.name
  }
  dependsOn: [
    rg
    names
    networkSecurityGroup
    hubDefinedRoutes
  ]
}

module managementVirtualMachine 'modules/managementVirtualMachine.bicep' = {
  name: 'mgmt-vm-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    applicationGatewaySslCertificateFilename: applicationGatewaySslCertificateFilename
    applicationGatewaySslCertificateName: applicationGatewaySslCertificateName
    applicationGatewaySslCertificatePassword: applicationGatewaySslCertificatePassword
    firewallPolicyName: azureFirewallPolicyName
    hubResourceGroup: hubResourceGroup
    hubStorageAccountContainerName: hubStorageAccountContainerName
    hubStorageAccountName: storageAccount.name
    keyVaultName: keyVault.outputs.keyVaultName
    localAdministratorPassword: localAdministratorPassword
    localAdministratorUsername: localAdministratorName
    location: location
    subnetName: mgmtSubnetNamingConvention
    userAssignedIdentityClientId: userAssignedManagedIdentity.outputs.uamiClienId
    userAssignedIdentityId: userAssignedManagedIdentity.outputs.uamiId
    userAssignedIdentityPrincipalId: userAssignedManagedIdentity.outputs.uamiPrincipalId
    virtualMachineName: managementVirtualMachineName
    virtualNetworkName: virtualNetworkNamingConvention
    vNetAddressPrefixes: vNetAddressPrefixes
  }
  dependsOn: [
    rg
    spokeVirtualNetwork
    roleAssignmentAzureFirewall
    roleAssignmentKeyVault
    roleAssignmentStorageAccount
  ]
}

module userDefinedRoutes 'modules/userDefinedRoute.bicep' = {
  name: 'udr-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    routes: spokeRoutes
    disableBgpRoutePropagation: disableBgpRoutePropagation
    location: location
    udrName: gwUdrAddressNamingConvention
  }
  dependsOn: [
    rg
  ]
}

module hubDefinedRoutes 'modules/userDefinedRoute.bicep' = {
  name: 'hub-udr-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  params: {
    routes: hubRoutes
    disableBgpRoutePropagation: disableBgpRoutePropagation
    location: location
    udrName: hubUdrAddressNamingConvention
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
  dependsOn: [
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

module webApp 'modules/webAppOnHostingEnvironment.bicep' = {
  name: 'web-app-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    appName: appNamingConvention
    aseName: appServiceEnvironment.outputs.hostingEnvironmentName
    hostingPlanName: appServicePlan.outputs.appServicePlanName
    location: location
    managedIdentityName: userAssignedManagedIdentity.outputs.uamiName
    principalId: userAssignedManagedIdentity.outputs.uamiPrincipalId
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

module roleAssignmentAzureFirewall 'modules/roleAssignmentAzureFirewall.bicep' = {
  name: 'rbac-fw-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  params: {
    azureFirewallPolicyName: azureFirewallPolicyName
    azureFirewallResourceId: azureFirewall.id
    principalId: userAssignedManagedIdentity.outputs.uamiPrincipalId
  }
}

module applicationGateway 'modules/applicationGateway.bicep' = {
  name: 'applicationGateway-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    applicationGatewayName: applicationGatewayNamingConvention
    applicationGatewayPrivateIp: applicationGatewayPrivateIp
    applicationGatewaySslCertificateName: applicationGatewaySslCertificateName
    cookieBasedAffinity: cookieBasedAffinity
    hostnames: hostnames
    keyVaultName: keyVault.outputs.keyVaultName
    location: location
    managedIdentityName: userAssignedManagedIdentity.outputs.uamiName
    mgmtSubnetNamingConvention: mgmtSubnetNamingConvention
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
    tier: tier
    virtualNetworkName: spokeVirtualNetwork.outputs.name
    webAppFqdn: '${webAppFqdnNamingConvention}.${appServiceEnvironment.outputs.dnssuffix}'
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
