pipeline {

  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:

  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command:
      - /busybox/sh
      - -c
      - sleep 999999
    tty: true
    volumeMounts:
      - name: docker-config
        mountPath: /kaniko/.docker/config.json
        subPath: .dockerconfigjson
      - name: workspace
        mountPath: /workspace

  - name: trivy
    image: aquasec/trivy:latest
    command:
      - sh
      - -c
      - sleep 999999
    tty: true

  volumes:
    - name: docker-config
      secret:
        secretName: dockerhub-secret

    - name: workspace
      emptyDir: {}
"""
    }
  }

  options {
    buildDiscarder(
      logRotator(
        numToKeepStr: '20',
        daysToKeepStr: '14'
      )
    )

    disableConcurrentBuilds()

    timestamps()
  }

  environment {

    IMAGE_NAME  = "praveendevops95/devops-portfolio"

    IMAGE_TAG   = "v${BUILD_NUMBER}"

    GITOPS_REPO = "github.com/MytPraveen/portfolio-gitops.git"

  }

  stages {

    stage('Checkout Application Source') {
      steps {
        checkout scm
      }
    }

    stage('Build & Push Docker Image') {
      steps {

        container('kaniko') {

          sh '''
            echo "Building Docker image..."

            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=$WORKSPACE \
              --destination=${IMAGE_NAME}:${IMAGE_TAG} \
              --cleanup

            echo "Docker image pushed successfully"
          '''
        }
      }
    }

    stage('Security Scan - Trivy') {
      steps {

        container('trivy') {

          sh '''
            echo "Running Trivy security scan..."

            trivy image \
              --severity HIGH,CRITICAL \
              --exit-code 1 \
              docker.io/${IMAGE_NAME}:${IMAGE_TAG}

            echo "Trivy scan completed successfully"
          '''
        }
      }
    }

    stage('Update GitOps Repository') {

      steps {

        withCredentials([
          usernamePassword(
            credentialsId: 'github-creds',
            usernameVariable: 'GIT_USER',
            passwordVariable: 'GIT_TOKEN'
          )
        ]) {

          sh '''
            echo "Cloning GitOps repository..."

            rm -rf portfolio-gitops

            git clone https://${GIT_USER}:${GIT_TOKEN}@${GITOPS_REPO}

            cd portfolio-gitops

            echo "Updating deployment image..."

            sed -i "s|image: .*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" deployment.yaml

            git config user.email "jenkins@ci.com"
            git config user.name "Jenkins CI"

            git add deployment.yaml

            git commit -m "Updated image to ${IMAGE_NAME}:${IMAGE_TAG}"

            git push

            echo "GitOps repository updated successfully"
          '''
        }
      }
    }
  }

  post {

    success {

      echo """
========================================
✅ PIPELINE COMPLETED SUCCESSFULLY
========================================

Docker Image:
${IMAGE_NAME}:${IMAGE_TAG}

GitOps repository updated.
ArgoCD will sync automatically.

========================================
"""
    }

    failure {

      echo """
========================================
❌ PIPELINE FAILED
========================================

Check:
- Docker build logs
- Trivy scan results
- GitHub credentials
- GitOps deployment.yaml

========================================
"""
    }

    always {

      cleanWs()

    }
  }
}