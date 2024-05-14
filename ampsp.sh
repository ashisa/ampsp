#!/bin/bash

# This script performs a series of operations to obtain an access token and make an API call to the SaaS Fulfillment API.

# Parameters:
#   $1 - The application ID from the Partner Center
#   $2 - The tenant ID from the Partner Center

appId=$1
tenantId=$2

# Query the object ID of the currently signed-in user
echo "Querying object of currently signed-in user..."
objectId=$(az ad signed-in-user show --query id -o tsv)

# Query the prefix used during SaaS Accelerator deployment
echo "Querying prefix used during SaaS Accelerator deployment..."
prefix=$(az ad app show --id $appId --query displayName -o tsv | awk -F - '{print $1}')

# Create a service principal for the app registration
echo "Creating service principal for the app registration..."
az ad sp create --id $appId

# Set KeyVault policy on $prefix-kv for the current user to read the client secret
echo "Setting KeyVault policy on $prefix-kv for the current user to read the client secret..."
az keyvault set-policy -n $prefix-kv --secret-permissions get list --object-id $objectId -o none

# Query the client secret ADApplicationSecret
echo "Querying the client secret ADApplicationSecret..."
clientSecret=$(az keyvault secret show --vault-name $prefix-kv --name ADApplicationSecret --query value -o tsv)

# Obtain the access token
echo "Obtaining the access token..."
accessToken=$(curl -s -X POST \
    https://login.microsoftonline.com/$tenantId/oauth2/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=$appId" \
    -d "client_secret=$clientSecret" \
    -d "resource=20e940b3-4c77-4b0b-9a53-9e16a1b010a7" | jq -r .access_token)

# Place an API call to SaaS Fulfillment API
echo "Placing an API call to SaaS Fulfillment API..."
curl -s -X GET https://marketplaceapi.microsoft.com/api/saas/subscriptions?api-version=2018-08-31 -H "Content-Type: application/json" -H "Authorization: Bearer $accessToken" | jq .

echo "if you see a valid output from SaaS API call, then the OID fix is successful."

# Discard client secret and access token from memory
echo "Discarding client secret and access token from memory..."
unset clientSecret
unset accessToken
