FROM registry.access.redhat.com/rhel
MAINTAINER Kolbe Kegel <kolbe@mariadb.com>

USER root
COPY mariadb-enterprise.repo /etc/yum.repos.d/mariadb-enterprise.repo

# An empty mysql subdirectory is created in datadir to keep the RPM installer from running 
# mysql_install_db, but it's removed right away so that the entrypoint script knows to run 
# mysql_install_db. Initializing the datadir ahead of time would be needless and could cause 
# the image to contain InnoDB tablespace & log files (110M), which is surely unnecessary.
#
# The MySQL-server RPM also installs a whole bunch of enormous files that are of almost no
# use in most environments, so we ditch those to save about 150M in our final image.
#
# And finally clean the yum caches to save about 100M more.
#
RUN mkdir -p /var/lib/mariadb-socket /var/lib/mariadb-load-data /var/lib/mysql/mysql \
    && rpm --import https://downloads.mariadb.com/files/MariaDB/RPM-GPG-KEY-MariaDB-Ent \
    && yum update \
    && yum -y install MariaDB-server hostname \
    && rmdir /var/lib/mysql/mysql \
    && rm /usr/lib64/libmysqld.so* \
          /usr/lib64/mysql/plugin/ha_spider.so \
          /usr/lib64/mysql/plugin/ha_mroonga.so \
          /usr/lib64/mysql/plugin/ha_tokudb.so \
          /usr/lib64/mysql/plugin/ha_innodb.so \
    && yum clean all 

COPY bootstrap.cnf.docker /etc/my.cnf.d/
COPY docker.cnf /etc/my.cnf.d/
COPY docker-entry.bash /bin/docker-entry
COPY my_print_uidgid.bash /bin/my_print_uidgid
COPY my_wait_socket.bash /bin/my_wait_socket

RUN chmod 555 /bin/docker-entry /bin/my_print_uidgid /bin/my_wait_socket \
    && chown -R mysql:mysql /var/lib/mariadb-socket /var/lib/mariadb-load-data /var/lib/mysql

USER mysql
WORKDIR /var/lib/mysql

VOLUME /var/lib/mysql /var/lib/mariadb-socket /var/lib/mariadb-load-data
EXPOSE 3306

# the mysql client complains that TERM is not set
ENV TERM dumb

ENTRYPOINT ["/bin/docker-entry"]
