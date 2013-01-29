name             "solr_ec2"
maintainer       "Derek Kastner"
maintainer_email "dkastner@gmail.com"
license          "Apache 2.0"
description      "Sets up the solr master or slave"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.0.1"

recipe "solr_ec2", "Empty placeholder"
recipe "solr_ec2::ebs_volume", "Sets up an EBS volume in EC2 for the database"

depends "solr"
depends "aws"
depends "xfs"

%w{ debian ubuntu centos suse fedora redhat scientific amazon }.each do |os|
  supports os
end
