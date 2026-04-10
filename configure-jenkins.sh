#!/bin/bash

set -e

echo "===== STOP JENKINS ====="
sudo systemctl stop jenkins || true

echo "===== DISABLE SETUP WIZARD ====="
echo 'JENKINS_JAVA_OPTIONS="-Djenkins.install.runSetupWizard=false"' | sudo tee /etc/sysconfig/jenkins

echo "===== CLEAN OLD SETUP ====="
sudo rm -rf /var/lib/jenkins/secrets/initialAdminPassword
sudo rm -rf /var/lib/jenkins/users/*

echo "===== CLEAN PLUGINS (IMPORTANT) ====="
sudo rm -rf /var/lib/jenkins/plugins/*
sudo rm -rf /var/lib/jenkins/plugins/*.jpi
sudo rm -rf /var/lib/jenkins/plugins/*.hpi
sudo rm -rf /var/lib/jenkins/plugins/*.lock

echo "===== CREATE GROOVY INIT ====="
sudo mkdir -p /var/lib/jenkins/init.groovy.d

cat <<EOF | sudo tee /var/lib/jenkins/init.groovy.d/create-user.groovy
#!groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin123")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
EOF

echo "===== DOWNLOAD PLUGIN MANAGER ====="
sudo wget -q https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar -O /tmp/plugin-manager.jar


# Disable wizard
echo 'JENKINS_JAVA_OPTIONS="-Djenkins.install.runSetupWizard=false"' | sudo tee -a /etc/sysconfig/jenkins

# Mark setup complete
echo "2.0" | sudo tee /var/lib/jenkins/jenkins.install.UpgradeWizard.state
echo "2.0" | sudo tee /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

# Reload systemd
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Start Jenkins ONCE
sudo systemctl start jenkins

# WAIT until Jenkins fully up (CRITICAL)
sleep 30

# Now install plugins
sudo java -jar /tmp/plugin-manager.jar \
  --war /usr/share/java/jenkins.war \
  --plugin-download-directory /var/lib/jenkins/plugins \
  --plugins \
    workflow-aggregator \
    git \
    docker-workflow \
    credentials-binding \
  --latest true

# Fix permissions
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Restart Jenkins
sudo systemctl restart jenkins

echo "===== VERIFY ====="
if sudo journalctl -u jenkins -n 50 | grep -Ei "failed|error"; then
  echo "❌ Plugin errors detected"
  exit 1
else
  echo "✅ Jenkins setup successful"
fi

