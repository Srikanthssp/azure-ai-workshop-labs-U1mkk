Param(
    [Parameter(Mandatory = $true)] [string] $AzureUserName,
    [Parameter(Mandatory = $true)] [string] $AzurePassword,
    [Parameter(Mandatory = $true)] [string] $AzureTenantID,
    [Parameter(Mandatory = $true)] [string] $AzureSubscriptionID,
    [Parameter(Mandatory = $true)] [string] $ODLID,
    [Parameter(Mandatory = $false)] [string] $InstallCloudLabsShadow,
    [Parameter(Mandatory = $true)] [string] $DeploymentID,
    [Parameter(Mandatory = $true)] [string] $vmAdminUsername,
    [Parameter(Mandatory = $true)] [string] $vmAdminPassword,
    [Parameter(Mandatory = $false)] [string] $trainerUserName,
    [Parameter(Mandatory = $false)] [string] $trainerUserPassword
)

$ErrorActionPreference = 'Stop'

Start-Transcript -Path 'C:\WindowsAzure\Logs\CloudLabsCustomScriptExtension.txt' -Append

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    New-Item -Path 'C:\LabFiles' -ItemType Directory -Force | Out-Null
    New-Item -Path 'C:\Users\Public\Desktop' -ItemType Directory -Force | Out-Null

    function CreateCredFile {
        $commonBase = 'https://experienceazure.blob.core.windows.net/templates/cloudlabs-common'
        $credTxtUrl = "$commonBase/AzureCreds.txt"
        $credPs1Url = "$commonBase/AzureCreds.ps1"
        $tempDir = 'C:\LabFiles\Temp'
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

        $credTxtLocal = Join-Path $tempDir 'AzureCreds.txt'
        $credPs1Local = Join-Path $tempDir 'AzureCreds.ps1'

        Invoke-WebRequest -Uri $credTxtUrl -OutFile $credTxtLocal -UseBasicParsing
        Invoke-WebRequest -Uri $credPs1Url -OutFile $credPs1Local -UseBasicParsing

        $openBrace = [char]123
        $closeBrace = [char]125
        $placeholderPrefix = [string]::Concat($openBrace, $openBrace)
        $placeholderSuffix = [string]::Concat($closeBrace, $closeBrace)
        $odlidPlaceholder = [string]::Concat($placeholderPrefix, 'ODLID', $placeholderSuffix)
        $content = Get-Content -Path $credTxtLocal -Raw
        $content = $content.Replace($odlidPlaceholder, $ODLID)
        Set-Content -Path $credTxtLocal -Value $content -Encoding UTF8

        Copy-Item -Path $credTxtLocal -Destination 'C:\LabFiles\AzureCreds.txt' -Force
        Copy-Item -Path $credPs1Local -Destination 'C:\LabFiles\AzureCreds.ps1' -Force
        Copy-Item -Path $credTxtLocal -Destination 'C:\Users\Public\Desktop\AzureCreds.txt' -Force
        Copy-Item -Path $credPs1Local -Destination 'C:\Users\Public\Desktop\AzureCreds.ps1' -Force
    }

    CreateCredFile

    if (Get-Command choco.exe -ErrorAction SilentlyContinue) {
        choco feature enable -n allowGlobalConfirmation | Out-Null
        choco install azure-cli git vscode python --no-progress
    }

    $projectRoot = 'C:\LabFiles\CosmosDbAIDocumentStore'
    New-Item -Path $projectRoot -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $projectRoot 'exercise-01-rag-store') -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $projectRoot 'exercise-02-semantic-search') -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $projectRoot 'exercise-03-index-optimization') -ItemType Directory -Force | Out-Null

    $readme = @'
Azure Cosmos DB for NoSQL AI-ready document retrieval lab files are staged here.
Use the exercise folders for the RAG document store, semantic search, and vector index optimization activities.
'@
    Set-Content -Path (Join-Path $projectRoot 'README.txt') -Value $readme -Encoding UTF8

    $envFile = Join-Path $projectRoot '.env'
    $envContent = @"
AZURE_TENANT_ID=$AzureTenantID
AZURE_SUBSCRIPTION_ID=$AzureSubscriptionID
AZURE_USERNAME=$AzureUserName
AZURE_PASSWORD=$AzurePassword
ODL_ID=$ODLID
DEPLOYMENT_ID=$DeploymentID
PROJECT_ROOT=$projectRoot
"@
    Set-Content -Path $envFile -Value $envContent -Encoding UTF8

    $azCmd = Get-Command az.cmd -ErrorAction SilentlyContinue
    if (-not $azCmd) {
        $azCmd = Get-Command az -ErrorAction SilentlyContinue
    }

    if ($azCmd) {
        & $azCmd.Source login --service-principal -u $AzureUserName -p $AzurePassword --tenant $AzureTenantID 2>$null
        if ($LASTEXITCODE -ne 0) {
            & $azCmd.Source login -u $AzureUserName -p $AzurePassword --tenant $AzureTenantID 2>$null
        }
        & $azCmd.Source account set --subscription $AzureSubscriptionID 2>$null
    }

    $desktopShortcut = 'C:\Users\Public\Desktop\Cosmos DB Lab Files.url'
    $shortcutContent = @"
[InternetShortcut]
URL=file:///$($projectRoot.Replace('\','/'))
"@
    Set-Content -Path $desktopShortcut -Value $shortcutContent -Encoding ASCII
}
finally {
    Stop-Transcript
}
