# Exercise 01: Build a RAG document store on Azure Cosmos DB for NoSQL

### Estimated Duration: 45 Minutes

## Scenario

Your team is building the first stage of an AI-ready retrieval solution. In this exercise, you will use the pre-staged lab files on the VM to verify the Azure Cosmos DB for NoSQL environment, confirm Microsoft Entra ID data-plane access, and complete the Python logic that stores and retrieves chunked documents for a retrieval-augmented generation (RAG) workflow.

## Overview

In this exercise, you will work from the starter project that is already staged on the lab VM at `<inject key="projectRootPath"></inject>`. You will confirm that the Azure Cosmos DB account **<inject key="cosmosAccountName"></inject>** and database **<inject key="databaseName"></inject>** are available, verify that you can connect by using your lab identity, review the RAG container design, finish the Python implementation, and run the local test app to validate end-to-end document storage and retrieval.

## Objectives

- Task 1: Sign in and inspect the pre-staged RAG starter project
- Task 2: Verify the Azure Cosmos DB account, database, and container
- Task 3: Confirm Microsoft Entra ID data access to Azure Cosmos DB
- Task 4: Complete and test the RAG document store workflow

## Task 1: Sign in and inspect the pre-staged RAG starter project

In this task, you will sign in to Azure, open the lab VM workspace, and review the files you will use throughout the exercise.

1. On the lab VM, open a browser and go to <https://portal.azure.com>.
2. Sign in with the following credentials:
   - Username: `<inject key="AzureAdUserEmail"></inject>`
   - Password: `<inject key="AzureAdUserPassword"></inject>`
3. Confirm that you are working in subscription `<inject key="SubscriptionID"></inject>` and tenant `<inject key="TenantID"></inject>`.
4. Open **Visual Studio Code** from the desktop or Start menu.
5. In VS Code, select **File** > **Open Folder**.
6. Browse to the lab workspace folder: `<inject key="projectRootPath"></inject>`.
7. Locate the folder for Exercise 01. Review the starter files that support the RAG workflow, such as the Python application code, requirements file, sample documents, and any helper scripts included with the staged project.
8. Open a VS Code terminal and record the deployment identifier shown for this lab: **<inject key="DeploymentID" enableCopy="false"/>**.
9. In the terminal, sign in to Azure CLI if needed:

   ```azurecli
   az login
   ```

10. If a subscription prompt appears, set the active subscription explicitly:

   ```azurecli
   az account set --subscription <inject key="SubscriptionID"></inject>
   ```

11. Verify the current account context:

   ```azurecli
   az account show --output table
   ```

> [!Tip]
> Keep VS Code, the Azure portal, and the terminal open side by side. You will use all three during the exercise.

## Task 2: Verify the Azure Cosmos DB account, database, and container

In this task, you will confirm that the baseline Azure Cosmos DB resources for the lab are available before you begin coding.

1. In the Azure portal search bar, search for **Azure Cosmos DB** and open the account named **<inject key="cosmosAccountName"></inject>**.
2. On the **Overview** page, confirm that the account status is healthy and note the account endpoint.
3. In the left menu, select **Data Explorer**.
4. Confirm that the database **<inject key="databaseName"></inject>** exists.
5. Expand the database and verify that the RAG container **<inject key="ragContainerName"></inject>** is present.
6. Select the container and review its partition key setting in the portal.
7. In the terminal, verify the Azure Cosmos DB account from Azure CLI:

   ```azurecli
   az cosmosdb show \
     --name <inject key="cosmosAccountName"></inject> \
     --resource-group rg-<inject key="DeploymentID"></inject> \
     --query "{name:name,location:location,documentEndpoint:documentEndpoint}" \
     --output table
   ```

8. Verify that the database exists:

   ```azurecli
   az cosmosdb sql database show \
     --account-name <inject key="cosmosAccountName"></inject> \
     --resource-group rg-<inject key="DeploymentID"></inject> \
     --name <inject key="databaseName"></inject> \
     --output jsonc
   ```

9. Verify that the container exists:

   ```azurecli
   az cosmosdb sql container show \
     --account-name <inject key="cosmosAccountName"></inject> \
     --resource-group rg-<inject key="DeploymentID"></inject> \
     --database-name <inject key="databaseName"></inject> \
     --name <inject key="ragContainerName"></inject> \
     --output jsonc
   ```

10. Review the container properties in the CLI output and confirm that the container is ready for document item storage.

