# PowerShell script to test Blue-Green deployment
Write-Host "==== Blue-Green Deployment Testing Script ====" -ForegroundColor Green

# Get EKS cluster details from Terraform output
Write-Host "===== Getting EKS Cluster Details =====" -ForegroundColor Cyan
Set-Location -Path terraform
$EKS_CLUSTER_NAME = terraform output -raw eks_cluster_name
$AWS_REGION = "us-east-1" # Update this based on your configuration
Set-Location -Path ..

# Configure kubectl to use the EKS cluster
Write-Host "===== Configuring kubectl for EKS =====" -ForegroundColor Cyan
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME

# Check current deployments
Write-Host "===== Checking Current Deployments =====" -ForegroundColor Cyan
kubectl get deployments -n myapp

# Check which color is currently active
Write-Host "===== Checking Active Color =====" -ForegroundColor Cyan
$ACTIVE_COLOR = kubectl get service myapp-service -n myapp -o jsonpath='{.spec.selector.color}'
$INACTIVE_COLOR = if ($ACTIVE_COLOR -eq "blue") { "green" } else { "blue" }

Write-Host "Active environment: $ACTIVE_COLOR" -ForegroundColor Yellow
Write-Host "Inactive environment: $INACTIVE_COLOR" -ForegroundColor Yellow

# Check service endpoint
Write-Host "===== Getting Service Endpoint =====" -ForegroundColor Cyan
$SERVICE_URL = kubectl get service myapp-service -n myapp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Service URL: $SERVICE_URL" -ForegroundColor Yellow

# Make a request to the service to verify it's working
Write-Host "===== Testing Current Service =====" -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://$SERVICE_URL" -UseBasicParsing
    Write-Host "Response status code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response first 100 characters: $($response.Content.Substring(0, [Math]::Min(100, $response.Content.Length)))" -ForegroundColor Green
} catch {
    Write-Host "Error accessing service: $_" -ForegroundColor Red
}

# Simulate a manual switch to test blue-green switching
Write-Host "===== Manual Service Switch Test =====" -ForegroundColor Cyan
$switch = Read-Host -Prompt "Would you like to manually switch the service to $INACTIVE_COLOR? (yes/no)"

if ($switch -eq "yes") {
    Write-Host "Switching service to $INACTIVE_COLOR..." -ForegroundColor Yellow
    kubectl patch service myapp-service -n myapp -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"color\":\"$INACTIVE_COLOR\"}}}"
    
    # Verify the switch
    $NEW_ACTIVE_COLOR = kubectl get service myapp-service -n myapp -o jsonpath='{.spec.selector.color}'
    Write-Host "Service now points to: $NEW_ACTIVE_COLOR" -ForegroundColor Green
    
    # Test the service again
    Write-Host "===== Testing New Service =====" -ForegroundColor Cyan
    Start-Sleep -Seconds 5 # Give it a moment to switch
    try {
        $response = Invoke-WebRequest -Uri "http://$SERVICE_URL" -UseBasicParsing
        Write-Host "Response status code: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "Response first 100 characters: $($response.Content.Substring(0, [Math]::Min(100, $response.Content.Length)))" -ForegroundColor Green
    } catch {
        Write-Host "Error accessing service: $_" -ForegroundColor Red
    }
    
    # Offer to switch back
    $switchBack = Read-Host -Prompt "Would you like to switch back to $ACTIVE_COLOR? (yes/no)"
    if ($switchBack -eq "yes") {
        Write-Host "Switching service back to $ACTIVE_COLOR..." -ForegroundColor Yellow
        kubectl patch service myapp-service -n myapp -p "{\"spec\":{\"selector\":{\"app\":\"myapp\",\"color\":\"$ACTIVE_COLOR\"}}}"
        Write-Host "Service switched back to $ACTIVE_COLOR" -ForegroundColor Green
    }
}

Write-Host "==== Blue-Green Testing Complete ====" -ForegroundColor Green