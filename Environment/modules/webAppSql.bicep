@description('Specifies region for all resources')
param location string = resourceGroup().location

// hardcoding DoD East for testing
@description('Specifies region for sql resources -- using usdodeast in test')
param sqllocation string = 'usdodeast'

@description('Specifies sql admin login')
param sqlAdministratorLogin string

@description('Specifies sql admin password')
@secure()
param sqlAdministratorPassword string

@description('Specifies managed identity name')
param managedIdentityName string

param aseName string
param hostingPlanName string

@description('Specifies hid')
param hostingPlanID string = resourceId('Microsoft.Web/serverfarms/', hostingPlanName)

param hostingEnvironmentProfile string = resourceId('Microsoft.Web/hostingEnvironments/', aseName)

param httpsEnable bool = true

param databaseName string

// Data resources
resource sqlserver 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: 'sqlsrv-${databaseName}'
  location: sqllocation
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    version: '12.0'
  }

  resource database 'databases@2020-08-01-preview' = {
    name: databaseName
    location: sqllocation
    sku: {
      name: 'Basic'
    }
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
      maxSizeBytes: 1073741824
    }
  }

  resource firewallRule 'firewallRules@2020-11-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }
}

resource webSite 'Microsoft.Web/sites@2020-12-01' = {
  name: 'web-${hostingPlanName}'
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

  resource connectionString 'config@2020-12-01' = {
    name: 'connectionstrings'
    properties: {
      DefaultConnection: {
        value: 'Data Source=tcp:${sqlserver.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlserver::database.name};User Id=${sqlserver.properties.administratorLogin}@${sqlserver.properties.fullyQualifiedDomainName};Password=${sqlAdministratorPassword};'
        type: 'SQLAzure'
      }
    }
  }
}

// Managed Identity resources
resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

resource roleassignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(msi.id, resourceGroup().id, 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: msi.properties.principalId
  }
}

// Monitor
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appInsights-${webSite.name}'
  location: location
  tags: {
    'hidden-link:${webSite.id}': 'Resource'
    displayName: 'AppInsightsComponent'
  }
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

