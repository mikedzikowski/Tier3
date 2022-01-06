
param location string  = resourceGroup().location
param aseLbMode int = 3
param aseName string
param aseSubnetName string 
param aseVnetId string
param aseKind string

var subnetId  = '${aseVnetId}/Subnets/${aseSubnetName}'
resource asev3 'Microsoft.Web/hostingEnvironments@2021-01-01' = {  
  name: aseName
  location: location
  kind: aseKind
  properties: {
    // dnsSuffix: '${aseName}.appserviceenvironment.us'
    internalLoadBalancingMode: aseLbMode
    virtualNetwork: {
      id: subnetId
    }
  }
}
output dnssuffix string = asev3.properties.dnsSuffix
output hostingid string = asev3.id
