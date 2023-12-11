param location string = resourceGroup().location
param userAssignedIdentityClientId string
param virtualMachineName string


resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: virtualMachineName
}

resource removeVirtualMachine 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  parent: virtualMachine
  name: 'removeVirtualMachine'
  location: location
  tags: {}
  properties: {
    treatFailureAsDeploymentFailure: true
    asyncExecution: false
    parameters: [
      {
        name: 'Environment'
        value: environment().name
      }
      {
        name: 'ManagementVmName'
        value: virtualMachine.name
      }
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
      {
        name: 'SubscriptionId'
        value: subscription().subscriptionId
      }
      {
        name: 'TenantId'
        value: tenant().tenantId
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
    ]
    source: {
      script: '''
        param(
          [string]$Environment,
          [string]$ManagementVmName,
          [string]$ResourceGroupName,
          [string]$SubscriptionId,
          [string]$TenantId,
          [string]$UserAssignedIdentityClientId
        )
        $ErrorActionPreference = 'Stop'
        Connect-AzAccount -Environment $Environment -Tenant $TenantId -Subscription $SubscriptionId -Identity -AccountId $UserAssignedIdentityClientId | Out-Null
        Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $ManagementVmName -Force
      '''
    }
  }
}
