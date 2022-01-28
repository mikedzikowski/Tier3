param vNetAddressPrefixes array
param location string = resourceGroup().location
param virtualNetworkName string
param subnets array

resource virtualnetwork 'Microsoft.Network/virtualNetworks@2020-11-01' = {
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
        networkSecurityGroup: (empty(item.networkSecurityGroupName) ? json('null') : json('{"id": "${resourceId('Microsoft.Network/networkSecurityGroups', item.networkSecurityGroupName)}"}'))
        delegations: item.delegations
      }
    }]
  }
}

output name string = virtualnetwork.name
output vNetId string = virtualnetwork.id
output subnets array = virtualnetwork.properties.subnets
