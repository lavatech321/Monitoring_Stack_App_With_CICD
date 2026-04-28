#!/bin/bash
set -e

echo "===== STOP JENKINS ====="
sudo systemctl stop jenkins || true

echo "===== DISABLE SETUP WIZARD ====="
sudo sed -i '/JENKINS_JAVA_OPTIONS/d' /etc/default/jenkins 2>/dev/null || true
echo 'JENKINS_JAVA_OPTIONS="-Djenkins.install.runSetupWizard=false"' | \
sudo tee -a /etc/default/jenkins >/dev/null

echo "===== CLEAN OLD SETUP ====="
sudo rm -f /var/lib/jenkins/secrets/initialAdminPassword
sudo rm -rf /var/lib/jenkins/users/*

echo "===== CLEAN OLD/BROKEN PLUGINS ====="
sudo rm -rf /var/lib/jenkins/plugins/*

echo "===== CREATE GROOVY INIT USER ====="
sudo mkdir -p /var/lib/jenkins/init.groovy.d

cat <<'EOF' | sudo tee /var/lib/jenkins/init.groovy.d/create-user.groovy >/dev/null
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.instanceOrNull

if (instance != null) {
  def realm = new HudsonPrivateSecurityRealm(false)
  realm.createAccount("admin","admin123")
  instance.setSecurityRealm(realm)

  def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
  strategy.setAllowAnonymousRead(false)
  instance.setAuthorizationStrategy(strategy)

  instance.save()
}
EOF

echo "===== MARK SETUP COMPLETE ====="
echo "2.0" | sudo tee /var/lib/jenkins/jenkins.install.UpgradeWizard.state >/dev/null
echo "2.0" | sudo tee /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion >/dev/null

echo "===== DOWNLOAD PLUGIN MANAGER ====="
sudo wget -q \
https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar \
-O /tmp/plugin-manager.jar

echo "===== RELOAD SYSTEMD ====="
sudo systemctl daemon-reload

echo "===== START JENKINS ====="
sudo systemctl start jenkins

echo "===== WAIT FOR JENKINS ====="
until curl -s http://localhost:8080/login > /dev/null; do
  echo "Waiting for Jenkins..."
  sleep 5
done

echo "===== CREATE PLUGIN LIST ====="
sudo tee /tmp/plugins.txt >/dev/null <<EOF
git
workflow-aggregator
docker-workflow
blueocean
EOF

echo "===== INSTALL PLUGINS ====="

for i in 1 2 3; do
  echo "Attempt $i..."

  sudo java -jar /tmp/plugin-manager.jar \
    --war /usr/share/java/jenkins.war \
    --plugin-file /tmp/plugins.txt \
    --plugin-download-directory /var/lib/jenkins/plugins \
    --verbose && break

  echo "Retrying with alternative mirror..."

  export JENKINS_UC=https://archives.jenkins.io/update-center.json

  sleep 10
done

echo "===== FIX PERMISSIONS ====="
sudo chown -R jenkins:jenkins /var/lib/jenkins

echo "===== RESTART JENKINS ====="
sudo systemctl restart jenkins

echo "===== FINAL WAIT ====="
sleep 30

echo "===== VERIFY ====="

if ls /var/lib/jenkins/plugins | grep -q workflow; then
  echo "✅ Jenkins setup successful"
  echo "Login: http://<server>:8080"
  echo "Username: admin"
  echo "Password: admin123"
else
  echo "❌ Plugins not installed correctly"
  exit 1
fi

