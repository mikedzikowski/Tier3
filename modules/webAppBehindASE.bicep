param location string = resourceGroup().location
param managedIdentityName string
param aseName string
param hostingPlanName string
param hostingPlanID string = resourceId('Microsoft.Web/serverfarms/', hostingPlanName)
param hostingEnvironmentProfile string = resourceId('Microsoft.Web/hostingEnvironments/', aseName)
param httpsEnable bool = true
param appName string 

resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30'existing = {
  name: managedIdentityName
}

resource webSite 'Microsoft.Web/sites@2020-12-01' = {
  name: appName
  location: location
  tags: {
    'hidden-related:${hostingPlanID}': 'empty'
    displayName: 'Website'
  }
  properties: {
    serverFarmId: hostingPlanID
    hostingEnvironmentProfile: hostingEnvironmentProfile
    httpsOnly: httpsEnable
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${msi.id}': {}
    }
  }
}

resource roleassignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: webSite
  name: guid(msi.id, resourceGroup().id, 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: msi.properties.principalId
  }
}

