FROM registry.access.redhat.com/ubi8-minimal:8.1-407

ENV HOME=/home/theia

RUN mkdir /projects ${HOME}

ENV GLIBC_VERSION=2.30-r0 \
    ODO_VERSION=v2.0.0 \
    OC_VERSION=4.5 \
    KUBECTL_VERSION=v1.19.3 \
    TKN_VERSION=0.13.0 \
    MAVEN_VERSION=3.6.3 \
    JDK_VERSION=11 \
    YQ_VERSION=2.4.1 \
    ARGOCD_VERSION=v1.7.7 \
    IKE_VERSION=0.0.3 \
    GRAALVM_VERSION=20.0.0 \
    JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true"

RUN microdnf install -y \
        bash curl wget tar gzip java-${JDK_VERSION}-openjdk-devel git openssh which httpd python36 procps && \
    microdnf -y clean all && rm -rf /var/cache/yum && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages"

# install oc
RUN wget -qO- https://mirror.openshift.com/pub/openshift-v4/clients/oc/${OC_VERSION}/linux/oc.tar.gz | tar xvz -C /usr/local/bin && \
    oc version --client

# install odo
# RUN wget -O /usr/local/bin/odo https://mirror.openshift.com/pub/openshift-v4/clients/odo/${ODO_VERSION}/odo-linux-amd64 && \
#     chmod +x /usr/local/bin/odo && \
#     odo version --client

# Using a specific version of odo integrating PR and PR
ADD tools/custom-odo-linux-amd64.tar.gz .
RUN tar -zxvf custom-odo-linux-amd64.tar.gz && \
    rm custom-odo-linux-amd64.tar.gz && \
    mv odo /usr/local/bin && \
    odo version --client

# install kubectl
ADD https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl && \
    kubectl version --client

# install tekton
RUN mkdir ${HOME}/.vs-tekton && \
    wget -qO- https://github.com/tektoncd/cli/releases/download/v${TKN_VERSION}/tkn_${TKN_VERSION}_Linux_x86_64.tar.gz | tar xvz -C /usr/local/bin && \
    ln -s /usr/local/bin/tkn ${HOME}/.vs-tekton/tkn && \
    tkn version

#install GraalVM
ENV GRAALVM_HOME /usr/lib/graalvm
ENV PATH ${GRAALVM_HOME}/bin:$PATH
RUN wget https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${GRAALVM_VERSION}/graalvm-ce-java${JDK_VERSION}-linux-amd64-${GRAALVM_VERSION}.tar.gz && \
    tar -zxvf graalvm-ce-java${JDK_VERSION}-linux-amd64-${GRAALVM_VERSION}.tar.gz && \
    rm graalvm-ce-java${JDK_VERSION}-linux-amd64-${GRAALVM_VERSION}.tar.gz && \
    mv graalvm-ce-java${JDK_VERSION}-${GRAALVM_VERSION} /usr/lib/graalvm

# install yq
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

# install argocd
RUN wget -qO /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64 && \
    chmod +x /usr/local/bin/argocd

# install maven
ENV MAVEN_HOME /usr/lib/mvn
ENV PATH ${MAVEN_HOME}/bin:$PATH

RUN wget http://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
  tar -zxvf apache-maven-$MAVEN_VERSION-bin.tar.gz && \
  rm apache-maven-$MAVEN_VERSION-bin.tar.gz && \
  mv apache-maven-$MAVEN_VERSION /usr/lib/mvn
ADD etc/before-start.sh /before-start.sh

# install telepresence
ENV TELEPRESENCE_VERSION=0.104
RUN git clone https://github.com/telepresenceio/telepresence.git && \
    cd telepresence && PREFIX=/usr/local ./install.sh && \
    echo "Installed Telepresence"

RUN rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    microdnf install -y sshfs && \
    rpm -e epel-release-7-12 && \
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    microdnf install -y torsocks && \
    rpm -e epel-release-8-8.el8 && \
    microdnf clean all -y && \
    echo "Installed Telepresence Dependencies"

# install ike
RUN curl -sL http://git.io/get-ike | bash -s  -- --version=v${IKE_VERSION} --dir=/usr/local/bin && \
    echo "Installed istio-workspace" && \
    ike version

# Configure Java
ENV JAVA_HOME ${GRAALVM_HOME}

WORKDIR /projects

ADD etc/entrypoint.sh /entrypoint.sh

# Change permissions to let any arbitrary user
RUN for f in "${HOME}" "/etc/passwd" "/projects"; do \
      echo "Changing permissions on ${f}" && chgrp -R 0 ${f} && \
      chmod -R g+rwX ${f}; \
    done

ENTRYPOINT [ "/entrypoint.sh" ]
CMD ${PLUGIN_REMOTE_ENDPOINT_EXECUTABLE}
