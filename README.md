# RHEL-based MariaDB Docker image

## Design decisions

I wanted to avoid the use of an environment variable to set the root password. It has several important security problems:
* The root password is part of the image's metadata forever
* The root password is in the environment of every process running on the container
* The root passwors is in the environment of every process running on a linked container
* Requires an administrator to generate a high-quality password

And of course the aesthetic problem that environment variables are ugly and upper-case ones even moreso.

My solution is instead to generate (by default) a random root password and allow only localhost connections. It's easy to retrieve and change the root password. 

I support several volumes in my Dockerfile:
* `/var/lib/mysql`
* `/var/lib/mariadb-socket`
* `/var/lib/mariadb-load-data`


## Building image

* Create RHEL7 VM on [AWS](https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2) and do SSH-login to it;
* Set up an entitlement for RHEL (get credentials from Kolbe):

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

## Running a container from the image

### Simple use case

```
$ sudo -i
# c=$(docker run -d mdbe/mariadb-rhel)
  (wait several seconds for the image to initialize)
# docker exec -ti "$c" mysql
```

### Complex use case

The image supports several environment variables (see docker-entry.bash for full details) and several mounted volumes (see Dockerfile for full details).

Note that to use external volumes, it seems that they must be owned by the same uid/gid as the process accessing them inside the container. This has strange results, since the uid/gid on the host may map to different users than in the container. For that reason, I provided a small script in the image to print the uid:gid of the "mysql" user inside the container. Invoke it by overriding the entrypoint of the image to be `print_mysql_uidgid`. The output of that script can then be used to adjust ownership of the volumes you want to mount. I include this in my example below.

Here's an example that uses all of the available volumes:
```
# vols=( mariadb-load-data mariadb-datadir mariadb-socket )
# mkdir -p "${vols[@]}"
# owner=$(docker run --rm --entrypoint=print_mysql_uidgid mdbe/mariadb-rhel)
# chown "$owner" "${vols[@]}"
# chcon -t svirt_sandbox_file_t "${vols[@]}"

# echo "1,a,2015-05-21" > mariadb-load-data/in.csv

# c=$(docker run -d -v "$PWD"/mariadb-load-data:/var/lib/mariadb-load-data -v "$PWD"/mariadb-datadir:/var/lib/mysql -v "$PWD"/mariadb-socket:/var/lib/mariadb-socket mdbe/mariadb-rhel)

# ls mariadb-datadir/
95f29b345719.pid       aria_log.00000001  ibdata1      ib_logfile1         mariadb-bin.000002  mariadb-bin.index  mysql               test
95f29b345719-slow.log  aria_log_control   ib_logfile0  mariadb-bin.000001  mariadb-bin.000003  multi-master.info  performance_schema

# pass=$(docker exec -t "$c" awk -F= '$1=="password"{pass=$2}END{print pass}' .my.cnf | tr -d '\r')

# /usr/bin/mysql -S mariadb-socket/mariadb.sock -u root -p"$pass" test
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 5
Server version: 10.0.17-MariaDB-enterprise-log MariaDB Enterprise Certified Binary

Copyright (c) 2000, 2015, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [test]> create table t1 (id serial, c varchar(32), d date);
Query OK, 0 rows affected (0.01 sec)

MariaDB [test]> load data infile '/var/lib/mariadb-load-data/in.csv' into table t1 fields terminated by ',';
Query OK, 1 row affected (0.00 sec)
Records: 1  Deleted: 0  Skipped: 0  Warnings: 0

MariaDB [test]> select * from t1;
+----+------+------------+
| id | c    | d          |
+----+------+------------+
|  1 | a    | 2015-05-21 |
+----+------+------------+
1 row in set (0.00 sec)

MariaDB [test]>
```

Notice that I'm actually storing the datadir on the *host*, not in a volume inside the guest. This directory could of course be on any kind of storage, such as an SSD used only for database storage. Conceivably, some container running XtraBackup would also be able to use the datadir volume to make backups.

The socket is in a directory by itself, which can also be mounted by other images. This would facilitate UNIX socket connections by other containers, which can simplify permissions and improve security, while also providing a performance benefit.

The `mariadb-load-data` directory is perhaps more of a novelty than anything else, but it could be mounted by some other container that needs to load data into the server.
