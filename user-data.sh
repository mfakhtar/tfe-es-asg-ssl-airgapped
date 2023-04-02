#!/bin/bash

#Install AWS_CLI
sudo apt-get update
sudo apt-get install -y awscli jq


#Install Docker
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt install docker-ce

#copy license file from S3
aws s3 cp s3://${bucket_name}/license.rli /tmp/license.rli
aws s3 cp s3://${bucket_name}/TerraformEnterprise.airgap /tmp/TerraformEnterprise.airgap
aws s3 cp s3://${bucket_name}/replicated.tar.gz /tmp/replicated.tar.gz
aws s3 cp s3://${bucket_name}/install.sh /tmp/install.sh

PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PUBLIC_DNS=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)

cat > /tmp/tfe_settings.json <<EOF
{
   "aws_instance_profile": {
        "value": "1"
    },
    "enc_password": {
        "value": "${tfe-pwd}"
    },
    "hairpin_addressing": {
        "value": "0"
    },
    "hostname": {
        "value": "${dns_hostname}.${dns_zonename}"
    },
    "pg_dbname": {
        "value": "${db_name}"
    },
    "pg_netloc": {
        "value": "${db_address}"
    },
    "pg_password": {
        "value": "${db_password}"
    },
    "pg_user": {
        "value": "${db_user}"
    },
    "placement": {
        "value": "placement_s3"
    },
    "production_type": {
        "value": "external"
    },
    "s3_bucket": {
        "value": "${bucket_name}"
    },
    "s3_endpoint": {},
    "s3_region": {
        "value": "${region}"
    }
}
EOF

json=/tmp/tfe_settings.json

jq -r . $json
if [ $? -ne 0 ] ; then
    echo ERR: $json is not a valid json
    exit 1
fi

# create replicated unattended installer config
cat > /etc/replicated.conf <<EOF
{
  "DaemonAuthenticationType": "password",
  "DaemonAuthenticationPassword": "${tfe-pwd}",
  "TlsBootstrapType": "self-signed",
  "TlsBootstrapHostname": "${dns_hostname}.${dns_zonename}",
  "LogLevel": "debug",
  "ImportSettingsFrom": "/tmp/tfe_settings.json",
  "LicenseFileLocation": "/tmp/license.rli",
  "BypassPreflightChecks": true
}
EOF

json=/etc/replicated.conf
jq -r . $json
if [ $? -ne 0 ] ; then
    echo ERR: $json is not a valid json
    exit 1
fi

# install replicated
sudo mkdir -p /opt/tfe
pushd /opt/tfe
sudo tar xvf /tmp/replicated.tar.gz

sudo bash /tmp/install.sh airgap private-address=$PRIVATE_IP