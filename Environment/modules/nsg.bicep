@description('Required. Array of Security Rules to deploy to the Network Security Group.')
param networkSecurityGroupSecurityRules array

@description('location')
param location string = resourceGroup().location

@description('nsgName')
param nsgName string

resource networksecuritygroup 'Microsoft.Network/networkSecurityGroups@2020-11-01' =  {
  name: nsgName
  location: location
  properties: {
    securityRules: [for item in networkSecurityGroupSecurityRules: {
      name: item.name
      properties: {
        description: item.properties.description
        access: item.properties.access
        destinationAddressPrefix: ((item.properties.destinationAddressPrefix == '') ? json('null') : item.properties.destinationAddressPrefix)
        destinationAddressPrefixes: ((length(item.properties.destinationAddressPrefixes) == 0) ? json('null') : item.properties.destinationAddressPrefixes)
        destinationPortRanges: ((length(item.properties.destinationPortRanges) == 0) ? json('null') : item.properties.destinationPortRanges)
        destinationPortRange: ((item.properties.destinationPortRange == '') ? json('null') : item.properties.destinationPortRange)
        direction: item.properties.direction
        priority: int(item.properties.priority)
        protocol: item.properties.protocol
        sourceAddressPrefix: ((item.properties.sourceAddressPrefix == '') ? json('null') : item.properties.sourceAddressPrefix)
        sourcePortRanges: ((length(item.properties.sourcePortRanges) == 0) ? json('null') : item.properties.sourcePortRanges)
        sourcePortRange: item.properties.sourcePortRange
      }
    }]
  }
}
