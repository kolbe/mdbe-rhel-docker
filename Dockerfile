FROM registry.access.redhat.com/rhel
MAINTAINER Kolbe Kegel <kolbe@mariadb.com>

USER root
COPY mariadb-enterprise.repo /etc/yum.repos.d/mariadb-enterprise.repo
COPY bootstrap.cnf.docker /etc/my.cnf.d/
COPY docker.cnf /etc/my.cnf.d/
COPY docker-entry.bash /bin/docker-entry

# RUN all the things together so only one layer is made. This can save a lot of disk space
# for the image as a whole. Even still, the install process is kind of convoluted. An empty
# mysql subdirectory is created in datadir to keep the RPM installer from running mysql_install_db,
# but it's removed right away so that the entrypoint script knows to run mysql_install_db.
# Initializing the datadir ahead of time would be needless and could cause the image to contain
# InnoDB tablespace & log files, which is surely unnecessary.
#
RUN rpm --import https://downloads.mariadb.com/files/MariaDB/RPM-GPG-KEY-MariaDB-Ent \
    && chmod 555 /bin/docker-entry \
    && mkdir -p /var/lib/mariadb-socket /var/lib/mariadb-load-data /var/lib/mysql/mysql \
    && yum -y install MariaDB-server hostname \
    && rmdir /var/lib/mysql/mysql \
    && chown -R mysql:mysql /var/lib/mariadb-socket /var/lib/mariadb-load-data /var/lib/mysql \
    && rm /usr/lib64/libmysqld.so* \
    && yum clean all 

USER mysql
WORKDIR /var/lib/mysql

VOLUME /var/lib/mysql /var/lib/mariadb-socket /var/lib/mariadb-load-data
EXPOSE 3306

# the mysql client complains that TERM is not set
ENV TERM dumb

ENTRYPOINT ["/bin/docker-entry"]
