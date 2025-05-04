pipeline {
    agent any
    
    tools {
        maven 'Maven' // Use the Maven installation name configured in Jenkins
    }
    
    environment {
        DOCKER_IMAGE = "spring-boot-demo:${BUILD_NUMBER}"
        DOCKER_HUB_CREDS = credentials('docker-hub-creds')
        // Determine the inactive environment to deploy to
        ACTIVE_COLOR = sh(script: "kubectl get service myapp-service -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo 'blue'", returnStdout: true).trim()
        TARGET_COLOR = "${ACTIVE_COLOR == 'blue' ? 'green' : 'blue'}"
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }
        
        stage('Build with Maven') {
            steps {
                sh 'mvn clean package'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ${DOCKER_IMAGE} .'
                sh 'docker tag ${DOCKER_IMAGE} ${DOCKER_HUB_CREDS_USR}/spring-boot-demo:${BUILD_NUMBER}'
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                sh 'echo ${DOCKER_HUB_CREDS_PSW} | docker login -u ${DOCKER_HUB_CREDS_USR} --password-stdin'
                sh 'docker push ${DOCKER_HUB_CREDS_USR}/spring-boot-demo:${BUILD_NUMBER}'
            }
        }
        
        stage('Deploy to Inactive Environment') {
            steps {
                echo "Current active environment is ${ACTIVE_COLOR}, deploying to ${TARGET_COLOR}"
                
                // Update the image in the target deployment
                sh "kubectl set image deployment/myapp-${TARGET_COLOR} myapp=${DOCKER_HUB_CREDS_USR}/spring-boot-demo:${BUILD_NUMBER} --record"
                
                // Wait for deployment to complete
                sh "kubectl rollout status deployment/myapp-${TARGET_COLOR}"
                
                echo "Deployment to ${TARGET_COLOR} environment completed"
            }
        }
        
        stage('Test Inactive Environment') {
            steps {
                // Create a temporary service to test the inactive environment
                sh """
                kubectl create service loadbalancer myapp-${TARGET_COLOR}-test \\
                    --tcp=80:8080 \\
                    -o yaml --dry-run=client | \\
                    kubectl label --local -f - app=myapp color=${TARGET_COLOR} -o yaml | \\
                    kubectl create -f - || true
                """
                
                // Wait for the service to get an external IP
                sh "kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' service/myapp-${TARGET_COLOR}-test --timeout=300s"
                
                // Get the service URL and test it
                script {
                    def serviceUrl = sh(script: "kubectl get service myapp-${TARGET_COLOR}-test -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()
                    
                    // Simple test to check if the application is responding
                    sh "curl -s http://${serviceUrl} | grep 'Welcome'"
                }
            }
            post {
                always {
                    // Clean up test service
                    sh "kubectl delete service myapp-${TARGET_COLOR}-test || true"
                }
            }
        }
        
        stage('Switch Traffic') {
            steps {
                input "Ready to switch traffic to ${TARGET_COLOR} environment?"
                
                // Switch the service selector to the new color
                sh """
                kubectl patch service myapp-service -p '{"spec":{"selector":{"app":"myapp","color":"${TARGET_COLOR}"}}}' --record
                """
                
                echo "Traffic switched to ${TARGET_COLOR} environment"
            }
        }
        
        stage('Verify Production') {
            steps {
                // Get the service URL
                script {
                    def serviceUrl = sh(script: "kubectl get service myapp-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()
                    
                    // Verify the application is responding in production
                    sh "curl -s http://${serviceUrl} | grep 'Welcome'"
                }
                
                echo "Verification successful - new version is live!"
            }
        }
    }
    
    post {
        success {
            echo 'Blue-Green deployment completed successfully!'
        }
        failure {
            echo 'Pipeline failed! The service is still pointing to the stable environment.'
        }
    }
}