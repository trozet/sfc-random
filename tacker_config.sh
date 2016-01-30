#!/bin/env bash

# Script to install/configure tacker on an Apex deployment
# author: Tim Rozet (trozet@redhat.com)

SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)

instack_mac=$(virsh domiflist instack | grep default | \
                  grep -Eo "[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+:[0-9a-f\]+")
UNDERCLOUD=$(/usr/sbin/arp -e | grep ${instack_mac} | awk {'print $1'})

# get controller IP
node=$(ssh ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" "source stackrc; nova list | grep controller | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'")

# copy host key to instack
scp ${SSH_OPTIONS[@]} ~/.ssh/id_rsa.pub "stack@$UNDERCLOUD":jumphost_id_rsa.pub

# add host key to controller authorized keys
ssh -T ${SSH_OPTIONS[@]} "stack@$UNDERCLOUD" << EOI
cat ~/jumphost_id_rsa.pub | ssh -T ${SSH_OPTIONS[@]} "heat-admin@$node" 'cat >> ~/.ssh/authorized_keys'
EOI

ssh -T ${SSH_OPTIONS[@]} "heat-admin@$node" <<EOF
set -o errexit
sudo -i
/bin/bash -c "mount -o remount,inode64 /"
rm -rf python-tackerclient
git clone https://github.com/trozet/python-tackerclient.git -b SFC_refactor
pushd python-tackerclient
python setup.py build
python setup.py install
popd
# setup tacker
rm -rf tacker
git clone https://github.com/trozet/tacker.git -b SFC_brahmaputra
pushd tacker
python setup.py build
python setup.py install
rm -rf /etc/tacker
mv -f etc/tacker /etc/
chmod 755 /etc/tacker
rm -f /etc/init.d/tacker-server
mv -f init.d/tacker-server /etc/init.d/tacker-server
chmod 775 /etc/init.d/tacker-server
popd
# setup puppet-tacker
rm -rf puppet-tacker
git clone https://github.com/trozet/puppet-tacker.git
rm -rf /etc/puppet/modules/tacker
mv -f puppet-tacker/ /etc/puppet/modules/tacker
# find tacker values
auth_uri=\$(hiera heat::auth_uri)
identity_uri=\$(hiera heat::identity_uri)
database_connection="mysql://tacker:tacker@\$(hiera mysql_virtual_ip)/tacker"
rabbit_host=\$(hiera rabbitmq::node_ip_address)
rabbit_password=\$(hiera nova::rabbit_password)
sql_host=\$(hiera mysql_vip)
admin_url="http://\$(hiera keystone_admin_api_vip):8888/"
public_url="http://\$(hiera keystone_public_api_vip):8888/"
allowed_hosts="[\"%\", \"\$(hiera mysql_bind_host)\"]"

# setup local puppet module
cat > configure_tacker.pp << EOC
   class { 'tacker':
     package_ensure        => 'absent',
     client_package_ensure => 'absent',
     keystone_password     => 'tacker',
     keystone_tenant       => 'service',
     auth_uri              => '\${auth_uri}',
     identity_uri          => '\${identity_uri}',
     database_connection   => '\${database_connection}',
     rabbit_host           => '\${rabbit_host}',
     rabbit_password       => '\${rabbit_password}',
   }
   
   class { 'tacker::db::mysql':
       password      => 'tacker',
       host          => '\${sql_host}',
       allowed_hosts => \${allowed_hosts},
   } 
   
   class { 'tacker::keystone::auth':
     password            => 'tacker',
     tenant              => 'service',
     admin_url           => '\${admin_url}',
     internal_url        => '\${admin_url}',
     public_url          => '\${public_url}',
     region              => 'regionOne',
   }
EOC
# setup systemd service
cat > /usr/lib/systemd/system/openstack-tacker.service << EOC
[Unit]
Description=OpenStack Tacker Server
After=syslog.target network.target

[Service]
Type=notify
NotifyAccess=all
TimeoutStartSec=0
Restart=always
User=root
ExecStart=/usr/bin/tacker-server

[Install]
WantedBy=multi-user.target

EOC
chmod 644 /etc/systemd/system/multi-user.target.wants/openstack-tacker.service
systemctl daemon-reload

puppet apply configure_tacker.pp
EOF
