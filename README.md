# SSH Key Management and Script Execution Action

This GitHub Action automates SSH-based script execution on a remote server. It either generates a new ed25519 SSH key or uses a provided custom key, copies the key to the remote server, executes a user-defined script with optional environment variables (custom or sourced from GitHub Secrets/env), and removes the key from the server afterward. The action runs in a Docker container for consistent execution.

## Features

- Generates an ed25519 SSH key or uses a custom key.
- Copies the key to a remote server using `ssh-copy-id` with optional password authentication.
- Runs a user script on the remote server with custom or GitHub-sourced environment variables.
- Cleans up by removing the SSH key from the remote server's `authorized_keys`.
- Supports password-based SSH authentication via `sshpass`.
- Executes in a lightweight Ubuntu-based Docker container.

## Repository Setup

To use this action, you can reference it from a GitHub repository or include it locally in your project.

### Option 1: Use from a GitHub Repository

1. **Fork or Create a Repository**:
   - Create a new repository (e.g., `your-username/ssh-action`) or fork an existing one.
   - Place the following files in the root of the repository:
     ```
     ├── action.yml
     ├── Dockerfile
     ├── entrypoint.sh
     ├── README.md
     ```
2. **Tag a Release**:

   - Commit and push the files to your repository.
   - Create a release or tag (e.g., `v1`) to reference the action (e.g., `your-username/ssh-action@v1`).
   - Example:
     ```bash
     git tag v1
     git push origin v1
     ```

3. **Reference in Workflow**:
   - Use the action in your workflow with `uses: your-username/ssh-action@v1`.

### Option 2: Use Locally

1. **Create the Action Directory**:
   - Place the files in your repository under `.github/actions/ssh-action/`:
     ```
     .github/
     └── actions/
         └── ssh-action/
             ├── action.yml
             ├── Dockerfile
             ├── entrypoint.sh
             ├── README.md
     ```
2. **Reference in Workflow**:
   - Use the action with `uses: ./.github/actions/ssh-action`.

## Inputs

| Input                | Description                                                                                                                                                                          | Required | Default |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ------- |
| `ssh-host`           | Remote server hostname or IP address.                                                                                                                                                | Yes      | -       |
| `ssh-user`           | SSH user for the remote server.                                                                                                                                                      | Yes      | -       |
| `ssh-port`           | SSH port for the remote server.                                                                                                                                                      | No       | `22`    |
| `ssh-password`       | Optional password for SSH authentication (used with `sshpass`).                                                                                                                      | No       | -       |
| `custom-ed25519-key` | Optional custom ed25519 private key to use instead of generating a new one.                                                                                                          | No       | -       |
| `script`             | Script to execute on the remote server.                                                                                                                                              | Yes      | -       |
| `env-vars`           | Optional environment variables for the script. Use `KEY=VALUE` for custom vars or variable names for GitHub env/secrets (e.g., `KEY1=VALUE1,KEY2=VALUE2` or `SECRET_NAME,ENV_NAME`). | No       | -       |

## Usage Examples

### Example 1: Using from a Repository with Custom Environment Variables

Reference the action from a GitHub repository and run a script with hardcoded environment variables.

```yaml
name: Deploy Script
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: your-username/ssh-action@v1
        with:
          ssh-host: "example.com"
          ssh-user: "deploy"
          ssh-port: "22"
          ssh-password: ${{ secrets.SSH_PASSWORD }}
          custom-ed25519-key: ${{ secrets.CUSTOM_ED25519_KEY }}
          env-vars: "APP_ENV=production,DB_HOST=localhost"
          script: |
            echo "Environment: $APP_ENV"
            echo "Database: $DB_HOST"
            sudo systemctl restart my-service
```

### Example 2: Using from a Repository with GitHub Secrets and Workflow Environment Variables

Pass secrets and workflow environment variables to the script.

