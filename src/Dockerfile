#
# Oracle Java 8 Dockerfile
#
# https://github.com/dockerfile/java
# https://github.com/dockerfile/java/tree/master/oracle-java8
#

# Pull base image.
# FROM ubuntu
FROM rigon/archlinux-jdk
RUN pacman-key --refresh-keys
RUN pacman --quiet --noconfirm -Syu
RUN pacman --quiet --noconfirm -S base-devel
RUN pacman --quiet --noconfirm -S openssh
RUN pacman --quiet --noconfirm -S nano emacs
RUN pacman --quiet --noconfirm -S tzdata
RUN pacman --quiet --noconfirm -S git

RUN \
  mkdir /root/.ssh/ && \
  touch /root/.ssh/known_hosts && \
  ssh-keyscan github.iu.edu >> /root/.ssh/known_hosts


# Define working directory.
WORKDIR /app

# Copy the current directory contents into the container at /app
ADD . /app

ADD id_rsa /root/.ssh/id_rsa

ADD id_rsa.pub /root/.ssh/id_rsa.pub

ENV TZ=America/New_York

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Define default command.
CMD ["bash", "/app/generate_reports.sh"]
