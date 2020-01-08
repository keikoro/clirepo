#!/usr/bin/env bash
#
# Create a new remote repository on GitHub, GitLab or Bitbucket
# from your command line.
#
# Copyright (c) 2018 K Kollmann <code∆k.kollmann·moe>

# you can change the directory you want to use to store your credentials
# in by changing the value of credentials_dir
credentials_dir="$HOME/.clirepo/credentials"


#
#
#
declare -A services=(["bb"]="bb" ["bitbucket"]="bb" ["gh"]="gh" ["github"]="gh" ["gl"]="gl" ["gitlab"]="gl")

declare -A bb=(["label"]="bitbucket" ["full_name"]="Bitbucket" ["web"]="bitbucket.org" ["func"]="create_repo_bitbucket")
declare -A gh=(["label"]="github" ["full_name"]="GitHub" ["web"]="github.com" ["func"]="create_repo_github")
declare -A gl=(["label"]="gitlab" ["full_name"]="GitLab" ["web"]="gitlab.com" ["func"]="create_repo_gitlab")

usage=".....
CLIREPO
This script supports the command line-based creation
of remote repositories hosted on GitHub, GitLab and Bitbucket.

Usage:
  ./clirepo.sh <reponame> <service> [public]

Use -h or --help for more information:
  ./clirepo.sh -h"

helptext="CLIREPO help

USAGE
-----
  ./clirepo.sh <reponame> <service> [public]

SETUP
-----
For each service you want to use, you have to have a file
with your credentials saved in the credentials directory
($credentials_dir/).

Use -t as first argument to see templates for any (or all)
available credential files, e.g.
  ./clirepo.sh -t [github]

Once you have added your credentials, make sure to set the file permissions
so only your user can access the file(s), e.g.
  chmod 600 file_name

SHORTCUTS
---------
You can use the following shortcuts in place of the full service names:
  bb for Bitbucket
  gh for GitHub
  gl for GitLab
e.g.
   ./clirepo.sh MyNewRepo gl
"
if [ "$1" == "-t" ]; then
  platform=$2
  # template text can be displayed per service
  if [[ -n "$platform" ]] && [[ -n "${services[$platform]}" ]]; then
      id=${services[$platform]}
      l=$id[label]
      label=${!l}
      n=$id[full_name]
      full_name=${!n}
      printf "%s\n" "Template for .$label credentials file:" "$(<$credentials_dir/.$label.template)"
  else
    if [[ -n "$platform" ]]; then
      printf "%s\n" "Service $platform does not exist." ""
    fi
    printf "%s\n" "Templates for credential files for available services:"
    for fn in $credentials_dir/.[^.]*.template; do
      printf "%s\n" " $(basename $fn)" "$(<$fn)"
    done
  fi
  exit
