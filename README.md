# Mission Owner Environment - Tier 3 Environment #

How to build the bicep code

**Example** 

```plaintext
bicep build .\bicep\main.bicep
```

How to deploy

**Example**

```plaintext
az deployment sub create --name Tier3Deployment --location usgovvirginia  --template-file .\bicep\main.bicep
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
      ResourceGroupName: rg-app-gateway-example-01
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

# Referemces #

Quickstart: Direct web traffic with Azure Application Gateway - Azure portal [Quickstart: Direct web traffic with Azure Application Gateway - Azure portal] (https://docs.microsoft.com/en-us/samples/azure-samples/application-gateway-dotnet-manage-simple-application-gateways/getting-started-on-managing-simple-application-gateways-in-c/).

Tutorial: Import a certificate in Azure Key Vault [Tutorial: Import a certificate in Azure Key Vault] (https://docs.microsoft.com/en-us/azure/key-vault/certificates/tutorial-import-certificate).
