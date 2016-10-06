#!/usr/bin/env bash

#network setup not needed in devstack
#openstack network create  net_mgmt --provider:network_type=vxlan --provider:segmentation_id 1005
#openstack subnet create --network net_mgmt --subnet-range 123.123.123.0/24 test
cat > test.yaml << EOI
tosca_definitions_version: tosca_simple_profile_for_nfv_1_0_0
description: Demo example

metadata:
 template_name: sample-tosca-vnfd

topology_template:
  node_templates:
    VDU1:
      type: tosca.nodes.nfv.VDU.Tacker
      capabilities:
        nfv_compute:
          properties:
            disk_size: 1 GB
            mem_size: 512 MB
            num_cpus: 2
      properties:
        image: cirros-0.3.4-x86_64-uec
        mgmt_driver: noop
        availability_zone: nova

    CP1:
      type: tosca.nodes.nfv.CP.Tacker
      properties:
        management: true
        anti_spoofing_protection: false
      requirements:
        - virtualLink:
            node: VL1
        - virtualBinding:
            node: VDU1

    VL1:
      type: tosca.nodes.nfv.VL
      properties:
        network_name: net_mgmt
        vendor: Tacker

EOI

tacker vnfd-create --vnfd-file ./test.yaml VNFD1
tacker vnf-create testVNF1 --vnfd-name VNFD1
#wget https://www.dropbox.com/s/focu44sh52li7fz/sfc_cloud.qcow2
#openstack image create sfc --public --file ./sfc_cloud.qcow2 --disk-format qcow2
#openstack flavor create custom --ram 1000 --disk 5 --public

net_mgmt_id=$(openstack network list | grep net_mgmt | awk '{print $2}')
openstack server create --flavor m1.tiny --image cirros-0.3.4-x86_64-uec --nic net-id=$net_mgmt_id http_client
openstack server create --flavor m1.tiny --image cirros-0.3.4-x86_64-uec --nic net-id=$net_mgmt_id http_server
openstack security group rule create --egress default --protocol icmp
openstack security group rule create --ingress default --protocol icmp
openstack security group rule create --egress default
openstack security group rule create --ingress default

client_ip=$(nova list | grep http_client | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
client_port_id=$(openstack port list | grep $client_ip | awk '{print $2}')

cat > vnffgd.yaml << EOI
tosca_definitions_version: tosca_simple_profile_for_nfv_1_0_0

description: Sample VNFFG template

topology_template:
  description: Sample VNFFG template

  node_templates:

    Forwarding_path1:
      type: tosca.nodes.nfv.FP.Tacker
      description: creates path (CP12->CP22)
      properties:
        id: 51
        policy:
          type: ACL
          criteria:
            - network_src_port_id: ${client_port_id}
            - ip_proto: 1
        path:
          - forwarder: VNFD1
            capability: CP1

  groups:
    VNFFG1:
      type: tosca.groups.nfv.VNFFG
      description: HTTP to Corporate Net
      properties:
        vendor: tacker
        version: 1.0
        number_of_endpoints: 5
        dependent_virtual_link: [VL1]
        connection_point: [CP1]
        constituent_vnfs: [VNFD1]
      members: [Forwarding_path1]
EOI

tacker vnffgd-create --vnffgd-file vnffgd.yaml  test
tacker vnffg-create --vnffgd-name test myvnffg

