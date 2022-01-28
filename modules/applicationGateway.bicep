param subscriptionId string
param location string 
param resourceGroup string
param applicationGatewayName string 
param vNetName string 
param subnetName string 
param webAppFqdn string
param keyVaultSecretid string 
param sslCertificateName string 
param managedIdentityName string 
param hostnames array = []
param port int
param tier string
param sku string 
param capacity int
param autoScaleMaxCapacity int
param privateIPAllocationMethod string
param protocol string 
param cookieBasedAffinity string 
param pickHostNameFromBackendAddress bool
param requestTimeout int
param requireServerNameIndication bool
param publicIpAddressName string
param publicIpSku string
param publicIPAllocationMethod string
param http2Enabled bool
param requestRoutingRuleType string
param webApplicationFirewall object = {}

var frontendIPConfigurationName = '${applicationGatewayName}-publicFrontendIp'
var frontendPortName = 'port_${port}'
var httpslistenerName = '${applicationGatewayName}-https-listener'
var backendAddressPoolName = '${applicationGatewayName}-backend-pool'
var backendHttpSettingsName = '${applicationGatewayName}-https-setting'
var gatewayIPConfigurationsName = '${applicationGatewayName}-gatewayIpConfig'
var requestRoutingRulesName = '${applicationGatewayName}-https-routingrule'

resource virtualnetwork 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: vNetName
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  name: '${vNetName}/${subnetName}'
}
resource webSite 'Microsoft.Web/sites@2020-12-01' existing = {
  name: webAppFqdn
}
resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
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
      '${msi.id}': {}
    }
  }
  properties: {
    sku: {
      name: sku
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
        name: sslCertificateName
        properties: {
          keyVaultSecretId: keyVaultSecretid
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
            id: concat('/subscriptions/${subscriptionId}/resourcegroups/${resourceGroup}/providers/Microsoft.Network/applicationGateways/${applicationGatewayName}/sslCertificates/${sslCertificateName}')
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
