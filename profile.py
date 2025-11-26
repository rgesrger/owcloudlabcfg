import geni.portal as portal
import geni.rspec.pg as rspec

request = rspec.Request()

# Chooses the hardware class
portal.context.defineParameter(
    "node_type", "Node Type", portal.ParameterType.NODETYPE,
    "m510",
    longDescription="Type of machine to provision for the Control Plane (e.g., c6220, m510, xl170)."
)

# Chooses the OS image (currently ubuntu 22.04)
portal.context.defineParameter(
    "os_image", "OS Image", portal.ParameterType.IMAGE,
    "urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD",
    longDescription="The operating system image to install on the node. Ubuntu 22.04 recommended."
)

params = portal.context.bindParameters()

master_node = request.RawPC("k8s-master-node")
master_node.component_id = params.node_type
master_node.disk_image = params.os_image

# Execute startup.sh at boot from the profile repository that CloudLab mounts at /local/repository
master_node.addService(rspec.Execute(
    shell="bash",
    command="/bin/bash /local/repository/startup.sh > /local/repository/startup.log 2>&1"
))

portal.context.printRequestRSpec(request)
