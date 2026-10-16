// CI/CD pipeline for the product-catalog service.
//
// Runs on the Jenkins controller that Terraform builds (terraform/modules/jenkins).
// AWS access comes from the EC2 instance role; there are no stored credentials.
// These variables are set globally by Jenkins Configuration as Code:
//   AWS_REGION, ECR_REPOSITORY_URL, EKS_CLUSTER_NAME, K8S_NAMESPACE
//
// Flow: checkout -> quality checks (lint, unit tests, Terraform validate)
//       -> build image -> container smoke test -> push to ECR -> vulnerability gate
//       -> deploy to EKS (rolling) -> live smoke test through the ALB
//       -> automatic rollback if anything after the deploy fails.

pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  parameters {
    booleanParam(name: 'SKIP_DEPLOY', defaultValue: false, description: 'Build, test and push only. Do not deploy.')
    choice(name: 'BLOCK_ON_SEVERITY', choices: ['CRITICAL', 'HIGH', 'NONE'], description: 'Fail the build if the ECR scan finds vulnerabilities at this severity or above.')
  }

  environment {
    APP_NAME            = 'product-catalog'
    TF_IN_AUTOMATION    = 'true'
    TF_PLUGIN_CACHE_DIR = "${env.JENKINS_HOME}/.terraform.d/plugin-cache"
  }

  stages {

    stage('Prepare') {
      steps {
        script {
          env.SHORT_SHA = env.GIT_COMMIT.take(7)
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.SHORT_SHA}"
          env.IMAGE     = "${env.ECR_REPOSITORY_URL}:${env.IMAGE_TAG}"
          currentBuild.description = "image ${env.IMAGE_TAG}"
        }
        sh 'mkdir -p "$TF_PLUGIN_CACHE_DIR"'
        echo "Building ${env.IMAGE}"
      }
    }

    stage('Quality checks') {
      parallel {

        stage('App: lint and unit tests') {
          agent {
            docker {
              image 'node:24-alpine'
              reuseNode true
              args '-e HOME=/tmp -e npm_config_cache=/tmp/.npm'
            }
          }
          steps {
            dir('app') {
              sh 'npm ci --no-audit --no-fund'
              sh 'npm run lint'
              sh 'npm run test:ci'
            }
          }
          post {
            always {
              junit allowEmptyResults: false, testResults: 'app/reports/junit.xml'
            }
          }
        }

        stage('Terraform: fmt and validate') {
          steps {
            sh 'terraform fmt -check -recursive -diff terraform'
            sh '''
              for dir in terraform/bootstrap terraform/environments/prod terraform/modules/*/; do
                echo "--- validate $dir"
                terraform -chdir="$dir" init -backend=false -input=false -no-color > /dev/null
                terraform -chdir="$dir" validate -no-color
              done
            '''
          }
        }
      }
    }

    stage('Build image') {
      steps {
        // The Dockerfile's `test` stage runs the unit tests again inside the
        // exact image toolchain; `runtime` is the image we ship.
        sh 'docker build --target test -t "$APP_NAME:test-$IMAGE_TAG" app/'
        sh 'docker build --target runtime --build-arg APP_VERSION="$IMAGE_TAG" -t "$IMAGE" app/'
      }
    }

    stage('Container smoke test') {
      steps {
        sh '''
          set -eu
          CID=$(docker run -d --rm -P "$IMAGE")
          trap 'docker stop "$CID" >/dev/null 2>&1 || true' EXIT
          PORT=$(docker port "$CID" 3000/tcp | head -n1 | cut -d: -f2)
          for i in $(seq 1 20); do
            curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null && break
            sleep 1
          done
          curl -fsS "http://127.0.0.1:$PORT/health" | grep -q '"status":"healthy"'
          curl -fsS "http://127.0.0.1:$PORT/api/v1/products" | grep -q '"count":3'
          echo "Container answered on /health and /api/v1/products"
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          REGISTRY="${ECR_REPOSITORY_URL%%/*}"
          aws ecr get-login-password --region "$AWS_REGION" \
            | docker login --username AWS --password-stdin "$REGISTRY"
          docker push "$IMAGE"
        '''
      }
    }

    stage('Vulnerability gate') {
      when { expression { params.BLOCK_ON_SEVERITY != 'NONE' } }
      steps {
        sh '''
          set -eu
          REPO="${ECR_REPOSITORY_URL#*/}"
          # ECR registers the scan-on-push a few seconds after the push; until then
          # the waiter fails with ScanNotFoundException instead of waiting.
          for i in $(seq 1 30); do
            aws ecr describe-image-scan-findings --region "$AWS_REGION" \
              --repository-name "$REPO" --image-id imageTag="$IMAGE_TAG" >/dev/null 2>&1 && break
            echo "Waiting for ECR to start the scan ($i/30)..."; sleep 2
          done
          aws ecr wait image-scan-complete --region "$AWS_REGION" \
            --repository-name "$REPO" --image-id imageTag="$IMAGE_TAG"
          aws ecr describe-image-scan-findings --region "$AWS_REGION" \
            --repository-name "$REPO" --image-id imageTag="$IMAGE_TAG" \
            --query 'imageScanFindings.findingSeverityCounts' --output json > scan.json
          echo "ECR scan severity counts:"; cat scan.json
          CRITICAL=$(jq '.CRITICAL // 0' scan.json)
          HIGH=$(jq '.HIGH // 0' scan.json)
          if [ "$CRITICAL" -gt 0 ]; then echo "Blocking: $CRITICAL CRITICAL findings"; exit 1; fi
          # Parameters are unset on a brand-new job's first run, so default to CRITICAL.
          if [ "${BLOCK_ON_SEVERITY:-CRITICAL}" = "HIGH" ] && [ "$HIGH" -gt 0 ]; then echo "Blocking: $HIGH HIGH findings"; exit 1; fi
          echo "Scan gate passed"
        '''
      }
    }

    stage('Deploy to EKS') {
      when { expression { !params.SKIP_DEPLOY } }
      steps {
        sh 'aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME" --kubeconfig "$WORKSPACE/.kubeconfig"'
        script { env.KUBECONFIG = "${env.WORKSPACE}/.kubeconfig" }
        sh '''
          set -eu
          rm -rf build/k8s && mkdir -p build/k8s
          for f in k8s/*.yaml; do
            sed -e "s|IMAGE_PLACEHOLDER|$IMAGE|g" \
                -e "s|IMAGE_TAG_PLACEHOLDER|$IMAGE_TAG|g" \
                "$f" > "build/k8s/$(basename "$f")"
          done
          # Server-side dry run first: catches RBAC, admission (Pod Security) and schema errors.
          kubectl apply --dry-run=server -n "$K8S_NAMESPACE" -f build/k8s/
        '''
        script { env.DEPLOYED = 'true' }
        sh '''
          set -eu
          kubectl apply -n "$K8S_NAMESPACE" -f build/k8s/
          kubectl rollout status deployment/"$APP_NAME" -n "$K8S_NAMESPACE" --timeout=300s
          kubectl get pods -n "$K8S_NAMESPACE" -l app.kubernetes.io/name="$APP_NAME" -o wide
        '''
      }
    }

    stage('Live smoke test') {
      when { expression { !params.SKIP_DEPLOY } }
      steps {
        sh '''
          set -eu
          echo "Waiting for the ALB address..."
          HOST=""
          for i in $(seq 1 60); do
            HOST=$(kubectl get ingress "$APP_NAME" -n "$K8S_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || true)
            [ -n "$HOST" ] && break
            sleep 5
          done
          [ -n "$HOST" ] || { echo "Ingress never got an address"; exit 1; }
          URL="http://$HOST"
          echo "$URL" > app-url.txt

          # A new ALB needs a few minutes for DNS and health checks; later deploys pass at once.
          echo "Checking $URL/health reports version $IMAGE_TAG"
          for i in $(seq 1 60); do
            if curl -fsS --max-time 5 "$URL/health" | grep -q "\\"version\\":\\"$IMAGE_TAG\\""; then
              curl -fsS "$URL/api/v1/products" | grep -q '"count":3'
              echo "Live at $URL (version $IMAGE_TAG)"
              exit 0
            fi
            sleep 10
          done
          echo "New version not serving through the ALB in time"
          exit 1
        '''
      }
    }
  }

  post {
    success {
      script {
        def url = fileExists('app-url.txt') ? readFile('app-url.txt').trim() : 'n/a'
        currentBuild.description = "image ${env.IMAGE_TAG} | ${url}"
        echo "SUCCESS: ${env.IMAGE} is live at ${url}"
      }
    }
    failure {
      script {
        if (env.DEPLOYED == 'true') {
          echo 'Deployment or live check failed: rolling back to the previous revision'
          sh '''
            kubectl rollout undo deployment/"$APP_NAME" -n "$K8S_NAMESPACE" \
              && kubectl rollout status deployment/"$APP_NAME" -n "$K8S_NAMESPACE" --timeout=300s \
              || echo "No earlier revision to roll back to (first deploy?)"
          '''
        }
      }
    }
    cleanup {
      // `cleanup` runs after `failure`, so the rollback above still has its kubeconfig.
      sh '''
        docker image rm "$IMAGE" "$APP_NAME:test-$IMAGE_TAG" >/dev/null 2>&1 || true
        docker image prune -f --filter "until=24h" >/dev/null 2>&1 || true
      '''
      cleanWs(deleteDirs: true, disableDeferredWipeout: true)
    }
  }
}
