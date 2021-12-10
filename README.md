# Mission Owner Environment - Tier 3 Environment #

How to build the bicep code

**Example** 
```plaintext
bicep build .\bicep\main.bicep
```

**Example**
```plaintext
az deployment sub create --name Tier3Deployment --location usgovvirginia  --template-file .\bicep\main.bicep
```
How to enable vNet Peering to an existing virtual network 

**Example**
```plaintext

az deployment sub create --name Tier03Deployment --location usgovvirginia --template-file .\bicep\main.bicep `

--parameters usePeering=true `
--parameters existingRemoteVirtualNetworkName=vnet-hub-usgovvirginia-001 `
--parameters existingRemoteVirtualNetworkResourceGroupName=rg-hub-network-001 `
--parameters subscriptionId=00000000-0000-0000-0000-000000000000 `
--parameters resourceGroupName=rg-aad-dev-01 `
--parameters sqlLocation=usdodeast `
--parameters sqlAdministratorLogin=xadmin `
```

# GitHub Integration #

```Yaml
name: 'AzureBicepDeploy'

on:
  push:
    branches:
    - main
  pull_request:

jobs:

  AzureBicepDeploy:
    name: 'AzureBicepDeploy'
    runs-on: ubuntu-latest
    env:
      ResourceGroupName: rg-aad-dev-01
      ResourceGroupLocation: "usgovvirginia"
    environment: production

    steps:
    - uses: actions/checkout@v2
    - uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    - name: Azure Bicep Build
      run: |
        az bicep build --file BicepFiles/main.bicep
    - name: Az CLI Create Resource Group
      uses: Azure/CLI@v1
      with:
        inlineScript: |
          #!/bin/bash
          az group create --name ${{ env.ResourceGroupName }} --location ${{ env.ResourceGroupLocation }}
    - name: Deploy Azure Bicep
      uses: Azure/arm-deploy@v1
      with:
        resourceGroupName: ${{ env.ResourceGroupName }}
        subscriptionId: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        template: ./Bicep/main.json