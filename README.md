# Jenkins Pipeline Documentation - Complete Setup Guide

## Overview

This Jenkins pipeline automates the CI/CD process for the Pomodoro App, handling everything from code checkout to deployment on Nginx. The pipeline builds, tests, packages, and deploys the application through a series of automated stages.

---

## Table of Contents
1. [Jenkins Master Setup](#jenkins-master-setup)
2. [Required Plugins](#required-plugins)
3. [Jenkins Agents Configuration](#jenkins-agents-configuration)
4. [External Services Setup](#external-services-setup)
5. [Pipeline Stages Deep Dive](#pipeline-stages-deep-dive)

---

## Jenkins Master Setup

### 1. Install Jenkins

**On Ubuntu/Debian:**
```bash
# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt-get update
sudo apt-get install jenkins -y

# Install Java (Jenkins requirement)
sudo apt-get install openjdk-17-jdk -y

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Access Jenkins:**
- URL: `http://your-server-ip:8080`
- Use the initial admin password to unlock
- Install suggested plugins during setup wizard

### 2. Basic Jenkins Configuration

After installation:
1. Navigate to `Manage Jenkins` → `System`
2. Set `# of executors` to appropriate value (e.g., 2-4)
3. Configure `Jenkins URL` to your actual URL
4. Save configuration

---

## Required Plugins

### Installation Steps
Navigate to: `Manage Jenkins` → `Plugins` → `Available plugins`

### Essential Plugins List

| Plugin Name | Purpose | Installation Command |
|------------|---------|---------------------|
| **Git** | Source code management | Pre-installed with suggested plugins |
| **Pipeline** | Pipeline support | Pre-installed with suggested plugins |
| **Pipeline: Stage View** | Visual pipeline stages | Pre-installed with suggested plugins |
| **Credentials Binding** | Secure credential handling | Pre-installed with suggested plugins |
| **SSH Agent** | SSH authentication | `ssh-agent` |
| **NodeJS Plugin** | Node.js environment | `nodejs` |
| **SonarQube Scanner** | Code quality analysis | `sonar` |
| **Nexus Artifact Uploader** | Nexus integration | `nexus-artifact-uploader` |

### Plugin Installation via CLI (Alternative)
```bash
# Install plugins via Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin nodejs
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin sonar
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin nexus-artifact-uploader
java -jar jenkins-cli.jar -s http://localhost:8080/ safe-restart
```

### Configure NodeJS Plugin
1. Go to `Manage Jenkins` → `Tools`
2. Scroll to `NodeJS installations`
3. Click `Add NodeJS`
   - Name: `NodeJS-LTS` (or your preferred name)
   - Version: Select latest LTS (e.g., 20.x)
   - Check "Install automatically"
4. Save configuration

---

## Jenkins Agents Configuration

### Agent 1: 'sonar' (Build Agent)

**Purpose**: Handles stages 1-6 (checkout, build, test, package, upload)

#### Setup on Agent Machine

```bash
# Install Java
sudo apt-get update
sudo apt-get install openjdk-17-jdk -y

# Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installations
java -version
node -v
npm -v

# Install Git
sudo apt-get install git -y

# Install required tools
sudo apt-get install curl tar -y

# Create Jenkins user and workspace
sudo useradd -m -s /bin/bash jenkins
sudo mkdir -p /home/jenkins/workspace
sudo chown -R jenkins:jenkins /home/jenkins
```

#### Configure in Jenkins

1. Go to `Manage Jenkins` → `Nodes`
2. Click `New Node`
3. Configuration:
   - **Node name**: `sonar`
   - **Type**: Permanent Agent
   - **# of executors**: 2
   - **Remote root directory**: `/home/jenkins`
   - **Labels**: `sonar`
   - **Usage**: Use this node as much as possible
   - **Launch method**: Launch agent via SSH
     - **Host**: [Agent IP address]
     - **Credentials**: Add SSH credentials (username: jenkins)
     - **Host Key Verification Strategy**: Non verifying Verification Strategy
   - **Availability**: Keep this agent online as much as possible

4. Save and launch agent

### Agent 2: 'tomcat' (Deployment Agent)

**Purpose**: Handles stage 7 (deployment to Nginx)

#### Setup on Agent Machine

```bash
# Install Java
sudo apt-get update
sudo apt-get install openjdk-17-jdk -y

# Install required tools
sudo apt-get install curl tar -y

# Create Jenkins user
sudo useradd -m -s /bin/bash jenkins

# Configure sudo for Jenkins user (for deployment)
echo "jenkins ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/rm, /bin/tar, /bin/chown" | sudo tee /etc/sudoers.d/jenkins
sudo chmod 0440 /etc/sudoers.d/jenkins

# Create workspace
sudo mkdir -p /home/jenkins/workspace
sudo chown -R jenkins:jenkins /home/jenkins

# Prepare Nginx deployment directory
sudo mkdir -p /var/www/html/pomodoro
sudo chown -R www-data:www-data /var/www/html/pomodoro
```

#### Configure in Jenkins

1. Go to `Manage Jenkins` → `Nodes`
2. Click `New Node`
3. Configuration:
   - **Node name**: `tomcat`
   - **Type**: Permanent Agent
   - **# of executors**: 1
   - **Remote root directory**: `/home/jenkins`
   - **Labels**: `tomcat`
   - **Usage**: Only build jobs with label expressions matching this node
   - **Launch method**: Launch agent via SSH
     - **Host**: [Agent IP address]
     - **Credentials**: Add SSH credentials (username: jenkins)
   - **Availability**: Keep this agent online as much as possible

4. Save and launch agent

---

## External Services Setup

### 1. SonarQube Server Configuration

#### Install SonarQube
```bash
# Install PostgreSQL
sudo apt-get install postgresql postgresql-contrib -y

# Create SonarQube database
sudo -u postgres psql
CREATE DATABASE sonarqube;
CREATE USER sonarqube WITH ENCRYPTED PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;
\q

# Download and install SonarQube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.3.0.82913.zip
unzip sonarqube-10.3.0.82913.zip
sudo mv sonarqube-10.3.0.82913 /opt/sonarqube

# Create SonarQube user
sudo useradd -r -s /bin/bash sonar
sudo chown -R sonar:sonar /opt/sonarqube

# Start SonarQube
sudo -u sonar /opt/sonarqube/bin/linux-x86-64/sonar.sh start
```

#### Configure in Jenkins
1. Go to `Manage Jenkins` → `System`
2. Scroll to `SonarQube servers`
3. Click `Add SonarQube`
   - **Name**: `sonar`
   - **Server URL**: `http://sonarqube-server-ip:9000`
   - **Server authentication token**: Generate token from SonarQube (User → My Account → Security → Generate Token)
4. Save configuration

### 2. Nexus Repository Setup

#### Install Nexus
```bash
# Install Java
sudo apt-get install openjdk-11-jdk -y

# Download Nexus
cd /opt
sudo wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz
sudo tar -xvzf latest-unix.tar.gz
sudo mv nexus-3.* nexus

# Create Nexus user
sudo useradd -r -s /bin/bash nexus
sudo chown -R nexus:nexus /opt/nexus
sudo chown -R nexus:nexus /opt/sonatype-work

# Configure Nexus to run as nexus user
sudo vi /opt/nexus/bin/nexus.rc
# Add: run_as_user="nexus"

# Start Nexus
sudo -u nexus /opt/nexus/bin/nexus start
```

#### Configure Nexus Repository
1. Access Nexus: `http://3.19.221.46:8081`
2. Login with default credentials (admin/admin123)
3. Change admin password
4. Create repository:
   - Go to `Settings` → `Repositories` → `Create repository`
   - Select `raw (hosted)`
   - **Name**: `raw-releases`
   - **Version policy**: Release
   - **Deployment policy**: Allow redeploy
   - Save

#### Add Nexus Credentials to Jenkins
1. Go to `Manage Jenkins` → `Credentials` → `System` → `Global credentials`
2. Click `Add Credentials`
   - **Kind**: Username with password
   - **Scope**: Global
   - **Username**: [Nexus username]
   - **Password**: [Nexus password]
   - **ID**: `nexus`
   - **Description**: Nexus Repository Credentials
3. Save

### 3. Nginx Server Setup

#### Install and Configure Nginx
```bash
# Install Nginx
sudo apt-get update
sudo apt-get install nginx -y

# Create web root for application
sudo mkdir -p /var/www/html/pomodoro
sudo chown -R www-data:www-data /var/www/html/pomodoro

# Configure Nginx site
sudo vi /etc/nginx/sites-available/pomodoro
```

**Nginx Configuration** (`/etc/nginx/sites-available/pomodoro`):
```nginx
server {
    listen 80;
    server_name 18.116.203.32;

    root /var/www/html/pomodoro;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

```bash
# Enable site and restart Nginx
sudo ln -s /etc/nginx/sites-available/pomodoro /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Configure firewall
sudo ufw allow 'Nginx Full'
```

---

## Creating the Pipeline Job

### Step-by-Step Job Creation

1. **Create New Item**
   - Go to Jenkins dashboard
   - Click `New Item`
   - Enter name: `pomodoro-app-pipeline`
   - Select `Pipeline`
   - Click OK

2. **General Configuration**
   - **Description**: CI/CD pipeline for Pomodoro App
   - **Discard old builds**: Keep last 10 builds

3. **Pipeline Configuration**
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/ashuvee/pomodoro-app-js.git`
   - **Branch**: `*/main`
   - **Script Path**: `Jenkinsfile`

4. **Save** the configuration

5. **Build Triggers** (Optional)
   - Poll SCM: `H/5 * * * *` (check every 5 minutes)
   - Or set up GitHub webhook for automatic triggers

---

## Pipeline Stages Deep Dive

### Stage 1: Checkout Code

**Purpose**: Clone source code from GitHub repository

**Requirements**:
- Git plugin installed
- Network access to GitHub

**What happens**:
```groovy
checkout([$class: 'GitSCM',
    branches: [[name: '*/main']],
    userRemoteConfigs: [[url: 'https://github.com/ashuvee/pomodoro-app-js.git']]
])
```

**Verification**:
- Check console output for "Cloning repository"
- Verify workspace contains source files

**Troubleshooting**:
- **Error**: "Failed to connect to repository"
  - Solution: Check network connectivity and GitHub URL
- **Error**: "Authentication failed"
  - Solution: Add GitHub credentials if repository is private

---

### Stage 2: Install Dependencies

**Purpose**: Install npm packages required for the application

**Requirements**:
- Node.js and npm installed on agent
- `package.json` file in repository root
- Internet access to npm registry

**What happens**:
```bash
npm install
```

**Files created/modified**:
- `node_modules/` directory (contains all dependencies)
- `package-lock.json` (locked dependency versions)

**Verification**:
```bash
# Check if node_modules exists
ls -la node_modules/

# Verify specific packages
npm list
```

**Common Issues**:
- **Error**: "npm: command not found"
  - Solution: Install Node.js on the agent
  ```bash
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
  ```

- **Error**: "EACCES: permission denied"
  - Solution: Fix npm permissions
  ```bash
  mkdir ~/.npm-global
  npm config set prefix '~/.npm-global'
  export PATH=~/.npm-global/bin:$PATH
  ```

- **Error**: "Network timeout"
  - Solution: Configure npm registry or proxy
  ```bash
  npm config set registry https://registry.npmjs.org/
  ```

---

### Stage 3: Run Tests

**Purpose**: Execute automated test suite to validate code quality

**Requirements**:
- Test framework configured in `package.json`
- Dependencies installed from Stage 2

**What happens**:
```bash
npm test
```

**Expected Output**:
- Test results (passed/failed)
- Code coverage report (if configured)
- Exit code 0 for success, non-zero for failure

**Configure Tests** (in `package.json`):
```json
{
  "scripts": {
    "test": "jest --coverage",
    "test:watch": "jest --watch"
  }
}
```

**Verification**:
- Review test output in console
- Check for test failures or errors
- Verify all test suites passed

**Troubleshooting**:
- **Error**: "No tests found"
  - Solution: Ensure test files exist (e.g., `*.test.js`, `*.spec.js`)
  
- **Error**: "Cannot find module"
  - Solution: Re-run `npm install` or check imports

- **Pipeline stops**: Tests failing
  - Solution: Fix failing tests before proceeding
  - Review detailed error messages in console output

---

### Stage 4: Build Artifact

**Purpose**: Create production-optimized build of the application

**Requirements**:
- Build script defined in `package.json`
- All dependencies installed
- Source files valid

**What happens**:
```bash
npm run build
```

**Expected Output**:
- `dist/` directory created
- Compiled/bundled JavaScript files
- Optimized CSS files
- HTML files
- Static assets (images, fonts, etc.)

**Build Configuration** (in `package.json`):
```json
{
  "scripts": {
    "build": "webpack --mode production",
    // or
    "build": "vite build",
    // or
    "build": "react-scripts build"
  }
}
```

**Directory Structure After Build**:
```
dist/
├── index.html
├── assets/
│   ├── index-[hash].js
│   ├── index-[hash].css
│   └── logo-[hash].png
└── favicon.ico
```

**Verification**:
```bash
# Check build output
ls -lh dist/

# Verify key files exist
ls dist/index.html
ls dist/assets/
```

**Troubleshooting**:
- **Error**: "Build failed"
  - Solution: Check console for specific error (syntax errors, missing dependencies)
  
- **Error**: "dist/ directory empty"
  - Solution: Verify build configuration in webpack/vite config

- **Error**: "Out of memory"
  - Solution: Increase Node.js memory limit
  ```bash
  NODE_OPTIONS="--max-old-space-size=4096" npm run build
  ```

---

### Stage 5: Package Artifact

**Purpose**: Create compressed tarball of the build for distribution

**Requirements**:
- `dist/` directory exists from Stage 4
- `tar` utility available
- `BUILD_NUMBER` environment variable (auto-provided by Jenkins)

**What happens**:
```bash
VERSION="0.0.${BUILD_NUMBER}"
tar -czf ${NEXUS_ARTIFACT}-${VERSION}.tar.gz -C dist .
```

**Command Breakdown**:
- `tar`: Archive utility
- `-c`: Create new archive
- `-z`: Compress with gzip
- `-f`: Specify filename
- `-C dist`: Change to dist directory
- `.`: Include all contents

**Expected Output**:
- File: `pomodoro-app-0.0.42.tar.gz` (where 42 is build number)
- Contains all files from `dist/` directory

**Verification**:
```bash
# List tarball
ls -lh *.tar.gz

# View tarball contents
tar -tzf pomodoro-app-0.0.42.tar.gz | head -20

# Extract and verify (optional)
mkdir test-extract
tar -xzf pomodoro-app-0.0.42.tar.gz -C test-extract
ls -la test-extract/
```

**Troubleshooting**:
- **Error**: "tar: command not found"
  - Solution: Install tar
  ```bash
  sudo apt-get install tar -y
  ```

- **Error**: "No such file or directory: dist"
  - Solution: Ensure Stage 4 completed successfully

- **File too large**:
  - Check for unnecessary files in dist/
  - Verify `.gitignore` and build configuration

---

### Stage 6: Upload Artifact to Nexus

**Purpose**: Store versioned artifact in Nexus repository for later retrieval

**Requirements**:
- Nexus repository configured and accessible
- Valid Nexus credentials in Jenkins
- Tarball created from Stage 5
- `curl` utility available

**What happens**:
```bash
curl -v -u ${NEXUS_USR}:${NEXUS_PSW} --upload-file "$TARBALL" \
  "${NEXUS_URL}/repository/${NEXUS_REPO}/${NEXUS_GROUP}/${NEXUS_ARTIFACT}/${VERSION}/${TARBALL}"
```

**URL Structure**:
```
http://3.19.221.46:8081/repository/raw-releases/com/web/pomodoro/pomodoro-app/0.0.42/pomodoro-app-0.0.42.tar.gz
```

**Credentials Handling**:
- Uses `withCredentials` block for security
- Credentials never exposed in console output
- Username stored in `NEXUS_USR`
- Password stored in `NEXUS_PSW`

**Verification**:
```bash
# Check if artifact exists in Nexus
curl -u username:password \
  http://3.19.221.46:8081/repository/raw-releases/com/web/pomodoro/pomodoro-app/0.0.42/

# Or access via Nexus web UI
# Browse → raw-releases → com → web → pomodoro → pomodoro-app → 0.0.42
```

**Troubleshooting**:
- **Error**: "401 Unauthorized"
  - Solution: Verify Nexus credentials in Jenkins
  - Check credential ID matches 'nexus'

- **Error**: "Connection refused"
  - Solution: Verify Nexus is running
  ```bash
  curl http://3.19.221.46:8081/
  ```

- **Error**: "404 Not Found"
  - Solution: Verify repository 'raw-releases' exists in Nexus
  - Check repository allows redeployment

- **Error**: "403 Forbidden"
  - Solution: Check Nexus user has deployment permissions
  - Verify repository security settings

**Verify Upload in Nexus UI**:
1. Login to Nexus: `http://3.19.221.46:8081`
2. Navigate to Browse → raw-releases
3. Follow path: com/web/pomodoro/pomodoro-app/[VERSION]
4. Confirm tarball exists and size is correct

---

### Stage 7: Deploy to Nginx

**Purpose**: Download artifact and deploy to production web server

**Requirements**:
- Runs on `tomcat` agent (switches from `sonar` agent)
- Nginx installed and configured on target server
- Jenkins user has sudo permissions for deployment commands
- Network access to Nexus

**What happens**:

**Step 1: Download from Nexus**
```bash
VERSION="0.0.${BUILD_NUMBER}"
TARBALL="${NEXUS_ARTIFACT}-${VERSION}.tar.gz"
DOWNLOAD_URL="${NEXUS_URL}/repository/${NEXUS_REPO}/${NEXUS_GROUP}/${NEXUS_ARTIFACT}/${VERSION}/${TARBALL}"

curl -f -u ${NEXUS_USR}:${NEXUS_PSW} -O "$DOWNLOAD_URL"
```

**Step 2: Validate Download**
```bash
if [[ ! -f "$TARBALL" ]]; then
    echo "❌ Download failed!"
    exit 1
fi
```

**Step 3: Deploy to Web Server**
```bash
# Create deployment directory
sudo mkdir -p ${NGINX_WEB_ROOT}

# Clean old files
sudo rm -rf ${NGINX_WEB_ROOT}/*

# Extract new files
sudo tar -xzf "$TARBALL" -C ${NGINX_WEB_ROOT}/

# Set proper ownership
sudo chown -R www-data:www-data ${NGINX_WEB_ROOT}
```

**Directory Changes**:
```
Before:
/var/www/html/pomodoro/ (old files)

After:
/var/www/html/pomodoro/
├── index.html (new)
├── assets/ (new)
└── ... (new files)
```

**Verification**:
```bash
# Check files on server
ls -la /var/www/html/pomodoro/

# Verify ownership
ls -ld /var/www/html/pomodoro/
# Should show: drwxr-xr-x www-data www-data

# Test application
curl http://18.116.203.32/pomodoro/

# Or access in browser
# http://18.116.203.32/pomodoro/
```

**Troubleshooting**:

- **Error**: "sudo: no tty present and no askpass program specified"
  - Solution: Configure passwordless sudo for Jenkins user
  ```bash
  sudo visudo -f /etc/sudoers.d/jenkins
  # Add:
  jenkins ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/rm, /bin/tar, /bin/chown
  ```

- **Error**: "Download failed"
  - Solution: Verify artifact exists in Nexus
  - Check network connectivity from tomcat agent to Nexus

- **Error**: "Permission denied" on /var/www/html
  - Solution: Create directory with proper permissions
  ```bash
  sudo mkdir -p /var/www/html/pomodoro
  sudo chmod 755 /var/www/html/pomodoro
  ```

- **Error**: "Nginx not serving new files"
  - Solution: Clear Nginx cache and restart
  ```bash
  sudo systemctl restart nginx
  # Or reload
  sudo nginx -s reload
  ```

- **Application shows 404**:
  - Check Nginx configuration for correct root path
  - Verify index.html exists in deployment directory
  ```bash
  sudo nginx -t  # Test configuration
  ls /var/www/html/pomodoro/index.html
  ```

**Post-Deployment Verification**:
1. Check Nginx access logs:
   ```bash
   sudo tail -f /var/log/nginx/access.log
   ```

2. Check Nginx error logs:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

3. Test application in browser:
   - URL: `http://18.116.203.32/pomodoro/`
   - Verify page loads correctly
   - Check browser console for errors
   - Test application functionality

4. Verify file permissions:
   ```bash
   ls -la /var/www/html/pomodoro/
   # All files should be owned by www-data:www-data
   ```

---

## Complete Credentials Setup

### SSH Credentials for Agents

**Create SSH Key Pair** (on Jenkins master):
```bash
# Generate SSH key for Jenkins agents
ssh-keygen -t rsa -b 4096 -C "jenkins@master" -f ~/.ssh/jenkins_agent_key -N ""

# Copy public key to agents
ssh-copy-id -i ~/.ssh/jenkins_agent_key.pub jenkins@[AGENT_IP]
```

**Add to Jenkins**:
1. Navigate to `Manage Jenkins` → `Credentials` → `System` → `Global credentials`
2. Click `Add Credentials`
   - **Kind**: SSH Username with private key
   - **Scope**: Global
   - **ID**: `jenkins-agent-ssh`
   - **Username**: `jenkins`
   - **Private Key**: Enter directly (paste contents of `~/.ssh/jenkins_agent_key`)
3. Save

### Nexus Credentials

Already covered in [External Services Setup](#external-services-setup) section.

### GitHub Credentials (Optional - for private repos)

If your repository is private:
1. Navigate to `Manage Jenkins` → `Credentials` → `System` → `Global credentials`
2. Click `Add Credentials`
   - **Kind**: Username with password (or Personal Access Token)
   - **Scope**: Global
   - **Username**: Your GitHub username
   - **Password**: Personal Access Token (not your GitHub password)
   - **ID**: `github-credentials`
3. Update Jenkinsfile to use credentials in checkout stage

---

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `SONARQUBE_SERVER` | `sonar` | SonarQube server identifier |
| `NEXUS_URL` | `http://3.19.221.46:8081` | Nexus repository URL |
| `NEXUS_REPO` | `raw-releases` | Nexus repository name |
| `NEXUS_GROUP` | `com/web/pomodoro` | Maven-style group path |
| `NEXUS_ARTIFACT` | `pomodoro-app` | Artifact name |
| `NGINX_SERVER` | `18.116.203.32` | Nginx deployment server IP |
| `NGINX_WEB_ROOT` | `/var/www/html/pomodoro` | Web root directory on Nginx |

### Modifying Environment Variables

To change any environment variable:
1. Edit the Jenkinsfile
2. Update the `environment` block
3. Commit and push changes
4. Pipeline will use new values on next run

---

## Pipeline Execution Flow

### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Jenkins Master                            │
│                     Triggers Pipeline                            │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Agent: sonar                                │
├─────────────────────────────────────────────────────────────────┤
│  Stage 1: Checkout Code                                         │
│    └─ Clone from GitHub (main branch)                           │
│                                                                  │
│  Stage 2: Install Dependencies                                  │
│    └─ npm install                                               │
│                                                                  │
│  Stage 3: Run Tests                                             │
│    └─ npm test                                                  │
│                                                                  │
│  Stage 4: Build Artifact                                        │
│    └─ npm run build → generates dist/                          │
│                                                                  │
│  Stage 5: Package Artifact                                      │
│    └─ tar -czf pomodoro-app-0.0.X.tar.gz                       │
│                                                                  │
│  Stage 6: Upload to Nexus                                       │
│    └─ curl upload to Nexus repository                          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Agent: tomcat                               │
├─────────────────────────────────────────────────────────────────┤
│  Stage 7: Deploy to Nginx                                       │
│    ├─ Download artifact from Nexus                             │
│    ├─ Extract to /var/www/html/pomodoro/                       │
│    └─ Set permissions (www-data:www-data)                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Application Live on Nginx                      │
│                http://18.116.203.32/pomodoro/                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Pipeline Stages Summary

### Quick Reference

| Stage | Agent | Purpose | Key Commands |
|-------|-------|---------|--------------|
| 1. Checkout Code | sonar | Clone source from GitHub | `checkout scm` |
| 2. Install Dependencies | sonar | Install npm packages | `npm install` |
| 3. Run Tests | sonar | Execute test suite | `npm test` |
| 4. Build Artifact | sonar | Create production build | `npm run build` |
| 5. Package Artifact | sonar | Create tarball | `tar -czf` |
| 6. Upload to Nexus | sonar | Store artifact in Nexus | `curl --upload-file` |
| 7. Deploy to Nginx | tomcat | Deploy to web server | `curl -O`, `tar -xzf` |

*Detailed explanations for each stage are provided in the [Pipeline Stages Deep Dive](#pipeline-stages-deep-dive) section above.*

---

## Versioning

Version format: `0.0.${BUILD_NUMBER}`

Example: Build #42 creates version `0.0.42`

## Post Actions

- **Success**: Displays success message indicating the application is live
- **Failure**: Displays failure message prompting to check Jenkins logs

## How to Trigger the Pipeline

### Manual Trigger
1. Navigate to the Jenkins job: `http://jenkins-url/job/pomodoro-app-pipeline/`
2. Click **Build Now** button
3. Monitor the progress:
   - Click on the build number (e.g., #42)
   - Select **Console Output** to view real-time logs
   - Or view **Pipeline Steps** for stage-by-stage view

### Automatic Trigger via GitHub Webhook

**Setup GitHub Webhook**:
1. Go to your GitHub repository: `https://github.com/ashuvee/pomodoro-app-js`
2. Navigate to **Settings** → **Webhooks** → **Add webhook**
3. Configuration:
   - **Payload URL**: `http://your-jenkins-url/github-webhook/`
   - **Content type**: `application/json`
   - **Which events**: Select "Just the push event"
   - **Active**: Check this box
4. Save webhook

**Configure Jenkins Job**:
1. Open pipeline configuration
2. Under **Build Triggers**, check **GitHub hook trigger for GITScm polling**
3. Save configuration

Now, every push to the `main` branch will automatically trigger the pipeline.

### Automatic Trigger via SCM Polling

Alternative to webhooks:
1. Open pipeline configuration
2. Under **Build Triggers**, check **Poll SCM**
3. Set schedule (cron syntax):
   ```
   H/5 * * * *     # Check every 5 minutes
   H/15 * * * *    # Check every 15 minutes
   ```
4. Save configuration

---

## Monitoring and Logs

### Jenkins Console Output

View detailed logs for each build:
```bash
# Access console output
http://jenkins-url/job/pomodoro-app-pipeline/[BUILD_NUMBER]/console
```

**Key things to look for**:
- Git clone success/failure
- npm install progress
- Test results and coverage
- Build output and bundle sizes
- Upload confirmation to Nexus
- Deployment success message

### Nginx Logs

**Access Logs** (track requests):
```bash
sudo tail -f /var/log/nginx/access.log | grep pomodoro
```

**Error Logs** (track issues):
```bash
sudo tail -f /var/log/nginx/error.log
```

### Nexus Repository Browser

View all uploaded artifacts:
1. Login to Nexus: `http://3.19.221.46:8081`
2. Click **Browse** → **raw-releases**
3. Navigate: `com/web/pomodoro/pomodoro-app/`
4. View all versions and download if needed

### Pipeline Stage View

Jenkins provides a visual representation:
- Go to pipeline job page
- View **Stage View** showing:
  - Each stage duration
  - Success/failure status
  - Trends over time

---

## Deployment URL

After successful deployment, the application is accessible at:
```
http://18.116.203.32/
```

**Verification Steps**:
1. Open URL in browser
2. Check that application loads correctly
3. Test core functionality (start timer, pause, reset)
4. Check browser console for JavaScript errors (F12)
5. Verify network requests in DevTools

---

