# PowerShell deployment script
Write-Host "==== Starting Deployment Process ====" -ForegroundColor Green

# Step 1: Terraform Infrastructure Deployment
Write-Host "===== Step 1: Deploying Infrastructure with Terraform =====" -ForegroundColor Cyan
Set-Location -Path terraform
terraform init
terraform plan
terraform apply -auto-approve

# Capture Jenkins IP address
$JENKINS_IP = terraform output -raw jenkins_public_ip
Write-Host "Jenkins Server IP: $JENKINS_IP" -ForegroundColor Yellow

Write-Host "===== Step 2: Manual Jenkins Setup =====" -ForegroundColor Cyan
Write-Host "1. SSH into your instance: ssh -i your-key.pem ubuntu@$JENKINS_IP" -ForegroundColor White
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
Write-Host "   sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"" -ForegroundColor White
Write-Host "   sudo apt update" -ForegroundColor White
Write-Host "   sudo apt install -y docker-ce" -ForegroundColor White
Write-Host "   sudo usermod -aG docker ubuntu" -ForegroundColor White
Write-Host "   sudo usermod -aG docker jenkins" -ForegroundColor White
Write-Host "   sudo systemctl restart jenkins" -ForegroundColor White
Write-Host "4. Get Jenkins password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword" -ForegroundColor White

Write-Host "===== Step 3: Jenkins Configuration =====" -ForegroundColor Cyan
Write-Host "1. Access Jenkins at: http://$JENKINS_IP`:8080" -ForegroundColor Green
Write-Host "2. Enter the admin password" -ForegroundColor Green
Write-Host "3. Install suggested plugins" -ForegroundColor Green
Write-Host "4. Create an admin user" -ForegroundColor Green
Write-Host "5. Configure Jenkins with Maven and Docker plugins" -ForegroundColor Green

Write-Host "==== Deployment Process Complete ====" -ForegroundColor Green

# Return to the root directory
Set-Location -Path ..