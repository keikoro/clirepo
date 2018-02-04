# clirepo
A Bash script to create remote repositories from the command line.

## Background
If you use Git a lot, and only from the command line, having to switch to a browser and go online to create new repositories on code sharing and collaboration websites like GitHub, GitLab and Bitbucket can be inconvenient.

I've been using `curl` to create new remote repositories from the terminal for quite a while now. To have a more portable solution – and to not have my access tokens show up in my console history anymore – I wrote this script.

## Usage example
To create a new repository called `neato_proj` on GitHub, you could use the following command:

```
$ ./clirepo.sh neato_proj github
```

## Requirements
You need to have Bash installed on your machine for this script to work (it does not have to be your main shell; it isn't mine either).

You will also have to have created personal access tokens for the services you want to use. Check the official docs on [GitLab](https://docs.gitlab.com/ce/user/profile/personal_access_tokens.html), [GitHub](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/) and [Bitbucket](https://confluence.atlassian.com/bitbucketserver/personal-access-tokens-939515499.html#Personalaccesstokens-Generatingpersonalaccesstokens) to find out how to do this.

## Installation
By default, the script looks for files with user credentials in a directory called `.clirepo` in your home directory. You can change the name and location of this directory by modifying the `credentials_dir` variable at the start of the script.

The easiest way to set everything up is to clone this repo into the default dir:

```
$ git clone URL_TO_THIS_REPO.git ~/.clirepo
```

Next, you need to create a file for user credentials for each service you want to use. Currently, the script supports remote repositories on Bitbucket, GitHub and GitLab. The files with credentials are named like the services, but using lower case characters and a leading dot, so e.g. `.gitlab` for the file for GitLab.

Templates for these three files are included in the `file_templates` directory in this repository. If you cloned the repo, you only need to copy the templates one level up into the main `.clirepo` directory, rename them from `.servicename.template` to `.servicename`, and fill in your own credentials.

You can also call the script with `-t` (and, optionally, a service name) to see the required formatting of the credentials:

```
$ .clirepo.sh -t bitbucket
```

Finally, you should set the permissions for these files so only your user can access them, e.g.:

```
$ chmod 600 .servicename
```

## More usage examples

If you cloned the repository as described above and did not move the actual script, it will sit inside `.clirepo` in your home directory. To call it from there to create a `myJSFramework` repository on bitbucket.org, you could use:

```
$ ~/.clirepo/clirepo.sh myJSFramework bitbucket
```

though you could also shorten the service's names to two letters (use `gh` for github, `gl` for gitlab, `bb` for bitbucket):

```
$ ~/.clirepo/clirepo.sh myJSFramework bb
```

---
You can also always use `-h` or `--help` for more information on how to use the script:
```
$ ./clirepo.sh -h
```

## Contributing
If you have ideas for how this script could be improved, gimme a shout. Depending on the motivation for and dimensions of any proposed changes, I might consider merging them into my script – or ask you to just fork it and adapt it to your own needs.

## Licence
This project is released under The MIT License.

- - -
<span xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/">This README was created using <span rel="dct:type" href="http://purl.org/dc/dcmitype/Text"><a property="dct:title" rel="cc:attributionURL" href="https://github.com/keikoro/README.template">README.template</a> by <span property="cc:attributionName">K Kollmann</span>, which is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by/4.0/">Creative Commons Attribution 4.0 International License</a>.</span>


