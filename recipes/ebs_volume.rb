#
# Author:: Derek Kastner (<dkastner@gmail.com>)
# Cookbook Name:: solr_ec2
# Recipe:: ebs_volume
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if node[:ec2]
  include_recipe "aws"
  include_recipe "xfs"

  begin
    aws = Chef::DataBagItem.load(:aws, :main)
    Chef::Log.info("Loaded AWS information from DataBagItem aws[#{aws['id']}]")
  rescue
    Chef::Log.fatal("Could not find the 'main' item in the 'aws' data bag")
    raise
  end

  ebs_vol_dev = node['solr']['ebs_vol_dev']
  if (platform?("ubuntu") && node['platform_version'].to_f >= 11.04)
    ebs_vol_dev_mount =  ebs_vol_dev.sub(/^\/dev\/sd/, "/dev/xvd")
  else
    ebs_vol_dev_mount = ebs_vol_dev
  end
  ebs_vol_id = String.new
  db_type = String.new
  db_role = String.new
  master_role = String.new
  slave_role = String.new
  root_pw = String.new

  search(:apps) do |app|
    if (app["solr_master_role"] & node.run_list.roles).length == 1 || (app["solr_slave_role"] & node.run_list.roles).length == 1
      master_role = app["solr_master_role"] & node.run_list.roles
      slave_role = app["solr_slave_role"] & node.run_list.roles
      root_pw = app["solr_root_password"][node.chef_environment]

      if (master_role & node.run_list.roles).length == 1
        db_type = "master"
        db_role = RUBY_VERSION.to_f <= 1.8 ? master_role : master_role.join
      elsif (slave_role & node.run_list.roles).length == 1
        db_type = "slave"
        db_role = RUBY_VERSION.to_f <= 1.8 ? slave_role : slave_role.join
      end

      Chef::Log.info "solr::ebs_volume - db_role: #{db_role} db_type: #{db_type}"
    end
  end

  begin
    ebs_info = Chef::DataBagItem.load(:aws, "ebs_#{db_role}_#{node.chef_environment}")
    Chef::Log.info("Loaded #{ebs_info['volume_id']} from DataBagItem aws[#{ebs_info['id']}]")
  rescue
    Chef::Log.warn("Could not find the 'ebs_#{db_role}_#{node.chef_environment}' item in the 'aws' data bag")
    ebs_info = Hash.new
  end

  ruby_block "store_#{db_role}_#{node.chef_environment}_volid" do
    block do
      ebs_vol_id = node[:aws][:ebs_volume]["#{db_role}_#{node.chef_environment}"][:volume_id]

      unless ebs_info['volume_id']
        item = {
          "id" => "ebs_#{db_role}_#{node.chef_environment}",
          "volume_id" => ebs_vol_id
        }
        Chef::Log.info "Storing volume_id #{item.inspect}"
        databag_item = Chef::DataBagItem.new
        databag_item.data_bag("aws")
        databag_item.raw_data = item
        databag_item.save
        Chef::Log.info("Created #{item['id']} in #{databag_item.data_bag}")
      end
    end
    action :nothing
  end

  aws_ebs_volume "#{db_role}_#{node.chef_environment}" do
    aws_access_key aws['aws_access_key_id']
    aws_secret_access_key aws['aws_secret_access_key']
    size 50
    device ebs_vol_dev
    snapshots_to_keep 1
    case db_type
    when "master"
      if ebs_info['volume_id'] && ebs_info['volume_id'] =~ /vol/
        volume_id ebs_info['volume_id']
        action :attach
      elsif ebs_info['volume_id'] && ebs_info['volume_id'] =~ /snap/
        snapshot_id ebs_info['volume_id']
        action [ :create, :attach ]
      else
        action [ :create, :attach ]
      end
      notifies :create, resources(:ruby_block => "store_#{db_role}_#{node.chef_environment}_volid")
    when "slave"
      if master_info['volume_id']
        snapshot_id master_info['volume_id']
        action [:create, :attach]
      else
        Chef::Log.warn("Couldn't detect snapshot ID.")
        action :nothing
      end
    end
    provider "aws_ebs_volume"
  end

  %w{ec2_path data}.each do |dir|
    directory node['solr'][dir] do
      mode 0755
    end
  end

  mount node['solr']['ec2_path'] do
    device ebs_vol_dev_mount
    fstype "xfs"
    action :mount
  end

  mount node['solr']['data'] do
    device node['solr']['ec2_path']
    fstype "none"
    options "bind,rw"
    action :mount
  end
end
