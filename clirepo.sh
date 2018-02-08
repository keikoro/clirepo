#!/usr/bin/env bash
#
# Create a new remote repository on GitHub, GitLab or Bitbucket.
# Copyright (c) 2018 K Kollmann <code∆k.kollmann·moe>


# you can change the directory you want to use to store your credentials
# in by changing the value of credentials_dir
credentials_dir="$HOME/.clirepo"

if [ "$credentials_dir" == "$HOME/.clirepo" ]; then
  credentials_dir_display="~/.clirepo"
else
  credentials_dir_display="$credentials_dir"
fi

helptext="You
need to provide the name of the remote repository you want to
\ncreate as well as the service you want to create it on (either
\nits full name in lower case letters or its name shortened to two
\nletters - bb for bitbucket, gh for github, gl for gitlab). The
\nvisibility of all new repositories is set to private, though you
\ncan override this behaviour by using 'public' as optional third
\nargument.
\nThis script supports the creation of remote repositories hosted on
\nGitHub, GitLab and Bitbucket. You have to have a file with your
\ncredentials for the service you want to use in $credentials_dir_display.
Use -t
\nas first argument to see templates for any (or all) of these files,
\ne.g. ./clirepo.sh -t [github]. Make sure to set the file permissions
\nso only your user can access the file(s), e.g. chmod 600 FILENAME.
\nUsage: ./clirepo.sh <reponame> <service> [public]"

bitbucket='Contents of file .bitbucket:
\nmachine api.bitbucket.org login YOUR_USERNAME password YOUR_TOKEN'

github='Contents of file .github:
\nmachine api.github.com login YOUR_USERNAME password YOUR_TOKEN'

gitlab='Contents of file .gitlab:
\n--header "Private-Token: YOUR_PRIVATE_TOKEN"'

if [ "$1" == "-t" ]; then
  # template text can be displayed per service
  if [ "$2" == "bitbucket" ] \
    || [ "$2" == "github" ] \
    || [ "$2" == "gitlab" ]; then
    echo -e ${!2}
  else
    echo -e $bitbucket
    echo -e $github
    echo -e $gitlab
  fi
  exit
elif [ "$1" == "-h" ] || [ "$1" == "--help" ] \
  || [ "$1" == "" ] || [ "$2" == "" ]; then
  echo -e $helptext
  exit
else
  reponame=$1
  service=$2
  privacylevel=$3

  # allow shortened versions of service names as args but switch to
  # full names for easier referencing of credentials files
  case "$service" in
    "bb" )
      service=bitbucket ;;
    "gh" )
      service=github ;;
    "gl" )
      service=gitlab ;;
    # set file name to empty if an unknown service was provided
    * )
      filename="" ;;
  esac

  if [ ! $filename ]; then
    filename=."$service"
    filepath="$credentials_dir/$filename"
  else
    echo The provided service "$service" is unknown.
    echo Could not create repository "$reponame".
    exit
  fi
fi

function create_bitbucket_repo {
  website=bitbucket.org

  # user name is needed for constructing Bitbucket URLs
  read -r m s l user p t < <(cat "$filepath")
  # Bitbucket needs repo name in lower case characters for repo slug
  repo_lowercase="$(echo "$reponame" | tr '[:upper:]' '[:lower:]')"
  url="https://api.$website/2.0/repositories/$user/$repo_lowercase"

  is_private=true
  if [ "$privacylevel" == "public" ]; then
    is_private=false
  fi
  options='{"name": "'"$reponame"'", "scm": "git", "is_private": '"$is_private"'}'

  # issue curl command and save its stdout output into a variable
  response=$(curl --silent -H "Content-Type: application/json" \
  -d "$options" \
  --netrc-file <(cat "$filepath") "$url")
  echo "${response[@]}"

  # filter out ssh_url and https_url from JSON response
  clone_info=$(echo "$response" | grep -Eo '"clone": \[.*?\]')
  ssh_url=$(echo "$clone_info" | grep -Eo 'git@[^"]*')
  https_url=$(echo "$clone_info" | grep -Eo 'https:[^"]*')

  # construct (clickable) URL to repo on web
  # Bitbucket allows: alphanumerical, underscores, dashes, dots
  repo_lowercase=$(echo "$repo_lowercase" | sed 's:[^0-9a-z\-\_\.]:-:g')
  web_url="https://$website/$user/$repo_lowercase"

  # check if repo creation failed because it already exists
  if [ -z "$ssh_url" ] && [ -z "$https_url" ]; then
    repo_exists=$(echo "$response" \
    | grep -Eo 'Repository with this Slug and Owner already exists.')
  fi
}

