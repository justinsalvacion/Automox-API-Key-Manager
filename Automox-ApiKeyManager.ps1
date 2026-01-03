<#
.SYNOPSIS
    Automox API Key Manager - Create, List, Delete API Keys
    
.PARAMETER ApiKey
    Your existing Global API key
    
.PARAMETER Action
    What to do: CreateOrgKeys, CreateGlobalKey, ListKeys, DeleteKey

.EXAMPLE
    .\Automox-ApiKeyManager.ps1 -ApiKey "your-key" -Action ListKeys
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("CreateOrgKeys", "CreateGlobalKey", "ListKeys", "DeleteKey")]
    [string]$Action = "ListKeys",
    
    [Parameter(Mandatory = $false)]
    [int[]]$OrgIds,
    
    [Parameter(Mandatory = $false)]
    [switch]$AllOrgs,
    
    [Parameter(Mandatory = $false)]
    [string]$KeyName = "API",
    
    [Parameter(Mandatory = $false)]
    [int]$DeleteKeyId,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Global", "Org")]
    [string]$KeyType = "Global",
    
    [Parameter(Mandatory = $false)]
    [int]$DeleteOrgId
)

$BaseUrl = "https://console.automox.com/api"
$Headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json, text/plain, */*"
}

$script:UserId = $null
$script:AllOrgsList = @()

#region Helper Functions

function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

function Get-CurrentUser {
    Write-Host "[*] Getting current user..." -ForegroundColor Yellow
    try {
        $user = Invoke-RestMethod -Uri "$BaseUrl/users/self" -Headers $Headers -Method Get
        $script:UserId = $user.id
        Write-Host "    User: $($user.firstname) $($user.lastname) (ID: $($user.id))" -ForegroundColor Green
        return $user
    }
    catch {
        Write-Host "    ERROR: Authentication failed" -ForegroundColor Red
        exit 1
    }
}

function Get-AllOrganizations {
    Write-Host "[*] Getting all organizations..." -ForegroundColor Yellow
    try {
        $orgs = Invoke-RestMethod -Uri "$BaseUrl/orgs" -Headers $Headers -Method Get
        $script:AllOrgsList = $orgs
        Write-Host "    Found $($orgs.Count) organization(s)" -ForegroundColor Green
        return $orgs
    }
    catch {
        Write-Host "    ERROR: Could not get organizations" -ForegroundColor Red
        return @()
    }
}

function Get-GlobalApiKeys {
    Write-Host "[*] Getting Global API Keys..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/global/api_keys" -Headers $Headers -Method Get -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json
        
        # Response format: {"results":[...], "size":N}
        if ($data.results) {
            return $data.results
        }
        elseif ($data.data) {
            return $data.data
        }
        else {
            return $data
        }
    }
    catch {
        Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

function Get-OrgApiKeys {
    param([int]$OrgId)
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/orgs/$OrgId/api_keys" -Headers $Headers -Method Get -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json
        
        if ($data.results) { return $data.results }
        elseif ($data.data) { return $data.data }
        else { return $data }
    }
    catch {
        return @()
    }
}

function Decrypt-GlobalApiKey {
    param([int]$KeyId)
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/global/api_keys/$KeyId/decrypt" -Headers $Headers -Method Post -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json
        
        if ($data.secret) { return $data.secret }
        if ($data.key) { return $data.key }
        if ($data.api_key) { return $data.api_key }
        if ($data.value) { return $data.value }
        
        return $response.Content
    }
    catch {
        return $null
    }
}

function Decrypt-OrgApiKey {
    param([int]$KeyId, [int]$OrgId, [int]$UserId)
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/users/$UserId/api_keys/$KeyId/decrypt?o=$OrgId" -Headers $Headers -Method Post -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json
        
        if ($data.secret) { return $data.secret }
        if ($data.key) { return $data.key }
        if ($data.api_key) { return $data.api_key }
        if ($data.value) { return $data.value }
        
        return $response.Content
    }
    catch {
        return $null
    }
}

function New-GlobalApiKey {
    param([string]$Name)
    
    Write-Host ""
    Write-Host "    Creating Global API Key: $Name" -ForegroundColor Cyan
    
    $body = @{ name = $Name } | ConvertTo-Json
    
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/global/api_keys" -Headers $Headers -Method Post -Body $body -UseBasicParsing
        $newKey = $response.Content | ConvertFrom-Json
        
        Write-Host "    SUCCESS! Key ID: $($newKey.id)" -ForegroundColor Green
        
        $secret = Decrypt-GlobalApiKey -KeyId $newKey.id
        
        return @{
            Success = $true
            Type = "Global"
            KeyId = $newKey.id
            KeyName = $Name
            Secret = $secret
        }
    }
    catch {
        $err = $_.Exception.Message
        if ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $err = $reader.ReadToEnd()
            } catch {}
        }
        Write-Host "    ERROR: $err" -ForegroundColor Red
        return @{ Success = $false; Error = $err }
    }
}

function New-OrgApiKey {
    param([int]$OrgId, [string]$Name)
    
    $orgName = ($script:AllOrgsList | Where-Object { $_.id -eq $OrgId }).name
    if (-not $orgName) { $orgName = "Org $OrgId" }
    
    Write-Host ""
    Write-Host "    Creating Org API Key for: $orgName (ID: $OrgId)" -ForegroundColor Cyan
    
    $body = @{ name = $Name } | ConvertTo-Json
    
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/users/$($script:UserId)/api_keys?o=$OrgId" -Headers $Headers -Method Post -Body $body -UseBasicParsing
        $newKey = $response.Content | ConvertFrom-Json
        
        Write-Host "    SUCCESS! Key ID: $($newKey.id)" -ForegroundColor Green
        
        $secret = Decrypt-OrgApiKey -KeyId $newKey.id -OrgId $OrgId -UserId $script:UserId
        
        return @{
            Success = $true
            Type = "Organization"
            OrgId = $OrgId
            OrgName = $orgName
            KeyId = $newKey.id
            KeyName = $Name
            Secret = $secret
        }
    }
    catch {
        $err = $_.Exception.Message
        if ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $err = $reader.ReadToEnd()
            } catch {}
        }
        Write-Host "    ERROR: $err" -ForegroundColor Red
        return @{ Success = $false; OrgId = $OrgId; OrgName = $orgName; Error = $err }
    }
}

function Remove-GlobalApiKey {
    param([int]$KeyId)
    
    Write-Host "    Deleting Global API Key ID: $KeyId" -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri "$BaseUrl/global/api_keys/$KeyId" -Headers $Headers -Method Delete
        Write-Host "    SUCCESS! Key deleted." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-OrgApiKey {
    param([int]$KeyId, [int]$OrgId)
    
    Write-Host "    Deleting Org API Key ID: $KeyId from Org: $OrgId" -ForegroundColor Yellow
    try {
        Invoke-RestMethod -Uri "$BaseUrl/users/$($script:UserId)/api_keys/$KeyId`?o=$OrgId" -Headers $Headers -Method Delete
        Write-Host "    SUCCESS! Key deleted." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Main Logic

Write-Banner "Automox API Key Manager"

$user = Get-CurrentUser

switch ($Action) {
    
    "ListKeys" {
        Write-Banner "Listing All API Keys"
        
        # Global Keys
        Write-Host ""
        Write-Host "GLOBAL API KEYS:" -ForegroundColor Magenta
        Write-Host "-----------------" -ForegroundColor Magenta
        $globalKeys = Get-GlobalApiKeys
        
        if ($globalKeys -and $globalKeys.Count -gt 0) {
            foreach ($key in $globalKeys) {
                $status = if ($key.is_enabled) { "Enabled" } else { "Disabled" }
                $expires = if ($key.expires_at) { $key.expires_at } else { "Never" }
                Write-Host "  ID: $($key.id) | Name: $($key.name) | Status: $status | Expires: $expires" -ForegroundColor White
                Write-Host "    Created: $($key.created_at) | User: $($key.user.email)" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "  No global keys found" -ForegroundColor Gray
        }
        
        # Org Keys
        Write-Host ""
        Write-Host "ORGANIZATION API KEYS:" -ForegroundColor Magenta
        Write-Host "-----------------------" -ForegroundColor Magenta
        
        $orgs = Get-AllOrganizations
        $foundOrgKeys = $false
        
        foreach ($org in $orgs) {
            $orgKeys = Get-OrgApiKeys -OrgId $org.id
            
            if ($orgKeys -and $orgKeys.Count -gt 0) {
                $myKeys = $orgKeys | Where-Object { $_.user.id -eq $script:UserId }
                
                if ($myKeys -and $myKeys.Count -gt 0) {
                    $foundOrgKeys = $true
                    Write-Host ""
                    Write-Host "  $($org.name) (Org ID: $($org.id)):" -ForegroundColor Yellow
                    foreach ($key in $myKeys) {
                        $status = if ($key.is_enabled) { "Enabled" } else { "Disabled" }
                        Write-Host "    ID: $($key.id) | Name: $($key.name) | Status: $status" -ForegroundColor White
                    }
                }
            }
        }
        
        if (-not $foundOrgKeys) {
            Write-Host "  No organization keys found for your user" -ForegroundColor Gray
        }
    }
    
    "CreateGlobalKey" {
        Write-Banner "Creating Global API Key"
        
        $result = New-GlobalApiKey -Name $KeyName
        
        Write-Banner "RESULT"
        if ($result.Success) {
            Write-Host ""
            Write-Host "Key Name: $($result.KeyName)" -ForegroundColor White
            Write-Host "Key ID:   $($result.KeyId)" -ForegroundColor White
            Write-Host ""
            Write-Host "API KEY:" -ForegroundColor Yellow
            Write-Host "$($result.Secret)" -ForegroundColor Cyan
            Write-Host ""
        }
    }
    
    "CreateOrgKeys" {
        Write-Banner "Creating Organization API Keys"
        
        $orgs = Get-AllOrganizations
        
        if ($AllOrgs) {
            $targetOrgIds = $orgs | Select-Object -ExpandProperty id
            Write-Host "[*] Creating keys for ALL $($targetOrgIds.Count) organizations" -ForegroundColor Yellow
        }
        elseif ($OrgIds) {
            $targetOrgIds = $OrgIds
            Write-Host "[*] Creating keys for $($targetOrgIds.Count) specified organization(s)" -ForegroundColor Yellow
        }
        else {
            Write-Host "ERROR: Specify -OrgIds or -AllOrgs" -ForegroundColor Red
            exit 1
        }
        
        $results = @()
        foreach ($orgId in $targetOrgIds) {
            $result = New-OrgApiKey -OrgId $orgId -Name $KeyName
            $results += $result
            Start-Sleep -Milliseconds 300
        }
        
        Write-Banner "SUMMARY"
        
        $successResults = $results | Where-Object { $_.Success }
        $failedResults = $results | Where-Object { -not $_.Success }
        
        Write-Host ""
        Write-Host "SUCCESS: $($successResults.Count) | FAILED: $($failedResults.Count)" -ForegroundColor White
        Write-Host ""
        
        if ($successResults) {
            Write-Host "CREATED KEYS:" -ForegroundColor Green
            Write-Host "-------------" -ForegroundColor Green
            foreach ($r in $successResults) {
                Write-Host ""
                Write-Host "Org: $($r.OrgName) (ID: $($r.OrgId))" -ForegroundColor Yellow
                Write-Host "  Key ID:   $($r.KeyId)" -ForegroundColor White
                Write-Host "  Key Name: $($r.KeyName)" -ForegroundColor White
                Write-Host "  API KEY:  $($r.Secret)" -ForegroundColor Cyan
            }
        }
        
        if ($failedResults) {
            Write-Host ""
            Write-Host "FAILED:" -ForegroundColor Red
            Write-Host "-------" -ForegroundColor Red
            foreach ($r in $failedResults) {
                Write-Host "  Org: $($r.OrgName) (ID: $($r.OrgId)) - $($r.Error)" -ForegroundColor Red
            }
        }
        
        # Export to CSV
        $csvPath = ".\Automox_OrgKeys_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $successResults | Select-Object OrgId, OrgName, KeyId, KeyName, Secret | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host ""
        Write-Host "Results exported to: $csvPath" -ForegroundColor Green
    }
    
    "DeleteKey" {
        Write-Banner "Deleting API Key"
        
        if (-not $DeleteKeyId) {
            Write-Host "ERROR: Specify -DeleteKeyId" -ForegroundColor Red
            exit 1
        }
        
        if ($KeyType -eq "Global") {
            Remove-GlobalApiKey -KeyId $DeleteKeyId
        }
        else {
            if (-not $DeleteOrgId) {
                Write-Host "ERROR: Specify -DeleteOrgId for Org keys" -ForegroundColor Red
                exit 1
            }
            Remove-OrgApiKey -KeyId $DeleteKeyId -OrgId $DeleteOrgId
        }
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green

#endregion
