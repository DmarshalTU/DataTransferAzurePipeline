# Azure Storage Migration Solution Comparison

Denis Tu

## Current Python Solution vs. Proposed Pipeline Approach

### Architecture Comparison

| Feature | Python Scripts | Azure DevOps Pipeline |
|---------|---------------|----------------------|
| AzCopy Usage | Yes (via subprocess) | Yes (direct integration) |
| Execution Environment | Local/Server Python Runtime | Azure-managed Compute |
| Authentication | Manual SAS Token Management | Managed Identities + Auto SAS |
| Parallel Processing | Limited by Python GIL | Native Container-level Parallelism |
| Error Handling | Basic Python try/catch | Built-in Pipeline Retry Logic |

### Technical Advantages of Pipeline

1. **Improved Parallelization**
   - Python: Sequential container processing with `--parallel-level=32` for files
   - Pipeline: 
     - Parallel container-level operations
     - Configurable parallel transfers (up to 128)
     - No Python GIL limitations

2. **Resource Management**
   - Python:
     - Fixed compute resources
     - Local memory constraints
     - Process-level limitations
   - Pipeline:
     - Auto-scaling compute
     - Managed memory allocation
     - Enterprise-grade infrastructure

3. **Operational Benefits**
   - Python:
     ```python
     # Current approach
     def ensure_container_exists(container_name):
         make_command = f'azcopy make "https://{target_storage_account}..."'
         os.system(make_command)  # Limited error handling
     ```
   - Pipeline:
     ```yaml
     # Pipeline approach
     steps:
     - task: AzureCLI@2
       name: MigrateContainer
       continueOnError: true
       retryCountOnTaskFailure: 3
     ```

4. **Security Improvements**
   - Python:
     - Manual SAS token management
     - Tokens in code/environment
   - Pipeline:
     - Azure Key Vault integration
     - Managed identities
     - Automatic token rotation

### Performance Metrics

| Operation | Python Scripts | Pipeline |
|-----------|---------------|-----------|
| Container Creation | Sequential | Parallel |
| Blob Transfer | 32 parallel files | 128 parallel operations |
| Error Recovery | Manual restart | Automatic retry |
| Progress Tracking | Basic logging | Built-in analytics |

### Cost-Benefit Analysis

1. **Development Costs**
   - Python: Higher maintenance overhead
   - Pipeline: Managed service, minimal maintenance

2. **Operational Costs**
   - Python: Dedicated compute resources
   - Pipeline: Pay-per-use, auto-scaling

3. **Time Efficiency**
   - Python: Manual execution and monitoring
   - Pipeline: Automated scheduling and monitoring

### Migration Process Comparison

Python Approach (Current)
```python
def main():
containers = list_containers()
for container in containers: # Sequential processing
ensure_container_exists(container)
sync_command = f'azcopy sync...'
os.system(sync_command)
```

Pipeline Approach (Proposed)
```yaml
jobs:
job: Migration
strategy:
parallel: 10 # Concurrent container processing
steps:
task: AzureCLI@2
inputs:
scriptType: 'bash'
inlineScript: |
azcopy copy ... --parallel-level=128
```


### Why Pipeline is Superior

1. **Enterprise Features**
   - Built-in monitoring and alerts
   - Integration with Azure DevOps boards
   - Automated deployment gates
   - Compliance tracking

2. **Scalability**
   - Handles larger datasets efficiently
   - Better resource utilization
   - Automatic performance optimization

3. **Reliability**
   - Checkpoint and resume capability
   - Automated validation
   - Built-in disaster recovery

4. **Maintainability**
   - No custom code maintenance
   - Version controlled infrastructure
   - Standardized deployment process

## Implementation Timeline
- Pipeline Setup: 2-3 hours
- Testing: 4-6 hours
- Production Ready: 1-2 days

