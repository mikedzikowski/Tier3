targetScope = 'subscription'

// REQUIRED PARAMETERS

@description('Required. Subscription GUID.')
param subscriptionId string = 'f4972a61-1083-4904-a4e2-a790107320bf'

@description('Required. ResourceGroup location.')
param location string = 'usgovvirginia'

@description('Required. ResourceGroup Name.')
param targetResourceGroup string = 'rg-app-gateway-example'

@description('Required. Creating UTC for deployments.')
param deploymentNameSuffix string = utcNow()

// NAMING CONVENTION RULES
/*
  These parameters are for the naming convention 

  environment // FUNCTION or GOAL OF ENVIRONMENT
  function // FUNCTION or GOAL OF ENVIRONMENT
  index // STARTING INDEX NUMBER
  appName // APP NAME 

  EXAMPLE RESULT: tier3-t-environment-vnet-01 // tier3{appName}, t[environment], environment{function}, VNET{abbreviation}, 01{index} 
  
*/

// ENVIRONMENT 

@allowed([
  'development'
  'test'
  'staging'
  'production'
])
param environment string = 'development'

// FUNCTION or GOAL OF ENVIRONMENT

param function string = 'env'

// STARTING INDEX NUMBER

param index int = 1

// APP NAME 

param appName string = 'tier3'


// Certificate
/*

  After the initial build, import the required certificates to your keyvault. 
  Once the certificate is imported:
  Set buildAppGateway value to true and buildKeyVault to false
  Deploy main.bicep

*/

var managedIdentityNamingConvention = replace(names.outputs.resourceName, '[PH]', 'mi')
var keyVaultNamingConvention= replace(names.outputs.resourceName, '[PH]', 'kv')

module rg 'modules/resourceGroup.bicep' = {
  name: 'resourceGroup-deployment-${deploymentNameSuffix}'
  scope: subscription(subscriptionId)
  params: {
    name: targetResourceGroup
    location: location
    tags: {}
  }
}

module names 'modules/namingConvention.bicep' = {
  name: 'naming-convention-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, targetResourceGroup)
  params: {
    environment: environment
    function: function
    index: index
    appName: appName
  }
  dependsOn: [
    rg
  ]
}

module msi 'modules/managedIdentity.bicep' = {
  name: 'managed-identity-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, targetResourceGroup)
  params: {
    managedIdentityName:managedIdentityNamingConvention
    location: location
  }
}

module keyvault 'modules/keyVault.bicep' = {
  name: 'keyvault-deployment-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, targetResourceGroup)
  params: {
    keyVaultName: keyVaultNamingConvention
    objectId: msi.outputs.msiPrincipalId
  }
  dependsOn: [
    rg
    names
    msi
  ]
}
