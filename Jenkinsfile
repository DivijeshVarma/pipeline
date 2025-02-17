pipeline {
    agent { label 'node-1' }

    environment {
        DOCKER_HUB_REPO = 'divijeshhub/pikube'
        DOCKER_HUB_CREDENTIALS_ID = 'dockerhub'
        DEPLOYMENT_NAME_PREFIX = 'pipeline-deployment'
        NAMESPACE = 'default'
        TERRAFORM_DIR = '.'  // Path to the directory containing your Terraform files
        SSH_CREDENTIALS_ID = 'ec2-ssh-key'  // SSH credentials ID in Jenkins
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Checking out code for branch ${env.BRANCH_NAME}..."
                git branch: "${env.BRANCH_NAME}", url: 'https://github.com/DivijeshVarma/pipeline.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def tag = "${env.BRANCH_NAME ?: 'latest-v1'}"
                    echo "Building Docker image for branch ${env.BRANCH_NAME} with tag: ${tag}..."
                    def buildResult = sh(script: "docker build -t ${DOCKER_HUB_REPO}:${tag} .", returnStatus: true)

                    if (buildResult != 0) {
                        error 'Docker build failed!'
                    }
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                script {
                    echo 'Running Trivy security scan on the Docker image...'
                    def scanResult = sh(script: "trivy image ${DOCKER_HUB_REPO}:${env.BRANCH_NAME}", returnStatus: true)

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
                input message: 'Approve Docker Image Push?', ok: 'Push'
                script {
                    echo "Pushing Docker image for branch ${env.BRANCH_NAME} to DockerHub..."

                    withCredentials([usernamePassword(credentialsId: "${DOCKER_HUB_CREDENTIALS_ID}", usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh '''
                            echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
                        '''
                    }

                    sh "docker push ${DOCKER_HUB_REPO}:${env.BRANCH_NAME}"
                }
            }
        }

        stage('Run Terraform for EC2 and Docker Setup') {
            steps {
                input message: 'Approve Terraform Execution?', ok: 'Deploy'
                script {
                    echo 'Running Terraform to launch EC2 instance and set up Docker...'

                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-id']]) {
                        dir(TERRAFORM_DIR) {
                            // Initialize Terraform and apply the configuration
                            sh 'terraform init'
                            sh 'terraform apply -auto-approve'  // Apply the Terraform configuration

                            // Fetch the EC2 public IP from Terraform output
                            def ec2Ip = sh(script: 'terraform output -raw ec2_public_ip', returnStdout: true).trim()
                            echo "Terraform output ec2_public_ip: ${ec2Ip}"

                            // Store the IP in the environment variable for use in subsequent stages
                            if (ec2Ip == '') {
                                error 'Terraform output is empty, no public IP found.'
                            }
                            env.EC2_INSTANCE_IP = ec2Ip
                        }
                    }
                }
            }
        }

        stage('Deploy Docker Image to EC2') {
            steps {
                input message: 'Approve Docker Deployment to EC2?', ok: 'Deploy'
                script {
                    def containerName = "${DEPLOYMENT_NAME_PREFIX}-${env.BRANCH_NAME}"
                    echo "Deploying Docker container for branch ${env.BRANCH_NAME} to EC2 instance: ${env.EC2_INSTANCE_IP}"

                    // Using sshagent to securely handle SSH credentials for EC2 instance
                    sshagent(credentials: [env.SSH_CREDENTIALS_ID]) {
                        try {
                            // SSH into EC2 instance and deploy Docker image
                            sh """
                                ssh -o StrictHostKeyChecking=no ec2-user@${env.EC2_INSTANCE_IP} \
                                    'sudo systemctl start docker && \
                                     sudo systemctl enable docker && \
                                     docker pull ${DOCKER_HUB_REPO}:${env.BRANCH_NAME} && \
                                     sudo docker run -d --name ${DEPLOYMENT_NAME} -p 8501:8501 ${DOCKER_HUB_REPO}:${DOCKER_TAG}'  
                            """
                        } catch (Exception e) {
                            error "Docker deployment to EC2 failed: ${e.message}"
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline for branch ${env.BRANCH_NAME} executed successfully!"
        }
        failure {
            echo "Pipeline for branch ${env.BRANCH_NAME} failed."
        }
    }
}