function create_github_repo {
  website=github.com
  url="https://api.$website/user/repos"
  repo_lowercase="$(echo "$reponame" | tr '[:upper:]' '[:lower:]')"

  private=true
  if [ "$privacylevel" == "public" ]; then
    private=false
  fi
  options='{"name": "'"$reponame"'", "private": '"$private"'}'

  # issue curl command and save its stdout output into a variable
  response=$(curl --silent -H "Content-Type: application/json" \
  -d "$options" \
  --netrc-file <(cat "$filepath") "$url")
  echo "${response[@]}"

  # filter out ssh_url and https_url from JSON response
  ssh_url=$(echo "$response" \
  | grep -Eo '"ssh_url":\s*"[^"]*' | grep -Eo 'git@.*')
  https_url=$(echo "$response" \
  | grep -Eo '"clone_url":\s*"[^"]*' | grep -Eo 'https:.*')

  # construct (clickable) URL to repo on web
  web_url=$(echo "$https_url" | sed 's:\(.*\)\.git:\1:')

  # check if repo creation failed because it already exists
  if [ -z "$ssh_url" ] && [ -z "$https_url" ]; then
    repo_exists=$(echo "$response" \
    | grep -Eo 'name already exists on this account')
    repo_lowercase=$(echo "$repo_lowercase" \
    | sed 's:[^0-9a-z\-\_\.]\{1,\}:-:g')

    # user name is needed for GitHub web URLs
    read -r m s l user p t < <(cat "$filepath")

    web_url="https://$website/$user/$repo_lowercase"
  fi
}

function create_gitlab_repo {
  website=gitlab.com
  url="https://$website/api/v4/projects"
  repo_lowercase="$(echo "$reponame" | tr '[:upper:]' '[:lower:]')"

  visibility="private"
  if [ "$privacylevel" == "public" ]; then
    visibility="public"
  fi
  options='{"name": "'"$reponame"'", "visibility": "'"$visibility"'"}'

  # issue curl command and save its stdout output into a variable
  response=$(curl --silent -H "Content-Type: application/json" \
  -d "$options" -K <(cat "$filepath") "$url")
  echo "${response[@]}"

  # filter out ssh_url and https_url from JSON response
  ssh_url=$(echo "$response" \
  | grep -Eo '"ssh_url_to_repo":"[^"]*' | grep -Eo 'git@.*')
  https_url=$(echo "$response" \
  | grep -Eo '"http_url_to_repo":"[^"]*' | grep -Eo 'https:.*')

  # construct (clickable) URL to repo on web
  get_user=$(curl --silent -H "Content-Type: application/json" \
  -K <(cat "$filepath") "https://$website/api/v4/user")
  user=$(echo "$get_user" | grep -Eo '"username":"[^"]*' \
  | sed 's:\"username\"\:\"\(.*\):\1:')

  # construct (clickable) URL to repo on web
  web_url=$(echo "$https_url" | sed 's:\(.*\)\.git:\1:')

  # check if repo creation failed because it already exists
  if [ -z "$ssh_url" ] && [ -z "$https_url" ]; then
    repo_exists=$(echo "$response" | grep -Eo 'has already been taken')
    # GitLab allows: letters, digits, emojis, '_', '.', dash, space
    # repositories must start with letter, digit, emoji or '_'
    repo_lowercase=$(echo "$repo_lowercase" \
    | sed 's:[^0-9a-z\-\_]\{1,\}:-:g')

    web_url="https://$website/$user/$repo_lowercase"
  fi
}

# check for credentials file
if [ ! -f "$filepath" ]; then
  echo File "$filename" with user credentials missing!
  exit
else
  # note: if a 3rd arg was used, its value is saved in
  # global var $privacylevel (and referenced as such in each function)
  if [ "$service" == "bitbucket" ]; then
    create_bitbucket_repo "$filename"
  elif [ "$service" == "github" ]; then
    create_github_repo "$filename"
  elif [ "$service" == "gitlab" ]; then
    create_gitlab_repo "$filename"
  fi

  # note: the two git clone url variables are global vars
  # (hence work here too, outside of the function they were created in)
  echo ""

  if [ ! -z "$ssh_url" ] && [ ! -z "$https_url" ]; then
    echo "You can now git remote add ..."
    echo "$ssh_url"
    echo "$https_url"
    echo ""
  elif [ ! -z "$repo_exists" ]; then
    echo "Repository '$reponame' already exists!"
  else
    echo "Something went wrong while trying to create '$reponame'..."
    echo "Please check the above response message for more info."
    exit
  fi
  echo "Web URL: $web_url"
fi
