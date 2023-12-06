param principalId string
param azureFirewallResourceId string
param azureFirewallPolicyName string

var roleDefinitionIds = [
  'b24988ac-6180-42a0-ab88-20f7382dd24c'

] // Contributor | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor

resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' existing = {
  name: split(azureFirewallResourceId, '/')[8]
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' existing = {
  name: azureFirewallPolicyName
}

resource roleAssignmentFirewall 'Microsoft.Authorization/roleAssignments@2022-04-01' =  [for roleDefinitionId in roleDefinitionIds: {
  scope: firewall
  name: guid(principalId, roleDefinitionId, firewall.id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]

resource roleAssignmentFirewallPolicy 'Microsoft.Authorization/roleAssignments@2022-04-01' =  [for roleDefinitionId in roleDefinitionIds: {
  scope: firewallPolicy
  name: guid(principalId, roleDefinitionId, firewallPolicy.id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
