param appName string
param location string = resourceGroup().location
param hostingPlanName string
param hostingEnvironmentProfileName string
param alwaysOn bool = true
param sku string = 'IsolatedV2'
param skuCode string = 'I1V2'
param phpVersion string = 'OFF'
param netFrameworkVersion string = 'v5.0'

resource site 'Microsoft.Web/sites@2021-01-15' = {
  name: appName
  location: location
  properties: {
    siteConfig: {
      phpVersion: phpVersion
      netFrameworkVersion: netFrameworkVersion
      alwaysOn: alwaysOn
    }
    serverFarmId: hostingPlan.id
    clientAffinityEnabled: true
    hostingEnvironmentProfile: {
      id: resourceId('Microsoft.Web/hostingEnvironments', hostingEnvironmentProfileName)
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: hostingPlanName
  location: location
  sku: {
    tier: sku
    name: skuCode
  }
  properties: {
    hostingEnvironmentProfile: {
      id: resourceId('Microsoft.Web/hostingEnvironments', hostingEnvironmentProfileName)
    }
  }
}
