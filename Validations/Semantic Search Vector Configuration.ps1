using namespace System.Net

# Note: $sub (subscription id) and $DID (deployment id) are injected by the platform.
$rg = "rg-cosmos-rag-$DID"
$count = 0
$found = $false

function Get-FirstPropertyValue {
    param(
        [object]$Object,
        [string[]]$CandidateNames
    )

    if ($null -eq $Object) {
        return $null
    }

    foreach ($name in $CandidateNames) {
        $prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
        if ($prop -and $null -ne $prop.Value) {
            return $prop.Value
        }
    }

    return $null
}

do {
    $count = $count + 1
    try {
        Set-AzContext -Subscription $sub -ErrorAction Stop

        $cosmosAccounts = Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.DocumentDB/databaseAccounts" -ErrorAction Stop

        if ($cosmosAccounts.Count -eq 0) {
            throw "No Azure Cosmos DB account was found in resource group '$rg'."
        }

        $matchingAccount = $null
        $matchingDatabase = $null
        $matchingContainer = $null
        $vectorPath = $null
        $vectorDataType = $null
        $vectorDistanceFunction = $null
        $vectorDimensions = $null
        $vectorIndexType = $null
        $vectorIndexPath = $null
        $capabilityName = $null

        foreach ($account in $cosmosAccounts) {
            $accountObj = Get-AzResource -ResourceId $account.ResourceId -ExpandProperties -ErrorAction Stop
            $capabilities = @($accountObj.Properties.capabilities)
            $hasVectorCapability = $false

            foreach ($capability in $capabilities) {
                $name = Get-FirstPropertyValue -Object $capability -CandidateNames @('name')
                if ($name -eq 'EnableNoSQLVectorSearch') {
                    $hasVectorCapability = $true
                    $capabilityName = $name
                    break
                }
            }

            if (-not $hasVectorCapability) {
                continue
            }

            $sqlDatabases = Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.DocumentDB/databaseAccounts/sqlDatabases" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "$($account.Name)/*" }

            foreach ($database in $sqlDatabases) {
                $containerResources = Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers" -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "$($database.Name)/*" }

                foreach ($container in $containerResources) {
                    $containerObj = Get-AzResource -ResourceId $container.ResourceId -ExpandProperties -ApiVersion '2024-05-15' -ErrorAction Stop
                    $resourceProps = $containerObj.Properties.resource
                    if ($null -eq $resourceProps) {
                        continue
                    }

                    $vectorEmbeddings = @($resourceProps.vectorEmbeddingPolicy.vectorEmbeddings)
                    $vectorIndexes = @($resourceProps.indexingPolicy.vectorIndexes)

                    if ($vectorEmbeddings.Count -lt 1 -or $vectorIndexes.Count -lt 1) {
                        continue
                    }

                    $embedding = $vectorEmbeddings[0]
                    $embeddingPath = Get-FirstPropertyValue -Object $embedding -CandidateNames @('path')
                    $embeddingDataType = Get-FirstPropertyValue -Object $embedding -CandidateNames @('dataType','datatype')
                    $embeddingDistance = Get-FirstPropertyValue -Object $embedding -CandidateNames @('distanceFunction')
                    $embeddingDimensions = Get-FirstPropertyValue -Object $embedding -CandidateNames @('dimensions')

                    $matchingVectorIndex = $null
                    foreach ($index in $vectorIndexes) {
                        $idxPath = Get-FirstPropertyValue -Object $index -CandidateNames @('path')
                        $idxType = Get-FirstPropertyValue -Object $index -CandidateNames @('type')
                        if (-not [string]::IsNullOrWhiteSpace($idxPath) -and -not [string]::IsNullOrWhiteSpace($idxType) -and $idxPath -eq $embeddingPath) {
                            $matchingVectorIndex = $index
                            break
                        }
                    }

                    if ($null -eq $matchingVectorIndex) {
                        continue
                    }

                    $matchingAccount = $account.Name
                    $matchingDatabase = ($database.Name -split '/',2)[1]
                    $matchingContainer = ($container.Name -split '/',3)[2]
                    $vectorPath = $embeddingPath
                    $vectorDataType = $embeddingDataType
                    $vectorDistanceFunction = $embeddingDistance
                    $vectorDimensions = $embeddingDimensions
                    $vectorIndexPath = Get-FirstPropertyValue -Object $matchingVectorIndex -CandidateNames @('path')
                    $vectorIndexType = Get-FirstPropertyValue -Object $matchingVectorIndex -CandidateNames @('type')
                    $found = $true
                    break
                }

                if ($found) {
                    break
                }
            }

            if ($found) {
                break
            }
        }

        if ($found) {
            $message = @{
                Status  = "Succeeded"
                Message = "Cosmos DB account '$matchingAccount' in RG '$rg' has capability '$capabilityName'. Database '$matchingDatabase' contains vector-enabled container '$matchingContainer' with vector path '$vectorPath', data type '$vectorDataType', distance function '$vectorDistanceFunction', dimensions '$vectorDimensions', and vector index type '$vectorIndexType' on path '$vectorIndexPath'."
            } | ConvertTo-Json
        } else {
            $message = @{
                Status  = "Failed"
                Message = "No Cosmos DB SQL container in RG '$rg' was found with EnableNoSQLVectorSearch enabled plus both a vector embedding policy and matching vector index configuration required for Exercise 2."
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
        Message = "Semantic-search vector configuration not found in RG '$rg' after 3 attempts."
    } | ConvertTo-Json
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $message
    })
}
