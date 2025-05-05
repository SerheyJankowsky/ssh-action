#!/bin/bash
set -e

# Read inputs from environment variables (GitHub Actions prefixes inputs with INPUT_)
SSH_HOST="$INPUT_SSH_HOST"
SSH_USER="$INPUT_SSH_USER"
SSH_PORT="$INPUT_SSH_PORT"
SSH_PASSWORD="$INPUT_SSH_PASSWORD"
CUSTOM_ED25519_KEY="$INPUT_CUSTOM_ED25519_KEY"
SCRIPT="$INPUT_SCRIPT"
ENV_VARS="$INPUT_ENV_VARS"

echo "SSH_HOST: $SSH_HOST"
echo "SSH_USER: $SSH_USER"
echo "SSH_PORT: $SSH_PORT"
echo "SSH_PASSWORD: $SSH_PASSWORD"
echo "CUSTOM_ED25519_KEY: $CUSTOM_ED25519_KEY"
echo "SCRIPT: $SCRIPT"
echo "ENV_VARS: $ENV_VARS"

# Validate required inputs
if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ] || [ -z "$SCRIPT" ]; then
  echo "Error: ssh-host, ssh-user, and script are required inputs"
  exit 1
fi

# Set default port if not provided
SSH_PORT=${SSH_PORT:-22}

# Set up SSH directory
mkdir -p ~/.ssh

# Set up ed25519 key: use custom key if provided, otherwise generate a new one
if [ -n "$CUSTOM_ED25519_KEY" ]; then
  echo "$CUSTOM_ED25519_KEY" > ~/.ssh/temp_key
  chmod 600 ~/.ssh/temp_key
  ssh-keygen -y -f ~/.ssh/temp_key > ~/.ssh/temp_key.pub
else
  ssh-keygen -t ed25519 -f ~/.ssh/temp_key -N "" -C "github-action-temp-key"
fi

# Copy public key to remote server
if [ -n "$SSH_PASSWORD" ]; then
  sshpass -p "$SSH_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/temp_key.pub -p "$SSH_PORT" "$SSH_USER@$SSH_HOST"
else
  ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/temp_key.pub -p "$SSH_PORT" "$SSH_USER@$SSH_HOST"
fi

# Build environment variable export commands
ENV_SCRIPT=""
if [ -n "$ENV_VARS" ]; then
  IFS=',' read -ra ENV_ARRAY <<< "$ENV_VARS"
  for ENV in "${ENV_ARRAY[@]}"; do
    if [[ "$ENV" == *"="* ]]; then
      # Custom key-value pair (e.g., KEY=VALUE)
      ESCAPED_VALUE=$(echo "$ENV" | sed -e 's/[\\"]/\\&/g')
      ENV_SCRIPT="$ENV_SCRIPT export $ESCAPED_VALUE;"
    else
      # GitHub environment variable or secret (e.g., SECRET_NAME)
      ENV_VALUE=$(printenv "$ENV" || echo "")
      if [ -n "$ENV_VALUE" ]; then
        ESCAPED_VALUE=$(echo "$ENV_VALUE" | sed -e 's/[\\"]/\\&/g')
        ENV_SCRIPT="$ENV_SCRIPT export $ENV=\"$ESCAPED_VALUE\";"
      fi
    fi
  done
fi

# Run user script on remote server with environment variables
ssh -i ~/.ssh/temp_key -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" << EOF
$ENV_SCRIPT
$SCRIPT
EOF

# Remove key from remote server
ssh -i ~/.ssh/temp_key -o StrictHostKeyChecking=no -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" << EOF
sed -i '/github-action-temp-key/d' ~/.ssh/authorized_keys
EOF

# Clean up local keys
rm -f ~/.ssh/temp_key ~/.ssh/temp_key.pub

echo "Action completed successfully"