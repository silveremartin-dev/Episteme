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
    --tags=http-server,https-server,grpc-server `
    --metadata=startup-script="#!/bin/bash
    sudo apt-get update
    sudo apt-get install -y maven git wget
    
    # 1. Install Java 25 GA
    wget https://download.java.net/java/GA/jdk25.0.2/b1e0dfa218384cb9959bdcb897162d4e/10/GPL/openjdk-25.0.2_linux-x64_bin.tar.gz -O /tmp/jdk25.tar.gz
    sudo mkdir -p /usr/lib/jvm/java-25-openjdk-amd64
    sudo tar -xzf /tmp/jdk25.tar.gz -C /usr/lib/jvm/java-25-openjdk-amd64 --strip-components=1
    export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64
    export PATH=`$JAVA_HOME/bin:`$PATH
    
    # 2. Clone Episteme codebase (using user account directory to avoid root permission issues)
    su - spinradnorman -c '
    export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64
    export PATH=`$JAVA_HOME/bin:`$PATH
    git clone https://github.com/silveremartin-dev/Episteme.git ~/Episteme
    cd ~/Episteme
    
    # 3. Formally install local MPJ dependency
    mvn install:install-file -Dfile=libs/mpj.jar -DgroupId=org.mpjexpress -DartifactId=mpj -Dversion=0.44 -Dpackaging=jar
    
    # 4. Build exactly the server module required for Docker (to avoid full project OOM)
    mvn package -pl episteme-server -am -DskipTests
    
    # 5. Build the GPU container
    docker build -t episteme-gpu-test -f docker/Dockerfile.gpu .
    '
    "

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create VM instance." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "✅ VM Instance Created Successfully!" -ForegroundColor Green
Write-Host "⏳ The VM is currently running a startup script to install Java 25, build Episteme, and compile the Docker container."
Write-Host "⏳ This automated process takes approximately 10-15 minutes."
Write-Host ""
Write-Host "[2/2] Connecting to VM via SSH..."
Write-Host "(This will open a connection. Type 'exit' to leave the VM when done)."
Write-Host ""

gcloud compute ssh $InstanceName --zone=$Zone --project=$ProjectID

Write-Host ""
Write-Host "============= Deployment Script Finished =============="
Write-Host "To delete this VM and stop charges, run:"
Write-Host "gcloud compute instances delete $InstanceName --zone=$Zone --project=$ProjectID --quiet"
