param vNetAddressPrefixes array
param location string = resourceGroup().location
param virtualNetworkName string
param subnets array
param udrName string

resource userDefinedRoute 'Microsoft.Network/routeTables@2021-05-01' existing = {
  name: udrName
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vNetAddressPrefixes
    }
    subnets: [for item in subnets: {
      name: item.name
      properties: {
        addressPrefix: item.addressPrefix
        networkSecurityGroup: (empty(item.networkSecurityGroupName) ? null : json('{"id": "${resourceId('Microsoft.Network/networkSecurityGroups', item.networkSecurityGroupName)}"}'))
        delegations: item.delegations
        routeTable: {
          id: userDefinedRoute.id
        }
      }
    }]
  }
}

output name string = virtualNetwork.name
output vNetId string = virtualNetwork.id
output subnets array = virtualNetwork.properties.subnets
