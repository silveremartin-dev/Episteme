#!/bin/bash

# Configuration
PROJECT_ID="project-5ab36d37-3e39-413e-a07"
ZONE="europe-west4-b"
INSTANCE_NAME="episteme-gpu-test-vm"

# Retrieve current GCP authenticated user
USER_EMAIL=$(gcloud config get-value account)
if [ -z "$USER_EMAIL" ]; then
    echo "❌ You are not logged into gcloud. Please run: gcloud auth login"
    exit 1
fi
# Extract username from email (everything before @)
SSH_USER=$(echo "$USER_EMAIL" | cut -d@ -f1)

echo "============= Episteme GCP GPU Auto-Deploy =============="
echo "Project: $PROJECT_ID"
echo "Zone: $ZONE"
echo "Instance: $INSTANCE_NAME"
echo "Target User: $SSH_USER"
echo "========================================================="
echo ""
echo "[1/2] Creating GPU Virtual Machine (SPOT pricing)..."

gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type=n1-standard-4 \
    --accelerator=type=nvidia-tesla-t4,count=1 \
    --image-family=common-cu121-debian-11-py310 \
    --image-project=deeplearning-platform-release \
    --maintenance-policy=TERMINATE \
    --provisioning-model=SPOT \
    --boot-disk-size=50GB \
    --tags=http-server,https-server,grpc-server \
    --metadata=startup-script="#!/bin/bash
    sudo apt-get update
    sudo apt-get install -y maven git wget
    
    # 1. Install Java 25 GA
    wget https://download.java.net/java/GA/jdk25.0.2/b1e0dfa218384cb9959bdcb897162d4e/10/GPL/openjdk-25.0.2_linux-x64_bin.tar.gz -O /tmp/jdk25.tar.gz
    sudo mkdir -p /usr/lib/jvm/java-25-openjdk-amd64
    sudo tar -xzf /tmp/jdk25.tar.gz -C /usr/lib/jvm/java-25-openjdk-amd64 --strip-components=1
    export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64
    export PATH=\$JAVA_HOME/bin:\$PATH
    
    # 2. Clone Episteme codebase
    su - $SSH_USER -c '
    export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64
    export PATH=\$JAVA_HOME/bin:\$PATH
    git clone https://github.com/silveremartin-dev/Episteme.git ~/Episteme
    cd ~/Episteme
    
    # 3. Formally install local MPJ dependency
    mvn install:install-file -Dfile=libs/mpj.jar -DgroupId=org.mpjexpress -DartifactId=mpj -Dversion=0.44 -Dpackaging=jar
    
    # 4. Build exactly the server and benchmark modules required for Docker (to avoid full project OOM)
    mvn package -pl episteme-server,episteme-benchmarks -am -DskipTests -Djavacpp.platform=linux-x86_64
    
    # 5. Build the GPU container
    docker build -t episteme-gpu-test -f docker/Dockerfile.gpu .
    '
    "

if [ $? -ne 0 ]; then
    echo "❌ Failed to create VM instance."
    exit 1
fi

echo "✅ VM Instance Created Successfully!"
echo "⏳ The VM is currently running a startup script to automatically install Java 25, build Episteme, and compile the Docker container."
echo "⏳ This automated process takes approximately 10-15 minutes."
echo ""
echo "[2/2] Connecting to VM via SSH..."
echo "(This will open a connection. Type 'exit' to leave the VM when done)."
echo ""

gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --project="$PROJECT_ID"

echo ""
echo "============= Deployment Script Finished =============="
echo "To delete this VM and stop charges, run:"
echo "gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --project=$PROJECT_ID --quiet"
