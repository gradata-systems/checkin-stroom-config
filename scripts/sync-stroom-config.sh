#!/bin/bash
# Downloads Stroom configuration via the API and checks in changes to a Git repository.

stroom_url="${STROOM_URL:-}"
auth_token_url="${STROOM_AUTH_TOKEN_URL:-}"
auth_client_id="${STROOM_AUTH_CLIENT_ID:-}"
auth_client_secret_file="${STROOM_AUTH_CLIENT_SECRET_FILE:-}"
repo_dir="${STROOM_REPO_DIR:-./repo}"
git_user="${STROOM_GIT_USER:-}"
git_email="${STROOM_GIT_EMAIL:-}"
git_url="${STROOM_GIT_URL:-}"
git_branch="${STROOM_GIT_BRANCH:-master}"
ssh_key_file="${STROOM_SSH_KEY_FILE:-}"

function usage() {
  echo "Usage: sync-stroom-config --stroom-url https://stroom.example.com
                               --auth-token-url https://auth.example.com/realms/stroom/protocol/openid-connect/token
                               --auth-client-id stroom
                               --auth-client-secret-file ~/auth-client-secret
                               --git-user 'Git User'
                               --git-email 'git-user@github.com'
                               --git-url git@github.com:test-user/stroom-config.git
                               --git-branch master
                               --ssh-key-file ~/.ssh/private.key"
  exit 2
}

short_opts='s:a:r:u:e:g:b:k:'
long_opts='stroom-url:,auth-token-url:,auth-client-id:,auth-client-secret-file:,repo-dir:,git-user:,git-email:,git-url:,git-branch:,ssh-key-file:'
parsed_arguments=$(getopt -a -n sync-stroom-config -o "$short_opts" --long "$long_opts" -- "$@")
eval set -- "$parsed_arguments"
while :
do
  case "$1" in
    -s | --stroom-url)
      stroom_url="$2"
      shift 2
      ;;
    --auth-token-url)
      auth_token_url="$2"
      shift 2
      ;;
    --auth-client-id)
      auth_client_id="$2"
      shift 2
      ;;
    --auth-client-secret-file)
      auth_client_secret_file="$2"
      shift 2
      ;;
    -r | --repo-dir)
      repo_dir="$2"
      shift 2
      ;;
    -u | --git-user)
      git_user="$2"
      shift 2
      ;;
    -e | --git-email)
      git_email="$2"
      shift 2
      ;;
    -g | --git-url)
      git_url="$2"
      shift 2
      ;;
    -b | --git-branch)
      git_branch="$2"
      shift 2
      ;;
    -k | --ssh-key-file)
      ssh_key_file="$2"
      shift 2
      ;;
    --) shift; break ;;
    *)
      echo "Unrecognised option: $1"
      usage ;;
  esac
done

if [ -z "$stroom_url" ]; then
  echo 'Stroom URL not specified (--stroom-url)'
  usage
elif [ -z "$auth_token_url" ]; then
  echo 'OAuth2 token URL not specified (--auth-token-url)'
  usage
elif [ -z "$auth_client_id" ]; then
  echo 'OAuth2 client ID not specified (--auth-client-id)'
  usage
elif [ ! -f "$auth_client_secret_file" ]; then
  echo 'OAuth2 client secret file does not exist (--auth-client-secret-file)'
  usage
elif [ -z "$repo_dir" ]; then
  echo 'Repo directory path not specified (--repo-dir)'
  usage
elif [ -z "$git_user" ]; then
  echo 'Git user name not specified (--git-user)'
  usage
elif [ -z "$git_email" ]; then
  echo 'Git user email address not specified (--git-email)'
  usage
elif [ -z "$git_url" ]; then
  echo 'Git URL not specified (--git-url)'
  usage
elif [ -z "$git_branch" ]; then
  echo 'Git branch not specified (--git-branch)'
  usage
elif [ ! -f "$ssh_key_file" ]; then
  echo "SSH key file $ssh_key_file does not exist (--ssh-key-file)"
  usage
fi

echo "Options:"
echo " * Stroom URL: $stroom_url"
echo " * OAuth2 token URL: $auth_token_url"
echo " * OAuth2 client ID: $auth_client_id"
echo " * OAuth2 client secret file: $auth_client_secret_file"
echo " * Repo directory: $repo_dir"
echo " * Git username: $git_user"
echo " * Git email: $git_email"
echo " * Git URL: $git_url"
echo " * Git branch: $git_branch"
echo " * SSH key file: $ssh_key_file"

# Delete the repo directory if it exists
if [ -d "$repo_dir" ]; then
  rm -rf "$repo_dir"
fi

# Create the repo directory
mkdir -p "$repo_dir"

# Add the SSH key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add "$ssh_key_file"
git_server_hostname=$(echo "$git_url" | sed -E 's/^git@(.+):.+$/\1/g')
mkdir -p ~/.ssh
ssh-keyscan "$git_server_hostname" >> ~/.ssh/known_hosts

cd "$repo_dir" || exit

# Pull the git repo
git init --quiet
git remote add origin "$git_url"
git config user.name "$git_user"
git config user.email "$git_email"

# Checkout the branch if it exists, else create a local branch
echo "Checking out branch $git_branch from repository $git_url..."
branch_exists=$(git ls-remote --heads "$git_url" "$git_branch" | wc -l)
if [ "$branch_exists" -ne 1 ]; then
  echo "Branch $git_branch does not exist on remote. Creating..."
  git checkout -b "$git_branch"
else
  if ! git pull --rebase origin "$git_branch"; then
    echo "Failed to check out repository $git_url"
    exit 1
  fi
fi

# Obtain an access token from the OAuth2 provider
access_token_file='/tmp/access-token'
status_code=$(curl -k -X POST \
  --silent \
  --output "$access_token_file" \
  --write-out %\{http_code\} \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials' \
  -d "client_id=$auth_client_id" \
  -d "client_secret=$(cat "$auth_client_secret_file")" \
  "$auth_token_url")

if [ "$status_code" -ne 200 ]; then
  echo "Failed to obtain access token. HTTP status code: $status_code"
  exit 1
fi

access_token=$(jq -r '.access_token' "$access_token_file")
if [ "$access_token" = "null" ]; then
  echo "Invalid access token"
  exit 1
fi

# Dump Stroom config
echo "Downloading Stroom config..."
download_url="$stroom_url/api/export/v1"
out_file='/tmp/stroom-config.zip'
status_code=$(curl -k -X GET \
  --silent \
  --output "$out_file" \
  --write-out %\{http_code\} \
  -H "Authorization:Bearer $access_token" \
  "$download_url")

if [ "$status_code" -ne 200 ]; then
  echo "Failed to download Stroom config from $download_url. Status code: $status_code"
  exit 1
fi

echo "Unzipping $out_file..."
unzip -o -q "$out_file" -d .

# Clean up temporary files
rm -f "$access_token_file"
rm -f "$out_file"

# Commit new files, changes and deletions
echo "Committing changes..."
git add --all
if git commit --message "Automatic check-in at $(date -Iseconds)"; then
  if git push --set-upstream origin "$git_branch"; then
    echo "Push successful"
    exit 0
  else
    echo "Failed to push to remote"
    exit 1
  fi
fi

exit 0
