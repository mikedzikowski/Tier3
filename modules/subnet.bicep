@description('Required. The Virtual Network (vNet) Name.')
param virtualNetworkName string

@description('Required. The subnet Name of ASEv3.')
param subnetName string

@description('Required. The subnet Name of ASEv3.')
param subnetAddressPrefix string

param delegations array

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
    name: '${virtualNetworkName}/${subnetName}'
    properties:{
      addressPrefix: subnetAddressPrefix
      delegations: delegations
    }
}
