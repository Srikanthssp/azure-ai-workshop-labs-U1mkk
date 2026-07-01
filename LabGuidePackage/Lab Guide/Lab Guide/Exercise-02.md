# Exercise 02: Build semantic search with Azure Cosmos DB for NoSQL

### Estimated Duration: 45 Minutes

## Scenario

In Exercise 1, you created the Cosmos DB account, worked with the shared database, and tested a document-store workflow for RAG-style retrieval. In this exercise, you will extend that same environment by enabling vector search in Azure Cosmos DB for NoSQL, creating a vector-enabled container, and completing the Python code that performs similarity search over the staged support-content dataset.

## Overview

In this exercise, you will use the lab VM and the Azure Cosmos DB account that were prepared earlier in the workshop. You will verify that vector search is enabled on the account, review the vector container configuration, update the Python semantic-search functions in the staged project, and run the local app to confirm that query embeddings, metadata filters, and `VectorDistance`-based ranking work together.

## Objectives

- Task 1: Sign in and prepare the semantic search workspace
- Task 2: Verify Azure Cosmos DB vector search configuration
- Task 3: Complete the Python semantic search implementation
- Task 4: Run and validate the semantic search app

## Task 1: Sign in and prepare the semantic search workspace

In this task, you will sign in to Azure, confirm the correct subscription context, and open the pre-staged Exercise 2 project on the lab VM.

1. Sign in to the Azure portal at <https://portal.azure.com> by using the following credentials:
   - Username: `<inject key="AzureAdUserEmail"></inject>`
   - Password: `<inject key="AzureAdUserPassword"></inject>`

2. Confirm that you are working in subscription `<inject key="SubscriptionID"></inject>` and tenant `<inject key="TenantID"></inject>`.

3. On the lab VM, open **Windows Terminal** or **PowerShell**.

4. Sign in to Azure CLI with the same lab identity:

   ```azurecli
   az login
   ```

5. If prompted to choose a subscription, select `<inject key="SubscriptionID"></inject>`. Then set it explicitly:

   ```azurecli
   az account set --subscription <inject key="SubscriptionID"></inject>
   ```

6. Display the active context and confirm that the output matches your lab tenant and subscription:

   ```azurecli
   az account show --output table
   ```

7. Note the deployment context for this environment. Your deployment identifier is **<inject key="DeploymentID" enableCopy="false"/>**.

8. In File Explorer, browse to the pre-staged lab files under `<inject key="projectRootPath"></inject>`.

9. Open the semantic search project folder in Visual Studio Code. If the staged folder names match the exercise layout, open the Exercise 2 folder that contains the semantic search app, sample data, and Python source files.

10. In the VS Code terminal, create and activate the virtual environment if it is not already active:

   ```powershell
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   ```

11. Install the required packages from the staged requirements file:

   ```powershell
   pip install -r requirements.txt
   ```

> [!Tip]
> This workshop is designed so that starter files and sample content are already present on the lab VM. You should not need to clone an external repository during the exercise.

## Task 2: Verify Azure Cosmos DB vector search configuration

In this task, you will verify that the Cosmos DB account supports vector search and that the semantic-search container is available in the shared database.

1. In the terminal, define environment variables for the account and database names used throughout the lab:

   ```powershell
   $COSMOS_ACCOUNT = "<inject key="cosmosAccountName"></inject>"
   $DATABASE_NAME = "<inject key="databaseName"></inject>"
   $VECTOR_CONTAINER = "<inject key="vectorContainerName"></inject>"
   ```

2. Verify that the Cosmos DB account exists:

   ```azurecli
   az cosmosdb show \
     --name $COSMOS_ACCOUNT \
     --resource-group "rg-<inject key="DeploymentID" enableCopy="false"/>" \
     --query "{name:name,location:location,kind:kind}" \
     --output table
   ```

3. Check whether vector search capability is enabled on the account:

   ```azurecli
   az cosmosdb show \
     --name $COSMOS_ACCOUNT \
     --resource-group "rg-<inject key="DeploymentID" enableCopy="false"/>" \
     --query "capabilities[].name" \
     --output table
   ```

4. Confirm that `EnableNoSQLVectorSearch` appears in the results.

5. If the capability is not yet visible, run the update command below and wait a few minutes before checking again:

   ```azurecli
   az cosmosdb update \
     --resource-group "rg-<inject key="DeploymentID" enableCopy="false"/>" \
     --name $COSMOS_ACCOUNT \
     --capabilities EnableNoSQLVectorSearch
   ```

6. List the SQL containers in the shared database and confirm that the semantic-search container exists:

   ```azurecli
   az cosmosdb sql container list \
     --account-name $COSMOS_ACCOUNT \
     --resource-group "rg-<inject key="DeploymentID" enableCopy="false"/>" \
     --database-name $DATABASE_NAME \
     --query "[].name" \
     --output table
   ```

7. In the Azure portal, open your Azure Cosmos DB for NoSQL account, and then review the **Data Explorer** experience for database `<inject key="databaseName"></inject>` and container `<inject key="vectorContainerName"></inject>`.

8. Confirm that the container is dedicated to the semantic search portion of the workshop and is separate from the RAG container you used earlier: `<inject key="ragContainerName"></inject>`.

9. Review the expected vector design used by this lab:
   - The documents include a vector property used for similarity search.
   - The container uses a vector embedding policy that defines the vector path, datatype, dimensions, and distance function.
   - The indexing policy includes a vector index for the vector path.
   - The vector path is excluded from standard indexing to reduce write overhead.

10. Keep the portal open so that you can compare the app behavior with the stored data during the next tasks.

