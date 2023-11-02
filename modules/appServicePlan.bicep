param appServicePlanKind string = 'windows'
param appServicePlanName string
param appServicePlanWorkerCount int = 3
param appServicePlanWorkerSize int  = 6
param appServicePlanSku object  = {
  Name: 'I1v2'
  tier: 'IsolatedV2'
}
param hostingEnvironmentId string
param location string = resourceGroup().location

var hostingEnvironmentProfile = {
  id: hostingEnvironmentId
}

resource serverFarm 'Microsoft.Web/serverfarms@2019-08-01' = {
  kind: appServicePlanKind
  name: appServicePlanName
  location: location
  properties: {
    hostingEnvironmentProfile: hostingEnvironmentProfile
    perSiteScaling: false
    reserved: false
    targetWorkerCount: appServicePlanWorkerCount
    targetWorkerSizeId: appServicePlanWorkerSize
  }
  sku: appServicePlanSku
}

output appServicePlanName string = serverFarm.name
