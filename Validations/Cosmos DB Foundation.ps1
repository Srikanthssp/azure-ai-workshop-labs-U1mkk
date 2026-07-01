using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-cosmos-rag-$DID"
$count = 0
$found = $false

# Expected resource names are provided by deployment outputs.
$accountName = '<inject key="cosmosAccountName"></inject>'
$databaseName = '<inject key="databaseName"></inject>'
$expectedRegion = 'East US'

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop

        $cosmosAccount = Get-AzCosmosDBAccount -ResourceGroupName $rg -Name $accountName -ErrorAction Stop
        $sqlDatabase = Get-AzCosmosDBSqlDatabase -ResourceGroupName $rg -AccountName $accountName -Name $databaseName -ErrorAction Stop

        $accountRegion = $null
        if ($cosmosAccount.WriteLocations -and $cosmosAccount.WriteLocations.Count -gt 0) {
            $accountRegion = $cosmosAccount.WriteLocations[0].LocationName
        }

        $resourceTypeMatches = $cosmosAccount.Id -match '/providers/Microsoft.DocumentDB/databaseAccounts/'
        $databaseIdMatches = $sqlDatabase.Id -match '/sqlDatabases/'
        $endpointReachable = -not [string]::IsNullOrWhiteSpace($cosmosAccount.DocumentEndpoint)
        $provisioningSucceeded = $cosmosAccount.ProvisioningState -eq 'Succeeded'
        $regionMatches = $accountRegion -eq $expectedRegion

        if ($resourceTypeMatches -and $databaseIdMatches -and $endpointReachable -and $provisioningSucceeded -and $regionMatches) {
            $found = $true
            $message = @{
                Status  = 'Succeeded'
                Message = "Azure Cosmos DB account '$accountName' of type Microsoft.DocumentDB/databaseAccounts and SQL database '$databaseName' were found in RG '$rg'. Account endpoint '$($cosmosAccount.DocumentEndpoint)' is available, provisioning state is '$($cosmosAccount.ProvisioningState)', and primary write region is '$accountRegion'."
            } | ConvertTo-Json
        } else {
            $failureReasons = @()
            if (-not $resourceTypeMatches) { $failureReasons += 'Cosmos DB account resource type could not be confirmed' }
            if (-not $databaseIdMatches) { $failureReasons += 'SQL database resource path could not be confirmed' }
            if (-not $endpointReachable) { $failureReasons += 'DocumentEndpoint is empty' }
            if (-not $provisioningSucceeded) { $failureReasons += "provisioning state is '$($cosmosAccount.ProvisioningState)'" }
            if (-not $regionMatches) { $failureReasons += "primary write region '$accountRegion' does not match expected region '$expectedRegion'" }

            $message = @{
                Status  = 'Failed'
                Message = "Cosmos DB foundation check failed for account '$accountName' and database '$databaseName' in RG '$rg': $($failureReasons -join '; ')."
            } | ConvertTo-Json
        }
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $message
        })
    }
    catch {
        $message = @{
            Status  = 'Failed'
            Message = "Error during check. Attempt $count of 3. Error: $($_.Exception.Message)"
        } | ConvertTo-Json
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $message
        })
        Start-Sleep -Seconds 10
    }
} while ($count -lt 3 -and -not $found)

# Post-loop: if every attempt failed, emit a final failure JSON so CloudLabs
# always sees a structured result.
if (-not $found) {
    $message = @{
        Status  = 'Failed'
        Message = "Azure Cosmos DB account '$accountName' and/or SQL database '$databaseName' not found or not ready in RG '$rg' after 3 attempts."
    } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}
