param udrName string
param location string
param disableBgpRoutePropagation bool
param routes array = []

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
}
output name string = routeTable.name
output id string = routeTable.id
