# YDBEncrypt

YDBEncrypt provides an encryption reference plugin for YottaDB.

# Installation

Before installing YDBEncrypt, you will need to install the prerequisite packages

Ubuntu or Debian Linux:
```
apt install -y git make gcc libgcrypt-dev libssl-dev libgpgme-dev libconfig-dev
```

Red Hat or Rocky Linux:
```
dnf install -y dnf-plugins-core
dnf config-manager --set-enabled powertools
dnf install -y git make gcc libgcrypt-devel openssl-devel gpgme-devel libconfig-devel
```

Since this is a plug-in for [YottaDB](https://gitlab.com/YottaDB/DB/YDB),
YottaDB is required to use YDBEncrypt.

YDBEncrypt can be installed while installing YottaDB by using the `--encplugin` command line option:

```sh
sudo ./ydbinstall.sh --encplugin
```

By default, `ydbinstall.sh` will build the current master branch of YottaDB.

YDBEncrypt can also be installed after YottaDB is installed by running `ydbinstall.sh` using the `--encplugin` and `--plugins-only` command line options.

```sh
sudo ./ydbinstall.sh --plugins-only --encplugin
```

If you have multiple YottaDB versions installed, make sure the environment variable `$ydb_dist` is set to the correct version before running `ydbinstall.sh` with the `--plugins-only` command line option.

To install YDBEncrypt without using `ydbinstall.sh`, you can build it from source with the following commands:

```sh
# Make sure that you have the ydb_dist & ydb_icu_version environment variables defined in your shell before continuing
make && sudo --preserve-env=ydb_dist,ydb_icu_version make install
```

## Contributing

To contribute or help with further development, [fork the repository](https://docs.gitlab.com/ee/gitlab-basics/fork-project.html), clone your fork to a local copy and begin contributing! Please also set up the pre-commit script to automatically enforce some coding conventions. Assuming you are in the top-level directory, the following will work:

```sh
ln -s ../../pre-commit .git/hooks
```

Note that this script requires `tcsh`.
