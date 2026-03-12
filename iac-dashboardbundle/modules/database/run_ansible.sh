#!/bin/bash
PLAYBOOK_DIR=$1
DB_IP=$2
BASTION_IP=$3
export ANSIBLE_PRIVATE_KEY_FILE=$4
export ANSIBLE_HOST_KEY_CHECKING=False

# Wait for the connection to be ready
MAX_ATTEMPTS=50
SLEEP_INTERVAL=5
ATTEMPT=0

while (( ATTEMPT < MAX_ATTEMPTS )); do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT of $MAX_ATTEMPTS: Waiting for connection to $DB_IP through proxy $BASTION_IP..."
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $ANSIBLE_PRIVATE_KEY_FILE -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $ANSIBLE_PRIVATE_KEY_FILE ubuntu@$BASTION_IP" ubuntu@$DB_IP 'exit' && break
  sleep $SLEEP_INTERVAL
done

if (( ATTEMPT == MAX_ATTEMPTS )); then
  echo "Failed to connect to $DB_IP through proxy $BASTION_IP after $MAX_ATTEMPTS attempts."
  exit 1
fi

echo "Successfully connected to $DB_IP through proxy $BASTION_IP."

cd $PLAYBOOK_DIR

ansible-playbook -i $DB_IP, --private-key $ANSIBLE_PRIVATE_KEY_FILE -u ubuntu s3_bucket_setup.yml --extra-vars "jenkins_login_pem=/tmp/dashboard_secrets/.passwd-s3fs" \
-e "ansible_ssh_common_args='-o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $ANSIBLE_PRIVATE_KEY_FILE -W %h:%p ubuntu@$BASTION_IP\"'" -vv

ansible-playbook -i $DB_IP, --private-key $ANSIBLE_PRIVATE_KEY_FILE -u ubuntu db_playbook.yml --extra-vars "jenkins_login_pem=/tmp/dashboard_secrets/.passwd-s3fs" \
-e "ansible_ssh_common_args='-o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $ANSIBLE_PRIVATE_KEY_FILE -W %h:%p ubuntu@$BASTION_IP\"'"