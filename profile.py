import geni.portal as portal
import geni.rspec.pg as rspec

request = rspec.Request()

# Optional OS image (Ubuntu 22.04)
portal.context.defineParameter(
    "os_image", "OS Image", portal.ParameterType.IMAGE,
    "urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD",
    longDescription="The operating system image to install on the node."
)

params = portal.context.bindParameters()

master_node = request.RawPC("k8s-master-node")

# Only set OS image
master_node.disk_image = params.os_image

# Run startup script
master_node.addService(rspec.Execute(
    shell="bash",
    command="/bin/bash /local/repository/startup.sh > /local/repository/startup.log 2>&1"
))

portal.context.printRequestRSpec(request)
