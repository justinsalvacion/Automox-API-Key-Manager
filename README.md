# Automox API Key Manager

A PowerShell script to manage Automox API keys programmatically. Create, list, and delete both Global and Organization-level API keys across your Automox account.

## Features

- List Keys - View all Global and Organization API keys
- Create Global Keys - Create API keys that work across all organizations
- Create Organization Keys - Create API keys for specific orgs or all orgs at once
- Delete Keys - Remove unwanted Global or Organization API keys
- CSV Export - Automatically exports created org keys to CSV file

## Prerequisites

- PowerShell 5.1 or later
- Automox Global API Key with appropriate permissions
- Personal API Key: Manage permission
- Organization: Read permission
- Full Administrator role recommended

## Installation

1. Download the Automox-ApiKeyManager.ps1 script
2. Place it in your desired directory
3. Obtain your Global API Key from Automox Console (Setup and Configuration then Keys)

## Usage

### List All Keys

.\Automox-ApiKeyManager.ps1 -ApiKey "your-global-api-key" -Action ListKeys

### Create Global API Key

.\Automox-ApiKeyManager.ps1 -ApiKey "your-global-api-key" -Action CreateGlobalKey -KeyName "MyGlobalKey"

### Create Organization API Keys

Create keys for specific organizations:

.\Automox-ApiKeyManager.ps1 -ApiKey "your-global-api-key" -Action CreateOrgKeys -OrgIds @(120769, 116770) -KeyName "API"

Create keys for ALL organizations at once:

.\Automox-ApiKeyManager.ps1 -ApiKey "your-global-api-key" -Action CreateOrgKeys -AllOrgs -KeyName "API"

### Delete Keys

Delete a Global API key:

.\Automox-ApiKeyManager.ps1 -ApiKey "your-global-api-key" -Action DeleteKey -DeleteKeyId 323 -KeyType Global

Delete an Organization API key:

.\Automox-ApiKeyManager.ps1 -ApiKey "your-global-api-key" -Action DeleteKey -DeleteKeyId 106757 -KeyType Org -DeleteOrgId 120769

## Parameters

Parameter       | Required | Description
----------------|----------|-------------
-ApiKey         | Yes      | Your existing Automox Global API key
-Action         | No       | ListKeys, CreateGlobalKey, CreateOrgKeys, DeleteKey (Default: ListKeys)
-KeyName        | No       | Name for the new API key (Default: API)
-OrgIds         | No       | Array of Organization IDs for creating org keys
-AllOrgs        | No       | Switch to create keys for all organizations
-DeleteKeyId    | No       | Key ID to delete
-KeyType        | No       | Type of key to delete: Global or Org (Default: Global)
-DeleteOrgId    | No       | Organization ID (required when deleting Org keys)

## Complete Workflow Example

Step 1: List existing keys
.\Automox-ApiKeyManager.ps1 -ApiKey "abc123-your-key" -Action ListKeys

Step 2: Clean up old keys
.\Automox-ApiKeyManager.ps1 -ApiKey "abc123-your-key" -Action DeleteKey -DeleteKeyId 123 -KeyType Global

Step 3: Create keys for all organizations
.\Automox-ApiKeyManager.ps1 -ApiKey "abc123-your-key" -Action CreateOrgKeys -AllOrgs -KeyName "ProdAPI"

## CSV Output

When creating organization keys, results are exported to: Automox_OrgKeys_YYYYMMDD_HHMMSS.csv

Columns: OrgId, OrgName, KeyId, KeyName, Secret

## Security Notes

- Never commit API keys to version control
- Store the exported CSV file securely
- Delete the CSV file after transferring keys to a secure location
- Use a secrets manager for production environments
- Rotate API keys periodically

## Troubleshooting

403 Forbidden Error:
- Ensure your Global API key has Personal API Key: Manage permission
- Verify you have Full Administrator role or equivalent permissions

400 Bad Request Error:
- Check if a key with the same name already exists
- Verify you have not reached the 10-key limit per organization

Empty API Key in Output:
- The key was created but decryption failed
- Retrieve the key manually from Automox Console

## API Reference

This script uses the Automox API. For more information see: https://developer.automox.com/

## License

MIT License - Feel free to use and modify as needed.

## Author

Ashley Salvacion
