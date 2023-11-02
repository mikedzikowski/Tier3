param aseLbMode string
param aseName string
param aseSubnetName string
param aseVnetId string
param kind string
param location string = resourceGroup().location

var subnetId  = '${aseVnetId}/Subnets/${aseSubnetName}'

resource ase 'Microsoft.Web/hostingEnvironments@2021-01-01' = {
  name: aseName
  location: location
  kind: kind
  properties: {
    internalLoadBalancingMode: aseLbMode
    virtualNetwork: {
      id: subnetId
    }
  }
}

output dnssuffix string = ase.properties.dnsSuffix
output hostingid string = ase.id
output hostingEnvironmentName string = ase.name
