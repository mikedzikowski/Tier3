@maxLength(8)
param appName string
param function string
@allowed([
  'development'
  'test'
  'staging'
  'production'
])

param environment string
param index int

var functionShort = length(function) > 5 ? substring(function,0,5) : function
var appNameShort = length(appName) > 5 ? substring(appName,0,5) : appName
var environmentLetter = substring(environment,0,1)

var resourceNamePlaceHolder = '${appName}-${environmentLetter}-${function}-[PH]-${padLeft(index,2,'0')}'
var resourceNameShortPlaceHolder = '${appName}-${environmentLetter}-${functionShort}-[PH]-${padLeft(index,2,'0')}'

var dbNamePlaceHolder = '${appName}${environmentLetter}${functionShort}db${padLeft(index,2,'0')}'
var storageAccountNamePlaceHolder = '${appName}${environmentLetter}${functionShort}sta${padLeft(index,2,'0')}'
var vmNamePlaceHolder = '${appNameShort}-${environmentLetter}-${functionShort}-${padLeft(index,2,'0')}'
var networkSecurityGroupNamePlaceHolder = '${appName}${environmentLetter}${functionShort}-nsg${padLeft(index,2,'0')}'

output resourceName string = resourceNamePlaceHolder 
output resourceNameShort string = resourceNameShortPlaceHolder
output storageAccountName string = storageAccountNamePlaceHolder
output dbName string = dbNamePlaceHolder
output networkSecurityGroupName string = networkSecurityGroupNamePlaceHolder
output vmName string = vmNamePlaceHolder

