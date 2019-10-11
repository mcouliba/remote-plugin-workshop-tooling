# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

FROM eclipse/che-theia-endpoint-runtime:7.2.0

ENV GLIBC_VERSION=2.29-r0 \
    ODO_VERSION=v1.0.0-beta6 \
    OC_VERSION=4.2 \
    KUBECTL_VERSION=v1.14.6 \
    SQUASHCTL_VERSION=v0.5.12

# the plugin executes the commands relying on Bash
RUN apk add --no-cache bash && \
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
RUN sudo chmod +x /usr/local/bin/kubectl && \
    kubectl version --client

# install maven/openjdk11
RUN apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
    && apk add procps nss \
    && chmod 777 /home/theia
ENV JAVA_HOME /usr/lib/jvm/default-jvm/
ADD etc/before-start.sh /before-start.sh

WORKDIR /projects