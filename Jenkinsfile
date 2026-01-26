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
    IMAGE_TAG = "v${BUILD_NUMBER}"
    GITOPS_REPO = "https://github.com/MytPraveen/portfolio-gitops.git"
  }

  stages {

stage('Build & Push Image') {
  steps {
    container('kaniko') {
      sh '''
        /kaniko/executor \
          --dockerfile=Dockerfile \
          --context=$WORKSPACE \
          --destination=praveendevops95/portfolio:${IMAGE_TAG}
      '''
    }
  }
}

stage('Update GitOps Repo') {
  steps {
    withCredentials([usernamePassword(
      credentialsId: 'github-creds',
      usernameVariable: 'GITHUB_USER',
      passwordVariable: 'GITHUB_TOKEN'
    )]) {
      sh '''
      git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/MytPraveen/portfolio-gitops.git
      cd portfolio-gitops

      sed -i "s|image: praveendevops95/portfolio:.*|image: praveendevops95/portfolio:${IMAGE_TAG}|" deployment.yaml

      git config user.email "jenkins@ci.com"
      git config user.name "Jenkins CI"
      git add deployment.yaml
      git commit -m "Deploy portfolio ${IMAGE_TAG}"
      git push
      '''
    }
  }
}
