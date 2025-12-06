// Jenkins Pipeline for AI Infrastructure

pipeline {
    agent any
    
    environment {
        DOCKER_BUILDKIT = '1'
        COMPOSE_DOCKER_CLI_BUILD = '1'
        DOCKER_REGISTRY = credentials('docker-registry')
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 1, unit: 'HOURS')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Setup') {
            steps {
                sh 'make setup'
                sh 'make check'
            }
        }
        
        stage('Lint') {
            parallel {
                stage('Lint Python') {
                    steps {
                        sh 'make lint-python || true'
                    }
                }
                stage('Lint Node.js') {
                    steps {
                        sh 'make lint-nodejs || true'
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                sh 'make build'
            }
        }
        
        stage('Test') {
            steps {
                sh 'make ci-test'
            }
            post {
                always {
                    junit '**/test-results/*.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('Security Scan') {
            parallel {
                stage('Vulnerability Scan') {
                    steps {
                        sh 'make security-scan || true'
                    }
                }
                stage('Dependency Audit') {
                    steps {
                        sh 'make audit || true'
                    }
                }
            }
        }
        
        stage('Push Images') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    docker.withRegistry('', 'docker-registry') {
                        sh 'docker-compose push'
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            environment {
                DEPLOY_ENV = 'staging'
            }
            steps {
                input message: 'Deploy to Staging?', ok: 'Deploy'
                sh 'make ci-deploy-staging'
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            environment {
                DEPLOY_ENV = 'production'
            }
            steps {
                input message: 'Deploy to Production?', ok: 'Deploy'
                sh 'make ci-deploy-prod'
            }
            post {
                success {
                    slackSend(
                        color: 'good',
                        message: "Deployed to Production: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                    )
                }
                failure {
                    slackSend(
                        color: 'danger',
                        message: "Production Deployment Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                    )
                }
            }
        }
        
        stage('Health Check') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                sh 'make health'
            }
        }
    }
    
    post {
        always {
            sh 'make clean || true'
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
            // Add notification here (email, Slack, etc.)
        }
    }
}

