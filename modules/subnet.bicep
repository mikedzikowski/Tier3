param subnetName string
param subnetAddressPrefix string
param delegations array
param virtualNetworkName string
param udrName string
param location string = resourceGroup().location
param disableBgpRoutePropagation bool
param aseSubnetAddressPrefix string
param azureFirewallIpAddress string
param appGwSubnetAddressPrefix string
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

resource virtualnetwork 'Microsoft.Network/virtualNetworks@2020-11-01'existing = {
  name: virtualNetworkName
}

resource useDefinedRoute 'Microsoft.Network/routeTables@2021-05-01'existing = {
    name: udrName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  name: subnetName
  parent: virtualnetwork
  properties:{
    addressPrefix: subnetAddressPrefix
    delegations: delegations
    routeTable:  {
      id: useDefinedRoute.id
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
