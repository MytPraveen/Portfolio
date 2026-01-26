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
      - --context=/home/jenkins/agent/workspace/portfolio-ci
      - --destination=praveendevops95/portfolio:v${BUILD_NUMBER}
    volumeMounts:
      - name: docker-config
        mountPath: /kaniko/.docker
      - name: jenkins-workspace
        mountPath: /home/jenkins/agent
  volumes:
    - name: docker-config
      secret:
        secretName: dockerhub-secret
    - name: jenkins-workspace
      emptyDir: {}
"""
    }
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
  }
}
