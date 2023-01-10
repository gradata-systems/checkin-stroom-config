#!/bin/bash
# Downloads Stroom configuration via the API and checks in changes to a Git repository.

stroom_url="${STROOM_URL:-}"
stroom_api_key_file="${STROOM_API_KEY_FILE:-}"
repo_dir="${STROOM_REPO_DIR:-./repo}"
git_user="${STROOM_GIT_USER:-}"
git_email="${STROOM_GIT_EMAIL:-}"
git_url="${STROOM_GIT_URL:-}"
git_branch="${STROOM_GIT_BRANCH:-master}"
ssh_key_file="${STROOM_SSH_KEY_FILE:-}"

usage() {
  echo "Usage: checkin-stroom-config   --stroom-url https://stroom.example.com
                               --stroom-api-key-file ~/api_key
                               --git-user 'Git User'
                               --git-email 'git-user@github.com'
                               --git-url git@github.com:test-user/stroom-config.git
                               --git-branch master
                               --ssh-key-file ~/.ssh/private.key"
  exit 2
}

short_opts='s:a:r:u:e:g:b:k:'
long_opts='stroom-url:,stroom-api-key-file:,repo-dir:,git-user:,git-email:,git-url:,git-branch:,ssh-key-file:'
parsed_arguments=$(getopt -a -n checkin-stroom-config -o "$short_opts" --long "$long_opts" -- "$@")
eval set -- "$parsed_arguments"
while :
do
  case "$1" in
    -s | --stroom-url)
      stroom_url="$2"
      shift 2
      ;;
    -a | --stroom-api-key-file)
      stroom_api_key_file="$2"
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
elif [ ! -f "$stroom_api_key_file" ]; then
  echo 'API key file does not exist (--stroom-api-key-file)'
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
echo "Stroom URL: $stroom_url"
echo "Stroom API key file: $stroom_api_key_file"
echo "Repo directory: $repo_dir"
echo "Git username: $git_user"
echo "Git email: $git_email"
echo "Git URL: $git_url"
echo "Git branch: $git_branch"
echo "SSH key file: $ssh_key_file"

# Delete the repo directory if it exists
if [ -d "$repo_dir" ]; then
  rm -rf "$repo_dir"
fi

# Create the repo directory
mkdir -p "$repo_dir"

# Add the SSH key to ssh-agent
eval `ssh-agent -s`
ssh-add "$ssh_key_file"
git_server_hostname=$(echo "$git_url" | sed -E 's/^git@(.+):.+$/\1/g')
mkdir -p ~/.ssh
ssh-keyscan "$git_server_hostname" >> ~/.ssh/known_hosts

# Store the StroomAPI key
api_key=$(cat "$stroom_api_key_file")

cd "$repo_dir"

# Pull the git repo
git init --quiet
git remote add origin "$git_url"
git config user.name "$git_user"
git config user.email "$git_email"

# Checkout the branch if it exists, else create a local branch
echo "Checking out branch $git_branch from repository $git_url..."
branch_exists=$(git ls-remote --heads "$git_url" "$git_branch" | wc -l)
if [ $branch_exists -ne 1 ]; then
  echo "Branch $git_branch does not exist on remote. Creating..."
  git checkout -b "$git_branch"
else
  git pull --rebase origin "$git_branch"
fi

# Dump Stroom config
echo "Downloading Stroom config..."
out_file='/tmp/stroom-config.zip'
curl -k -X GET \
  -H "Authorization:Bearer $api_key" \
  "$stroom_url/api/export/v1" --silent --output "$out_file"

echo "Unzipping $out_file..."
unzip -o -q "$out_file" -d .
rm -f "$out_file"

# Commit new files, changes and deletions
echo "Committing changes..."
git add --all
git commit --message "Automatic check-in at $(date -Iseconds)"
git push --set-upstream origin "$git_branch"

exit 0
