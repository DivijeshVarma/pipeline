pipeline {
    agent { label 'node-1' } // Set the agent to use node-1

    environment {
        DOCKER_IMAGE = 'my-app'               // Docker image name
        DOCKER_TAG = 'latest-v014'            // Docker tag
        DOCKER_HUB_REPO = 'royjith/pikube'   // Docker Hub repository
        DOCKER_HUB_CREDENTIALS_ID = 'dockerhub'  // Docker Hub credentials ID
        DEPLOYMENT_NAME = 'pipeline-deployment'
        NAMESPACE = 'default'  // Kubernetes namespace to deploy to
        TERRAFORM_DIR = '.'  // Use the current directory as it will be where the 'main.tf' is located after checkout
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from Git...'
                // Checkout the code from the 'master' branch
                git branch: 'main', credentialsId: 'dockerhub', url: 'https://github.com/Royjith/demo.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Set default tag to 'latest' if DOCKER_TAG is not defined
                    def tag = "${DOCKER_TAG ?: 'latest-v014'}"
                    echo "Building Docker image with tag: ${tag}..."
                    // Build the Docker image with the determined tag
                    def buildResult = sh(script: "docker build -t ${DOCKER_HUB_REPO}:${tag} .", returnStatus: true)
            
                    if (buildResult != 0) {
                        error 'Docker build failed!'  // Explicitly fail if Docker build fails
                    }
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                script {
                    echo 'Running Trivy security scan on the Docker image...'

                    // Run Trivy scan for vulnerabilities in the Docker image
                    def scanResult = sh(script: "trivy image ${DOCKER_HUB_REPO}:${DOCKER_TAG}", returnStatus: true)

                    // Fail the build if vulnerabilities are found (returnStatus != 0 means issues were detected)
                    if (scanResult != 0) {
                        error 'Trivy scan found vulnerabilities in the Docker image!'
                    } else {
                        echo 'Trivy scan passed: No vulnerabilities found.'
                    }
                }
            }
        }

        stage('Push Image to DockerHub') {
            steps {
                input message: 'Approve Deployment?', ok: 'Deploy'  // Manual approval for deployment
                script {
                    echo 'Pushing Docker image to DockerHub...'

                    try {
                        // Manually login to Docker Hub using the credentials
                        withCredentials([usernamePassword(credentialsId: "${DOCKER_HUB_CREDENTIALS_ID}", usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                            sh '''
                                echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
                            '''
                        }

                        // Push the Docker image to Docker Hub
                        sh "docker push ${DOCKER_HUB_REPO}:${DOCKER_TAG}"

                    } catch (Exception e) {
                        error "Docker push failed: ${e.message}"  // Explicitly fail if push fails
                    }
                }
            }
        }

        stage('Run Terraform for EC2 and Docker Setup') {
            steps {
                input message: 'Approve Terraform Execution?', ok: 'Deploy'  // Manual approval before running Terraform
                script {
                    echo 'Running Terraform to launch EC2 instance and set up Docker...'

                    try {
                        // Set up Terraform credentials (ensure you have the necessary credentials in Jenkins)
                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-id']]) {
                            // Initialize Terraform and apply the configuration from the 'main.tf' file in the checked-out repository
                            // Navigate to the directory where 'main.tf' is located (current directory after checkout)
                            dir('.') {
                                // Initialize Terraform
                                sh 'terraform init'

                                // Apply Terraform configuration to create EC2 instance and set up Docker
                                sh 'terraform apply -auto-approve'
                            }
                        }
                    } catch (Exception e) {
                        error "Terraform execution failed: ${e.message}"  // Explicitly fail if Terraform execution fails
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()  // Clean workspace after pipeline execution
        }
        success {
            echo 'Pipeline executed successfully!'
        }
        failure {
            echo 'Pipeline failed.'
        }
    }
}
