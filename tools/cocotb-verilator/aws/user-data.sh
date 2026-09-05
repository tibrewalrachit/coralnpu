#!/bin/bash
# EC2 user-data for the Coral cocotb/Verilator run. Ubuntu 24.04 x86_64.
# Substituted by launch.py: __REPO__ __BRANCH__ __PARALLEL__ __THREADS__ __S3__
set -eux
exec > >(tee -a /var/log/coral-cocotb-userdata.log) 2>&1
# sshd also on 443 (the driving host may only reach 443)
grep -q '^Port 443' /etc/ssh/sshd_config || { echo 'Port 22' >> /etc/ssh/sshd_config; echo 'Port 443' >> /etc/ssh/sshd_config; systemctl restart ssh; }
apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential git curl python3 python3-pip python3-venv autoconf bison flex unzip
snap install amazon-ssm-agent --classic 2>/dev/null || true
sudo -u ubuntu -i bash -c '
set -eux
git clone --branch "__BRANCH__" "__REPO__" ~/coralnpu
cd ~/coralnpu/tools/cocotb-verilator
export CORAL_WORK=$HOME/coral-cocotb
nohup ./run-all.sh --parallel __PARALLEL__ --threads __THREADS__ > ~/coral-cocotb-run.log 2>&1 &
'
echo "user-data done; run-all.sh started in background"
