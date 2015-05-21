# RHEL-based MariaDB Docker image

## Building image

* Create RHEL7 VM on [AWS](https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2) and do SSH-login to it;
* Set up an entitlement for RHEL (mariadbenterprise/cUsh0Dip1Hej0Uf4Vap):

```
$ sudo subscription-manager register
$ sudo subscription-manager attach --pool=8a85f9814d0bf2ce014d3505ac3e52e2
$ sudo subscription-manager repos --enable=rhel-7-server-extras-rpms
$ subscription-manager repos --enable=rhel-7-server-optional-rpms
```

* Install prepequisites and start docker service:

```
$ sudo yum install docker git -y
$ sudo service docker start
```

* Clone [MariaDB docker repository](https://github.com/mariadb-corporation/mariadb-enterprise-docker) and build Docker image:

```
$ git clone https://github.com/mariadb-corporation/mariadb-enterprise-docker.git
$ cd mariadb-enterprise-docker/mdbe-rhel/
$ sudo docker build -t mdbe/mariadb-rhel .
```

* Start Docker container from the image

```
$ sudo -s
# c=$(docker run -d -v "$PWD"/mariadb-load-data:/var/lib/mariadb-load-data -v "$PWD"/var-lib-mariadb:/var/lib/mysql -v "$PWD"/mariadb-socket:/var/lib/mariadb-socket -e mariadb_random_root_password=1 -e mariadb_verbose_entry=1 mdbe/mariadb-rhel)
# pass=$(docker exec -t "$c" awk -F= '$1=="password"{pass=$2}END{print pass}' .my.cnf | tr -d '\r')
# TODO
```
