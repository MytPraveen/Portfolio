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
  }

  environment {
    IMAGE_NAME   = "praveendevops95/portfolio"
    IMAGE_TAG    = "v${BUILD_NUMBER}"
    GITOPS_REPO  = "github.com/MytPraveen/portfolio-gitops.git"
  }

  stages {

    stage('Checkout App Source') {
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
              --context=$WORKSPACE \
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
            rm -rf portfolio-gitops
            git clone https://${GIT_USER}:${GIT_TOKEN}@${GITOPS_REPO}
            cd portfolio-gitops

            echo "Updating deployment.yaml to ${IMAGE_TAG}"

            sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|" deployment.yaml

            git config user.email "jenkins@ci.com"
            git config user.name "Jenkins CI"

            git add deployment.yaml
            git commit -m "Deploy ${IMAGE_NAME}:${IMAGE_TAG}"
            git push
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ Image pushed AND GitOps updated to ${IMAGE_TAG}"
    }
    failure {
      echo "❌ Pipeline failed"
    }
  }
}
