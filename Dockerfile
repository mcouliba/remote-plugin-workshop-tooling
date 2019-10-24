# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

FROM eclipse/che-theia-endpoint-runtime:7.3.0

ENV GLIBC_VERSION=2.29-r0 \
    ODO_VERSION=v1.0.0-beta6 \
    OC_VERSION=4.2 \
    KUBECTL_VERSION=v1.14.6 \
    SQUASHCTL_VERSION=v0.5.12 \
    TKN_VERSION=0.4.0 \
    MAVEN_VERSION=3.6.2 \
    JDK_VERSION=11 \
    SIEGE_VERSION=3.1.4

# the plugin executes the commands relying on Bash
RUN apk add --no-cache bash curl && \
    # install glibc compatibility layer package for Alpine Linux
    # see https://github.com/openshift/origin/issues/18942 for the details
    wget -O glibc-${GLIBC_VERSION}.apk https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk && \
    apk --update --allow-untrusted add glibc-${GLIBC_VERSION}.apk && \
    rm -f glibc-${GLIBC_VERSION}.apk && \
    # install odo
    wget -O /usr/local/bin/odo https://github.com/openshift/odo/releases/download/${ODO_VERSION}/odo-linux-amd64 && \
    chmod +x /usr/local/bin/odo && \
    odo version && \
    # install oc
    wget -qO- https://mirror.openshift.com/pub/openshift-v4/clients/oc/${OC_VERSION}/linux/oc.tar.gz | tar xvz -C /usr/local/bin && \
    oc version && \
    # CA certificates
    apk --update --allow-untrusted add ca-certificates && rm -rf /var/cache/apk/*

# install squashctl
RUN wget -qO /usr/local/bin/squashctl https://github.com/solo-io/squash/releases/download/${SQUASHCTL_VERSION}/squashctl-linux && \
    chmod +x /usr/local/bin/squashctl

# install kubectl
ADD https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl && \
    kubectl version --client

# install tekton
RUN mkdir ${HOME}/.vs-tekton && \
    wget -qO- "https://github.com/tektoncd/cli/releases/download/v${TKN_VERSION}/tkn_${TKN_VERSION}_Linux_x86_64.tar.gz" | tar xvz -C /usr/local/bin && \
    ln -s /usr/local/bin/tkn ${HOME}/.vs-tekton/tkn && \
    tkn version

# install openjdk
RUN apk --no-cache add openjdk${JDK_VERSION} --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community && \
    apk add procps nss && \
    chmod 777 /home/theia && \
    find /usr/share/ca-certificates/mozilla/ -name "*.crt" -exec keytool -import -trustcacerts \
    -keystore /usr/lib/jvm/java-${JDK_VERSION}-openjdk/jre/lib/security/cacerts  -storepass changeit -noprompt \
    -file {} -alias {} \; && \
    keytool -list -keystore /usr/lib/jvm/java-${JDK_VERSION}-openjdk/jre/lib/security/cacerts  --storepass changeit
ENV JAVA_HOME /usr/lib/jvm/default-jvm/

# install maven
ENV MAVEN_HOME /usr/lib/mvn
ENV PATH $MAVEN_HOME/bin:$PATH

RUN wget http://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
  tar -zxvf apache-maven-$MAVEN_VERSION-bin.tar.gz && \
  rm apache-maven-$MAVEN_VERSION-bin.tar.gz && \
  mv apache-maven-$MAVEN_VERSION /usr/lib/mvn
ADD etc/before-start.sh /before-start.sh

# install git
RUN apk add --no-cache git openssh

# install httperf
RUN apk add --update --no-cache --virtual=.build-dependencies \
            # unzip \
            # libtool \
            # build-base \
            autoconf \
            automake \
            make && \
    wget https://github.com/rtCamp/httperf/archive/master.zip && \
    unzip master.zip && \
    mkdir /usr/src/httperf-master/build && \
    cd httperf-master && \
    autoreconf -i && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf httperf-master /usr/src/master.zip && \
    apk del .build-dependencies

WORKDIR /projects
