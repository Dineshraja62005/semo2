# PowerShell deployment script for Blue-Green Deployment Setup
Write-Host "==== Starting Blue-Green Deployment Setup Process ====" -ForegroundColor Green

# Step 1: Terraform Infrastructure Deployment
Write-Host "===== Step 1: Deploying Infrastructure with Terraform =====" -ForegroundColor Cyan
Set-Location -Path terraform
terraform init
terraform plan
terraform apply -auto-approve

# Capture Jenkins IP address and EKS cluster name
$JENKINS_IP = terraform output -raw jenkins_public_ip
$EKS_CLUSTER_NAME = terraform output -raw eks_cluster_name
$AWS_REGION = "us-east-1" # Update this based on your configuration

Write-Host "Jenkins Server IP: $JENKINS_IP" -ForegroundColor Yellow
Write-Host "EKS Cluster Name: $EKS_CLUSTER_NAME" -ForegroundColor Yellow

# Update Ansible inventory with Jenkins IP
Set-Location -Path ..\ansible
(Get-Content -Path inventory) -replace '\$JENKINS_IP', $JENKINS_IP | Set-Content -Path inventory
Write-Host "Updated Ansible inventory with Jenkins IP: $JENKINS_IP" -ForegroundColor Green

# Step 2: Configure Jenkins with Ansible (using WSL)
Write-Host "===== Step 2: Configuring Jenkins with Ansible =====" -ForegroundColor Cyan

# Get the key path
$keyPath = Read-Host -Prompt "Enter the full path to your AWS key file (e.g., C:\Users\username\vockey.pem)"
$keyPath = $keyPath.Trim('"') # Remove any quotes
if (-not (Test-Path $keyPath)) {
    Write-Host "Key file not found at $keyPath. Please check the path." -ForegroundColor Red
    exit 1
}

# Convert Windows path to WSL path
$wslKeyPath = $keyPath -replace '\\', '/' -replace '^([A-Za-z]):', '/mnt/$1'
Write-Host "WSL Key Path: $wslKeyPath" -ForegroundColor Gray

# Set environment variables for Ansible
$env:EKS_CLUSTER_NAME = $EKS_CLUSTER_NAME
$env:AWS_REGION = $AWS_REGION

# Get current paths for WSL
$wslCurrentDir = (Get-Location).Path -replace '\\', '/' -replace '^([A-Za-z]):', '/mnt/$1'

# Run Ansible playbook using WSL
Write-Host "Running Ansible playbook to configure Jenkins through WSL..." -ForegroundColor Green
$ansibleCommand = "cd '$wslCurrentDir' && ansible-playbook -i inventory install-jenkins-bluegreen.yml --private-key='$wslKeyPath'"
Write-Host "Executing: $ansibleCommand" -ForegroundColor Gray
wsl bash -c "$ansibleCommand"

# Step 3: Configure Jenkins and Setup Pipeline
Write-Host "===== Step 3: Jenkins Manual Configuration Instructions =====" -ForegroundColor Cyan
Write-Host "1. Access Jenkins at: http://$JENKINS_IP`:8080" -ForegroundColor Green
Write-Host "2. Enter the admin password displayed in Ansible output" -ForegroundColor Green
Write-Host "3. Install suggested plugins plus: GitHub Integration, Docker Pipeline, Kubernetes, and Blue Ocean" -ForegroundColor Green
Write-Host "4. Create an admin user" -ForegroundColor Green
Write-Host "5. Configure Jenkins:" -ForegroundColor Green
Write-Host "   - Go to 'Manage Jenkins' > 'Global Tool Configuration'" -ForegroundColor Green
Write-Host "   - Add Maven with name 'Maven'" -ForegroundColor Green
Write-Host "   - Add Docker with name 'Docker'" -ForegroundColor Green
Write-Host "6. Add credentials:" -ForegroundColor Green
Write-Host "   - Go to 'Manage Jenkins' > 'Manage Credentials'" -ForegroundColor Green
Write-Host "   - Add Docker Hub credentials with ID 'docker-hub-creds'" -ForegroundColor Green
Write-Host "   - Add GitHub credentials if using private repository" -ForegroundColor Green
Write-Host "7. Create a new Pipeline job:" -ForegroundColor Green
Write-Host "   - Click 'New Item'" -ForegroundColor Green
Write-Host "   - Enter a name like 'blue-green-deployment' and select 'Pipeline'" -ForegroundColor Green
Write-Host "   - In Pipeline configuration, select 'Pipeline script from SCM'" -ForegroundColor Green
Write-Host "   - Select Git as SCM and enter your repository URL" -ForegroundColor Green
Write-Host "   - Set the Script Path to 'Jenkinsfile'" -ForegroundColor Green
Write-Host "   - Configure GitHub webhook at: http://$JENKINS_IP`:8080/github-webhook/" -ForegroundColor Green
Write-Host "   - Click Save" -ForegroundColor Green

Write-Host "===== Step 4: EKS Cluster Connection Information =====" -ForegroundColor Cyan
Write-Host "To manually connect to the EKS cluster:" -ForegroundColor Green
Write-Host "aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME" -ForegroundColor White

Write-Host "===== Blue-Green Deployment Testing =====" -ForegroundColor Green
Write-Host "1. Make a small change to your application code" -ForegroundColor Green
Write-Host "2. Push the change to your GitHub repository" -ForegroundColor Green
Write-Host "3. Jenkins will automatically trigger the pipeline" -ForegroundColor Green
Write-Host "4. Observe the blue-green deployment process:" -ForegroundColor Green
Write-Host "   - New version deploys to inactive environment (blue or green)" -ForegroundColor Green
Write-Host "   - Pipeline will wait for approval to switch traffic" -ForegroundColor Green
Write-Host "   - After approval, traffic switches to the new version" -ForegroundColor Green
Write-Host "   - Old version remains available for immediate rollback if needed" -ForegroundColor Green

Write-Host "==== Blue-Green Deployment Setup Complete ====" -ForegroundColor Green

# Return to root directory
Set-Location -Path ..