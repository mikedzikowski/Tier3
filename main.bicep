targetScope = 'subscription'

// REQUIRED PARAMETERS
@description('The address prefix for the application gateway subnet.')
param appGwSubnetAddressPrefix string

@description('The private IP address for the application gateway.')
param applicationGatewayPrivateIp string

@description('The filename of the SSL certificate for the application gateway.')
param applicationGatewaySslCertificateFilename string

@description('The password for the SSL certificate for the application gateway.')
@secure()
param applicationGatewaySslCertificatePassword string = ''

@description('The name of the application.')
param appName string

@description('The address prefix for the ASE subnet.')
param aseSubnetAddressPrefix string

@description('The name of the Azure Firewall.')
param azureFirewallName string

@description('The name of the Azure Firewall policy.')
param azureFirewallPolicyName string

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('The name of the DNS zone.')
param dnsZoneName string

@description('The environment.')
@allowed([
  'development'
  'test'
  'staging'
  'production'
])
param env string

@description('The function.')
param function string

@description('The address prefix for the gateway subnet.')
param gatewaySubnetAddressPrefix string

@description('The GUID value.')
param guidValue string = newGuid()

@description('The resource group for the hub.')
param hubResourceGroup string

@description('The container name for the hub storage account.')
param hubStorageAccountContainerName string

@description('The name of the hub storage account.')
param hubStorageAccountName string

@description('The subscription ID for the hub.')
param hubSubscriptionId string

@description('The name of the hub virtual network.')
param hubVirtualNetworkName string

@description('The index.')
param index int

@description('The location.')
param location string = deployment().location

@description('The address prefix for the management virtual machine subnet.')
param managementVirtualMachineSubnetAddressPrefix string

// @description('The resource group for the spoke.')
// param spokeResourceGroup string

@description('The subscription ID for the spoke.')
param spokeSubscriptionId string

@description('The address prefixes for the virtual network.')
param vNetAddressPrefixes string

var localAdministratorPassword = '${toUpper(uniqueString(subscription().id))}-${guidValue}'

// RESOURCE NAME CONVENTIONS WITH ABBREVIATIONS
var environmentLetter = substring(env,0,1)
var spokeResourceGroup = 'rg-${function}-${appName}-${environmentLetter}-${padLeft(index,2,'0')}'
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
    addressPrefix: vNetAddressPrefixes
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

module roleAssignmentManagementVirtualMachine 'modules/roleAssignmentVirtualMachine.bicep' = {
  name: 'rbac-vm-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
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

module removeVirtualMachine  'modules/removeVirtualMachine.bicep' = {
  name: 'remove-vm-${deploymentNameSuffix}'
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroup)
  params: {
    location: location
    userAssignedIdentityClientId: userAssignedManagedIdentity.outputs.uamiClienId
    virtualMachineName: managementVirtualMachineName
  }
  dependsOn: [
    applicationGateway
    roleAssignmentManagementVirtualMachine
  ]
}
