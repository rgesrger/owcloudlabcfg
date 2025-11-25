"""
CloudLab Profile Manifest (Geni-Lib) for Kubernetes Master and OpenWhisk Deployment.

This script defines a single RawPC node and specifies the command to execute 
the 'startup.sh' file upon boot, automating the entire setup process.

NOTE: This script assumes you have uploaded 'startup.sh', 'kubernetes.sh', and 
'openwhisk.sh' into the Profile File Repository.
"""

import geni.portal as portal
import geni.rspec.pg as rspec

# Create a Request object
request = rspec.Request()

# --- 1. Define User Parameters ---
portal.context.defineParameter(
    "node_type", "Node Type", portal.ParameterType.NODETYPE,
    "m510",
    longDescription="Type of machine to provision for the Control Plane (e.g., c6220, m510, xl170). The larger the machine, the better the performance."
)
portal.context.defineParameter(
    "os_image", "OS Image", portal.ParameterType.IMAGE,
    "urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU22-64-STD",
    longDescription="The operating system image to install on the node. Ubuntu 22.04 is required for the scripts to run correctly."
)

# Fetch parameter values
params = portal.context.bindParameters()

# --- 2. Define the Master Node ---
# We define one node to act as the Control Plane and Worker (Master-Worker setup)
master_node = request.RawPC("k8s-master-node")
# Set the hardware type based on user selection
master_node.component_id = params.node_type
# Set the OS image based on user selection
master_node.disk_image = params.os_image

# --- 3. CRITICAL: Define the Automatic Startup Command (The Execution Trigger) ---
# This tells the node's OS to run your setup script located in the profile repository.
# CloudLab mounts the repository files at /local/repository.
master_node.addService(rspec.Execute(
    # Use sh shell for execution
    shell="sh",
    # Command to run the /local/repository/startup.sh script using bash
    # This single command launches the entire K8s/OpenWhisk pipeline.
    command="/bin/bash /local/repository/startup.sh"
))

# Print the RSpec to the console (This is mandatory for CloudLab to accept the profile)
portal.context.printRequestRSpec(request)