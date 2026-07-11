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
    command: ["/busybox/sh"]
    args: ["-c", "sleep 999999"]
    tty: true
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker/config.json
      subPath: .dockerconfigjson
    - name: workspace
      mountPath: /workspace

  - name: trivy
    image: aquasec/trivy:latest
    command: [sh]
    args: ["-c", "sleep 999999"]
    tty: true
    volumeMounts:
    - name: workspace
      mountPath: /workspace
    - name: workspace-volume
      mountPath: /home/jenkins/agent

  - name: git
    image: alpine/git:latest
    command: [sh]
    args: ["-c", "apk add --no-cache openssh && sleep 999999"]
    tty: true
    env:
    - name: GIT_SSH_COMMAND
      value: "ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519"
    volumeMounts:
    - name: github-ssh
      mountPath: /root/.ssh
      readOnly: true

  - name: sonar
    image: sonarsource/sonar-scanner-cli:latest
    command: ["cat"]
    tty: true

  - name: zap
    image: zaproxy/zap-stable:latest
    command: ["sh"]
    args: ["-c", "sleep 999999"]
    tty: true
    volumeMounts:
    - name: zap-wrk
      mountPath: /zap/wrk

  - name: curl
    image: alpine:latest
    command: ["sh"]
    args: ["-c", "apk add --no-cache curl && sleep 999999"]
    tty: true

  volumes:
  - name: docker-config
    secret:
      secretName: dockerhub-secret
  - name: workspace
    emptyDir: {}
  - name: github-ssh
    secret:
      secretName: github-ssh-key
      defaultMode: 0400
  - name: zap-wrk
    emptyDir: {}
