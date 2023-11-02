param applicationGatewayName string
param applicationGatewaySslCertificateName string
param autoScaleMaxCapacity int
param capacity int
param cookieBasedAffinity string
param hostnames array = []
param http2Enabled bool
param keyVaultName string
param location string
param managedIdentityName string
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
param subscriptionId string
param tier string
param virtualNetworkName string
param webAppFqdn string
param webApplicationFirewall object = {}

var frontendIPConfigurationName = '${applicationGatewayName}-publicFrontendIp'
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

resource applicationGateway 'Microsoft.Network/applicationGateways@2020-11-01' = {
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
            id: subnet.id
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
    trustedRootCertificates: []
    trustedClientCertificates: []
    sslProfiles: []
    frontendIPConfigurations: [
      {
        name: frontendIPConfigurationName
        properties: {
          privateIPAllocationMethod: privateIPAllocationMethod
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortName
        properties: {
          port: port
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
    httpListeners: [
      {
        name: httpslistenerName
        properties: {
          frontendIPConfiguration: {
            id: concat('/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}/providers/Microsoft.Network/applicationGateways/${applicationGatewayName}/frontendIPConfigurations/${frontendIPConfigurationName}')
          }
          frontendPort: {
            id: concat('/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}/providers/Microsoft.Network/applicationGateways/${applicationGatewayName}/frontendPorts/${frontendPortName}')
          }
          protocol: protocol
          sslCertificate: {
            id: concat('/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}/providers/Microsoft.Network/applicationGateways/${applicationGatewayName}/sslCertificates/${applicationGatewaySslCertificateName}')
          }
          hostNames: hostnames
          requireServerNameIndication: requireServerNameIndication
        }
      }
    ]
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: requestRoutingRulesName
        properties: {
          ruleType: requestRoutingRuleType
          httpListener: {
            id: concat('/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}/providers/Microsoft.Network/applicationGateways/${applicationGatewayName}/httpListeners/${httpslistenerName}')
          }
          backendAddressPool: {
            id: concat('/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}/providers/Microsoft.Network/applicationGateways/${applicationGatewayName}/backendAddressPools/${backendAddressPoolName}')
          }
          backendHttpSettings: {
            id: concat('/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}/providers/Microsoft.Network/applicationGateways/${applicationGatewayName}/backendHttpSettingsCollection/${backendHttpSettingsName}')
          }
        }
      }
    ]
    probes: []
    rewriteRuleSets: []
    redirectConfigurations: []
    privateLinkConfigurations: []
    webApplicationFirewallConfiguration: webApplicationFirewall
    enableHttp2: http2Enabled
    autoscaleConfiguration: {
      minCapacity: capacity
      maxCapacity: autoScaleMaxCapacity
    }
  }
}

output publicIpAddress string = publicIpAddress.properties.ipAddress
