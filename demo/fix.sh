#!/bin/bash
# =============================================================================
# Rollback Script: Restore Working Application Code
# =============================================================================
# This script restores the original index.html, removes the broken index.php,
# and pushes to trigger a clean deployment.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ROLLBACK: Restoring Working App${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 1: Remove the broken index.php
echo -e "\n${GREEN}[1/4] Removing broken index.php...${NC}"
if [ -f "$REPO_DIR/index.php" ]; then
  rm "$REPO_DIR/index.php"
  echo "Removed index.php"
else
  echo "index.php not found (already removed)"
fi

# Step 2: Restore index.html from backup or recreate
echo -e "\n${GREEN}[2/4] Restoring index.html...${NC}"
if [ -f "$REPO_DIR/index.html.backup" ]; then
  cp "$REPO_DIR/index.html.backup" "$REPO_DIR/index.html"
  rm "$REPO_DIR/index.html.backup"
  echo "Restored from backup"
else
  # Recreate the working index.html
  cat > "$REPO_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Sample Deployment</title>
  <style>
    body {
      color: #ffffff;
      background-color: #007f3f;
      font-family: Arial, sans-serif;
      font-size: 14px;
    }
    
    h1 {
      font-size: 500%;
      font-weight: normal;
      margin-bottom: 0;
    }
    
    h2 {
      font-size: 200%;
      font-weight: normal;
      margin-bottom: 0;
    }
  </style>
</head>
<body>
  <div align="center">
    <h1>Congratulations!</h1>
    <h2>You have successfully created a pipeline that retrieved this source application from GitHub and deployed it to Amazon EC2 using AWS CodeDeploy.</h2>
    <p>For next steps, read the AWS CodePipeline Documentation.</p>
    <p><a href="/broken.php" style="color: #ffcccc;">Test 500 Error</a> | <a href="/unavailable.php" style="color: #ffcccc;">Test 503 Error</a></p>
  </div>
</body>
</html>
EOF
  echo "Recreated index.html"
fi

# Step 3: Restore appspec.yml and .htaccess
echo -e "\n${GREEN}[3/4] Restoring appspec.yml and .htaccess...${NC}"

cat > "$REPO_DIR/appspec.yml" << 'EOF'
version: 0.0
os: linux
files:
  - source: /index.html
    destination: /var/www/html/
  - source: /500.html
    destination: /var/www/html/
  - source: /503.html
    destination: /var/www/html/
  - source: /broken.php
    destination: /var/www/html/
  - source: /unavailable.php
    destination: /var/www/html/
  - source: /.htaccess
    destination: /var/www/html/
hooks:
  BeforeInstall:
    - location: scripts/install_dependencies
      timeout: 300
      runas: root
  ApplicationStop:
    - location: scripts/stop_server
      timeout: 300
      runas: root
  AfterInstall:
    - location: scripts/start_server
      timeout: 300
      runas: root
EOF

cat > "$REPO_DIR/.htaccess" << 'EOF'
# Custom error documents
ErrorDocument 500 /500.html
ErrorDocument 503 /503.html
EOF

echo "Restored appspec.yml and .htaccess"

# Step 4: Commit and push
echo -e "\n${GREEN}[4/4] Committing and pushing fix...${NC}"
cd "$REPO_DIR"
git add -A
git commit -m "FIX: Restore working application - rollback from fault injection"
git push origin master:main

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Rollback Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "The pipeline will now deploy the working application."
echo -e "The CloudWatch alarm should return to OK state after ~2 minutes."
echo ""
echo -e "Monitor the pipeline:"
echo -e "  aws codepipeline get-pipeline-state --name SampleWebApp-Pipeline --region us-east-1"
echo ""
echo -e "Check alarm status:"
echo -e "  aws cloudwatch describe-alarms --alarm-names Apache-5xx-Errors --region us-east-1"
