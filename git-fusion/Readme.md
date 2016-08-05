# Perforce Git Fusion image

This initializes a new git fusion instance that connects to a server and installs itself for that one the first time run. Triggers needs to be installed on the server as well, see the server docker image on how to do that after the fact (see the use of $USE_GIT_FUSION).

By default this image also syncs the ssh keys once every minute from the main server onto this container (sync-keys.sh).

## Environment variables

|Name         |Default       |Notes                                          |
|-------------|--------------|-----------------------------------------------|
|NAME         |gf            |Name of the server, will be used as server id  |
|P4PORT       |1666          |location of the server                         |
|P4USER       |p4admin       |Admin user needed for setup                    |
|P4PASSWD     |              |Password for the admin user                    |

## Volumes

There is a /data volume where all the data is redirected to.
