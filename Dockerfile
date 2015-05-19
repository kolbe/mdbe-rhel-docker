FROM registry.access.redhat.com/rhel
MAINTAINER Kolbe Kegel <kolbe@mariadb.com>

USER root
COPY mariadb-enterprise.repo /etc/yum.repos.d/mariadb-enterprise.repo
RUN rpm --import https://downloads.mariadb.com/files/MariaDB/RPM-GPG-KEY-MariaDB-Ent
RUN yum -y install MariaDB-server

COPY bootstrap.cnf.docker /etc/my.cnf.d/bootstrap.cnf.docker
RUN printf %s\\n \
"delete from mysql.user where user <> 'root';" \
"delete from mysql.user where host <> 'localhost';" \
"insert into mysql.plugin values ('SEQUENCE', 'ha_sequence.so');" \
| mysqld --defaults-extra-file=/etc/my.cnf.d/bootstrap.cnf.docker

# the mysql client complains that TERM is not set
ENV TERM dumb

VOLUME /var/lib/mysql

# COPY docker.cnf /etc/my.cnf.d/docker.cnf
COPY docker-entry.bash /bin/docker-entry
RUN chmod 555 /bin/docker-entry

EXPOSE 3306

USER mysql
ENTRYPOINT ["/bin/docker-entry"]
