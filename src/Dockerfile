#
# Oracle Java 8 Dockerfile
#
# https://github.com/dockerfile/java
# https://github.com/dockerfile/java/tree/master/oracle-java8
#

# Pull base image.
# FROM openjdk/8-jdk
 FROM ubuntu

# Install Java.
RUN \
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  apt-get update && \
  apt-get install -y software-properties-common keychain git nano tzdata && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java8-installer && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk8-installer

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

# Define commonly used JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# Define default command.
CMD ["bash", "/app/generate_reports.sh"]