elif [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  printf "%s\n" "$helptext"
  exit
elif [ "$1" == "" ] || [ "$2" == "" ]; then
  printf "%s\n" "$usage"
  exit
else
  repo_name=$1
  platform=$2
  privacylevel=$3

  if [[ -n "${services[$platform]}" ]]; then
    id=${services[$platform]}

    l=$id[label]
    label=${!l}
    n=$id[full_name]
    full_name=${!n}
    w=$id[web]
    web=${!w}
    f=$id[func]
    func=${!f}

    file_name=."$label"
    file_path="$credentials_dir/$file_name"
    repo_lowercase="$(echo "$repo_name" | tr '[:upper:]' '[:lower:]')"
  else
    printf "%s\n" "The provided service $platform is unknown."
    printf "%s\n" "Could not create repository $repo_name."
    exit
  fi
fi

function create_repo_bitbucket {
  # user name is needed for constructing Bitbucket URLs
  read -r m s l user p t < <(cat "$file_path")
  # Bitbucket needs repo name in lower case characters for repo slug
  api_url="https://api.$web/2.0/repositories/$user/$repo_lowercase"

  is_private=true
  if [ "$privacylevel" == "public" ]; then
    is_private=false
  fi
  options='{"name": "'"$repo_name"'", "scm": "git", "is_private": '"$is_private"'}'

  # issue curl command and save its stdout output into a variable
  response=$(curl --silent -H "Content-Type: application/json" \
  -d "$options" \
  --netrc-file <(cat "$file_path") "$api_url")

  # filter out git@ and https urls from JSON response
  clone_info=$(echo "$response" | grep -Eo '"clone": \[.*?\]')
  git_ssh=$(echo "$clone_info" | grep -Eo 'git@[^"]*')
  git_https=$(echo "$clone_info" | grep -Eo 'https:[^"]*')

  # construct (clickable) URL to repo on web
  # Bitbucket allows: alphanumerical, underscores, dashes, dots
  repo_slug=$(echo "$repo_lowercase" | sed 's:[^0-9a-z\-\_\.]:-:g')
  web_url="https://$web/$user/$repo_slug"

  # check if repo creation failed because it already exists
  if [ -z "$git_ssh" ] && [ -z "$git_https" ]; then
    repo_exists=$(echo "$response" \
    | grep -Eo 'Repository with this Slug and Owner already exists.')
  fi
}

function create_repo_github {
  api_url="https://api.$web/user/repos"

  private=true
  if [ "$privacylevel" == "public" ]; then
    private=false
  fi
  options='{"name": "'"$repo_name"'", "private": '"$private"'}'

  # issue curl command and save its stdout output into a variable
  response=$(curl --silent -H "Content-Type: application/json" \
  -d "$options" \
  --netrc-file <(cat "$file_path") "$api_url")

  # filter out ssh_url and https_url from JSON response
  git_ssh=$(echo "$response" \
  | grep -Eo '"ssh_url":\s*"[^"]*' | grep -Eo 'git@.*')
  git_https=$(echo "$response" \
  | grep -Eo '"clone_url":\s*"[^"]*' | grep -Eo 'https:.*')

  # construct (clickable) URL to repo on web
  web_url=$(echo "$git_https" | sed 's:\(.*\)\.git:\1:')

  # check if repo creation failed because it already exists
  if [ -z "$git_ssh" ] && [ -z "$git_https" ]; then
    repo_exists=$(echo "$response" \
    | grep -Eo 'name already exists on this account')
    repo_slug=$(echo "$repo_lowercase" \
    | sed 's:[^0-9a-z\-\_\.]\{1,\}:-:g')

    # user name is needed for GitHub web URLs
    read -r m s l user p t < <(cat "$file_path")

    web_url="https://$web/$user/$repo_slug"
    git_https="$web_url.git"
    git_ssh="git@$web:$user/$repo_slug.git"
  fi
}

function create_repo_gitlab {
  api_url="https://$web/api/v4/projects"

  visibility="private"
  if [ "$privacylevel" == "public" ]; then
    visibility="public"
  fi
  options='{"name": "'"$repo_name"'", "visibility": "'"$visibility"'"}'

  # issue curl command and save its stdout output into a variable
  response=$(curl --silent -H "Content-Type: application/json" \
  -d "$options" -K <(cat "$file_path") "$api_url")

  # filter out ssh_url_to_repo and http_url_to_repo from JSON response
  git_ssh=$(echo "$response" \
  | grep -Eo '"ssh_url_to_repo":"[^"]*' | grep -Eo 'git@.*')
  git_https=$(echo "$response" \
  | grep -Eo '"http_url_to_repo":"[^"]*' | grep -Eo 'https:.*')

  # construct (clickable) URL to repo on web
  get_user=$(curl --silent -H "Content-Type: application/json" \
  -K <(cat "$file_path") "https://$web/api/v4/user")
  user=$(echo "$get_user" | grep -Eo '"username":"[^"]*' \
  | sed 's:\"username\"\:\"\(.*\):\1:')

  # construct (clickable) URL to repo on web
  web_url=$(echo "$git_https" | sed 's:\(.*\)\.git:\1:')

  # check if repo creation failed because it already exists
  if [ -z "$git_ssh" ] && [ -z "$git_https" ]; then
    repo_exists=$(echo "$response" | grep -Eo 'has already been taken')
    # GitLab allows: letters, digits, emojis, '_', '.', dash, space
    # repositories must start with letter, digit, emoji or '_'
    repo_slug=$(echo "$repo_lowercase" \
    | sed 's:[^0-9a-z\-\_]\{1,\}:-:g')

    web_url="https://$web/$user/$repo_slug"
    git_https="$web_url.git"
    git_ssh="git@$web:$user/$repo_slug.git"
  fi
}

# check for credentials file
if [ ! -f "$file_path" ]; then
  printf "%s\n" "file $file_name for user credentials for service $full_name does not exist"
  printf "%s\n" "(missing file $file_path)"
  exit
else
  # note: if a 3rd arg was used, its value is saved in
  # global var $privacylevel (and referenced as such in each function)
  # echo "$func"
  $func "$file_name"
  # note: the two git clone url variables are global vars
  # (hence work here too, outside of the function they were created in)
  printf "%s\n" ""

  if [ -n "$repo_exists" ]; then
    printf "%s\n" "Repository '$repo_name' already exists on $full_name:"
    printf "%s\n" "$web_url" ""
    printf "%s\n" "For your convenience:"
    printf "%s\n" "git remote add $git_https"
    printf "%s\n" "git remote add $git_ssh"
    printf "%s\n" ""
  elif [ -n "$git_ssh" ] && [ -n "$git_https" ]; then
    printf "%s\n" "Repository '$repo_name' successfully created on $full_name!" ""
    printf "%s\n" "For your convenience:"
    printf "%s\n" "git remote add $git_https"
    printf "%s\n" "git remote add $git_ssh" ""
    printf "%s\n" "Visit in on the web:" "$web_url"
  else
    printf "%s\n" "Something went wrong while trying to create '$repo_name'..."
    printf "%s\n" "$response"
    exit
  fi
fi
