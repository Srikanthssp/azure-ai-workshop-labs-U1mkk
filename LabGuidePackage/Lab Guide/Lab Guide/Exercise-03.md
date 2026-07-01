# Exercise 03: Optimize Query Performance with Vector Indexes on Azure Cosmos DB for NoSQL

### Estimated Duration: 45 Minutes

## Scenario

Your semantic search prototype is working, but your team now needs evidence for which vector index strategy to use in production. In this exercise, you will compare three Azure Cosmos DB for NoSQL containers that use `flat`, `quantizedFlat`, and `diskANN` vector index types, run the prepared benchmark workflow from the lab VM, and interpret the trade-offs in latency, RU consumption, and recall characteristics.

## Overview

In this exercise, you will review the pre-staged performance comparison project, verify the three index-specific containers, run the local Python benchmark, and analyze how each vector index behaves for the same search workload.

## Objectives

- Task 1: Review the comparison workspace and verify vector index containers
- Task 2: Run comparative vector search benchmarks
- Task 3: Interpret performance trade-offs and summarize recommendations

## Task 1: Review the comparison workspace and verify vector index containers

In this task, you will sign in to Azure, open the pre-staged Exercise 3 project on the lab VM, and confirm that the three comparison containers exist in the shared Cosmos DB database.

1. On the lab VM, open a browser and go to <https://portal.azure.com>.
2. Sign in with the following credentials:
   - **Username:** `<inject key="AzureAdUserEmail"></inject>`
   - **Password:** `<inject key="AzureAdUserPassword"></inject>`
3. Confirm that you are working in the correct lab subscription by checking that the subscription ID is **`<inject key="SubscriptionID"></inject>`**.
4. On the lab VM, open **Windows Terminal**.
5. Run the following command to sign in with Azure CLI if the terminal session is not already authenticated:

   ```bash
   az login
   ```

6. If prompted, select the subscription **`<inject key="SubscriptionID"></inject>`**.
7. Change to the pre-staged lab project root:

   ```bash
   cd <inject key="projectRootPath"></inject>
   ```

8. Review the deployment identifier for this lab environment. Your deployment is **`<inject key="DeploymentID" enableCopy="false"></inject>`**.
9. Open the Exercise 3 project folder in Visual Studio Code.

   ```bash
   code .
   ```

10. In Visual Studio Code, locate the performance comparison project and review the files that will be used in this exercise, such as the benchmark script, configuration file, and sample dataset.
11. Return to the Azure portal, open your Azure Cosmos DB account **`<inject key="cosmosAccountName"></inject>`**, and then open **Data Explorer**.
12. Expand the database **`<inject key="databaseName"></inject>`** and verify that the following containers are present:
    - **`<inject key="flatContainerName"></inject>`**
    - **`<inject key="quantizedContainerName"></inject>`**
    - **`<inject key="diskAnnContainerName"></inject>`**
13. Select each container and review its items to confirm that benchmark documents are available for testing.
14. Optional: If the resource group name for your lab is provided by your instructor or visible in the portal overview, use that exact name to verify containers from the command line with `az cosmosdb sql container list`.

> [!Important]
> In Azure Cosmos DB for NoSQL, vector policies and vector indexes are defined at container creation time. If you need a different vector index type, you typically create a different container instead of modifying the existing one.

> [!Tip]
> Azure Cosmos DB documentation recommends using `TOP N` with `VectorDistance` queries to avoid unnecessary RU consumption and extra latency.

<validation step="Validation 3"/>

## Task 2: Run comparative vector search benchmarks

In this task, you will execute the prepared Python benchmark so you can compare the same search workload against `flat`, `quantizedFlat`, and `diskANN` containers.

1. In Visual Studio Code, open the benchmark script for Exercise 3 and review the section that maps the three container names:
   - `flat` -> `<inject key="flatContainerName"></inject>`
   - `quantizedFlat` -> `<inject key="quantizedContainerName"></inject>`
   - `diskANN` -> `<inject key="diskAnnContainerName"></inject>`
