param principalId string
param keyVaultResourceId string

var roleDefinitionIds = [
  'a4417e6f-fecd-4de8-b567-7b0420556985'
  'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
] // Key Vault Certificates Officer | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-reader

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: split(keyVaultResourceId, '/')[8]
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  [for roleDefinitionId in roleDefinitionIds: {
  scope: keyVault
  name: guid(principalId, roleDefinitionId, keyVaultResourceId)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
