param subnetName string
param subnetAddressPrefix string
param delegations array
param virtualNetworkName string
param udrName string
param location string = resourceGroup().location
param disableBgpRoutePropagation bool
param routes array = []

resource virtualnetwork 'Microsoft.Network/virtualNetworks@2020-11-01'existing = {
  name: virtualNetworkName
}

resource udr 'Microsoft.Network/routeTables@2021-05-01'existing = {
    name: udrName
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  name: subnetName
  parent: virtualnetwork
  properties:{
    addressPrefix: subnetAddressPrefix
    delegations: delegations
    routeTable:  {
      id: udr.id
      location: location
      properties: {
        disableBgpRoutePropagation: disableBgpRoutePropagation
          routes: [for route in routes: {
              name: route.name
              properties: {
                addressPrefix: route.addressPrefix
                hasBgpOverride: contains(route, 'hasBgpOverride') ? route.hasBgpOverride : null
                nextHopIpAddress: contains(route, 'nextHopIpAddress') ? route.nextHopIpAddress : null
                nextHopType: route.nextHopType
              }
            }]
        }
      }
    }
  }
