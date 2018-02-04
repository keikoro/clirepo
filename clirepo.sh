#!/usr/bin/env bash
#
# Create a new remote repository on GitHub, GitLab or Bitbucket.
# Copyright (c) 2018 K Kollmann <code∆k.kollmann·moe>


# you can change the directory you use to store your credentials in
credentials_dir="$HOME/.clirepo"

if [ "$credentials_dir" == "$HOME/.clirepo" ]; then
  credentials_dir_display='~/.clirepo'
else
  credentials_dir_display=$credentials_dir
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

github='Contents of file .github:
\nmachine api.github.com login YOUR_USERNAME password YOUR_TOKEN'

gitlab='Contents of file .gitlab:
\n--header "Private-Token: YOUR_PRIVATE_TOKEN"'

bitbucket='Contents of file .bitbucket:
\nmachine api.bitbucket.org login YOUR_USERNAME password YOUR_TOKEN'

if [ "$1" == "-t" ]; then
  if [ "$2" == "gitlab" ]; then
    echo -e $gitlab
  elif [ "$2" == "bitbucket" ]; then
    echo -e $bitbucket
  elif [ "$2" == "github" ]; then
    echo -e $github
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
fi

if [ "$service" == "bitbucket" ] || [ "$service" == "bb" ]; then
  filedir="$credentials_dir"/.bitbucket
  # user name is needed for constructing the Bitbucket URL
  read -r m s l user p t < <(cat "$filedir")
  # Bitbucket needs repo name in lower case characters for repo slug
  repo_lowercase="$(echo "$reponame" | tr '[:upper:]' '[:lower:]')"
  url=https://api.bitbucket.org/2.0/repositories/$user/$repo_lowercase
  is_private=true
  if [ "$privacylevel" == "public" ]; then
    is_private=false
  fi
  options='{"name": "'"$reponame"'", "scm": "git", "is_private": '"$is_private"'}'

  curl -H "Content-Type: application/json" -d "$options" \
  --netrc-file <(cat "$filedir") "$url"

elif [ "$service" == "github" ] || [ "$service" == "gh" ]; then
  filedir="$credentials_dir"/.github
  url=https://api.github.com/user/repos
  private=true
  if [ "$privacylevel" == "public" ]; then
    private=false
  fi
  options='{"name": "'"$reponame"'", "private": '"$private"'}'

  curl -H "Content-Type: application/json" -d "$options" \
  --netrc-file <(cat "$filedir") "$url"

elif [ "$service" == "gitlab" ] || [ "$service" == "gl" ]; then
  filedir="$credentials_dir"/.gitlab
  url=https://gitlab.com/api/v4/projects
  visibility="private"
  if [ "$privacylevel" == "public" ]; then
    visibility="public"
  fi
  options='{"name": "'"$reponame"'", "visibility": "'"$visibility"'"}'

  curl -H "Content-Type: application/json" -d "$options" \
  -K <(cat "$filedir") "$url"

else
  echo The provided service "$service" is unknown.
  echo Could not create repository "$reponame".

fi