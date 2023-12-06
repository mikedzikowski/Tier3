param applicationGatewaySslCertificateFilename string
param applicationGatewaySslCertificateName string
@secure()
param applicationGatewaySslCertificatePassword string
param firewallPolicyName string
param hubStorageAccountContainerName string
param keyVaultName string
@secure()
param localAdministratorPassword string
param localAdministratorUsername string
param location string
param hubStorageAccountName string
param hubResourceGroup string
param subnetName string
param userAssignedIdentityClientId string
param userAssignedIdentityId string
param userAssignedIdentityPrincipalId string
param virtualMachineName string
param virtualNetworkName string
param vNetAddressPrefixes string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: hubStorageAccountName
}

resource virtualnetwork 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
 name: virtualNetworkName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  parent: virtualnetwork
  name: subnetName
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: take('${virtualMachineName}-nic-${uniqueString(virtualMachineName)}', 17)
  location: location
  tags:  {}
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: false
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: location
  tags: {}
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: localAdministratorUsername
      adminPassword: localAdministratorPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-core-g2'
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadWrite'
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        osType: 'Windows'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
  }
}

resource modules 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'runCommandAppModules'
  location: location
  tags: {}
  parent: virtualMachine
  properties: {
    treatFailureAsDeploymentFailure: true
    asyncExecution: false
    parameters: [
      {
        name: 'ContainerName'
        value: hubStorageAccountContainerName
      }
      {
        name: 'StorageAccountName'
        value: storageAccount.name
      }
      {
        name: 'StorageEndpoint'
        value: environment().suffixes.storage
      }
      {
        name: 'UserAssignedIdentityObjectId'
        value: userAssignedIdentityPrincipalId
      }
    ]
    source: {
      script: '''
        param(
          [string]$ContainerName,
          [string]$StorageAccountName,
          [string]$StorageEndpoint,
          [string]$UserAssignedIdentityObjectId
        )
        $ErrorActionPreference = "Stop"
        $StorageAccountUrl = "https://" + $StorageAccountName + ".blob." + $StorageEndpoint + "/"
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&object_id=$UserAssignedIdentityObjectId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $BlobNames = @('az.accounts.2.13.0.nupkg','az.automation.1.9.0.nupkg','az.keyvault.4.11.0.nupkg','az.resources.6.6.0.nupkg', 'az.network.6.2.0.nupkg')
        foreach($BlobName in $BlobNames)
        {
          do
          {
              try
              {
                  Write-Output "Download Attempt $i"
                  Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$BlobName" -OutFile "$env:windir\temp\$BlobName"
              }
              catch [System.Net.WebException]
              {
                  Start-Sleep -Seconds 60
                  $i++
                  if($i -gt 10){throw}
                  continue
              }
              catch
              {
                  $Output = $_ | select *
                  Write-Output $Output
                  throw
              }
          }
          until(Test-Path -Path $env:windir\temp\$BlobName)
          Start-Sleep -Seconds 5
          Unblock-File -Path $env:windir\temp\$BlobName
          $BlobZipName = $Blobname.Replace('nupkg','zip')
          Rename-Item -Path $env:windir\temp\$BlobName -NewName $BlobZipName
          $BlobNameArray = $BlobName.Split('.')
          $ModuleFolderName = $BlobNameArray[0] + '.' + $BlobNameArray[1]
          $VersionFolderName = $BlobNameArray[2] + '.' + $BlobNameArray[3]+ '.' + $BlobNameArray[4]
          $ModulesDirectory = "C:\Program Files\WindowsPowerShell\Modules"
          New-Item -Path $ModulesDirectory -Name $ModuleFolderName -ItemType "Directory" -Force
          Expand-Archive -Path $env:windir\temp\$BlobZipName -DestinationPath "$ModulesDirectory\$ModuleFolderName\$VersionFolderName" -Force
          Remove-Item -Path "$ModulesDirectory\$ModuleFolderName\$VersionFolderName\_rels" -Force -Recurse
          Remove-Item -Path "$ModulesDirectory\$ModuleFolderName\$VersionFolderName\package" -Force -Recurse
          Remove-Item -LiteralPath "$ModulesDirectory\$ModuleFolderName\$VersionFolderName\[Content_Types].xml" -Force
          Remove-Item -Path "$ModulesDirectory\$ModuleFolderName\$VersionFolderName\$ModuleFolderName.nuspec" -Force
        }
        Remove-Item -Path "$env:windir\temp\az*" -Force
      '''
    }
  }
  dependsOn: [
    storageAccount]
}

