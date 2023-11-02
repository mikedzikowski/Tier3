param location string
param managedIdentityName string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

output uamiId string = uami.id
output uamiName string = uami.name
output uamiPrincipalId string = uami.properties.principalId
output uamiClienId string = uami.properties.clientId
output uamiTenantId string = uami.properties.tenantId
