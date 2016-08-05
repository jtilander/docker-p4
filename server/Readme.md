# Perforce Server Image

This contains a full setup for the core perforce server. The defaults are geared towards an install serving windows users in a LDAP configuration.

It also have by default a checkpoint running each night. This can on larger installations cause locks in the db, so this should be avoided for those. Setting up a replica or a read only server and taking checkpoints on them instead could increase avaliability.

## LDAP

You can control who can auto create a user by adding the usernames to the group p4users. If the user who is trying to login exists there, they will automatically create and pull down information from AD. Otherwise they will be denied login.

Note that I've never got the SASL method to actually work with auto population of information from LDAP. Search method is probably slower on most AD installations.

## Environment variables

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


## Volumes

There are two volumes /data and /library that should be mounted to the host. /data will hold all the database files and /library will hold the versioned library files. The idea is that you can optionally mount /library on a NAS (NFS) to allow for more space.

## Backups

Be sure to backup the directories that you mounted /data and /library on.

