pipeline {
    agent { label 'sonar' }

    environment {
        SONARQUBE_SERVER = 'sonar'
        NEXUS_URL = 'http://3.19.221.46:8081'
        NEXUS_REPO = 'raw-releases'
        NEXUS_GROUP = 'com/web/pomodoro'
        NEXUS_ARTIFACT = 'pomodoro-app'
        NGINX_SERVER = '18.116.203.32'
        NGINX_WEB_ROOT = '/var/www/html/pomodoro'
    }

    stages {
        /* === Stage 1: Checkout Code === */
        stage('Checkout Code') {
            steps {
                echo '📦 Cloning source from GitHub...'
                checkout([$class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[url: 'https://github.com/ashuvee/pomodoro-app-js.git']]
                ])
            }
        }

        /* === Stage 2: Install Dependencies === */
        stage('Install Dependencies') {
            steps {
                echo '📥 Installing npm dependencies...'
                sh 'npm install'
                sh 'echo ✅ Dependencies installed!'
            }
        }

        /* === Stage 3: SonarQube Analysis === */
        stage('SonarQube Analysis') {
            steps {
                echo '🔍 Running SonarQube static analysis...'
                withSonarQubeEnv("${SONARQUBE_SERVER}") {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=pomodoro-app-js \
                          -Dsonar.projectName="Pomodoro App JS" \
                          -Dsonar.projectVersion=0.0.${BUILD_NUMBER} \
                          -Dsonar.sources=src \
                          -Dsonar.language=js \
                          -Dsonar.sourceEncoding=UTF-8
                    '''
                }
            }
        }

        /* === Stage 4: Run Tests === */
        stage('Run Tests') {
            steps {
                echo '🧪 Running tests...'
                sh 'npm test'
            }
        }

        /* === Stage 5: Build Artifact === */
        stage('Build Artifact') {
            steps {
                echo '⚙️ Building application...'
                sh 'npm run build'
                sh 'echo ✅ Build Completed!'
                sh 'ls -lh dist/ || true'
            }
        }

        /* === Stage 6: Package Artifact === */
        stage('Package Artifact') {
            steps {
                echo '📦 Creating tarball...'
                sh '''
                    VERSION="0.0.${BUILD_NUMBER}"
                    tar -czf ${NEXUS_ARTIFACT}-${VERSION}.tar.gz -C dist .
                    echo "✅ Package created: ${NEXUS_ARTIFACT}-${VERSION}.tar.gz"
                    ls -lh *.tar.gz
                '''
            }
        }

        /* === Stage 7: Upload Artifact to Nexus === */
        stage('Upload Artifact to Nexus') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus', usernameVariable: 'NEXUS_USR', passwordVariable: 'NEXUS_PSW')]) {
                    sh '''#!/bin/bash
                        set -e
                        VERSION="0.0.${BUILD_NUMBER}"
                        TARBALL="${NEXUS_ARTIFACT}-${VERSION}.tar.gz"

                        echo "📤 Uploading $TARBALL to Nexus..."

                        curl -v -u ${NEXUS_USR}:${NEXUS_PSW} --upload-file "$TARBALL" \
                          "${NEXUS_URL}/repository/${NEXUS_REPO}/${NEXUS_GROUP}/${NEXUS_ARTIFACT}/${VERSION}/${TARBALL}"

                        echo "✅ Artifact uploaded successfully to Nexus!"
                    '''
                }
            }
        }

        /* === Stage 8: Deploy to Nginx === */
        stage('Deploy to Nginx') {
            agent { label 'tomcat' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus', usernameVariable: 'NEXUS_USR', passwordVariable: 'NEXUS_PSW')]) {
                    sh '''#!/bin/bash
                        set -e
                        cd /tmp; rm -f *.tar.gz

                        VERSION="0.0.${BUILD_NUMBER}"
                        TARBALL="${NEXUS_ARTIFACT}-${VERSION}.tar.gz"
                        DOWNLOAD_URL="${NEXUS_URL}/repository/${NEXUS_REPO}/${NEXUS_GROUP}/${NEXUS_ARTIFACT}/${VERSION}/${TARBALL}"

                        echo "⬇️ Downloading tarball from: $DOWNLOAD_URL"
                        curl -f -u ${NEXUS_USR}:${NEXUS_PSW} -O "$DOWNLOAD_URL"

                        if [[ ! -f "$TARBALL" ]]; then
                            echo "❌ Download failed!"
                            exit 1
                        fi

                        echo "🚀 Deploying to Nginx..."
                        sudo mkdir -p ${NGINX_WEB_ROOT}
                        sudo rm -rf ${NGINX_WEB_ROOT}/*
                        sudo tar -xzf "$TARBALL" -C ${NGINX_WEB_ROOT}/
                        sudo chown -R www-data:www-data ${NGINX_WEB_ROOT}

                        echo "✅ Deployment successful! Application live on Nginx!"
                    '''
                }
            }
        }
    }

    post {
        success { echo '🎉 Pipeline completed successfully — Application live on Nginx!' }
        failure { echo '❌ Pipeline failed — Check Jenkins logs.' }
    }
}
