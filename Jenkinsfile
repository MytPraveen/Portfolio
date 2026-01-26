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

  // ✅ BUILD RETENTION (CORRECT)
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
    IMAGE_NAME = "praveendevops95/portfolio"
    IMAGE_TAG  = "v${BUILD_NUMBER}"
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
              --context=$WORKSPACE \
              --destination=${IMAGE_NAME}:${IMAGE_TAG}
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ Image pushed: ${IMAGE_NAME}:${IMAGE_TAG}"
    }
    failure {
      echo "❌ Build failed"
    }
    always {
      echo "🧹 Old builds cleaned automatically by Jenkins"
    }
  }
}
