# empty_containers.ps1

# Configuration
$STORAGE_ACCOUNT = "ASDFG"
$SUBSCRIPTION = "ASDFGSUB"
$RESOURCE_GROUP = "your-resource-group"  # Add your resource group name

Write-Host "Starting container cleanup process..." -ForegroundColor Green
$cleanup_log = "cleanup_summary.log"
"Cleanup Summary - Started at $(Get-Date)" | Out-File -FilePath $cleanup_log

# Login to Azure (uncomment if needed)
# az login
# az account set --subscription $SUBSCRIPTION

# Generate SAS token for target with delete permissions
Write-Host "Generating SAS token..." -ForegroundColor Yellow
$expiry = (Get-Date).AddDays(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mmZ")
$target_sas = az storage account generate-sas `
    --permissions rwdlacup `
    --account-name $STORAGE_ACCOUNT `
    --services b `
    --resource-types co `
    --expiry $expiry `
    --only-show-errors `
    -o tsv

# List all containers
Write-Host "Listing containers..." -ForegroundColor Yellow
$containers = az storage container list `
    --account-name $STORAGE_ACCOUNT `
    --sas-token $target_sas `
    --query "[].name" -o tsv

$total_containers = ($containers -split "`n").Count
Write-Host "Found $total_containers containers to process" -ForegroundColor Cyan
"Total containers to process: $total_containers" | Out-File -FilePath $cleanup_log -Append

# Process each container
$current = 0
foreach ($container in $containers -split "`n") {
    $current++
    Write-Host "Processing container $current/$total_containers`: $container" -ForegroundColor Yellow
    
    # Get blob count before deletion
    $blob_count = az storage blob list `
        --container-name $container `
        --account-name $STORAGE_ACCOUNT `
        --sas-token $target_sas `
        --query "length(@)" -o tsv
    
    Write-Host "Container $container has $blob_count blobs to delete" -ForegroundColor Cyan
    
    if ($blob_count -gt 0) {
        Write-Host "Emptying container: $container" -ForegroundColor Yellow
        
        # Delete all blobs in the container
        $deleteResult = az storage blob delete-batch `
            --source $container `
            --account-name $STORAGE_ACCOUNT `
            --sas-token $target_sas `
            --delete-snapshots include `
            --only-show-errors

        if ($LASTEXITCODE -eq 0) {
            "✓ Successfully emptied container: $container" | Out-File -FilePath $cleanup_log -Append
            Write-Host "✓ Deleted $blob_count blobs from $container" -ForegroundColor Green
        }
        else {
            "❌ Error emptying container: $container" | Out-File -FilePath $cleanup_log -Append
            Write-Host "❌ Error emptying container: $container" -ForegroundColor Red
        }
    }
    else {
        "Container $container is already empty" | Out-File -FilePath $cleanup_log -Append
        Write-Host "Container $container is already empty" -ForegroundColor Cyan
    }
    
    # Verify container is empty
    $remaining_blobs = az storage blob list `
        --container-name $container `
        --account-name $STORAGE_ACCOUNT `
        --sas-token $target_sas `
        --query "length(@)" -o tsv
    
    if ($remaining_blobs -eq 0) {
        "✓ Verified container $container is empty" | Out-File -FilePath $cleanup_log -Append
        Write-Host "✓ Verified container $container is empty" -ForegroundColor Green
    }
    else {
        "❌ Container $container still has $remaining_blobs blobs" | Out-File -FilePath $cleanup_log -Append
        Write-Host "❌ Container $container still has $remaining_blobs blobs" -ForegroundColor Red
    }
    
    # Progress percentage
    $progress = [math]::Round(($current * 100 / $total_containers), 2)
    Write-Progress -Activity "Emptying Containers" -Status "$progress% Complete" -PercentComplete $progress
}

# Final summary
"`n=== Cleanup Summary ===" | Out-File -FilePath $cleanup_log -Append
"Cleanup completed at $(Get-Date)" | Out-File -FilePath $cleanup_log -Append
"Total containers processed: $total_containers" | Out-File -FilePath $cleanup_log -Append

Write-Host "`nCleanup process completed. Check cleanup_summary.log for details." -ForegroundColor Green
