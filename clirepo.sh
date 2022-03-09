#!/usr/bin/env bash
#
# Create a new remote repository on GitHub, GitLab or Bitbucket
# from your command line.
#
# Copyright (c) 2018-2020 K Kollmann <code∆k.kollmann·moe>
#
#
# Before first use, verify the presence and readability of the configuration
# file named .conf. Use the config file to change the default location of your
# credential files or to add aliases for the services you want to use.
#
#


# ----- VARIABLES -----
script_dir="$(dirname "$0")"
config_file="$script_dir/.conf"

# global defaults for repository and API handling/creation
repo_exists=false
privacy_level="private"
header_content_type="Content-Type: application/json"
response_verbosity="--silent" # by default "--silent"; change to "-v" for debugging

# user settings
declare -A credentials_fnames
declare -A credentials_templates
declare -A settings

# services
declare -A aliases
declare -A full_names
declare -A labels
declare -A websites

# API-specific
declare -A api_urls
declare -A regex_web_urls
declare -A regex_ssh_clone_urls
declare -A regex_https_clone_urls

credentials_fnames=( # file names of credentials files
  ["bb"]=".bitbucket"
  ["gh"]=".github"
  ["gl"]=".gitlab"
)
credentials_templates=( # templates for contents of credentials files
  ["bb"]='-u "YOUR_USER_SLUG:YOUR_APP_PASSWORD"'
  ["gh"]='-H "Authorization: token YOUR_PERSONAL_ACCESS_TOKEN"'
  ["gl"]='-H "Private-Token: YOUR_PERSONAL_ACCESS_TOKEN"'
)
settings=( # settings which can be adapted by modifying .conf file
  ["credentials_dir"]="$HOME/.clirepo/credentials"
  ["alias_bitbucket"]="bb"
  ["alias_github"]="gh"
  ["alias_gitlab"]="gl"
)

aliases=( # alternative names for services / used to look up services
  ["bitbucket"]="bb"
  ["github"]="gh"
  ["gitlab"]="gl"
)
full_names=( # proper names of services, incl. brand-specific spellings
  ["bb"]="Bitbucket"
  ["gh"]="GitHub"
  ["gl"]="GitLab"
)
labels=( # simplified, lowercased versions of service names
  ["bb"]="bitbucket"
  ["gh"]="github"
  ["gl"]="gitlab"
)
websites=( # domain names, excl. protocol (https)
  ["bb"]="bitbucket.org"
  ["gh"]="github.com"
  ["gl"]="gitlab.com"
)

api_urls=( # API urls – built from variables later on (hence single quotes)
  ["bb"]='https://api.$website/2.0/repositories/$user_name/$repo_slug'
  ["gh"]='https://api.$website/user/repos'
  ["gl"]='https://$website/api/v4/projects'
)
regex_web_urls=(
  ["bb"]='"clone":\s*\[.*(https:\/\/)\w*@([A-Za-z0-9/.]*)\.git([^"]*)'
  ["gh"]='"svn_url":\s*"(https:[^"]*)'
  ["gl"]='"web_url":\s*"(http[^"]*)'
)
regex_ssh_clone_urls=(
  ["bb"]='"clone":\s*\[.*(git@[^"]*).*]'
  ["gh"]='"ssh_url":\s*"(git@[^"]*)'
  ["gl"]='"ssh_url_to_repo":\s*"(git@[^"]*)'
)
regex_https_clone_urls=(
  ["bb"]='"clone": \[.*(https:[^"]*).*]'
  ["gh"]='"clone_url":\s*"(https:[^"]*)'
  ["gl"]='"http_url_to_repo":\s*"(http[^"]*)'
)


# ----- HELP + USAGE TEXTS -----
usage=".....
CLIREPO
This script allows you to quickly create new remote repositories hosted on
GitHub, GitLab or Bitbucket directly from your command line.

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
Use .conf.template to create a configuration file .conf. This file needs to
be present and readable for the script even if you don't indent to set
own variables.

Next, for each service you want to use, you have to have a file with your
credentials for that particular service saved in the credentials directory
"${settings[credentials_dir]}"
The naming scheme for the credentials files is \".service\", where service is
the name of the website where you want to create your new remote repository,
i.e. .bitbucket, .github or .gitlab

Templates for all three credentials files are provided in the credentials
directory. They are named \".service.template\" and need only be renamed to
read \".service\", e.g. \".gitlab\".
You can also use -t as first argument when running the script to print any
(or all) of the templates to the console. Printing them to STDOUT will continue
to work even if you delete the original template files. If you provide the name
of a service as argument value, only that service's template will get displayed.
Otherwise, all templates are printed to the console.
Usage:
  ./clirepo.sh -t [github]

Once you have provided your credentials, make sure to modify the file permissions
so only your local user can access the credential file(s), e.g.
  chmod 600 .service

