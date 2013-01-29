Solr EC2 Cookbook
=================

Use an EBS volume for solr data.

Requirements
============

Chef version 0.10.10+.

Platform
--------

* Debian, Ubuntu
* Red Hat, CentOS, Scientific, Fedora, Amazon

Cookbooks
---------

The following cookbooks are dependencies:

* solr
* xfs
* aws

Recipes
=======

ebs\_volume
-----------

Loads the aws information from the data bag. Searches the applications
data bag for the solr master or slave role and checks that role is
applied to the node. Loads the EBS information and the master
information from data bags. Uses the aws cookbook LWRP,
`aws_ebs_volume` to manage the volume.

On a master node:
* if we have an ebs volume already as stored in a data bag, attach it.
* if we don't have the ebs information then create a new one and
  attach it.
* store the volume information in a data bag via a ruby block.

On a slave node:
* use the master volume information to generate a snapshot.
* create the new volume from the snapshot and attach it.

Also on a master node, generate some configuration for running a
snapshot via `chef-solo` from cron.

On a new filesystem volume, create as XFS, then mount it in /mnt, and
also bind-mount it to the mysql data directory (default
/var/lib/mysql).

master
------

This recipe no longer loads AWS specific information, and the solr
position for replication is no longer stored in a databag because the
client might not have permission to write to the databag item. This
may be handled in a different way at a future date.

Searches the apps databag for applications, and for each one it will
check that the specified solr master role is set in both the
databag and applied to the node's run list. Then, retrieves the
passwords for `root`, `repl` and `debian` users and saves them to the
node attributes. If the passwords are not found in the databag, it
prints a message that they'll be generated by the mysql cookbook.

Then it adds the application databag solr settings to a hash, to
use later.

License and Author
==================

- Author:: Derek Kastner (<dkastner@gmail.com>)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.