<validation step="Validation 2"/>

## Task 3: Complete the Python semantic search implementation

In this task, you will review and finish the Python functions that load embeddings, connect to Azure Cosmos DB, and issue a vector similarity query.

1. In VS Code, open the main Python file for the semantic search workflow. Depending on the staged project, this file might be named `app.py`, `semantic_search.py`, or be located under a `src` folder.

2. Open the environment file or configuration module used by the project and confirm that it references these lab values:
   - Cosmos DB account name: `<inject key="cosmosAccountName"></inject>`
   - Database name: `<inject key="databaseName"></inject>`
   - Vector container name: `<inject key="vectorContainerName"></inject>`

3. If the project uses an endpoint variable, confirm that it resolves to the Cosmos DB account endpoint for `<inject key="cosmosAccountName"></inject>`.

4. In the Python code, verify that authentication uses Microsoft Entra ID rather than an account key. The expected pattern is to use `DefaultAzureCredential` with `CosmosClient`.

5. If the app still needs your identity to receive data-plane permissions, run the following commands to locate your signed-in object ID and review existing SQL role assignments:

   ```azurecli
   $PRINCIPAL_ID = az ad signed-in-user show --query id --output tsv

   az cosmosdb sql role assignment list \
     --resource-group "rg-<inject key="DeploymentID" enableCopy="false"/>" \
     --account-name $COSMOS_ACCOUNT \
     --query "[].{principalId:principalId,scope:scope,roleDefinitionId:roleDefinitionId}" \
     --output table
   ```

6. If instructed by your lab proctor or if the assignment is missing, assign the built-in data contributor role at the account scope:

   ```azurecli
   $ROLE_DEFINITION_ID = az cosmosdb sql role definition list \
     --resource-group "rg-<inject key="DeploymentID" enableCopy="false"/>" \
     --account-name $COSMOS_ACCOUNT \
     --query "[?roleName=='Cosmos DB Built-in Data Contributor'].id | [0]" \
     --output tsv

   az cosmosdb sql role assignment create \
     --resource-group "rg-<inject key="DeploymentID" enableCopy="false"/>" \
     --account-name $COSMOS_ACCOUNT \
     --role-definition-id $ROLE_DEFINITION_ID \
     --principal-id $PRINCIPAL_ID \
     --scope "/"
   ```

7. Review the container connection code and confirm that it points to database `<inject key="databaseName"></inject>` and container `<inject key="vectorContainerName"></inject>`.

8. Locate the function that generates or loads the query embedding. In this workshop, use the embedding data and helper logic already staged with the lab files. Do not replace the exercise with a different model or external service.

9. Locate the function that performs the semantic query. Update it so that it uses a SQL query with `VectorDistance` and a `TOP` clause. The query pattern should follow this structure:

   ```sql
   SELECT TOP 5
       c.id,
       c.title,
       c.category,
       VectorDistance(c.embedding, @embedding) AS SimilarityScore
   FROM c
   WHERE c.category = @category
   ORDER BY VectorDistance(c.embedding, @embedding)
   ```

10. If your staged project uses a different vector field name, keep that field name exactly as provided in the starter code.

11. Add query parameters rather than concatenating raw values into the SQL statement.

12. Confirm that the query returns the highest-ranking matches first and that the application prints or displays the similarity score for each result.

13. Save your changes.

> [!Important]
> Azure Cosmos DB for NoSQL vector search should always use a `TOP N` clause. Without it, the query can consume more RUs and increase latency unnecessarily.

> [!Note]
> Vector search policies are applied when a new container is created. If you need a different vector policy or vector index policy, create a new container rather than trying to edit an existing vector-enabled container in place.

## Task 4: Run and validate the semantic search app

In this task, you will run the local semantic search app, test multiple prompts, and observe how metadata filters affect the ranked results.

1. In the VS Code terminal, make sure your virtual environment is still active.

2. If the project includes a setup or seed script for the semantic search dataset, run it now using the command documented in the staged files.

3. Start the semantic search app. Use the startup command provided in the project. A common pattern for the staged Flask app is:

   ```powershell
   python app.py
   ```

4. When the app starts, note the local URL shown in the terminal, such as `http://127.0.0.1:5000`.

5. Open the local app in a browser on the lab VM.

6. Submit a support-style search prompt that matches the staged dataset. For example, search for an issue related to billing, account access, or service configuration if those categories are included in your sample data.

7. Observe the returned results and confirm that the app displays the most relevant documents first.

8. Run the same search again with a metadata filter or category selection if the UI exposes one.

9. Compare the filtered results with the unfiltered results and note how metadata constraints reduce the candidate set before ranking.

10. Return to Azure portal **Data Explorer** and inspect one or more documents in `<inject key="vectorContainerName"></inject>` to verify that the stored items include both descriptive metadata and the vector field used by the query.

11. If the app logs the executed query or request diagnostics, review them in the terminal.

12. Stop the app after you confirm successful query behavior.

13. Record these observations for your own notes:
    - Why vector similarity helps semantic search return relevant results even when the wording differs.
    - Why metadata filtering is useful before or alongside similarity ranking.
    - Why the semantic search exercise uses a dedicated vector-enabled container rather than the RAG chunk container from Exercise 1.

## Summary

In this exercise, you extended the Cosmos DB environment from Exercise 1 to support semantic search. You verified the vector-search capability on the Azure Cosmos DB for NoSQL account, confirmed the vector container design, completed the Python logic that uses `DefaultAzureCredential` and `VectorDistance`, and tested how metadata filters and similarity ranking work together in the local app. In the next exercise, you will compare vector index strategies to understand performance and cost trade-offs at scale.