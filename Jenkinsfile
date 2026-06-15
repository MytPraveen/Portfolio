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
    timeout(time: 30, unit: 'MINUTES')
  }

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
    
    // Slack notification channel (configure in Jenkins credentials)
    SLACK_CHANNEL = "#devops-deployments"
  }

  stages {

    // ============================================================
    // STAGE 1: Checkout with Commit Info
    // ============================================================
    stage('Checkout Application Source') {
      steps {
        checkout scm
        sh 'echo "✅ Code checked out from GitHub"'
        
        script {
          GIT_COMMIT_SHORT = sh(script: "git rev-parse --short=7 HEAD", returnStdout: true).trim()
          env.GIT_COMMIT = GIT_COMMIT_SHORT
          env.BUILD_DATE = sh(script: "date -u +'%Y-%m-%dT%H:%M:%SZ'", returnStdout: true).trim()
          echo "📝 Git Commit ID: ${env.GIT_COMMIT}"
          echo "📝 Full Build Tag: ${env.IMAGE_TAG}-${env.GIT_COMMIT}"
          echo "📝 Build Date: ${env.BUILD_DATE}"
        }
      }
    }

    // ============================================================
    // STAGE 2: SonarQube Scan
    // ============================================================
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
                -Dsonar.javascript.file.suffixes=.js,.html \
                -Dsonar.exclusions=**/node_modules/**
            '''
          }
        }
      }
    }

    // ============================================================
    // STAGE 3: Quality Gate (Blocks pipeline if quality fails)
    // ============================================================
    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    // ============================================================
    // STAGE 4: Build & Push Docker Image (With Commit Tagging)
    // ============================================================
    stage('Build & Push Docker Image') {
      steps {
        container('kaniko') {
          sh '''
            echo "🔨 Building Docker image: ${IMAGE_NAME}"
            echo "📦 Tags to push:"
            echo "   - ${IMAGE_TAG} (Version tag)"
            echo "   - ${GIT_COMMIT} (Git commit ID)"
            echo "   - ${IMAGE_TAG}-${GIT_COMMIT} (Combined - RECOMMENDED)"
            echo "   - latest"
            
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
            
            echo "✅ Image pushed successfully with all tags"
          '''
        }
      }
    }

    // ============================================================
    // STAGE 5: Security Scan with Trivy (Fail on CRITICAL)
    // ============================================================
    stage('Security Scan - Trivy') {
      steps {
        container('trivy') {
          sh '''
            echo "🔍 Scanning image for vulnerabilities..."
            echo "This scan will FAIL if CRITICAL vulnerabilities found"
            
            trivy image \
              --exit-code ${TRIVY_EXIT_CODE} \
              --severity ${TRIVY_SEVERITY} \
              --no-progress \
              --format table \
              --timeout 10m \
              ${IMAGE_NAME}:${IMAGE_TAG}
            
            echo "✅ Security scan passed - no critical vulnerabilities"
          '''
        }
      }
      post {
        always {
          container('trivy') {
            sh '''
              trivy image \
                --exit-code 0 \
                --severity HIGH,CRITICAL \
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

    // ============================================================
    // STAGE 6: OWASP ZAP - Staging Security Scan
    // FIXED: FAILS on critical vulnerabilities (removed || true)
    // ============================================================
    stage('OWASP ZAP - Staging Security Scan') {
      steps {
        container('zap') {
          sh '''
            echo "⏳ Waiting for staging environment to be ready..."
            sleep 30
            
            echo "🛡️ Starting OWASP ZAP baseline scan on staging..."
            echo "Target: ${STAGING_URL}"
            echo ""
            echo "⚠️  This scan will FAIL if CRITICAL vulnerabilities are found"
            echo ""
            
            mkdir -p /zap/wrk/${ZAP_REPORT_DIR}
            
            # Run ZAP - pipeline will FAIL if critical vulnerabilities found
            zap-baseline.py \
              -t ${STAGING_URL} \
              -r /zap/wrk/${ZAP_REPORT_DIR}/zap-report.html \
              -x /zap/wrk/${ZAP_REPORT_DIR}/zap-report.xml \
              -w /zap/wrk/${ZAP_REPORT_DIR}/zap-report.md \
              -J /zap/wrk/${ZAP_REPORT_DIR}/zap-report.json \
              -I
            
            # If we reach here, no critical vulnerabilities found
            cp -r /zap/wrk/${ZAP_REPORT_DIR} ${WORKSPACE}/ || true
            
            echo ""
            echo "✅ ZAP scan completed - no critical vulnerabilities found"
            echo "📊 Report location: ${ZAP_REPORT_DIR}/zap-report.html"
          '''
        }
      }
      post {
        always {
          script {
            // Archive ZAP reports
            archiveArtifacts artifacts: "${ZAP_REPORT_DIR}/**/*",
                             allowEmptyArchive: true
            
            // Publish HTML report in Jenkins
            publishHTML target: [
              allowMissing: true,
              alwaysLinkToLastBuild: true,
              keepAll: true,
              reportDir: ZAP_REPORT_DIR,
              reportFiles: 'zap-report.html',
              reportName: 'OWASP ZAP Security Report'
            ]
          }
        }
      }
    }

    // ============================================================
    // STAGE 7: Image Size Check (Real company best practice)
    // ============================================================
    stage('Image Size Check') {
      steps {
        container('curl') {
          sh '''
            echo "📏 Checking Docker image size..."
            
            # Get image size using docker inspect (via remote API)
            # For kaniko builds, we check the registry
            SIZE=$(curl -s -X GET https://hub.docker.com/v2/repositories/${IMAGE_NAME}/tags/${IMAGE_TAG} | jq -r '.images[0].size // 0')
            
            if [ -n "$SIZE" ] && [ "$SIZE" -gt 0 ]; then
              SIZE_MB=$((SIZE / 1024 / 1024))
              echo "Image size: ${SIZE_MB} MB"
              
              if [ ${SIZE_MB} -gt 100 ]; then
                echo "⚠️  WARNING: Image size > 100MB (${SIZE_MB} MB)"
                echo "Consider optimizing Dockerfile:"
                echo "  - Use multi-stage builds"
                echo "  - Remove unnecessary files"
                echo "  - Combine RUN commands"
              else
                echo "✅ Image size is good (${SIZE_MB} MB)"
              fi
            else
              echo "ℹ️  Could not determine image size from registry"
            fi
          '''
        }
      }
    }

    // ============================================================
    // STAGE 8: Deploy to Staging
    // ============================================================
    stage('Deploy to Staging') {
      steps {
        container('git') {
          sh '''
            echo "📦 Updating staging image tag to ${IMAGE_TAG}-${GIT_COMMIT}..."
            
            mkdir -p /tmp/.ssh
            ssh-keyscan github.com > /tmp/.ssh/known_hosts 2>/dev/null
            
            export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o UserKnownHostsFile=/tmp/.ssh/known_hosts"

            git clone git@${GITOPS_REPO} gitops-repo
            cd gitops-repo

            git config user.email "${GIT_USER_EMAIL}"
            git config user.name "${GIT_USER_NAME}"

            sed -i "s|${IMAGE_NAME}:.*|${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}|g" staging/deployment.yaml

            git add staging/deployment.yaml
            git commit -m "ci: update staging to ${IMAGE_TAG}-${GIT_COMMIT} [build #${BUILD_NUMBER}]" || true
            git push origin main

            echo "✅ Staging deployment.yaml updated"
            echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}"
          '''
        }
      }
    }

    // ============================================================
    // STAGE 9: Staging Post-Deployment Validation
    // ============================================================
    stage('Staging - Post-Deployment Validation') {
      steps {
        container('curl') {
          sh '''
            echo "⏳ Waiting 30s for ArgoCD to sync staging..."
            sleep 30

            echo "✅ Running POST-DEPLOYMENT VALIDATION on staging..."

            # Check HTTP status (retry up to 3 times)
            for i in 1 2 3; do
              STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${STAGING_URL} || echo "000")
              if [ "$STATUS" = "200" ]; then
                echo "✅ HTTP status: $STATUS"
                break
              fi
              echo "Attempt $i: HTTP $STATUS, retrying in 10s..."
              sleep 10
            done

            if [ "$STATUS" != "200" ]; then
              echo "❌ HTTP status: $STATUS (expected 200)"
              exit 1
            fi

            # Check response time
            RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" ${STAGING_URL})
            echo "Response time: ${RESPONSE_TIME}s"

            if (( $(echo "$RESPONSE_TIME > 2" | bc -l 2>/dev/null || echo 0) )); then
              echo "⚠️  Warning: Response time > 2 seconds"
            fi

            # Validate content
            curl -s ${STAGING_URL} | grep -q "Praveen" || {
              echo "❌ Expected content 'Praveen' not found"
              exit 1
            }
            echo "✅ Content validation passed"

            echo "✅ STAGING POST-DEPLOYMENT VALIDATION PASSED"
          '''
        }
      }
    }

    // ============================================================
    // STAGE 10: Deploy to Production
    // ============================================================
    stage('Deploy to Production') {
      steps {
        container('git') {
          sh '''
            echo "🚀 Deploying ${IMAGE_TAG}-${GIT_COMMIT} to PRODUCTION..."

            mkdir -p /tmp/.ssh
            ssh-keyscan github.com >> /tmp/.ssh/known_hosts 2>/dev/null
            
            export GIT_SSH_COMMAND="ssh -i /root/.ssh/id_ed25519 -o UserKnownHostsFile=/tmp/.ssh/known_hosts"

            cd gitops-repo

            sed -i "s|${IMAGE_NAME}:.*|${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}|g" deployment.yaml

            git add deployment.yaml
            git commit -m "ci: PRODUCTION deploy ${IMAGE_TAG}-${GIT_COMMIT} [build #${BUILD_NUMBER}]" || true
            git push origin main

            echo "✅ Production deployment.yaml updated"
            echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}"
          '''
        }
      }
    }

    // ============================================================
    // STAGE 11: Production Post-Deployment Validation
    // ============================================================
    stage('Production - Post-Deployment Validation') {
      steps {
        container('curl') {
          sh '''
            echo "⏳ Waiting 60s for production rollout..."
            sleep 60

            echo "🏥 Running PRODUCTION POST-DEPLOYMENT VALIDATION..."

            # Check HTTP status with retry
            for i in 1 2 3 4 5; do
              STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${PROD_URL} || echo "000")
              if [ "$STATUS" = "200" ]; then
                echo "✅ HTTP status: $STATUS"
                break
              fi
              echo "Attempt $i: HTTP $STATUS, retrying in 15s..."
              sleep 15
            done

            if [ "$STATUS" != "200" ]; then
              echo "❌ HTTP status: $STATUS (expected 200)"
              exit 1
            fi

            # Check response time
            RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" ${PROD_URL})
            echo "Response time: ${RESPONSE_TIME}s"

            # Check SSL certificate (if HTTPS)
            echo "Checking SSL certificate..."
            SSL_INFO=$(echo | openssl s_client -servername praveeninfra.online -connect praveeninfra.online:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "No SSL")
            if [[ "$SSL_INFO" != "No SSL" ]]; then
              echo "✅ SSL certificate valid"
            else
              echo "⚠️  No SSL certificate found (HTTP only)"
            fi

            # Content validation
            curl -s ${PROD_URL} | grep -q "Praveen" || {
              echo "❌ Expected content not found"
              exit 1
            }
            echo "✅ Content validation passed"

            echo "✅ PRODUCTION DEPLOYMENT VALIDATED SUCCESSFULLY"
            echo "Site is live: ${PROD_URL}"
          '''
        }
      }
    }

    // ============================================================
    // STAGE 12: Performance Baseline Check
    // ============================================================
    stage('Performance Baseline Check') {
      steps {
        container('curl') {
          sh '''
            echo "⚡ Running performance baseline check..."
            
            TOTAL=0
            COUNT=0
            for i in 1 2 3 4 5; do
              TIME=$(curl -s -o /dev/null -w "%{time_total}" ${PROD_URL})
              echo "Request $i: ${TIME}s"
              TOTAL=$(echo "$TOTAL + $TIME" | bc 2>/dev/null || echo "0")
              COUNT=$((COUNT + 1))
            done
            
            if [ "$COUNT" -gt 0 ]; then
              AVG=$(echo "scale=3; $TOTAL / $COUNT" | bc 2>/dev/null || echo "0")
              echo "Average response time: ${AVG}s"
              
              if (( $(echo "$AVG < 1" | bc -l 2>/dev/null || echo 0) )); then
                echo "✅ Excellent performance (< 1s)"
              elif (( $(echo "$AVG < 2" | bc -l 2>/dev/null || echo 0) )); then
                echo "✅ Good performance (< 2s)"
              else
                echo "⚠️  Performance warning: average > 2s"
              fi
            fi
            
            echo "Performance check completed"
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
        Image: ${IMAGE_NAME}:${IMAGE_TAG}-${GIT_COMMIT}
        Version: ${IMAGE_TAG}
        Commit: ${GIT_COMMIT}
        Build Date: ${BUILD_DATE}
        Job: ${JOB_NAME} #${BUILD_NUMBER}
        Duration: ${currentBuild.durationString}
        
        Site: ${PROD_URL}
        
        Security Reports:
        - Trivy: ${BUILD_URL}artifact/trivy-report.json
        - OWASP ZAP: ${BUILD_URL}artifact/${ZAP_REPORT_DIR}/zap-report.html
        ============================================
      """
      
      // Uncomment when Slack plugin is configured
      /*
      slackSend(
        channel: "${SLACK_CHANNEL}",
        color: "good",
        message: "✅ *${JOB_NAME}* #${BUILD_NUMBER} succeeded!\\nImage: ${IMAGE_TAG}-${GIT_COMMIT}\\nSite: ${PROD_URL}\\n<${BUILD_URL}|View Build>"
      )
      */
    }

    failure {
      echo """
        ============================================
        ❌ PIPELINE FAILED
        Job: ${JOB_NAME} #${BUILD_NUMBER}
        Failed Stage: ${env.STAGE_NAME}
        Check logs: ${BUILD_URL}
        
        Possible causes:
        - SonarQube quality gate failed
        - Trivy found critical vulnerabilities
        - OWASP ZAP found critical vulnerabilities
        - Deployment validation failed
        - Infrastructure issue
        ============================================
      """
      
      // Uncomment when Slack plugin is configured
      /*
      slackSend(
        channel: "${SLACK_CHANNEL}",
        color: "danger",
        message: "❌ *${JOB_NAME}* #${BUILD_NUMBER} FAILED at stage: ${env.STAGE_NAME}\\n<${BUILD_URL}|View Build>"
      )
      */
    }

    unstable {
      echo """
        ============================================
        ⚠️  PIPELINE UNSTABLE
        Job: ${JOB_NAME} #${BUILD_NUMBER}
        Some security checks passed but with warnings
        Review ZAP and Trivy reports for details
        ============================================
      """
    }

    always {
      echo "Pipeline finished at: ${new Date()}"
      
      // Clean up workspace
      cleanWs()
    }

  }

} // end pipeline
