import geni.portal as portal
import geni.rspec.pg as rspec

request = rspec.Request()

# User can still select OS image if desired
portal.context.defineParameter(
    "os_image", "OS Image", portal.ParameterType.IMAGE,
    "urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD",
    longDescription="The OS image to install on the node."
)

params = portal.context.bindParameters()

master_node = request.RawPC("k8s-master-node")

# master_node.component_id = params.node_type   <-- removed

# ✔ Only set the OS image
master_node.disk_image = params.os_image

# Startup script
master_node.addService(rspec.Execute(
    shell="bash",
    command="/bin/bash /local/repository/startup.sh > /local/repository/startup.log 2>&1"
))

portal.context.printRequestRSpec(request)
