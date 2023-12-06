@description('Name of the VNET to add a subnet to')
param hubVnetName string

@description('Name of the subnet to add')
param gatewaySubnetName string

@description('Address space of the subnet to add')
param gatewaySubnetAddressPrefix string

@description('Name of the existing UDR to associate with the subnet')
param gatewayUserDefinedRouteTableName string

resource userDefinedRoute 'Microsoft.Network/routeTables@2021-05-01' existing = {
  name: gatewayUserDefinedRouteTableName
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' = {
  name: '${hubVnetName}/${gatewaySubnetName}'
  properties: {
    addressPrefix: gatewaySubnetAddressPrefix
    routeTable: {
      id: userDefinedRoute.id
    }
  }
}

output gatewaySubnetId string = gatewaySubnet.id

