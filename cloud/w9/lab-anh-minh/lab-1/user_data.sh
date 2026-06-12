#!/bin/bash
set -euxo pipefail

cat >/home/ec2-user/cpu-burn.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail
timeout "$${1:-8m}" bash -c 'while true; do :; done'
SCRIPT
chmod +x /home/ec2-user/cpu-burn.sh
chown ec2-user:ec2-user /home/ec2-user/cpu-burn.sh

if [ "${enable_cpu_test}" = "true" ]; then
  nohup /home/ec2-user/cpu-burn.sh 8m >/var/log/cpu-burn.log 2>&1 &
fi
