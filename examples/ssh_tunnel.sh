#!/bin/sh

## This is what a simple SSH tunnel might look like.
##
## SSH is a pretty convenient poor man's VPN, providing a secure
## way to talk to a remote ZMQ socket that is only bound to localhost.
##
## This example will let a local subscribe_time.pl 
## talk to a remote publish_time.pl ->

user=avenj
endpoint=eris
localport=5511
remoteport=5511

ssh -f ${user}@${endpoint} \
	-L localhost:${localport}:127.0.0.1:${remoteport} \
	-N
