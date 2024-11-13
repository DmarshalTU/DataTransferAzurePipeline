#!/bin/bash

# Configuration
STORAGE_ACCOUNT="ASDFG"
SUBSCRIPTION="ASDFGSUB"
RESOURCE_GROUP="your-resource-group"  # Add your resource group name

echo "Starting container cleanup process..."
cleanup_log="cleanup_summary.log"
echo "Cleanup Summary - Started at $(date)" > $cleanup_log

# Login to Azure (if not already logged in)
# az login
# az account set --subscription $SUBSCRIPTION

# Generate SAS token for target with delete permissions
echo "Generating SAS token..."
target_sas=$(az storage account generate-sas \
  --permissions rwdlacup \
  --account-name $STORAGE_ACCOUNT \
  --services b \
  --resource-types co \
  --expiry "$(date -u -d "1 day" '+%Y-%m-%dT%H:%MZ')" \
  --only-show-errors \
  -o tsv)

# List all containers
echo "Listing containers..."
containers=$(az storage container list \
  --account-name $STORAGE_ACCOUNT \
  --sas-token "$target_sas" \
  --query "[].name" -o tsv)

total_containers=$(echo "$containers" | wc -l)
echo "Found $total_containers containers to process"
echo "Total containers to process: $total_containers" >> $cleanup_log

# Process each container
current=0
while IFS= read -r container; do
  current=$((current + 1))
  echo "Processing container $current/$total_containers: $container"
  
  # Get blob count before deletion
  blob_count=$(az storage blob list \
    --container-name "$container" \
    --account-name $STORAGE_ACCOUNT \
    --sas-token "$target_sas" \
    --query "length(@)" -o tsv)
  
  echo "Container $container has $blob_count blobs to delete"
  
  if [ "$blob_count" -gt 0 ]; then
    echo "Emptying container: $container"
    
    # Delete all blobs in the container
    az storage blob delete-batch \
      --source "$container" \
      --account-name $STORAGE_ACCOUNT \
      --sas-token "$target_sas" \
      --delete-snapshots include \
      --only-show-errors
    
    if [ $? -eq 0 ]; then
      echo "✓ Successfully emptied container: $container" >> $cleanup_log
      echo "✓ Deleted $blob_count blobs from $container"
    else
      echo "❌ Error emptying container: $container" >> $cleanup_log
    fi
  else
    echo "Container $container is already empty" >> $cleanup_log
  fi
  
  # Verify container is empty
  remaining_blobs=$(az storage blob list \
    --container-name "$container" \
    --account-name $STORAGE_ACCOUNT \
    --sas-token "$target_sas" \
    --query "length(@)" -o tsv)
  
  if [ "$remaining_blobs" -eq 0 ]; then
    echo "✓ Verified container $container is empty" >> $cleanup_log
  else
    echo "❌ Container $container still has $remaining_blobs blobs" >> $cleanup_log
  fi
  
  # Progress percentage
  progress=$((current * 100 / total_containers))
  echo "Progress: $progress%"
  
done <<< "$containers"

# Final summary
echo -e "\n=== Cleanup Summary ===" >> $cleanup_log
echo "Cleanup completed at $(date)" >> $cleanup_log
echo "Total containers processed: $total_containers" >> $cleanup_log

echo "Cleanup process completed. Check cleanup_summary.log for details."
