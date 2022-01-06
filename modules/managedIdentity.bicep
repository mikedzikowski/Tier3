param managedIdentityName string
param location string

resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

output msiId string = msi.id
output msiName string = msi.name
output msiPrincipalId string = msi.properties.principalId
output msiClienId string = msi.properties.clientId
output msiTenantId string = msi.properties.tenantId