```yaml
name: Deploy Script
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      APP_ENV: production
      DB_HOST: localhost
    steps:
      - uses: actions/checkout@v3
      - uses: SerheyJankowsky/ssh-action@v1
        with:
          ssh-host: "example.com"
          ssh-user: "deploy"
          ssh-port: "22"
          ssh-password: ${{ secrets.SSH_PASSWORD }}
          custom-ed25519-key: ${{ secrets.CUSTOM_ED25519_KEY }}
          env-vars: "MY_SECRET,APP_ENV,DB_HOST"
          script: |
            echo "Secret: $MY_SECRET"
            echo "Environment: $APP_ENV"
            echo "Database: $DB_HOST"
            sudo systemctl restart my-service
        env:
          MY_SECRET: ${{ secrets.MY_SECRET }}
```

### Example 3: Mixing Custom and GitHub Variables

Combine custom and GitHub-sourced environment variables.

```yaml
name: Deploy Script
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      APP_ENV: production
    steps:
      - uses: actions/checkout@v3
      - uses: SerheyJankowsky/ssh-action@v1
        with:
          ssh-host: "example.com"
          ssh-user: "deploy"
          ssh-port: "22"
          ssh-password: ${{ secrets.SSH_PASSWORD }}
          custom-ed25519-key: ${{ secrets.CUSTOM_ED25519_KEY }}
          env-vars: "DB_HOST=localhost,MY_SECRET,APP_ENV"
          script: |
            echo "Secret: $MY_SECRET"
            echo "Environment: $APP_ENV"
            echo "Database: $DB_HOST"
            sudo systemctl restart my-service
        env:
          MY_SECRET: ${{ secrets.MY_SECRET }}
```

## Security Considerations

- **Secrets**: Store sensitive inputs (`ssh-password`, `custom-ed25519-key`, `env-vars` with secrets) in GitHub Secrets to prevent exposure in logs.
- **Environment Variables**: The action escapes special characters to prevent command injection. Avoid echoing sensitive variables in scripts.
- **SSH Password**: If `ssh-password` is used, ensure the server allows password-based authentication. Store the password in a secret.
- **Sudo**: If the script uses `sudo`, configure passwordless sudo (`NOPASSWD` in sudoers) on the server to avoid prompts.
- **Key Cleanup**: The action removes the SSH key from the remote server's `authorized_keys` file after execution.

## Notes

- **Docker**: The action runs in a Docker container built from the `Dockerfile`. GitHub Actions automatically builds the image when the action is used.
- **Repository Hosting**: Host the action in a public repository for public use or a private repository for restricted access. Use tags (e.g., `v1`) for versioning.
- **Error Handling**: The action validates required inputs and fails on errors. Check logs for issues with SSH authentication or script execution.
- **Environment Variables**:
  - Use `KEY=VALUE` for custom variables defined directly in `env-vars`.
  - Use variable names (e.g., `SECRET_NAME`) to source values from GitHub Secrets or workflow `env`. Pass these via the `env` section in the workflow.
- **SSH Authentication**: If `ssh-copy-id` fails (e.g., due to missing password), verify the server's SSH configuration.

## Publishing the Action

1. **Push to GitHub**:
   - Create a repository (e.g., `your-username/ssh-action`).
   - Add `action.yml`, `Dockerfile`, `entrypoint.sh`, and `README.md` to the root.
   - Commit and push:
     ```bash
     git add .
     git commit -m "Initial SSH action"
     git push origin main
     ```
2. **Create a Release**:
   - Tag a version:
     ```bash
     git tag v1
     git push origin v1
     ```
   - Optionally, create a release in the GitHub UI for better visibility.
3. **Use in Workflows**:
   - Reference the action as `your-username/ssh-action@v1` in your workflows.

## Troubleshooting

- **SSH Connection Fails**: Ensure `ssh-host`, `ssh-user`, and `ssh-port` are correct. Provide `ssh-password` if required.
- **Environment Variables Not Set**: Verify the `env-vars` format and ensure GitHub Secrets/env variables are passed in the workflow.
- **Sudo Prompts**: Configure passwordless sudo or contact the action maintainer to add `sudo-password` support.
- **Action Not Found**: Ensure the repository and tag exist (e.g., `your-username/ssh-action@v1`).

For feature requests or issues, please open an issue in the repository.
