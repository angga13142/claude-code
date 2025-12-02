// Jenkins Pipeline Example for LiteLLM Gateway
// Purpose: Automate gateway deployment and testing in Jenkins
// Usage: Create a new Jenkins Pipeline job and paste this script

pipeline {
    agent any
    
    environment {
        LITELLM_PORT = '4000'
        PYTHON_VERSION = '3.9'
        GCP_CREDENTIALS_ID = 'gcp-service-account' // Jenkins credentials ID
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Validate Configuration') {
            steps {
                script {
                    sh '''
                        pip install litellm pyyaml
                        python3 specs/001-llm-gateway-config/scripts/validate-config.py config/litellm.yaml
                        python3 -c "import yaml; yaml.safe_load(open('config/litellm.yaml'))" && echo "✅ YAML syntax valid"
                    '''
                }
            }
        }
        
        stage('Test Gateway') {
            steps {
                script {
                    withCredentials([file(credentialsId: env.GCP_CREDENTIALS_ID, variable: 'GCP_KEY_FILE')]) {
                        sh '''
                            export GOOGLE_APPLICATION_CREDENTIALS=${GCP_KEY_FILE}
                            pip install litellm google-cloud-aiplatform
                            
                            # Start gateway in background
                            litellm --config config/litellm.yaml --port ${LITELLM_PORT} &
                            GATEWAY_PID=$!
                            sleep 15
                            
                            # Health check
                            curl -f http://localhost:${LITELLM_PORT}/health || exit 1
                            echo "✅ Gateway health check passed"
                            
                            # Test model availability
                            python3 specs/001-llm-gateway-config/scripts/check-model-availability.py \
                                --config config/litellm.yaml \
                                --models gemini-2.5-flash,gemini-2.5-pro
                            
                            # Cleanup
                            kill $GATEWAY_PID || true
                        '''
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    echo "🚀 Deploying to staging environment"
                    // Add your deployment commands here
                    // Example: kubectl apply, terraform apply, etc.
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🚀 Deploying to production environment"
                    // Add your deployment commands here
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo "✅ Pipeline succeeded"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}

