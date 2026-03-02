param(
    [string]$ProjectID = "project-5ab36d37-3e39-413e-a07",
    [string]$Zone = "europe-west4-b",
    [string]$InstanceName = "episteme-gpu-test-vm"
)

Write-Host "============= Episteme GCP GPU Auto-Deploy =============="
Write-Host "Project: $ProjectID"
Write-Host "Zone: $Zone"
Write-Host "Instance: $InstanceName"
Write-Host "========================================================="
Write-Host ""
Write-Host "[1/2] Creating GPU Virtual Machine (SPOT pricing)..."

# Ensure the deep learning image with CUDA 11.8 is used to bypass manual driver installation
gcloud compute instances create $InstanceName `
    --project=$ProjectID `
    --zone=$Zone `
    --machine-type=n1-standard-4 `
    --accelerator=type=nvidia-tesla-t4,count=1 `
    --image-family=common-cu121-debian-11-py310 `
    --image-project=deeplearning-platform-release `
    --maintenance-policy=TERMINATE `
    --provisioning-model=SPOT `
    --boot-disk-size=50GB `
    --tags=http-server,https-server,grpc-server

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create VM instance." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "✅ VM Instance Created Successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "[2/2] Connecting to VM via SSH..."
Write-Host "(This will open a connection. Type 'exit' to leave the VM when done)."
Write-Host ""

gcloud compute ssh $InstanceName --zone=$Zone --project=$ProjectID

Write-Host ""
Write-Host "============= Deployment Script Finished =============="
Write-Host "To delete this VM and stop charges, run:"
Write-Host "gcloud compute instances delete $InstanceName --zone=$Zone --project=$ProjectID --quiet"
