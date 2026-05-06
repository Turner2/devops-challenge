pipeline {
    agent any

    environment {
        AWS_REGION         = 'us-east-1'
        ECR_REGISTRY       = '378388077304.dkr.ecr.us-east-1.amazonaws.com'
        ECR_REPO           = 'devops-challenge-product-catalog'
        IMAGE_TAG          = "${env.BUILD_NUMBER}"
        EKS_CLUSTER_NAME   = 'devops-challenge-eks'
        K8S_NAMESPACE      = 'production'
        DEPLOYMENT_NAME    = 'product-catalog'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Building commit: ${env.GIT_COMMIT}"
            }
        }

        stage('Install Dependencies') {
            steps {
                dir('app') {
                    sh 'npm install'
                }
            }
        }

        stage('Test') {
            steps {
                dir('app') {
                    sh 'npm run test:ci'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('app') {
                    sh """
                        docker buildx build \
                          --platform linux/amd64 \
                          -t ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG} \
                          -t ${ECR_REGISTRY}/${ECR_REPO}:latest \
                          --load .
                    """
                }
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ECR_REGISTRY}
                """
                sh "docker push ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
                sh "docker push ${ECR_REGISTRY}/${ECR_REPO}:latest"
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh """
                    aws eks update-kubeconfig \
                      --region ${AWS_REGION} \
                      --name ${EKS_CLUSTER_NAME}
                """
                sh """
                    kubectl set image deployment/${DEPLOYMENT_NAME} \
                      ${DEPLOYMENT_NAME}=${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG} \
                      -n ${K8S_NAMESPACE}
                """
                sh """
                    kubectl rollout status deployment/${DEPLOYMENT_NAME} \
                      -n ${K8S_NAMESPACE} \
                      --timeout=120s
                """
            }
        }

        stage('Verify Deployment') {
            steps {
                sh "kubectl get pods -n ${K8S_NAMESPACE}"
                sh "kubectl get svc -n ${K8S_NAMESPACE}"
            }
        }
    }

    post {
        success {
            echo "Deployment successful! Image: ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed. Rolling back..."
            sh "kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE} || true"
        }
        always {
            sh "docker rmi ${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG} || true"
            sh "docker rmi ${ECR_REGISTRY}/${ECR_REPO}:latest || true"
            cleanWs()
        }
    }
}