IMPORTANT
Please note that this script currently does not support the handling of encrypted
credentials, nor are the credentials files safeguarded in any way other
than via file permissions for whose setting you yourself are responsible.

ALIASES
-------
By default, the aliases "bb", "gh" and "gl" are available to refer to the
services in abbreviated form. You can provide your own aliases/shortcuts by
setting them in the configuration file, which will override the default values.
Usage:
  ./clirepo.sh MyNewRepo gl
"


# ----- MAIN SCRIPT -----
main() {
  check_config_file
  retrieve_config
  set_aliases

  if [ "$1" == "-t" ]; then
    # template text can be displayed for each service individually
    platform=$2
    if [[ -n "$platform" ]] && [[ -n "${aliases[$platform]}" ]]; then
      id="${aliases[$platform]}"
      label="${labels[$id]}"
      template="${credentials_templates[$id]}"
      printf "%s\n" "Template for .$label credentials file:" "$template"
    else
      if [[ -n "$platform" ]]; then
        printf "%s\n" "Service/alias $platform does not exist." ""
      fi
      printf "%s\n" "Templates for credential files:"
      for l in "${!labels[@]}"; do
        printf "%s\n" ."${labels[$l]}" "${credentials_templates[$l]}"
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
    if [[ -n "$3" ]]; then
      privacy_level=$3 # optional argument
    fi

    if [[ -n "${aliases[$platform]}" ]]; then
      id=${aliases[$platform]}
      file_name="${credentials_fnames[$id]}"
      file_path="${settings[credentials_dir]}/$file_name"

      check_credentials

      setup_service

      printf "%s\n" "About to create repository '$repo_name', standing by..." ""
      # create function names on the fly for calling them
      "create_repo_${id}" "$file_path"

      if [[ "$repo_exists" == "true" ]]; then
        printf "%s\n" "'$repo_name' already exists: $web_url"
      else
        printf "%s\n" "SUCCESS! Repository '$repo_name' was created on $full_name."
        printf "%s\n" "Visit it on the web: $web_url"
      fi
        printf "%s\n" ""
        printf "%s\n" "Add it as a remote:"
        printf "%s\n" "git remote add $platform $clone_url_https"
        printf "%s\n" "git remote add $platform $clone_url_ssh"
    else
      printf "%s\n" "The provided service $platform is unknown."
      printf "%s\n" "Could not create repository $repo_name."
      exit
    fi
  fi
}


# ----- FUNCTIONS -----
function get_urls() {
  local response=$1
  if [[ "$response" =~ ${regex_ssh_clone_urls[$id]} ]]; then
    clone_url_ssh=${BASH_REMATCH[1]}
  fi
  if [[ "$response" =~ ${regex_https_clone_urls[$id]} ]]; then
    clone_url_https=${BASH_REMATCH[1]}
  fi
  if [[ "$response" =~ ${regex_web_urls[$id]} ]]; then
    web_url=${BASH_REMATCH[1]}
    # web_url for bb has two capture groups
    if [[ "$id" == "bb" ]]; then
      web_url+=${BASH_REMATCH[2]}
    fi
  fi
}

function check_config_file() {
# check for existence of config file
  if [ ! -f "$config_file" ]; then
    printf "%s\n" "Config file $config_file not found or not readable."
    printf "%s\n" "Make sure it exists and can be read in by this script."
    exit
  fi
}

function retrieve_config() {
# get values from config file
  local line
  readarray -t lines < "$config_file"
  for line in "${lines[@]}"; do
    case "$line" in
      # ignore commented lines, empty values, empty lines
      *\#*)
            continue
            ;;
      *\=)
            continue
            ;;
      '')
            continue
            ;;
    esac
    local key="${line%%=*}"
    local value="${line#*=}"

    # only allow modification of known config options (must exist in settings array)
    if [[ -n "${settings[$key]}" ]] && [[ "${settings[$key]}" != "$value" ]]; then
      settings[$key]="$value"
    fi
  done
}

function set_aliases() {
# extract services' aliases from settings and add them to aliases array
# ATTN. because the script uses the default shortcuts bb, gh, gl internally
# to look up and reference services, we need to keep these abbreviations
# around + use them as values for additional aliases
  for i in "${!settings[@]}"; do
    local regex='alias\_(.*)'
    if [[ "$i" =~ $regex ]]; then
      local label=${BASH_REMATCH[1]}
      local alias=${settings[$i]}
      # values of default aliases are used to ID services
      local id="${aliases[$label]}"
      # add new aliases – or default aliases in case they remain unchanged
      aliases[$alias]="$id"
    fi
  done
}


