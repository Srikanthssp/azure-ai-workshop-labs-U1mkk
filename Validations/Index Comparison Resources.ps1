using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-cosmosdb-$DID"
$count = 0
$found = $false

function Get-VectorIndexType {
    param(
        [Parameter(Mandatory = $true)]
        $ContainerResource
    )

    $vectorIndexes = $ContainerResource.Properties.resource.indexingPolicy.vectorIndexes
    if ($null -eq $vectorIndexes -or $vectorIndexes.Count -eq 0) {
        return $null
    }

    foreach ($vectorIndex in $vectorIndexes) {
        if ($null -ne $vectorIndex.type -and -not [string]::IsNullOrWhiteSpace([string]$vectorIndex.type)) {
            return [string]$vectorIndex.type
        }
    }

    return $null
}

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop

        $accounts = Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.DocumentDB/databaseAccounts" -ErrorAction Stop
        $account = $accounts | Select-Object -First 1

        if ($null -eq $account) {
            throw "No Azure Cosmos DB account was found in resource group '$rg'."
        }

        $databases = Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.DocumentDB/databaseAccounts/sqlDatabases" -ErrorAction Stop |
            Where-Object { $_.Name -like "$($account.Name)/*" }
        $database = $databases | Select-Object -First 1

        if ($null -eq $database) {
            throw "No Azure Cosmos DB SQL database was found under account '$($account.Name)' in resource group '$rg'."
        }

        $containers = Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers" -ErrorAction Stop |
            Where-Object { $_.Name -like "$($account.Name)/*" }

        $flatContainer = $null
        $quantizedContainer = $null
        $diskAnnContainer = $null

        foreach ($container in $containers) {
            $indexType = Get-VectorIndexType -ContainerResource $container
            switch ($indexType) {
                "flat" {
                    if ($null -eq $flatContainer) {
                        $flatContainer = $container
                    }
                }
                "quantizedFlat" {
                    if ($null -eq $quantizedContainer) {
                        $quantizedContainer = $container
                    }
                }
                "diskANN" {
                    if ($null -eq $diskAnnContainer) {
                        $diskAnnContainer = $container
                    }
                }
            }
        }

        if ($null -ne $flatContainer -and $null -ne $quantizedContainer -and $null -ne $diskAnnContainer) {
            $found = $true
            $message = @{
                Status  = "Succeeded"
                Message = "Cosmos DB vector index comparison resources were found in RG '$rg'. Account '$($account.Name)' contains database '$($database.Name.Split('/')[-1])' with containers '$($flatContainer.Name.Split('/')[-1])' (flat), '$($quantizedContainer.Name.Split('/')[-1])' (quantizedFlat), and '$($diskAnnContainer.Name.Split('/')[-1])' (diskANN)."
            } | ConvertTo-Json
        } else {
            $missingIndexTypes = @()
            if ($null -eq $flatContainer) { $missingIndexTypes += "flat" }
            if ($null -eq $quantizedContainer) { $missingIndexTypes += "quantizedFlat" }
            if ($null -eq $diskAnnContainer) { $missingIndexTypes += "diskANN" }

            $message = @{
                Status  = "Failed"
                Message = "Cosmos DB vector index comparison resources are incomplete in RG '$rg'. Missing container configuration for index type(s): $($missingIndexTypes -join ', ')."
            } | ConvertTo-Json
        }
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $message
        })
    }
    catch {
        $message = @{
            Status  = "Failed"
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
        Status  = "Failed"
        Message = "Cosmos DB vector index comparison containers not found in RG '$rg' after 3 attempts."
    } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}
