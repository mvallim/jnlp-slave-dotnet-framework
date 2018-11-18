# Jenkins JNLP Slaves as Windows Container

[![](https://ci.appveyor.com/api/projects/status/vmr2c3al8i4jtis4?svg=true)](https://ci.appveyor.com/api/projects/status/vmr2c3al8i4jtis4?svg=true) [![](https://img.shields.io/docker/pulls/mvallim/jnlp-slave-dotnet-framework.svg)](https://img.shields.io/docker/pulls/mvallim/jnlp-slave-dotnet-framework.svg) [![](https://img.shields.io/docker/stars/mvallim/jnlp-slave-dotnet-framework.svg)](https://img.shields.io/docker/stars/mvallim/jnlp-slave-dotnet-framework.svg)

This is a base image for Jenkins agent (FKA "slave") on Windows using JNLP to establish connection.

This container contains:

* Microsoft SQL Server 2014 (SP2) (KB3171021) - 12.0.5000.0
* Git - 2.19.1
* Java 8 - OpenJDK
* .Net Framework - 4.7.2 SDK
* MSBuild - 15.9.20.62856
* NuGet - 4.4.1

This agent is powered by the Jenkins Remoting library, taken from their [artifacts repository](https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/).

For correct agent version see the [Remoting Sub-Project](https://github.com/jenkinsci/remoting/blob/master/CHANGELOG.md) for more info.

See [Jenkins Distributed builds](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds) for more info.

## Running

To run a Docker container

```
docker run mvallim/jnlp-slave-dotnet-framework -url http://jenkins-server:port <secret> <agent name>
```


*Optional environment variables:*

* JENKINS_URL: url for the Jenkins server, can be used as a replacement to -url option, or to set alternate jenkins URL
* JENKINS_TUNNEL: (HOST:PORT) connect to this agent host and port instead of Jenkins server, assuming this one do route TCP traffic to Jenkins master. Useful when when Jenkins runs behind a load balancer, reverse proxy, etc.
* JENKINS_SECRET: agent secret, if not set as an argument
* JENKINS_AGENT_NAME: agent name, if not set as an argument

## Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue](https://github.com/mvallim/jnlp-slave-dotnet-framework).

## Contributing

You are invited to contribute new features, fixes, or updates, large or small via pull requests, and I'll do my best to process them as fast as I can.
