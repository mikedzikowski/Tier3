param udrName string
param location string
param disableBgpRoutePropagation bool
param appGwSubnetAddressPrefix string
param aseSubnetAddressPrefix string
param azureFirewallIpAddress string

var routes = [
  {
    name: 'appGwRoute'
    addressPrefix: appGwSubnetAddressPrefix
    hasBgpOverride: false
    nextHopIpAddress: azureFirewallIpAddress
    nextHopType: 'VirtualAppliance'
  }
  {
    name: 'aseRoute'
    addressPrefix: aseSubnetAddressPrefix
    hasBgpOverride: false
    nextHopIpAddress: azureFirewallIpAddress
    nextHopType: 'VirtualAppliance'
  }
]

resource routeTable 'Microsoft.Network/routeTables@2021-05-01' = {
  name: udrName
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
  dependsOn: []
}

output name string = routeTable.name
output id string = routeTable.id
