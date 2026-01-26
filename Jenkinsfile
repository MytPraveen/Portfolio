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
      - --context=git://github.com/MytPraveen/Portfolio.git
      - --destination=praveendevops95/portfolio:latest
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
  restartPolicy: Never
  volumes:
  - name: docker-config
    secret:
      secretName: dockerhub-secret
"""
    }
  }

  stages {
    stage('Build & Push Image') {
      steps {
        echo "Building image with Kaniko"
      }
    }
  }
}
