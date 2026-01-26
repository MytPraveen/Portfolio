pipeline {

  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:latest
    command:
    - sleep
    args:
    - 9999999
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
  volumes:
  - name: docker-config
    secret:
      secretName: dockerhub-secret
"""
    }
  }

  environment {
    IMAGE_NAME  = "praveendevops95/portfolio"
    IMAGE_TAG   = "v${BUILD_NUMBER}"
    GITOPS_REPO = "github.com/MytPraveen/portfolio-gitops.git"
  }

  stages {

    stage('Checkout Source') {
      steps {
        checkout scm
      }
    }

    stage('Build & Push Image (Kaniko)') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=${WORKSPACE} \
              --destination=${IMAGE_NAME}:${IMAGE_TAG}
          '''
        }
      }
    }

    stage('Update GitOps Repo') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'github-creds',
            usernameVariable: 'GIT_USER',
            passwordVariable: 'GIT_TOKEN'
          )
        ]) {
          sh '''
            git clone https://${GIT_USER}:${GIT_TOKEN}@${GITOPS_REPO}
            cd portfolio-gitops

            sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" deployment.yaml

            git config user.email "jenkins@ci.com"
            git config user.name "Jenkins CI"

            git add deployment.yaml
            git commit -m "Deploy portfolio ${IMAGE_TAG}"
            git push
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ CI SUCCESS: ${IMAGE_NAME}:${IMAGE_TAG}"
    }
    failure {
      echo "❌ CI FAILED"
    }
  }
}
