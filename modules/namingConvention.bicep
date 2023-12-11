@maxLength(8)
param appName string
param deploymentNameSuffix string
@allowed([
  'development'
  'test'
  'staging'
  'production'
])
param environment string
param function string
param index int

var dbNamePlaceHolder = 'db${appName}${environmentLetter}${functionShort}${padLeft(index,2,'0')}'
var environmentLetter = substring(environment,0,1)
var functionShort = length(function) > 5 ? substring(function,0,5) : function
var managementVirtualMachineNamePlaceHolder =  take('[PH]-${uniqueString(deploymentNameSuffix)}', 15)
var networkSecurityGroupNamePlaceHolder = 'nsg-${appName}${environmentLetter}${functionShort}${padLeft(index,2,'0')}'
var resourceNamePlaceHolder = '[PH]-${function}-${appName}-${environmentLetter}-${padLeft(index,2,'0')}'
var resourceNameShortPlaceHolder = '[PH]-${functionShort}-${appName}-${environmentLetter}-${padLeft(index,2,'0')}'
var storageAccountNamePlaceHolder = 'sta${appName}${environmentLetter}${functionShort}${padLeft(index,2,'0')}'
var resourceGropuNamePlaceHolder = 'rg-${appName}${environmentLetter}${functionShort}${padLeft(index,2,'0')}'

output dbName string = dbNamePlaceHolder
output networkSecurityGroupName string = networkSecurityGroupNamePlaceHolder
output resourceName string = resourceNamePlaceHolder
output resourceNameShort string = resourceNameShortPlaceHolder
output storageAccountName string = storageAccountNamePlaceHolder
output virtualMachineName string = managementVirtualMachineNamePlaceHolder
output resourceGroupName string = resourceGropuNamePlaceHolder
