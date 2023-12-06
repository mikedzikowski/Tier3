param applicationGatewayName string
param applicationGatewaySslCertificateName string
param applicationGatewayPrivateIp string
param cookieBasedAffinity string
param hostnames array = []
param keyVaultName string
param location string
param managedIdentityName string
param mgmtSubnetNamingConvention string 
param pickHostNameFromBackendAddress bool
param port int
param privateIPAllocationMethod string
param protocol string
param publicIpAddressName string
param publicIPAllocationMethod string
param publicIpSku string
param requestRoutingRuleType string
param requestTimeout int
param requireServerNameIndication bool
param resourceGroup string
param skuName string
param subnetName string
param tier string
param virtualNetworkName string
param webAppFqdn string

var frontendIPConfigurationName = applicationGatewayName
var frontendPortName = 'port_${port}'
var httpslistenerName = '${applicationGatewayName}-https-listener'
var backendAddressPoolName = '${applicationGatewayName}-backend-pool'
var backendHttpSettingsName = '${applicationGatewayName}-https-setting'
var gatewayIPConfigurationsName = '${applicationGatewayName}-gatewayIpConfig'
var requestRoutingRulesName = '${applicationGatewayName}-https-routingrule'
var keyVaultSecretId = 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/secrets/${applicationGatewaySslCertificateName}'

resource virtualnetwork 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: virtualNetworkName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  parent: virtualnetwork
  name: subnetName
}

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: applicationGatewayName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedManagedIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: skuName
      tier: tier
    }
    gatewayIPConfigurations: [
      {
        name: gatewayIPConfigurationsName
        properties: {
          subnet: {
            id: resourceId(resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnet.name)
          }
        }
      }
    ]
    sslCertificates: [
      {
        name: applicationGatewaySslCertificateName
        properties: {
          keyVaultSecretId: keyVaultSecretId
        }
      }
    ]
    trustedRootCertificates: [
      {
        name: 'testcer'
        id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/trustedRootCertificates', applicationGatewayName, 'testcer')
        properties: {
          keyVaultSecretId: keyVaultSecretId
        }
      }
    ]
    trustedClientCertificates: []
    sslProfiles: []
    frontendIPConfigurations: [
      {
        name: '${frontendIPConfigurationName}-pubIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
      {
        name: '${frontendIPConfigurationName}-privIp'
        id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'fename')
        properties: {
          privateIPAddress: applicationGatewayPrivateIp
          privateIPAllocationMethod: privateIPAllocationMethod
          subnet: {
            id: resourceId(resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnet.name)
          }
          privateLinkConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/privateLinkConfigurations', applicationGatewayName, 'pl')
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendAddressPoolName
        properties: {
          backendAddresses: [
            {
              fqdn: webAppFqdn
            }
          ]
        }
      }
    ]
    loadDistributionPolicies: []
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingsName
        properties: {
          port: port
          protocol: protocol
          cookieBasedAffinity: cookieBasedAffinity
          pickHostNameFromBackendAddress: pickHostNameFromBackendAddress
          requestTimeout: requestTimeout
        }
      }
    ]
    backendSettingsCollection: []
    httpListeners: [
      {
        name: httpslistenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, '${frontendIPConfigurationName}-privIp')
          }
          frontendPort: {
            id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, frontendPortName)
          }
          protocol: protocol
          sslCertificate: {
            id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/sslCertificates', applicationGatewayName, applicationGatewaySslCertificateName)
          }
          hostNames: hostnames
          requireServerNameIndication: requireServerNameIndication
        }
      }
    ]
    listeners: []
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: requestRoutingRulesName
        properties: {
          ruleType: requestRoutingRuleType
          priority: 1
          httpListener: {
            id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, httpslistenerName)
          }
          backendAddressPool: {
            id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, backendAddressPoolName)
          }
          backendHttpSettings: {
            id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, backendHttpSettingsName)
          }
        }
      }
    ]
    routingRules: []
    probes: []
    rewriteRuleSets: []
    redirectConfigurations: []
    privateLinkConfigurations: [
      {
        name: 'pl'
        id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/privateLinkConfigurations', applicationGatewayName, 'pl')
        properties: {
          ipConfigurations: [
            {
              name: 'privateLinkIpConfig1'
              id: resourceId(resourceGroup, 'Microsoft.Network/applicationGateways/privateLinkConfigurations/ipConfigurations', applicationGatewayName, 'pl', 'privateLinkIpConfig1')
              properties: {
                privateIPAllocationMethod: 'Dynamic'
                primary: false
                subnet: {
                  id: resourceId(resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, mgmtSubnetNamingConvention)
                }
              }
            }
          ]
        }
      }
    ]
    enableHttp2: true
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: 'pe'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pl'
        properties: {
          privateLinkServiceId: applicationGateway.id
          groupIds: [
            '${applicationGatewayName}-privIp'
          ]
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: resourceId(resourceGroup, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, mgmtSubnetNamingConvention)
    }
  }
}

