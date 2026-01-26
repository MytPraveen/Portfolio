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
    tty: true
    workingDir: /workspace
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
    - name: workspace-volume
      mountPath: /workspace
  volumes:
  - name: docker-config
    secret:
      secretName: dockerhub-secret
  - name: workspace-volume
    emptyDir: {}
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

    stage('Build & Push Image') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=/workspace \
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
            git commit -m "Deploy ${IMAGE_TAG}"
            git push
          '''
        }
      }
    }
  }
}
