pipeline {

  // ============================================================
  // AGENT: Jenkins runs each build in a fresh Kubernetes pod
  // ============================================================
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:

  # --- Kaniko: builds Docker image WITHOUT needing Docker daemon
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

  # --- Trivy: scans the built image for CVEs
  - name: trivy
    image: aquasec/trivy:latest
    command: [sh]
    args: ["-c", "sleep 999999"]
    tty: true

  # --- Git: used to update the GitOps repo
  - name: git
    image: alpine/git:latest
    command: [sh]
    args: ["-c", "sleep 999999"]
    tty: true
    volumeMounts:
    - name: github-ssh
      mountPath: /root/.ssh
      readOnly: true

  # --- SonarQube scanner
  - name: sonar
    image: sonarsource/sonar-scanner-cli:latest
    command: ["cat"]
    tty: true

  # --- OWASP ZAP container for security scanning
  - name: zap
    image: owasp/zap2docker-stable:latest
    command: ["sh"]
    args: ["-c", "sleep 999999"]
    tty: true

  # --- Curl container for health checks
  - name: curl
    image: curlimages/curl:latest
    command: ["sh"]
    args: ["-c", "sleep 999999"]
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
"""
    }
  }

  // ============================================================
  // OPTIONS: Pipeline-level settings
  // ============================================================
  options {
    buildDiscarder(logRotator(
      numToKeepStr: '20',
      daysToKeepStr: '14'
    ))
    disableConcurrentBuilds()
    timestamps()
    timeout(time: 25, unit: 'MINUTES')
  }

  // ============================================================
  // ENVIRONMENT: Variables
  // ============================================================
  environment {
    IMAGE_NAME    = "praveendevops95/devops-portfolio"
    IMAGE_TAG     = "v${BUILD_NUMBER}"
    GITOPS_REPO   = "github.com:MytPraveen/portfolio-gitops.git"
    GIT_USER_NAME = "Jenkins CI"
    GIT_USER_EMAIL= "jenkins@ci.com"

    TRIVY_SEVERITY = "CRITICAL"
    TRIVY_EXIT_CODE = "1"

    STAGING_URL  = "https://staging.praveeninfra.online"
    PROD_URL     = "https://praveeninfra.online"
    
    ZAP_REPORT_DIR = "zap-reports"
  }

  stages {

    // ----------------------------------------------------------
    // STAGE 1: Checkout
    // ----------------------------------------------------------
    stage('Checkout Application Source') {
      steps {
        checkout scm
        sh 'echo "✅ Code checked out from GitHub"'
        sh 'ls -la'
      }
    }

    // ----------------------------------------------------------
    // STAGE 2: SonarQube Scan
    // ----------------------------------------------------------
    stage('SonarQube Scan') {
      steps {
        container('sonar') {
          withSonarQubeEnv('SonarQube') {
            sh '''
              sonar-scanner \
                -Dsonar.projectKey=portfolio \
                -Dsonar.projectName=portfolio \
                -Dsonar.sources=. \
                -Dsonar.sourceEncoding=UTF-8
            '''
          }
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 3: Quality Gate
    // ----------------------------------------------------------
    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 4: Build & Push Docker Image using Kaniko
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
    // STAGE 5: Security Scan with Trivy
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
      post {
        always {
          container('trivy') {
            sh '''
              trivy image \
                --exit-code 1 \
                --severity CRITICAL \
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
    // STAGE 6: OWASP ZAP Baseline Scan
    // ----------------------------------------------------------
    stage('OWASP ZAP - Staging Security Scan') {
      steps {
        container('zap') {
          sh '''
            echo "⏳ Waiting for staging environment to be ready..."
            sleep 30
            
            echo "🛡️ Starting OWASP ZAP baseline scan on staging..."
            echo "Target: ${STAGING_URL}"
            
            mkdir -p ${ZAP_REPORT_DIR}
            
            zap-full-scan.py \
              -t ${STAGING_URL} \
              -r ${ZAP_REPORT_DIR}/zap-report.html \
              -x ${ZAP_REPORT_DIR}/zap-report.xml \
              -w ${ZAP_REPORT_DIR}/zap-report.md \
              -a \
              -d \
              || true
            
            echo "✅ ZAP scan completed"
            
            echo ""
            echo "========== ZAP SCAN SUMMARY =========="
            echo "Check the HTML report for full details"
            echo "Report location: ${ZAP_REPORT_DIR}/zap-report.html"
            echo "======================================"
          '''
        }
      }
      post {
        always {
          archiveArtifacts artifacts: "${ZAP_REPORT_DIR}/**/*",
                           allowEmptyArchive: true
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 7: Deploy to STAGING
    // ----------------------------------------------------------
    stage('Deploy to Staging') {
      steps {
        container('git') {
          sh '''
            echo "📦 Updating staging image tag to ${IMAGE_TAG}..."
            
            mkdir -p /tmp/.ssh
            ssh-keyscan github.com > /tmp/.ssh/known_hosts
            
            export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o UserKnownHostsFile=/tmp/.ssh/known_hosts"

            git clone git@${GITOPS_REPO} gitops-repo
            cd gitops-repo

            git config user.email "${GIT_USER_EMAIL}"
            git config user.name "${GIT_USER_NAME}"

            sed -i "s|${IMAGE_NAME}:.*|${IMAGE_NAME}:${IMAGE_TAG}|g" staging/deployment.yaml

            git add staging/deployment.yaml
            git commit -m "ci: update staging image to ${IMAGE_TAG} [build #${BUILD_NUMBER}]" || true
            git push origin main

            echo "✅ Staging deployment.yaml updated"
          '''
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 8: Staging Smoke Test + Post-Deployment Validation
    // ----------------------------------------------------------
    stage('Staging - Post-Deployment Validation') {
      steps {
        container('curl') {
          sh '''
            echo "⏳ Waiting 30s for ArgoCD to sync staging..."
            sleep 30

            echo "✅ Running POST-DEPLOYMENT VALIDATION on staging..."

            # 1. Check HTTP status code
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${STAGING_URL} || echo "000")
            if [ "$STATUS" != "200" ]; then
              echo "❌ HTTP status: $STATUS (expected 200)"
              exit 1
            fi
            echo "✅ HTTP status: $STATUS"

            # 2. Check response time
            RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" ${STAGING_URL})
            echo "Response time: ${RESPONSE_TIME}s"

            # 3. Validate HTML content
            curl -s ${STAGING_URL} | grep -q "Praveen" || {
              echo "❌ Expected content 'Praveen' not found in page"
              exit 1
            }
            echo "✅ Content validation passed"

            # 4. Check for error patterns (FIXED: no backslash inside string)
            if curl -s ${STAGING_URL} | grep -qi "error"; then
              echo "⚠️ Warning: 'error' keyword found in response"
            else
              echo "✅ No error patterns detected"
            fi

            echo "=========================================="
            echo "✅ STAGING POST-DEPLOYMENT VALIDATION PASSED"
            echo "=========================================="
          '''
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 9: Deploy to PRODUCTION
    // ----------------------------------------------------------
    stage('Deploy to Production') {
      steps {
        container('git') {
          sh '''
            echo "🚀 Deploying ${IMAGE_TAG} to PRODUCTION..."

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
    // STAGE 10: Production - Post-Deployment Validation
    // ----------------------------------------------------------
    stage('Production - Post-Deployment Validation') {
      steps {
        container('curl') {
          sh '''
            echo "⏳ Waiting 60s for production rollout..."
            sleep 60

            echo "🏥 Running PRODUCTION POST-DEPLOYMENT VALIDATION..."

            # 1. Check HTTP status
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${PROD_URL} || echo "000")
            if [ "$STATUS" != "200" ]; then
              echo "❌ HTTP status: $STATUS (expected 200)"
              exit 1
            fi
            echo "✅ HTTP status: $STATUS"

            # 2. Check response time
            RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" ${PROD_URL})
            echo "Response time: ${RESPONSE_TIME}s"

            # 3. Content validation
            curl -s ${PROD_URL} | grep -q "Praveen" || {
              echo "❌ Expected content not found"
              exit 1
            }
            echo "✅ Content validation passed"

            # 4. Check for server errors (FIXED: no backslash)
            if curl -s ${PROD_URL} | grep -qi "500"; then
              echo "❌ Server error 500 found in response"
              exit 1
            else
              echo "✅ No server errors detected"
            fi

            echo "=========================================="
            echo "✅ PRODUCTION DEPLOYMENT VALIDATED SUCCESSFULLY"
            echo "Site is live: ${PROD_URL}"
            echo "Image version: ${IMAGE_NAME}:${IMAGE_TAG}"
            echo "=========================================="
          '''
        }
      }
    }

    // ----------------------------------------------------------
    // STAGE 11: Performance Baseline Check
    // ----------------------------------------------------------
    stage('Performance Baseline Check') {
      steps {
        container('curl') {
          sh '''
            echo "⚡ Running performance baseline check..."
            
            # Simple response time test
            TOTAL_TIME=0
            for i in 1 2 3 4 5; do
              TIME=$(curl -s -o /dev/null -w "%{time_total}" ${PROD_URL})
              TOTAL_TIME=$(echo "$TOTAL_TIME + $TIME" | bc)
              echo "Request $i: ${TIME}s"
            done
            AVG_TIME=$(echo "scale=3; $TOTAL_TIME / 5" | bc)
            echo "Average response time: ${AVG_TIME}s"
            
            if (( $(echo "$AVG_TIME < 2" | bc -l) )); then
              echo "✅ Performance is good (under 2 seconds)"
            else
              echo "⚠️ Performance warning: over 2 seconds"
            fi
          '''
        }
      }
    }

  } // end stages

  // ============================================================
  // POST: Runs after pipeline finishes
  // ============================================================
  post {

    success {
      echo """
        ============================================
        ✅ PIPELINE SUCCESS
        Image: ${IMAGE_NAME}:${IMAGE_TAG}
        Job: ${JOB_NAME} #${BUILD_NUMBER}
        Duration: ${currentBuild.durationString}
        
        Deployed URLs:
        Staging: ${STAGING_URL}
        Production: ${PROD_URL}
        
        Security Reports:
        Trivy: ${BUILD_URL}artifact/trivy-report.json
        OWASP ZAP: ${BUILD_URL}artifact/${ZAP_REPORT_DIR}/zap-report.html
        ============================================
      """
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
    }

    always {
      echo "Pipeline finished at: ${new Date()}"
    }

  }

} // end pipeline
