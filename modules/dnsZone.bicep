param dnsZoneName string
param location string
param appName string
param publicIpAddress string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: dnsZoneName
  location: location
  properties:{
    zoneType: 'Public'
  }
}

resource dnsARecord 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  name: appName
  parent: dnsZone
  properties: {
    TTL: 3600
    ARecords: [
      {
        ipv4Address: publicIpAddress
      }
    ]
  }
}
