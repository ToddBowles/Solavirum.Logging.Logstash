# README #

### What is this repository for? ###

This repository creates packages for Logstash that are deployable through Octopus. Logstash is installed as a Windows service via NSSM.

It is intended to be used with specific projects in Octopus which set the configuration that should be used (for example, LOGSTASH_Default). The configurations are defined in the src/configuration folder. A configuration is selected based on the name of the project in Octopus (the bit after LOGSTASH_).

A good place to start looking is the Deploy.ps1 script inside the /src directory. It gets executed when the package is deployed via Octopus.

### How do I get set up? ###

Building is easy. /scripts/build contains a script that can be used to build and optionally deploy the package to multiple projects in Octopus.