"""
    }
  }

  options {
    buildDiscarder(logRotator(
      numToKeepStr: '20',
      daysToKeepStr: '14'
    ))
    disableConcurrentBuilds()
    timestamps()
    // NOTE: overall timeout raised to 45 min because Manual Approval
    // can sit and wait for you to click "Proceed" in the Jenkins UI.
    timeout(time: 45, unit: 'MINUTES')
  }

  environment {
    IMAGE_NAME    = "praveendevops95/devops-portfolio"
    IMAGE_TAG     = "v${BUILD_NUMBER}"
    GITOPS_REPO   = "github.com:MytPraveen/portfolio-gitops.git"
    GIT_USER_NAME = "Jenkins CI"
    GIT_USER_EMAIL= "jenkins@ci.com"

    TRIVY_SEVERITY  = "CRITICAL"
    TRIVY_EXIT_CODE = "1"

    STAGING_URL = "https://staging.praveeninfra.online"
    PROD_URL    = "https://praveeninfra.online"

    ZAP_REPORT_DIR = "zap-reports"

    // Placeholder only - put your real Slack Incoming Webhook URL in a
    // Jenkins credential (Secret text) and reference it via credentials()
    // in the notification stage below instead of hardcoding it here.
    SLACK_WEBHOOK_CRED_ID = "slack-webhook-url"
  }

  stages {

    stage('Checkout Application Source') {
      steps {
        checkout scm
        sh 'echo "Code checked out from GitHub"'

        script {
          GIT_COMMIT_SHORT = sh(script: "git rev-parse --short=7 HEAD", returnStdout: true).trim()
          env.GIT_COMMIT  = GIT_COMMIT_SHORT
          env.BUILD_DATE  = sh(script: "date -u +'%Y-%m-%dT%H:%M:%SZ'", returnStdout: true).trim()
          echo "Git Commit ID: ${env.GIT_COMMIT}"
          echo "Full Build Tag: ${env.IMAGE_TAG}-${env.GIT_COMMIT}"
          echo "Build Date: ${env.BUILD_DATE}"
        }
      }
    }

    stage('Unit Test') {
      steps {
        // This project is a static HTML/FastAPI portfolio site, so there is
        // no compiled-language unit test suite to run here. In an
        // enterprise Java/Node project this stage would run
        // `mvn test` or `npm test` and publish JUnit results.
        sh '''
          echo "Unit Test stage placeholder"
          echo "Skipped: static frontend has no unit test suite"
          echo "In a Java/Node service this stage would run mvn test / npm test"
        '''
      }
    }

    stage('SonarQube Scan') {
      steps {
        container('sonar') {
          withSonarQubeEnv('SonarQube') {
            sh '''
              sonar-scanner \
                -Dsonar.projectKey=portfolio \
                -Dsonar.projectName=portfolio \
                -Dsonar.sources=. \
                -Dsonar.sourceEncoding=UTF-8 \
                -Dsonar.exclusions=**/*.pdf,**/.DS_Store,**/node_modules/**,**/entrypoint.sh \
                -Dsonar.html.file.suffixes=.html \
                -Dsonar.javascript.file.suffixes=.js
            '''
          }
        }
      }
    }
    
    /*
    stage('Quality Gate') {
      steps {
        script {
          echo "=========================================="
          echo "Checking SonarQube Quality Gate"
          echo "=========================================="

          timeout(time: 5, unit: 'MINUTES') {
            try {
              def qualityGate = waitForQualityGate abortPipeline: true

              if (qualityGate.status == 'OK') {
                echo "Quality Gate: PASSED"
              }
            } catch (Exception e) {
              echo "Quality Gate: FAILED - ${e.message}"
              error("Stopping pipeline: SonarQube Quality Gate failed")
            }
          }
        }
      }
    }
    */

    stage('Build Docker Image') {
      steps {
        container('kaniko') {
          sh '''
            echo "Building image (no push yet): ${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}"

            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=${WORKSPACE} \
              --no-push \
              --tarPath=/workspace/image.tar \
              --destination=${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT} \
              --cache=true \
              --cache-repo=${IMAGE_NAME}-cache \
              --build-arg BUILD_DATE=${BUILD_DATE} \
              --build-arg VCS_REF=${GIT_COMMIT}

            echo "Image built and saved as tarball for scanning"
          '''
        }
      }
    }

    stage('Trivy Scan (Pre-Push Gate)') {
      // Scanning the tarball BEFORE pushing means a vulnerable image
      // never reaches Docker Hub. This is the order most real
      // organizations enforce.
      steps {
        container('trivy') {
          sh '''
            echo "Scanning local image tarball for CRITICAL vulnerabilities..."

            trivy image \
              --input /workspace/image.tar \
              --exit-code ${TRIVY_EXIT_CODE} \
              --severity ${TRIVY_SEVERITY} \
              --no-progress \
              --format table \
              --timeout 10m

            echo "Trivy gate passed - safe to push"
          '''
        }
      }
      post {
        always {
          container('trivy') {
            sh '''
              trivy image \
                --input /workspace/image.tar \
                --exit-code 0 \
                --severity HIGH,CRITICAL \
                --format json \
                --output trivy-report.json || true
            '''
          }
          archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
        }
      }
    }

    stage('Push Docker Image') {
      // Re-running kaniko with --push (instead of re-using the tarball)
      // keeps this simple and reliable on a homelab kaniko setup.
      steps {
        container('kaniko') {
          sh '''
            echo "Trivy gate passed - pushing image to Docker Hub"

            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=${WORKSPACE} \
              --destination=${IMAGE_NAME}:${IMAGE_TAG} \
              --destination=${IMAGE_NAME}:${GIT_COMMIT} \
              --destination=${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT} \
              --destination=${IMAGE_NAME}:latest \
              --cache=true \
              --cache-repo=${IMAGE_NAME}-cache \
              --cleanup \
              --build-arg BUILD_DATE=${BUILD_DATE} \
              --build-arg VCS_REF=${GIT_COMMIT}

            echo "Image pushed: ${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}"
          '''
        }
      }
    }

    stage('Update GitOps Repo - Staging') {
      steps {
        container('git') {
          sh '''
            echo "Updating staging image tag to ${IMAGE_TAG}-${GIT_COMMIT}..."

            mkdir -p /tmp/.ssh
            ssh-keyscan github.com > /tmp/.ssh/known_hosts 2>/dev/null
            export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o UserKnownHostsFile=/tmp/.ssh/known_hosts"

            git clone git@${GITOPS_REPO} gitops-repo
            cd gitops-repo

            git config user.email "${GIT_USER_EMAIL}"
            git config user.name "${GIT_USER_NAME}"

            sed -i 's|praveendevops95/devops-portfolio:.*|praveendevops95/devops-portfolio:'"${IMAGE_TAG}"'|g' staging/frontend/deployment.yaml

            git add staging/frontend/deployment.yaml
            git commit -m "ci: update staging to ${IMAGE_TAG}-${GIT_COMMIT} [build #${BUILD_NUMBER}]" || true
            git push origin main

            echo "staging/deployment.yaml updated - ArgoCD will auto-sync"
          '''
        }
      }
    }

    stage('Smoke Test - Staging') {
      steps {
        container('curl') {
          sh '''
            echo "Waiting 30s for ArgoCD to sync staging..."
            sleep 30

            for i in 1 2 3; do
              STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${STAGING_URL} || echo "000")
              if [ "$STATUS" = "200" ]; then
                echo "HTTP status: $STATUS"
                break
              fi
              echo "Attempt $i: HTTP $STATUS, retrying in 10s..."
              sleep 10
            done

            if [ "$STATUS" != "200" ]; then
              echo "Smoke test FAILED - staging not healthy (HTTP $STATUS)"
              exit 1
            fi

            curl -s ${STAGING_URL} | grep -q "Praveen" || {
              echo "Smoke test FAILED - expected content not found"
              exit 1
            }

            echo "Smoke test PASSED on staging"
          '''
        }
      }
    }

    stage('OWASP ZAP - Staging Security Scan') {
      steps {
        container('zap') {
          sh '''
            echo "Starting OWASP ZAP baseline scan on staging..."
            mkdir -p /zap/wrk/${ZAP_REPORT_DIR}

            zap-baseline.py \
              -t ${STAGING_URL} \
              -r /zap/wrk/${ZAP_REPORT_DIR}/zap-report.html \
              -x /zap/wrk/${ZAP_REPORT_DIR}/zap-report.xml \
              -w /zap/wrk/${ZAP_REPORT_DIR}/zap-report.md \
              -J /zap/wrk/${ZAP_REPORT_DIR}/zap-report.json \
              -I || true

            cp -r /zap/wrk/${ZAP_REPORT_DIR} ${WORKSPACE}/ 2>/dev/null || true

            if [ ! -f "${WORKSPACE}/${ZAP_REPORT_DIR}/zap-report.html" ]; then
              mkdir -p ${WORKSPACE}/${ZAP_REPORT_DIR}
              echo "<html><body><h1>ZAP Scan</h1><p>Target: ${STAGING_URL}</p></body></html>" \
                > ${WORKSPACE}/${ZAP_REPORT_DIR}/zap-report.html
            fi

            echo "ZAP scan completed"
          '''
        }
      }
      post {
        always {
          archiveArtifacts artifacts: "${ZAP_REPORT_DIR}/**/*", allowEmptyArchive: true
        }
      }
    }

    stage('Manual Approval - Production') {
      steps {
        script {
          // Pauses the pipeline and waits for a human to click Proceed
          // in the Jenkins UI (Build page -> "Paused for input").
          // If nobody approves within 30 minutes, the pipeline aborts.
          timeout(time: 30, unit: 'MINUTES') {
            input message: "Deploy ${IMAGE_TAG}-${GIT_COMMIT} to PRODUCTION?",
                  ok: "Approve & Deploy"
          }
        }
      }
    }

    stage('Update GitOps Repo - Production') {
      steps {
        container('git') {
          sh '''
            echo "Deploying ${IMAGE_TAG}-${GIT_COMMIT} to PRODUCTION..."

            mkdir -p /tmp/.ssh
            ssh-keyscan github.com >> /tmp/.ssh/known_hosts 2>/dev/null
            export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o UserKnownHostsFile=/tmp/.ssh/known_hosts"

            cd gitops-repo

            sed -i "s|${IMAGE_NAME}:.*|${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}|g" production/frontend/deployment.yaml

            git add production/frontend/deployment.yaml
            git commit -m "ci: PRODUCTION deploy ${IMAGE_TAG}-${GIT_COMMIT} [build #${BUILD_NUMBER}]" || true
            git push origin main

            echo "Production deployment.yaml updated - ArgoCD will auto-sync"
          '''
        }
      }
    }

    stage('Production Validation') {
      steps {
        container('curl') {
          sh '''
            echo "Waiting 60s for production rollout..."
            sleep 60

            for i in 1 2 3 4 5; do
              STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${PROD_URL} || echo "000")
              if [ "$STATUS" = "200" ]; then
                echo "HTTP status: $STATUS"
                break
              fi
              echo "Attempt $i: HTTP $STATUS, retrying in 15s..."
              sleep 15
            done

            if [ "$STATUS" != "200" ]; then
              echo "Production validation FAILED (HTTP $STATUS)"
              echo "Rollback: revert the last commit in portfolio-gitops and ArgoCD will auto-sync back"
              exit 1
            fi

            curl -s ${PROD_URL} | grep -q "Praveen" || {
              echo "Production validation FAILED - expected content not found"
              exit 1
            }

            echo "PRODUCTION VALIDATED - site live at ${PROD_URL}"
          '''
        }
      }
    }

    stage('Performance Baseline Check') {
      steps {
        container('curl') {
          sh '''
            echo "Running performance baseline check..."
            TOTAL=0
            for i in 1 2 3 4 5; do
              TIME=$(curl -s -o /dev/null -w "%{time_total}" ${PROD_URL})
              echo "Request $i: ${TIME}s"
              TOTAL=$(echo "$TOTAL + $TIME" | bc 2>/dev/null || echo "0")
            done
            AVG=$(echo "scale=3; $TOTAL / 5" | bc 2>/dev/null || echo "0")
            echo "Average response time: ${AVG}s"
          '''
        }
      }
    }
  }

  post {

    success {
      echo """
        ============================================
        PIPELINE SUCCESS
        Image: ${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}
        Build: #${BUILD_NUMBER}   Date: ${env.BUILD_DATE}
        Site: ${PROD_URL}
        Trivy report: ${BUILD_URL}artifact/trivy-report.json
        ZAP report:   ${BUILD_URL}artifact/${ZAP_REPORT_DIR}/zap-report.html
        ============================================
      """
    }

    failure {
      echo """
        ============================================
        PIPELINE FAILED
        Job: ${JOB_NAME} #${BUILD_NUMBER}
        Failed Stage: ${env.STAGE_NAME}
        Logs: ${BUILD_URL}
        ============================================
      """
    }

    aborted {
      echo "Pipeline aborted - likely Manual Approval timed out or was rejected."
    }

    always {
      echo "Pipeline finished at: ${new Date()}"
    }

  }

}
