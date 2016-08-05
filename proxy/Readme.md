# Perforce Proxy image

This brings up a perforce proxy server with automatic pruning of disk space as well as optionally preloading the cache at periodic times.

You need to specify user / password / client for the preloading to work.

Preloading is by default on a 5 minute schedule.
Pruning is by default on a 10 minute schedule.


## Environment variables

|Name         |Default       |Notes                                          |
|-------------|--------------|-----------------------------------------------|
|P4TARGET     |perforce:1666 |The target server that will be cached          |
|CACHE_MAX_SIZE_MB|1048576   |Max size of the cache                          |
|CACHE_MAX_EMPTY_MB|51200    |If this amount of space is free already, skip prune|
|P4USER       |p4admin       |Preload cache with this user                   |
|P4PASSWD     |              |Preload cache with this password               |
|P4CLIENT     |              |Preload cache with this client, must have host to * and client root at /data/client|
|PARALLEL_SYNC|              |Set to max parallel syncs allowed when preloading|

## Volumes

There is a /data volume where all the data is stored on.

