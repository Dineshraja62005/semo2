# PowerShell deployment script using Ansible in Docker
Write-Host "==== Starting Deployment Process with Docker-based Ansible ====" -ForegroundColor Green

# Step 1: Check for Docker
try {
    $dockerVersion = docker --version
    Write-Host "Docker is installed: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "Docker is not installed. Please install Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Step 2: Terraform Infrastructure Deployment
Write-Host "===== Step 1: Deploying Infrastructure with Terraform =====" -ForegroundColor Cyan
Set-Location -Path terraform
terraform init
terraform plan
terraform apply -auto-approve

# Capture Jenkins IP address - use try/catch in case Terraform failed
try {
    $JENKINS_IP = terraform output -raw jenkins_public_ip
    Write-Host "Jenkins Server IP: $JENKINS_IP" -ForegroundColor Yellow
} catch {
    Write-Host "Failed to get Jenkins IP. Check if Terraform deployment succeeded." -ForegroundColor Red
    Set-Location -Path ..
    exit 1
}

# Update Ansible inventory with Jenkins IP
Set-Location -Path ..\ansible
(Get-Content -Path inventory) -replace '\$JENKINS_IP', $JENKINS_IP | Set-Content -Path inventory
Write-Host "Updated Ansible inventory with Jenkins IP: $JENKINS_IP" -ForegroundColor Green

# Step 3: Pull Ansible Docker image if needed
Write-Host "===== Step 2: Preparing Docker container with Ansible =====" -ForegroundColor Cyan
docker pull cytopia/ansible

# Step 4: Configure key path
$keyPath = Read-Host -Prompt "Enter the full path to your AWS key file (e.g., C:\Users\username\vockey.pem)"
$keyPath = $keyPath.Trim('"') # Remove any quotes
if (-not (Test-Path $keyPath)) {
    Write-Host "Key file not found at $keyPath. Please check the path." -ForegroundColor Red
    exit 1
}

# Get the filename from the path
$keyFileName = Split-Path $keyPath -Leaf

# Simple path fix for Docker - using Docker for Windows path format
$currentPath = (Get-Location).Path
$dockerAnsiblePath = $currentPath -replace '\\', '/'
$dockerKeyPath = $keyPath -replace '\\', '/'

Write-Host "===== Step 3: Running Ansible playbook in Docker container =====" -ForegroundColor Cyan
Write-Host "Waiting for Jenkins server to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30  # Give the server time to initialize

# Build the docker run command with simple paths
$dockerCmd = "docker run --rm -v `"$dockerAnsiblePath`":/ansible -v `"$dockerKeyPath`":/keys/$keyFileName cytopia/ansible ansible-playbook -i /ansible/inventory /ansible/install-jenkins.yml"
Write-Host "Executing Docker command..." -ForegroundColor Gray

try {
    # Run the command
    $ansibleResult = Invoke-Expression $dockerCmd
    Write-Host $ansibleResult
    $ansibleSuccess = $true
    Write-Host "Ansible playbook executed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Ansible playbook execution failed. Providing manual instructions..." -ForegroundColor Red
    $ansibleSuccess = $false
}

# If Ansible failed, provide manual instructions
if (-not $ansibleSuccess) {
    Write-Host "===== Manual Jenkins Setup Instructions =====" -ForegroundColor Magenta
    Write-Host "1. SSH into your instance: ssh -i $keyPath ubuntu@$JENKINS_IP" -ForegroundColor White
    Write-Host "2. Run the following commands to install Jenkins:" -ForegroundColor White
    Write-Host "   sudo apt update" -ForegroundColor White
    Write-Host "   sudo apt install -y openjdk-11-jdk" -ForegroundColor White
    Write-Host "   wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo apt-key add -" -ForegroundColor White
    Write-Host "   sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'" -ForegroundColor White
    Write-Host "   sudo apt update" -ForegroundColor White
    Write-Host "   sudo apt install -y jenkins" -ForegroundColor White
    Write-Host "   sudo systemctl start jenkins" -ForegroundColor White
    Write-Host "   sudo systemctl enable jenkins" -ForegroundColor White
    Write-Host "3. Install Docker:" -ForegroundColor White
    Write-Host "   sudo apt install -y apt-transport-https ca-certificates curl software-properties-common" -ForegroundColor White
    Write-Host "   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -" -ForegroundColor White
    Write-Host "   sudo add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable'" -ForegroundColor White
    Write-Host "   sudo apt update" -ForegroundColor White
    Write-Host "   sudo apt install -y docker-ce" -ForegroundColor White
    Write-Host "   sudo usermod -aG docker ubuntu" -ForegroundColor White
    Write-Host "   sudo usermod -aG docker jenkins" -ForegroundColor White
    Write-Host "   sudo systemctl restart jenkins" -ForegroundColor White
    Write-Host "4. Install Maven:" -ForegroundColor White
    Write-Host "   sudo apt install -y maven" -ForegroundColor White
    Write-Host "5. Get Jenkins password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword" -ForegroundColor White
}

# Return to root directory
Set-Location -Path ..

Write-Host "===== Next Steps =====" -ForegroundColor Cyan
Write-Host "1. Access Jenkins at: http://$JENKINS_IP`:8080" -ForegroundColor Green
Write-Host "2. Enter the admin password" -ForegroundColor Green
Write-Host "3. Install suggested plugins" -ForegroundColor Green
Write-Host "4. Create an admin user" -ForegroundColor Green
Write-Host "5. Configure Jenkins:" -ForegroundColor Green
Write-Host "   - Go to 'Manage Jenkins' > 'Global Tool Configuration'" -ForegroundColor Green
Write-Host "   - Add Maven with name 'Maven'" -ForegroundColor Green
Write-Host "6. Create a new Pipeline job:" -ForegroundColor Green
Write-Host "   - Click 'New Item'" -ForegroundColor Green
Write-Host "   - Enter a name and select 'Pipeline'" -ForegroundColor Green
Write-Host "   - In Pipeline configuration, select 'Pipeline script from SCM'" -ForegroundColor Green
Write-Host "   - Select Git as SCM and enter your repository URL" -ForegroundColor Green
Write-Host "   - Set the Script Path to 'Jenkinsfile'" -ForegroundColor Green
Write-Host "   - Click Save" -ForegroundColor Green
Write-Host "7. Run the pipeline" -ForegroundColor Green

Write-Host "===== After Deployment =====" -ForegroundColor Green
Write-Host "Your application will be available at: http://$JENKINS_IP`:8081" -ForegroundColor Green
Write-Host "==== Deployment Process Complete ====" -ForegroundColor Green


# C:\Users\dines\Downloads\KEY1.pem