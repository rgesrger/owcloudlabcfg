import geni.portal as portal
import geni.rspec.pg as rspec

# Create the request
request = rspec.Request()

# Hardware selection (optional)
portal.context.defineParameter(
    "node_type",
    "Hardware Type",
    portal.ParameterType.NODETYPE,
    "",
    longDescription="Choose a specific node type, or leave empty to let CloudLab choose automatically."
)

# OS image selection
portal.context.defineParameter(
    "os_image",
    "OS Image",
    portal.ParameterType.IMAGE,
    "urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD",
    longDescription="Operating system image to install on the node."
)

params = portal.context.bindParameters()

# Create the node
master_node = request.RawPC("k8s-master-node")

# Only set hardware type if the user selected one
if params.node_type and params.node_type.strip() != "":
    master_node.component_id = params.node_type

# Set OS image
master_node.disk_image = params.os_image

# Run startup script at boot
master_node.addService(rspec.Execute(
    shell="bash",
    command="/bin/bash /local/repository/startup.sh > /local/repository/startup.log 2>&1"
))

# Output the RSpec
portal.context.printRequestRSpec(request)
