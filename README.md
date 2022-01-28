# Mission Owner Environment - Tier 3 Environment #

# Application Gateway Example #

This example deploys a Tier 3 environment to support an Application Service Environment (ILB), App Service, and Application Gateway Integration.

Read on to understand what this example does, and when you're ready, collect all of the pre-requisites, then deploy the example.

# What this example does #

The docs on Integrate your ILB App Service Environment with the Azure Application Gateway: https://docs.microsoft.com/en-us/azure/app-service/environment/integrate-with-application-gateway. This sample shows how to deploy the sample environment using Azure Bicep.

![image alt text](/images/ase.png)

Example result

![image alt text](/images/result.png)

The subscription and resource group can be changed by providing the resource group name (Param: targetResourceGroup) and ensuring that the Azure context is set the proper subscription.

# Pre-requisites #

- An exisiting Mission Landing Zone deployment.
- A public DNS name that's used later to point to your application gateway.
- To use TLS/SSL encryption to the application gateway, a valid public certificate that's used to bind to your application gateway is required.
- Access policy will be created to import certificate into KeyVault.

# How to build the bicep code #

```plaintext
bicep build .\main.bicep
```

# Depoyment options using bicep #

```plaintext

Update main.bicep with required parameters. 

The solution can be deployed using only main.bicep or by building the KeyVault using keyVault.bicep, then deploying main.bicep.

1. Deploy KeyVault using keyVault.bicep 

az deployment sub create --name KeyVault --location usgovvirginia  --template-file .\keyVault.bicep

  - After the initial deployment of the key vault, import the required certificates to your keyvault. This step may require an access policy to be created. 
  - Once the certificate is imported, in main.bicep: 
  - Set buildKeyVault to false 
  - Set buildAppGateway value to true
  - Run az deployment sub create --name KeyVault --location usgovvirginia  --template-file .\main.bicep

-- 

2. Deploy Application Gateway and ASE Mission Owner Environment using a single main.bicep file

az deployment sub create --name Tier3Deployment --location usgovvirginia  --template-file .\main.bicep

/*
  If KeyVault is not deployed on first build, set buildKeyVault to true. 

  - After the initial build, import the required certificates to your keyvault. 
  - Once the certificate is imported
  - Set buildAppGateway value to true 
  - Set buildKeyVault to false and run az deployment sub create --name KeyVault --location usgovvirginia  --template-file .\main.bicep
*/

param buildKeyVault bool = true 
param buildAppGateway bool = false
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
    runs-on: windows-latest
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
```

# References #

- [Integrate your ILB App Service Environment with the Azure Application Gateway](https://docs.microsoft.com/en-us/azure/app-service/environment/integrate-with-application-gateway).

- [Tutorial: Import a certificate in Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/certificates/tutorial-import-certificate).