resource sslCertificates 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'runCommandSslCertificates'
  location: location
  tags: {}
  parent: virtualMachine
  properties: {
    treatFailureAsDeploymentFailure: true
    asyncExecution: false
    parameters: [
      {
        name: 'StorageEndpoint'
        value: environment().suffixes.storage
      }
      {
        name: 'UserAssignedIdentityObjectId'
        value: userAssignedIdentityPrincipalId
      }
      {
        name: 'ApplicationGatewaySslCertificateName'
        value: applicationGatewaySslCertificateName
      }
      {
        name: 'ApplicationGatewaySslCertificateFilename'
        value: applicationGatewaySslCertificateFilename
      }
      {
        name: 'KeyVaultName'
        value: keyVaultName
      }
      {
        name: 'StorageAccountName'
        value: storageAccount.name
      }
      {
        name:'Location'
        value: location
      }
      {
        name:'ContainerName'
        value: hubStorageAccountContainerName
      }
      {
        name: 'Environment'
        value: environment().name
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
    ]
    protectedParameters:[
      {
        name: 'ApplicationGatewaySslCertificatePassword'
        value: applicationGatewaySslCertificatePassword
      }
    ]
    source: {
      script: '''
      param(
        [string]$ApplicationGatewaySslCertificateFilename,
        [string]$ApplicationGatewaySslCertificateName,
        [Parameter(Mandatory=$false)]
        [string]$ApplicationGatewaySslCertificatePassword,
        [string]$ContainerName,
        [string]$Environment,
        [string]$KeyVaultName,
        [string]$Location,
        [string]$StorageAccountName,
        [string]$StorageEndpoint,
        [string]$UserAssignedIdentityClientId,
        [string]$UserAssignedIdentityObjectId
      )
      $ErrorActionPreference = 'Stop'
      $WarningPreference = 'SilentlyContinue'
      $StorageAccountUrl = "https://" + $StorageAccountName + ".blob." + $StorageEndpoint + "/"
      $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&object_id=$UserAssignedIdentityObjectId"
      $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
      New-Item -Path $env:windir\temp -Name certificate  -ItemType "directory" -Force
      Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$ApplicationGatewaySslCertificateFilename" -OutFile $env:windir\temp\certificate\$ApplicationGatewaySslCertificateFilename
      Set-Location -Path $env:windir\temp\certificate
      Import-Module Az.KeyVault
      Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment
      if($ApplicationGatewaySslCertificatePassword)
      {
        $certificatePassword = ConvertTo-SecureString -String $applicationGatewaySslCertificatePassword -AsPlainText -Force
        Import-AzKeyVaultCertificate -VaultName $keyVaultName -FilePath .\$ApplicationGatewaySslCertificateFilename -Name $ApplicationGatewaySslCertificateName -Password $certificatePassword
      }
      else
      {
        Import-AzKeyVaultCertificate -VaultName $keyVaultName -FilePath .\$ApplicationGatewaySslCertificateFilename -Name $ApplicationGatewaySslCertificateName
      }
      '''
    }
  }
  dependsOn: [
    modules
    storageAccount
  ]
}

resource spokeFirewallRule 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'addSpokeFirewallRule'
  location: location
  tags: {}
  parent: virtualMachine
  properties: {
    treatFailureAsDeploymentFailure: true
    asyncExecution: false
    parameters: [
      {
        name: 'VNetAddressPrefixes'
        value: vNetAddressPrefixes
      }
      {
        name: 'Environment'
        value: environment().name
      }
      {
        name: 'FirewallPolicyName'
        value: firewallPolicyName
      }
      {
        name: 'HubResourceGroup'
        value: hubResourceGroup
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
    ]
    protectedParameters:[
    ]
    source: {
      script: '''
      param(
        [string]$Environment,
        [string]$FirewallPolicyName,
        [string]$HubResourceGroup,
        [string]$VNetAddressPrefixes,
        [string]$UserAssignedIdentityClientId
      )
    $ErrorActionPreference = 'Stop'
    $WarningPreference = 'SilentlyContinue'
    Import-Module Az.Network
    Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -Environment $Environment
    $firewallPolicy = Get-AzFirewallPolicy -Name $firewallPolicyName -ResourceGroupName $hubResourceGroup
    # Get the existing rule collection
    $networkRuleCollectionGroup = Get-AzFirewallPolicyRuleCollectionGroup -Name "DefaultNetworkRuleCollectionGroup" -ResourceGroupName $hubResourceGroup -AzureFirewallPolicyName $firewallPolicy.Name
    $existingrulecollection = $networkRuleCollectionGroup.Properties.RuleCollection | Where-Object {$_.Name -eq "AllowTrafficBetweenSpokes"}
    # Get the current source addresses defined in the rule
    $currentSourceAddresses = $existingrulecollection.Rules[0].SourceAddresses
    # Add a new source address
    $spokeSourceAddress = $vNetAddressPrefixes
    $currentSourceAddresses += $spokeSourceAddress
    # Update the rule with the new source addresses
    $existingrulecollection.Rules[0].SourceAddresses = $currentSourceAddresses
    # Update the firewall policy
    Set-AzFirewallPolicyRuleCollectionGroup -Name "DefaultNetworkRuleCollectionGroup" -FirewallPolicyObject $firewallPolicy -Priority 200 -RuleCollection $networkRuleCollectionGroup.Properties.rulecollection
    '''
    }
  }
  dependsOn: [
    modules
    storageAccount
  ]
}