## References
- [Azure Pipeline Performance Benchmarks](https://docs.microsoft.com/en-us/azure/devops/pipelines/performance)
- [AzCopy Best Practices](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-optimize)

# Azure Storage Migration Pipeline

## Overview
This Azure DevOps pipeline enables automated migration of Azure Storage resources (Blobs, File Shares, and Tables) between different storage accounts, potentially across different subscriptions. The pipeline supports selective migration based on last modified date and includes performance optimization parameters.

## Features
- Cross-subscription migration support
- Time-based filtering of resources
- Parallel processing with configurable parameters
- Comprehensive logging and timing metrics
- Support for:
  - Blob containers
  - File shares
  - Tables
- Pre and post-migration validation

## Prerequisites
- Azure DevOps environment
- Two Azure subscriptions with storage accounts
- Service connections in Azure DevOps for both subscriptions
- Appropriate permissions on both storage accounts
- Custom agent pool with required capabilities

## Pipeline Parameters

### Transfer Settings

```yaml
parameters:
name: blockSize
type: number
default: 256
# Block size in MB for AzCopy operations
name: concurrency
type: number
default: 128
# Number of parallel operations
name: maxRetries
type: number
default: 10
# Maximum retry attempts for failed transfers
name: batchSize
type: number
default: 50000
# Batch size for table operations
```

### Time Filter Options


```yaml
name: modifiedSince
type: string
default: '3months'
values:
'7days'
'1month'
'3months'
'6months'
'1year'
'all'
```


## Pipeline Structure

### 1. Pre-Migration Setup Stage
Configures the target storage account for optimal migration:

```yaml
stage: PreMigrationSetup
jobs:
job: PrepareStorage
steps:
task: AzureCLI@2
name: ConfigureStorageNetworking
# Configures networking and access settings
```


### 2. Migration Stage
Performs the actual migration in several steps:

#### a. Generate SAS Tokens

```yaml
task: AzureCLI@2
name: GenerateSourceSAS
# Generates read-only SAS token for source
task: AzureCLI@2
name: GenerateTargetSAS
# Generates read-write SAS token for target
```


#### b. Prepare Source Data


```yaml
task: AzureCLI@2
name: PrepareSourceData
# Lists all resources to be migrated
```


#### c. Perform Migration

```yaml
task: AzureCLI@2
name: PerformMigration
# Executes the migration using AzCopy
```


### 3. Post-Migration Validation
Validates the migration success:

```yaml
stage: PostMigrationValidation
jobs:
job: Validate
# Compares source and target metrics
```


## Usage Examples

### Basic Migration

```yaml
Migrate all data modified in the last 3 months
parameters:
modifiedSince: '3months'
blockSize: 256
concurrency: 128
```


### Full Migration

```yaml
Migrate all data regardless of modification date
parameters:
modifiedSince: 'all'
blockSize: 256
concurrency: 128
```


### Performance-Optimized Migration

```yaml
For high-performance networks
parameters:
modifiedSince: '1month'
blockSize: 512
concurrency: 256
maxRetries: 15
```


### Limited-Resource Migration

```yaml
For constrained environments
parameters:
modifiedSince: '1month'
blockSize: 128
concurrency: 64
maxRetries: 5
```


## Configuration

### Required Variables

```yaml
variables:
SOURCE_ACCOUNT: 'source-storage-account-name'
TARGET_ACCOUNT: 'target-storage-account-name'
```


### Service Connections
Configure these in Azure DevOps:
- Source subscription: `QWERT_SUB`
- Target subscription: `ASDF_SUB`

## Logging and Monitoring

### Migration Logs
- Location: `migration_logs/`
- Files:
  - `migration_summary.log`: Overall migration summary
  - `{container}_blob_migration.log`: Individual container logs
  - `{share}_file_migration.log`: Individual share logs

### Summary Log Format

```text
text
Migration Summary - Started at [timestamp]
=== Blob Migration ===
Container [name] completed in [X] seconds
Total blob migration time: [X] seconds
=== File Share Migration ===
Share [name] completed in [X] seconds
Total file share migration time: [X] seconds
=== Table Migration ===
Table [name] completed in [X] seconds
Total table migration time: [X] seconds
=== Migration Summary ===
Total migration time: [X] seconds
Blob migration: [X] seconds
File share migration: [X] seconds
Table migration: [X] seconds
```


## Performance Optimization

### Recommended Settings by Scenario

#### High-Speed Network (10Gbps+)

```yaml
blockSize: 512
concurrency: 256
maxRetries: 15
```


#### Standard Network (1Gbps)

```yaml
blockSize: 256
concurrency: 128
maxRetries: 10
```





#### Limited Network (<100Mbps)

```yaml
blockSize: 128
concurrency: 64
maxRetries: 5
```


## Troubleshooting

### Common Issues

1. **Permission Errors**
   - Verify service connection permissions
   - Check SAS token permissions
   - Ensure storage account access policies

2. **Network Timeouts**
   - Reduce concurrency
   - Increase retry count
   - Check network connectivity

3. **Resource Constraints**
   - Reduce block size
   - Lower concurrency
   - Increase job timeout

### Error Recovery
- Pipeline can be safely rerun
- AzCopy automatically handles resume of failed transfers
- Existing resources are skipped by default

## Best Practices

1. **Pre-Migration**
   - Validate source and target connectivity
   - Estimate data volume
   - Test with small subset first

2. **During Migration**
   - Monitor logs actively
   - Watch for throttling
   - Check network utilization

3. **Post-Migration**
   - Validate data integrity
   - Compare metrics
   - Archive logs

## Security Considerations

1. **SAS Tokens**
   - Limited duration (7 days)
   - Minimum required permissions
   - Separate tokens for source and target

2. **Network Security**
   - Private endpoints where possible
   - Network rules on storage accounts
   - Restricted service access

## Support and Maintenance

### Regular Updates
- Review and update parameter defaults
- Check for AzCopy updates
- Validate service connection health

### Monitoring
- Track migration times
- Monitor resource usage
- Review error patterns

## License