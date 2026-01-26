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
    args:
      - --dockerfile=Dockerfile
      - --context=.
      - --destination=praveendevops95/portfolio:v\${BUILD_NUMBER}
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
    IMAGE_TAG   = "v${BUILD_NUMBER}"
    IMAGE_NAME  = "praveendevops95/portfolio"
    GITOPS_REPO = "github.com/MytPraveen/portfolio-gitops.git"
  }

  stages {

    stage('Checkout Source Code') {
      steps {
        checkout scm
      }
    }

    stage('Build & Push Image (Kaniko)') {
      steps {
        container('kaniko') {
          sh '''
            echo "Building image ${IMAGE_NAME}:${IMAGE_TAG}"
            # Kaniko runs automatically via container args
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
            echo "Updating GitOps repo with new image tag"

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
      echo "CI successful. Image ${IMAGE_NAME}:${IMAGE_TAG} deployed via GitOps."
    }
    failure {
      echo "CI failed. Check logs."
    }
  }
}
