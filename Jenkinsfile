pipeline {

  // ============================================================
  // AGENT: Jenkins runs each build in a fresh Kubernetes pod
  // The pod has 3 containers: kaniko (builds image), trivy
  // (security scan), and kubectl (for any K8s commands).
  // All 3 share the same workspace volume.
  // ============================================================
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:

  # --- Kaniko: builds Docker image WITHOUT needing Docker daemon
  # This is the secure way to build inside Kubernetes.
  # It reads your Dockerfile and pushes to Docker Hub.
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/busybox/sh"]
    args: ["-c", "sleep 999999"]
    tty: true
    volumeMounts:
    - name: docker-config     # Docker Hub credentials (secret)
      mountPath: /kaniko/.docker/config.json
      subPath: .dockerconfigjson
    - name: workspace
      mountPath: /workspace

  # --- Trivy: scans the built image for CVEs (vulnerabilities)
  - name: trivy
    image: aquasec/trivy:latest
    command: [sh]
    args: ["-c", "sleep 999999"]
    tty: true

  # --- Git: used to update the GitOps repo with new image tag
  - name: git
    image: alpine/git:latest
    command: [sh]
    args: ["-c", "sleep 999999"]
    tty: true
    volumeMounts:
    - name: github-ssh        # SSH key to push to GitHub
      mountPath: /root/.ssh
      readOnly: true

  volumes:
  - name: docker-config
    secret:
      secretName: dockerhub-secret   # kubectl create secret
  - name: workspace
    emptyDir: {}
  - name: github-ssh
    secret:
      secretName: github-ssh-key     # kubectl create secret
      defaultMode: 0400
"""
    }
  }

  // ============================================================
  // OPTIONS: Pipeline-level settings
  // ============================================================
  options {
    buildDiscarder(logRotator(
      numToKeepStr: '20',       // keep last 20 builds
      daysToKeepStr: '14'       // delete builds older than 14 days
    ))
    disableConcurrentBuilds()   // never run 2 builds at same time
    timestamps()                // show timestamps in logs
    timeout(time: 15, unit: 'MINUTES')  // kill if stuck > 15 min
  }

  // ============================================================
  // ENVIRONMENT: Variables used across all stages
  // Change IMAGE_NAME to your Docker Hub username/repo
  // ============================================================
  environment {
    IMAGE_NAME    = "praveendevops95/devops-portfolio"
    IMAGE_TAG     = "v${BUILD_NUMBER}"
    GITOPS_REPO   = "github.com:MytPraveen/portfolio-gitops.git"
    GIT_USER_NAME = "Jenkins CI"
    GIT_USER_EMAIL= "jenkins@ci.com"

    // Trivy thresholds — pipeline FAILS if these are found
    // CRITICAL = serious vulnerabilities, HIGH = important ones
    TRIVY_SEVERITY = "CRITICAL,HIGH"
    TRIVY_EXIT_CODE = "1"       // 1 = fail pipeline on findings
  }

  // ============================================================
  // STAGES: Each stage is one step in the pipeline
  // ============================================================
  stages {

    // ----------------------------------------------------------
    // STAGE 1: Checkout
    // Jenkins pulls your code from GitHub into the workspace.
    // "checkout scm" uses whatever repo triggered the build.
    // ----------------------------------------------------------
    stage('Checkout Application Source') {
      steps {
        checkout scm
        sh 'echo "✅ Code checked out from GitHub"'
        sh 'ls -la'   // show files so you can verify in logs
      }
    }

    // ----------------------------------------------------------
    // STAGE 2: Build & Push Docker Image using Kaniko
    //
    // WHY KANIKO instead of docker build?
    // Normal "docker build" needs the Docker daemon running.
    // Inside Kubernetes, running Docker inside Docker is a
    // security risk. Kaniko builds images in userspace — no
    // daemon needed, much safer.
    //
    // The image is tagged with the Jenkins build number:
    // e.g. praveendevops95/devops-portfolio:v8
    // ----------------------------------------------------------
    stage('Build & Push Docker Image') {
      steps {
        container('kaniko') {
          sh '''
            echo "🔨 Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"

            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=${WORKSPACE} \
              --destination=${IMAGE_NAME}:${IMAGE_TAG} \
              --destination=${IMAGE_NAME}:latest \
              --cache=true \
              --cache-repo=${IMAGE_NAME}-cache \
              --cleanup

            echo "✅ Image pushed: ${IMAGE_NAME}:${IMAGE_TAG}"
          '''
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 3: Security Scan with Trivy
    //
    // Trivy scans the image you just built for known CVEs.
    // CVE = Common Vulnerabilities and Exposures (security bugs).
    //
    // TRIVY_EXIT_CODE=1 means: if CRITICAL or HIGH vulns found,
    // FAIL the pipeline. Don't deploy insecure images.
    //
    // In interview say: "We don't deploy if security scan fails.
    // The pipeline is the security gate."
    // ----------------------------------------------------------
    stage('Security Scan - Trivy') {
      steps {
        container('trivy') {
          sh '''
            echo "🔍 Scanning image for vulnerabilities..."

            trivy image \
              --exit-code ${TRIVY_EXIT_CODE} \
              --severity ${TRIVY_SEVERITY} \
              --no-progress \
              --format table \
              ${IMAGE_NAME}:${IMAGE_TAG}

            echo "✅ Security scan passed"
          '''
        }
      }
      // Even if scan fails, save the report as a Jenkins artifact
      post {
        always {
          container('trivy') {
            sh '''
              trivy image \
                --exit-code 0 \
                --severity CRITICAL,HIGH,MEDIUM \
                --format json \
                --output trivy-report.json \
                ${IMAGE_NAME}:${IMAGE_TAG} || true
            '''
          }
          archiveArtifacts artifacts: 'trivy-report.json',
                           allowEmptyArchive: true
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 4: Deploy to STAGING
    //
    // Jenkins updates the image tag in portfolio-gitops repo
    // in the STAGING section. ArgoCD picks this up and deploys
    // to the "portfolio-staging" namespace automatically.
    //
    // This is the GitOps pattern:
    // Jenkins never does "kubectl apply" directly.
    // Jenkins only updates Git. ArgoCD does the actual deploy.
    // Git is the single source of truth.
    // ----------------------------------------------------------
    stage('Deploy to Staging') {
      steps {
        container('git') {
          sh '''
            echo "📦 Updating staging image tag to ${IMAGE_TAG}..."
             mkdir -p /tmp/.ssh
              ssh-keyscan github.com > /tmp/.ssh/known_hosts

              echo "SSH files:"
               ls -la /root/.ssh
              export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o UserKnownHostsFile=/tmp/.ssh/known_hosts"

            git clone git@${GITOPS_REPO} gitops-repo
            cd gitops-repo

            git config user.email "${GIT_USER_EMAIL}"
            git config user.name "${GIT_USER_NAME}"

            sed -i "s|${IMAGE_NAME}:.*|${IMAGE_NAME}:${IMAGE_TAG}|g" \
              staging/deployment.yaml

            git add staging/deployment.yaml

            git commit -m "ci: update staging image to ${IMAGE_TAG} [build #${BUILD_NUMBER}]" || true

            git push origin main

            echo "✅ Staging deployment.yaml updated"
          '''
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 5: Staging Smoke Test
    //
    // Wait for ArgoCD to deploy to staging, then hit the URL
    // to verify the site is actually responding.
    // If it returns HTTP 200 = pass. Anything else = fail.
    //
    // "staging.praveeninfra.online" is your staging URL.
    // Change this to your actual staging domain/IP.
    // ----------------------------------------------------------
    stage('Staging Smoke Test') {
      steps {
        sh '''
          echo "⏳ Waiting 30s for ArgoCD to sync staging..."
          sleep 30

          echo "🧪 Running smoke test on staging..."

          # Try 5 times, 10 second gap between attempts
          for i in 1 2 3 4 5; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
              https://staging.praveeninfra.online || echo "000")

            if [ "$STATUS" = "200" ]; then
              echo "✅ Staging smoke test passed (HTTP 200)"
              exit 0
            fi

            echo "Attempt $i: got HTTP $STATUS, retrying in 10s..."
            sleep 10
          done

          echo "❌ Staging smoke test FAILED after 5 attempts"
          exit 1
        '''
      }
    }
    // ----------------------------------------------------------
    // STAGE 7: Deploy to PRODUCTION
    //
    // Same as staging update — Jenkins updates the production
    // deployment.yaml in GitOps repo with new image tag.
    // ArgoCD auto-syncs and does rolling update in K8s.
    // Zero downtime because K8s brings up new pod before
    // killing the old one (rolling update strategy).
    // ----------------------------------------------------------
    stage('Deploy to Production') {
      steps {
        container('git') {
          sh '''
            echo "🚀 Deploying ${IMAGE_TAG} to PRODUCTION..."

            mkdir -p /tmp/.ssh
            ssh-keyscan github.com > /tmp/.ssh/known_hosts

             export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o UserKnownHostsFile=/tmp/.ssh/known_hosts"

            cd gitops-repo

            sed -i "s|${IMAGE_NAME}:.*|${IMAGE_NAME}:${IMAGE_TAG}|g" deployment.yaml

            git add deployment.yaml

            git commit -m "ci: PRODUCTION deploy ${IMAGE_TAG} [build #${BUILD_NUMBER}]" || true

            git push origin main

            echo "✅ Production deployment.yaml updated"
            echo "ArgoCD will sync within 3 minutes automatically"
          '''
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 8: Production Health Check
    //
    // After deploy, verify production is healthy.
    // Same curl check but on the real domain.
    // ----------------------------------------------------------
    stage('Production Health Check') {
      steps {
        sh '''
          echo "⏳ Waiting 45s for production rollout..."
          sleep 45

          echo "🏥 Checking production health..."

          for i in 1 2 3 4 5; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
              https://praveeninfra.online || echo "000")

            if [ "$STATUS" = "200" ]; then
              echo "✅ Production health check passed (HTTP 200)"
              exit 0
            fi

            echo "Attempt $i: HTTP $STATUS, retrying in 15s..."
            sleep 15
          done

          echo "❌ Production health check FAILED — consider rollback"
          echo "Run: kubectl rollout undo deployment/portfolio -n portfolio"
          exit 1
        '''
      }
    }

  } // end stages

  // ============================================================
  // POST: Runs after pipeline finishes — success OR failure
  //
  // This is where you add Slack/email notifications.
  // Right now it just prints. When you add Slack plugin,
  // uncomment the slackSend lines.
  // ============================================================
  post {

    success {
      echo """
        ============================================
        ✅ PIPELINE SUCCESS
        Image: ${IMAGE_NAME}:${IMAGE_TAG}
        Job: ${JOB_NAME} #${BUILD_NUMBER}
        Duration: ${currentBuild.durationString}
        Site: https://praveeninfra.online
        ============================================
      """
      // When you add Slack plugin, uncomment:
      // slackSend(
      //   channel: '#deployments',
      //   color: 'good',
      //   message: "✅ *${JOB_NAME}* #${BUILD_NUMBER} deployed ${IMAGE_TAG} to production\\nhttps://praveeninfra.online"
      // )
    }

    failure {
      echo """
        ============================================
        ❌ PIPELINE FAILED
        Job: ${JOB_NAME} #${BUILD_NUMBER}
        Failed Stage: ${env.STAGE_NAME}
        Check logs: ${BUILD_URL}
        ============================================
      """
      // slackSend(
      //   channel: '#deployments',
      //   color: 'danger',
      //   message: "❌ *${JOB_NAME}* #${BUILD_NUMBER} FAILED at stage: ${env.STAGE_NAME}\\n${BUILD_URL}"
      // )
    }

    always {
      echo "Pipeline finished"
    }

  }

} // end pipeline
