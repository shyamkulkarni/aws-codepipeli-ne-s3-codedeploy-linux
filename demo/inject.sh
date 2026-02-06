#!/bin/bash
# =============================================================================
# Fault Injection Script: Deploy Broken Application Code
# =============================================================================
# This script modifies index.php to return 500 errors, commits the change,
# and pushes to trigger the pipeline. This simulates a bad deployment.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}  FAULT INJECTION: Breaking the App${NC}"
echo -e "${RED}========================================${NC}"

# Step 1: Backup current index.html
echo -e "\n${GREEN}[1/4] Backing up current index.html...${NC}"
cp "$REPO_DIR/index.html" "$REPO_DIR/index.html.backup"
echo "Backup saved to index.html.backup"

# Step 2: Replace index.html with a broken PHP version that returns 500
echo -e "\n${GREEN}[2/4] Injecting broken code into index.php...${NC}"

cat > "$REPO_DIR/index.php" << 'EOF'
<?php
// FAULT INJECTION: This code intentionally returns 500 errors
// Simulating a database connection failure

header("HTTP/1.1 500 Internal Server Error");

// Log the error for CloudWatch
error_log("CRITICAL: Database connection failed - simulated fault injection");
?>
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>500 - Internal Server Error</title>
  <style>
    body {
      color: #ffffff;
      background-color: #cc0000;
      font-family: Arial, sans-serif;
      font-size: 14px;
    }
    h1 { font-size: 400%; font-weight: normal; margin-bottom: 0; }
    h2 { font-size: 150%; font-weight: normal; }
    .error-code { font-family: monospace; background: #990000; padding: 10px; margin: 20px; }
  </style>
</head>
<body>
  <div align="center">
    <h1>500 Internal Server Error</h1>
    <h2>Application Error: Database Connection Failed</h2>
    <div class="error-code">
      Error: SQLSTATE[HY000] [2002] Connection refused<br>
      Unable to connect to database server at db.internal:3306
    </div>
    <p>The application encountered an unexpected error.</p>
    <p>Incident has been logged and operations team has been notified.</p>
  </div>
</body>
</html>
EOF

# Step 3: Update appspec.yml to use index.php as the main page
echo -e "\n${GREEN}[3/4] Updating appspec.yml to deploy broken index.php...${NC}"

cat > "$REPO_DIR/appspec.yml" << 'EOF'
version: 0.0
os: linux
files:
  - source: /index.php
    destination: /var/www/html/
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

# Update .htaccess to make index.php the default
cat > "$REPO_DIR/.htaccess" << 'EOF'
# FAULT INJECTION: Route all traffic to broken index.php
DirectoryIndex index.php index.html

# Custom error documents
ErrorDocument 500 /500.html
ErrorDocument 503 /503.html
EOF

# Step 4: Commit and push
echo -e "\n${GREEN}[4/4] Committing and pushing broken code...${NC}"
cd "$REPO_DIR"
git add -A
git commit -m "FAULT INJECTION: Deploy broken application with database error"
git push origin master:main

echo -e "\n${RED}========================================${NC}"
echo -e "${RED}  Fault Injection Complete!${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "The pipeline will now deploy the broken application."
echo -e "This will trigger:"
echo -e "  1. HTTP 500 errors on the main page"
echo -e "  2. CloudWatch Metric Filter detection"
echo -e "  3. CloudWatch Alarm state change to ALARM"
echo -e "  4. EventBridge notification to DevOps Agent"
echo ""
echo -e "Monitor the pipeline:"
echo -e "  aws codepipeline get-pipeline-state --name SampleWebApp-Pipeline --region us-east-1"
echo ""
echo -e "${YELLOW}To rollback, run: ./fix.sh${NC}"
