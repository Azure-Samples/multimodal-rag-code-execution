

@description('Generated from /subscriptions/af509a4e-4374-4998-8d0d-15fc7b54f668/resourceGroups/test-research-copilot-rg/providers/Microsoft.Network/privateEndpoints/pepopenai')
resource pepopenai 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pepopenai'
  location: 'swedencentral'
  tags: {}
  properties: {
   
    privateLinkServiceConnections: [
      {
        name: 'pepopenai'
        id: '/subscriptions/af509a4e-4374-4998-8d0d-15fc7b54f668/resourceGroups/test-research-copilot-rg/providers/Microsoft.Network/privateEndpoints/pepopenai/privateLinkServiceConnections/pepopenai'
        etag: 'W/"f1da2af5-2c1a-4bcc-95bf-8f6ea3d45891"'
        properties: {
          privateLinkServiceId: '/subscriptions/af509a4e-4374-4998-8d0d-15fc7b54f668/resourceGroups/test-research-copilot-rg/providers/Microsoft.CognitiveServices/accounts/devopenaiswedencentralxe4t44kuwpez6'
          groupIds: [
            'account'
          ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Approved'
            actionsRequired: 'None'
          }
        }
        type: 'Microsoft.Network/privateEndpoints/privateLinkServiceConnections'
      }
    ]
    manualPrivateLinkServiceConnections: []
    customNetworkInterfaceName: 'pepopenai-nic'
    subnet: {
      id: '/subscriptions/af509a4e-4374-4998-8d0d-15fc7b54f668/resourceGroups/test-research-copilot-rg/providers/Microsoft.Network/virtualNetworks/dev-vnet-xe4t44kuwpez6/subnets/snet-privateEndpoints'
    }
  }
}
