# clirepo
A Bash script to create remote repositories from the command line.

## Background
If you use Git a lot, and only from the command line, having to switch to a browser and go online to create new repositories on code sharing and collaboration websites like GitHub, GitLab and Bitbucket can be inconvenient.

By accessing the APIs for these services with personal access tokens, you can, however, easily create new remote repositories directly from your terminal.

## Usage example
To create a new, private repository called `neato_proj` on GitHub using this script, you would use the following command:

```
$ ./clirepo.sh neato_proj github
```

On success, or even when your repository already exists, handy URLs pointing to it will get printed out to the console:

```
About to create repository 'neato_proj', standing by...

SUCCESS! Repository 'neato_proj' was created on GitHub.
Visit it on the web: https://github.com/youraccount/neato_proj

Add it as a remote:
git remote add github https://github.com/youraccount/neato_proj.git
git remote add github git@github.com:youraccount/neato_proj.git
```

## Requirements
You need to have Bash installed on your machine for this script to work, though it does not have to be your main shell (it isn't mine either).

You will also have to have created personal access tokens for the services you want to use, which you can do in the user settings. GitHub and GitLab call them exactly that, Personal Access Tokens, whereas Bitbucket refers to them as App Passwords.

## Setup
The `.clirepo.sh` script is dependent on the presence of a file called `.conf`, which can be used to provide user-specific settings. You can base it off of `.conf.template`, which is included with this project.

When run, the script looks for your user credentials in a directory called `credentials`. By default, this directory is expected to be located within the `.clirepo` directory, for which the script looks in your user's home directory (i.e. at `/home/YOUR_USER/.clirepo/credentials`).

You can change the name and location of the credentials directory by modifying the `credentials_dir` variable in the aforementioned `.conf` file. The easiest way to set everything up is to clone this repository to where it is expected to be out of the box:

```
$ git clone URL_TO_THIS_REPO.git ~/.clirepo
```
Next, you need to create files to hold your user credentials for all the services you want to use. Currently, the script supports remote repositories on Bitbucket, GitHub and GitLab. The credentials files are named like the services, with a leading dot and lowercased, so e.g. `.gitlab` for the file for GitLab.

Templates for the credentials files are included in the `credentials` directory. However, you can also call the script with the argument `-t` (and, optionally, a service name) to see how they need to be formatted:

```
$ .clirepo.sh -t bitbucket
```

Finally, you should set the permissions for these files so only your user can access them, e.g.:

```
$ chmod 600 .servicename
```

**IMPORTANT NOTE**  
Please note that this script currently does not support the handling of encrypted credentials, nor are the credentials files safeguarded in any way other than via file permissions for whose setting you yourself are responsible.

### Default config

To save time typing, you can use the alternative aliases `gh` for `github`, `gl` for `gitlab` and `bb` for `bitbucket` to refer to the services. If you provide your own aliases, these defaults are overwritten.


## More usage examples

If you cloned the repository as described above, it will sit inside `.clirepo` in your home directory. To call it to create a private `myJSFramework` repository on `bitbucket.org`, you would use:

```
$ ~/.clirepo/clirepo.sh myJSFramework bitbucket
```

You could also use the default alias `bb` to do the same thing:

```
$ ~/.clirepo/clirepo.sh myJSFramework bb
```

Note that all repositories created with this script are **set to private by default**. You can, however, use `public` as third argument to make them public on creation:

```
$ ~/.clirepo/clirepo.sh myJSFramework bb public
```

`-h` or `--help` prints out usage hints to the console:
```
$ ./clirepo.sh -h
```

## Contributing
If you have ideas for how this script could be improved, let me know via the issue tracker.

## Licence
This project is released under The MIT License.