2. Review the query logic and confirm that the benchmark uses the `VectorDistance` function and a `TOP N` query pattern.
3. Open a terminal in Visual Studio Code.
4. If a Python virtual environment is included with the starter project, activate it. Otherwise, use the environment already configured on the VM.
5. From the project root, install dependencies if the lab instructions indicate they are not already present:

   ```bash
   pip install -r requirements.txt
   ```

6. Run the benchmark script for the first time to compare all three containers.

   ```bash
   python exercise-03\benchmark_vector_indexes.py
   ```

7. Watch the output and identify the values reported for each container, including:
   - elapsed query time
   - RU consumption, if surfaced by the script
   - returned top matches or similarity scores
8. Run the benchmark a second time so you can compare whether the timing pattern is consistent.
9. If the script supports parameters, rerun it with a different `TOP N` value or filter option to observe how workload scope affects the results.
10. Record your observations in a table like the following:

   | Index type | Container | Query time | RU cost | Result quality notes |
   |---|---|---:|---:|---|
   | `flat` | `<inject key="flatContainerName"></inject>` |  |  |  |
   | `quantizedFlat` | `<inject key="quantizedContainerName"></inject>` |  |  |  |
   | `diskANN` | `<inject key="diskAnnContainerName"></inject>` |  |  |  |

11. If the script exposes the generated query vector or filter values, review them so you understand that all three containers are being compared with the same input.
12. Keep the terminal output available for the discussion in the next task.

> [!Note]
> The `flat` index is an exact brute-force search and can provide full recall, but it is limited to 505 dimensions. The `quantizedFlat` and `diskANN` index types support up to 4,096 dimensions.

> [!Note]
> Microsoft Learn notes that `quantizedFlat` and `diskANN` require at least 1,000 indexed vectors to avoid falling back to a full scan. If your dataset is smaller than that threshold, performance differences can be less pronounced.

## Task 3: Interpret performance trade-offs and summarize recommendations

In this task, you will connect your benchmark results to the documented behavior of each Azure Cosmos DB vector index type.

1. Review your recorded results from Task 2.
2. Compare the `flat` container results with the `quantizedFlat` container results.
3. Identify whether `quantizedFlat` reduced latency or RU usage relative to `flat`, and note whether the top results remained similar.
4. Compare the `diskANN` container results with the other two containers.
5. Determine whether `diskANN` delivered the best balance for the dataset size used in this lab.
6. In a text file or your lab notes, answer the following questions:
   - Which index type produced the most predictable result quality?
   - Which index type appeared to use the fewest RUs?
   - Which index type would you prefer for a smaller, highly filtered search scope?
   - Which index type would you prefer for a larger-scale vector search workload?
7. Use the following guidance as you write your conclusions:
   - `flat` is best when exact recall is the top priority and vector dimensions stay within the documented limit.
   - `quantizedFlat` is a strong option for smaller or filtered workloads where slightly reduced accuracy is acceptable in exchange for lower cost and better speed.
   - `diskANN` is generally the best fit for large-scale workloads where low latency and high throughput are critical.
8. If your benchmark results do not clearly match the expected pattern, consider whether any of the following factors could explain the difference:
   - the dataset size is still relatively small
   - the query filter narrows the candidate set significantly
   - the index is still warming up or recently populated
   - the script is measuring a mixed workload beyond raw vector search time
9. Save your notes for later review.

> [!Important]
> Benchmark results are workload-dependent. Use this exercise to understand the documented trade-offs, but always validate performance against the actual data size, embedding dimensions, and query filters of your application.

## Summary

In this exercise, you compared three Azure Cosmos DB for NoSQL vector index strategies by testing `flat`, `quantizedFlat`, and `diskANN` containers with the same benchmark workflow. You verified the comparison containers, ran the prepared Python benchmark, and interpreted how each index type affects latency, RU cost, and recall behavior. You can now explain when exact search is appropriate, when quantization is a practical compromise, and when DiskANN is the preferred option for larger-scale vector search scenarios.
