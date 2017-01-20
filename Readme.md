# Docker Perforce Images

Perforce docker images inspired by Amit's [docker images](https://github.com/ambakshi/docker-perforce). The base images have all been switched to [baseimage docker](https://github.com/phusion/baseimage-docker) for proper zombie process handling and cron usage. 


These images are also available on [docker hub](https://hub.docker.com/r/jtilander/)


## Usage

All operations on the images and repositories are encapsulated in the top level Makefile, which internally uses docker compose.

To install and run the full stack on your local computer, type:

    $ make [iterate]

To just build the images, simply type:

    $ make build


The docker compose file also uses external environment variables to configure itself, e.g. connecting to an LDAP server, so be sure to modify them if you need to.


### Customization

There are a number of customization points in the environment you can set to control both image building and runtime 

Runtime settings

| Variable       | Meaning                                              | Example             |
|----------------|------------------------------------------------------|---------------------|
| LDAPNAME       | Which ldap configuration to use                      | search              |
| LDAPSERVER     | Name of the LDAP server to connect to                | ldap.mycompany.com  |
| LDAPBINDUSER   | Connect to the LDAP server with this username        | myldapbind          |
| LDAPBINDPASSWD | Authenticate with the LDAP server using password     | secureforsure       |
| LDAPSEARCHBASE | LDAP search base                                     | dc=mycompany,dc=com |
| USE_GIT_FUSION | If "1", install Git Fusion triggers on intialization | 1                   |

Image settings

| Variable    | Meaning                    | Example                            |
|-------------|----------------------------|------------------------------------|
| DOCKER_REPO | Registry prefix for images | registry.mycompany.com/perforce    |
| TAG         | Tag to assign images       | latest                             |
| P4D_VERSION | Perforce server version    | 2016.2-1468155~trusty              |
| P4P_VERSION | Perforce proxy version     | 16.2                               |
| GF_VERSION  | Git Fusion version         | 2016.2-1398420~trusty              |


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


## References

  * https://github.com/phusion/baseimage-docker

