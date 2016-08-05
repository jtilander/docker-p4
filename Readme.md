# Docker Perforce Images

Perforce docker images inspired by Amit's [docker images](https://github.com/ambakshi/docker-perforce). The base images have all been switched to [baseimage docker](https://github.com/phusion/baseimage-docker) for proper zombie process handling and cron usage. 

## Installation

All operations on the images and repositories are encapsulated in the top level Makefile, which internally uses docker compose.

To install and run the full stack on your local computer, type:

    $ make [iterate]

To just build the images, simply type:

    $ make build



## Perforce Server Image

### Environment variables

|Name         |Default       |Notes                                          |
|-------------|--------------|-----------------------------------------------|
|NAME         |p4depot       |Name of the server, will be used as server id  |
|P4CONFIG     |.p4config     |                                               |
|P4ROOT       |/data/p4depot |Where to place the db files. Don't change      |
|P4PORT       |1666          |Optionally change to add SSL support           |
|P4USER       |p4admin       |Initial admin user name (local)                |
|CASE_INSENSITIVE|1          |Cause the server to boot with -C1              |
|ENABLE_AUTOCHECKPOINTS|1    |Cause a nightly cronjob take a checkpoint      |
|LDAPSERVER   |              |If set, will cause an ldap auth config to be configured|
|LDAPNAME     |simple        |simple / search bind strategy                  |
|LDAPBINDUSER |              |search requires a username                     |
|LDAPBINDPASSWD|             |search requires a password                     |
|LDAPSEARCHBASE|             |where in the ldap tree to search               |
|USE_GIT_FUSION|1            |Configure git fusion if this is an initial install|



### Volumes

There are two volumes /data and /library that should be mounted to the host. /data will hold all the database files and /library will hold the versioned library files. The idea is that you can optionally mount /library on a NAS (NFS) to allow for more space.

### Backups

Be sure to backup the directories that you mounted /data and /library on.



## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D


## Credits

- Jim Tilander (jim@tilander.org)
- Amit Bakshi (ambakshi@gmail.com)

## License

- [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0)