function setup_service() {
  # run config applicable to all services
  local is_private=true # default
  if [[ -n "$privacy_level" ]] && [[ "$privacy_level" == "public" ]]; then
    is_private=false
  fi

  label=${labels[$id]}
  full_name=${full_names[$id]}
  website=${websites[$id]}
  repo_slug="${repo_name,,}"

  user_name=""
  # only needed for BitBucket at this point (needed for API URLs)
  if [[ "$id" == "bb" ]]; then
    get_user
  fi

  web_url=""
  clone_url_ssh=""
  clone_url_https=""

  declare -A create_options=(
    ["name"]="\"$repo_name\""
    ["scm"]="\"git\""
    ["visibility"]="\"$privacy_level\""
    ["is_private"]="$is_private"
    ["private"]="$is_private"
  )

  options_string=""
  for o in "${!create_options[@]}"; do
    options_string="$options_string,\"$o\":${create_options[$o]}"
  done
  options_string="{${options_string:1}}"

  # function expects up to four args: the API url template, website URL,
  # user name (might be empty), repository name
  build_api_url "${api_urls[$id]}" "$website" "$user_name" "$repo_slug"
}

function get_user() {
  if [[ "$id" == "bb" ]]; then
    local firstline
    read -r firstline < "$file_path"

    local regex_extract_user='.*\"(.*):'
    if [[ "$firstline" =~ $regex_extract_user ]]; then
      user_name=${BASH_REMATCH[1]}
    fi
  fi
}

function build_api_url() {
  local temp_url=$1
  local website="$2"
  local user_name="$3" # provided as positional (empty) var even if non-existent
  local repo_slug="$4"

  temp_url="${temp_url/\$website/$website}"
  temp_url="${temp_url/\$user_name/$user_name}"
  temp_url="${temp_url/\$repo_slug/$repo_slug}"
  api_url="$temp_url"
}

function check_credentials() {
# check credentials file exists
  # check for existence of credentials file
  if [ ! -f "$file_path" ]; then
    printf "%s\n" "file $file_name for user credentials for service $website does not exist"
    printf "%s\n" "(missing file $file_path)"
    exit
  fi
}

function create_repo_bb() {
  # curl command formatted for BitBucket
  local response="$(curl \
    "$response_verbosity" \
    -H "$header_content_type" \
    -d "$options_string" \
    -K <(cat "$file_path") \
    "$api_url")"

  local regex_repo_exists='Repository with this Slug and Owner already exists.'
  if [[ "$response" =~ $regex_repo_exists ]]; then
    repo_exists=true

    response="$(curl \
      "$response_verbosity" \
      -H "$header_content_type" \
      -K <(cat "$file_path") \
      "https://api.$website/2.0/repositories/$user_name/$repo_slug")"
  fi

  get_urls "$response"
}

function create_repo_gh() {
  # curl command formatted for GitHub
  local response="$(curl \
    "$response_verbosity" \
    -H "$header_content_type" \
    -H "Accept: application/vnd.github.v3+json" \
    -K <(cat "$file_path") \
    -d "$options_string" \
    "$api_url")"

  local regex_repo_exists='name already exists on this account'
  if [[ "$response" =~ $regex_repo_exists ]]; then
    repo_exists=true

    # user name is needed for GitHub web URLs
    local user_response="$(curl \
      "$response_verbosity" \
      -H "$header_content_type" \
      -H "Accept: application/vnd.github.v3+json" \
      -K <(cat "$file_path") \
      "https://api.github.com/user")"

    local regex_user='"login":\s*"([^"]*)'
    if [[ "$user_response" =~ $regex_user ]]; then
      user_name=${BASH_REMATCH[1]}
    fi

    response="$(curl \
      "$response_verbosity" \
      -H "$header_content_type" \
      -H "Accept: application/vnd.github.v3+json" \
      -K <(cat "$file_path") \
      "https://api.github.com/repos/$user_name/$repo_slug")"
  fi

  get_urls "$response"
}

function create_repo_gl() {
  # curl command formatted for GitLab
  local response="$(curl \
    "$response_verbosity" \
    -H "$header_content_type" \
    -K <(cat "$file_path") \
    -d "$options_string" \
    "$api_url")"

  local regex_repo_exists='has already been taken'
  if [[ "$response" =~ $regex_repo_exists ]]; then
    repo_exists=true

    local user_response="$(curl \
      "$response_verbosity" \
      -H "$header_content_type" \
      -K <(cat "$file_path") \
      "https://$website/api/v4/user")"

    local regex_user='"username":\s*"([^"]*)'
    if [[ "$user_response" =~ $regex_user ]]; then
      user_name=${BASH_REMATCH[1]}
    fi

    response="$(curl \
      "$response_verbosity" \
      -H "$header_content_type" \
      -K <(cat "$file_path") \
      "https://$website/api/v4/projects/$user_name%2F$repo_slug")"
  fi

  get_urls "$response"
}

main "$@"; exit