> [!Important]
> This exercise assumes the baseline Azure Cosmos DB account and database were provisioned during deployment. If the database or container is missing, stop and confirm the deployment completed successfully before continuing.

<validation step="Azure Cosmos DB Foundation"/>

## Task 3: Confirm Microsoft Entra ID data access to Azure Cosmos DB

In this task, you will validate that your lab identity can access the Azure Cosmos DB for NoSQL data plane by using Microsoft Entra ID instead of account keys.

1. In the Azure portal, remain on the Azure Cosmos DB account **<inject key="cosmosAccountName"></inject>**.
2. Review the account settings that are relevant to authentication and access as directed by your instructor or deployment design.
3. In the terminal, list the current SQL role assignments for the account:

   ```azurecli
   az cosmosdb sql role assignment list \
     --resource-group rg-<inject key="DeploymentID"></inject> \
     --account-name <inject key="cosmosAccountName"></inject> \
     --output table
   ```

4. Confirm that your signed-in user appears in the effective access path used for the lab, or that a role assignment was created for the scope required by the environment.
5. In VS Code, open the RAG project configuration file such as `.env`, `settings.json`, or the starter code comments, and identify the values used by the app for:
   - Azure Cosmos DB endpoint
   - Database name
   - Container name
6. Confirm that the project is designed to use Azure credentials from your signed-in session rather than a hard-coded account key.
7. Open the terminal in the Exercise 01 project folder and install any missing Python dependencies if required:

   ```bash
   python -m pip install -r requirements.txt
   ```

8. Run the starter validation or smoke test included with the project, if provided, to verify that `DefaultAzureCredential` authentication can reach the Azure Cosmos DB container.

> [!Note]
> For Azure Cosmos DB for NoSQL, Microsoft Learn guidance supports using `DefaultAzureCredential` with the Python SDK and granting data-plane role assignments to the user identity. This lab follows that approach so you can test with your lab sign-in.

## Task 4: Complete and test the RAG document store workflow

In this task, you will finish the Python implementation that writes chunked documents to Azure Cosmos DB and retrieves them for testing.

1. In VS Code, open the main Python file for the Exercise 01 starter project.
2. Find the TODO sections related to the RAG document store workflow. These sections typically include logic to:
   - Connect to Azure Cosmos DB for NoSQL
   - Get the database client for **<inject key="databaseName"></inject>**
   - Get the container client for **<inject key="ragContainerName"></inject>**
   - Insert chunked document items
   - Query or read items back for validation
3. Update the connection logic so it uses the Azure Cosmos DB endpoint for **<inject key="cosmosAccountName"></inject>** together with Azure identity authentication.
4. Complete the item creation logic based on the starter schema supplied in the project. Make sure each stored chunk includes the document metadata and partition key value expected by the sample app.
5. Complete the retrieval logic so the app can read back stored chunks from **<inject key="ragContainerName"></inject>**.
6. Save your changes.
7. If the project includes a virtual environment setup step, create or activate it now.
8. Run the local app or test script supplied with the starter project. For example:

   ```bash
   python app.py
   ```

   or

   ```bash
   python test_rag_store.py
   ```

9. Use the sample documents that are pre-staged in the Exercise 01 folder to load data into the RAG container.
10. Confirm in the terminal output that items were written successfully.
11. Return to the Azure portal, open **Data Explorer**, select **<inject key="databaseName"></inject>** > **<inject key="ragContainerName"></inject>**, and inspect the inserted items.
12. Verify that the stored records reflect chunk-style document storage with IDs, content, and metadata fields from the lab starter project.
13. Use the local app's retrieval option or test route to fetch stored chunks and confirm the expected results are returned.
14. If the project includes a local web UI, open the local host URL shown in the terminal and validate that the document store workflow completes successfully.

> [!Tip]
> If item writes succeed but retrieval does not, compare the partition key value used during writes with the value used in reads or queries. In Azure Cosmos DB, the partition key must align with the container design for efficient access.

> [!Important]
> Do not redesign the schema during the exercise. Use the pre-staged starter structure so Exercise 02 can extend the same solution for semantic search.

## Summary

In this exercise, you verified the baseline Azure Cosmos DB for NoSQL environment, confirmed Microsoft Entra ID data-plane access, and completed the Python code required to store and retrieve chunked RAG documents. You now have the document storage foundation needed to extend the solution with vector similarity search in the next exercise.
