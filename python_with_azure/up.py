from azure.identity import ClientSecretCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.compute import ComputeManagementClient
import os

# Configuration
SUBSCRIPTION_ID = os.getenv("AZURE_SUBSCRIPTION_ID")
CLIENT_ID = os.getenv("AZURE_CLIENT_ID")
CLIENT_SECRET = os.getenv("AZURE_CLIENT_SECRET")
TENANT_ID = os.getenv("AZURE_TENANT_ID")

# Validate environment variables
for var in ["AZURE_SUBSCRIPTION_ID", "AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET", "AZURE_TENANT_ID"]:
    if not os.getenv(var):
        raise ValueError(f"Environment variable {var} not set.")
    
PREFIX = "OmerDevops"
LOCATION = "East US"
SSH_PUBLIC_KEY_PATH = os.path.expanduser("~/.ssh/id_rsa.pub")
 
# Initialize credential with service principal
credential = ClientSecretCredential(
    tenant_id=TENANT_ID,
    client_id=CLIENT_ID,
    client_secret=CLIENT_SECRET
)

# Initialize clients
resource_client = ResourceManagementClient(credential, SUBSCRIPTION_ID)
network_client = NetworkManagementClient(credential, SUBSCRIPTION_ID)
compute_client = ComputeManagementClient(credential, SUBSCRIPTION_ID)

# Create Resource Group
rg_params = {"location": LOCATION}
resource_client.resource_groups.create_or_update(f"{PREFIX}-rg", rg_params)
print("Resource Group created.")

# Create Virtual Network
vnet_params = {
    "location": LOCATION,
    "address_space": {"address_prefixes": ["10.0.0.0/16"]}
}
vnet_result = network_client.virtual_networks.begin_create_or_update(
    f"{PREFIX}-rg",
    f"{PREFIX}-network",
    vnet_params
).result()
print("Virtual Network created.")

# Create Subnet
subnet_params = {
    "address_prefix": "10.0.2.0/24"
}
subnet_result = network_client.subnets.begin_create_or_update(
    f"{PREFIX}-rg",
    f"{PREFIX}-network",
    "internal",
    subnet_params
).result()
print("Subnet created.")

# Create Public IP
public_ip_params = {
    "location": LOCATION,
    "sku": {"name": "Basic"},
    "public_ip_allocation_method": "Dynamic"
}
public_ip_result = network_client.public_ip_addresses.begin_create_or_update(
    f"{PREFIX}-rg",
    f"{PREFIX}-public-ip",
    public_ip_params
).result()
print("Public IP created.")

# Create Network Security Group with SSH rule
nsg_params = {
    "location": LOCATION,
    "security_rules": [
        {
            "name": "SSH",
            "properties": {
                "priority": 1001,
                "direction": "Inbound",
                "access": "Allow",
                "protocol": "Tcp",
                "sourcePortRange": "*",
                "destinationPortRange": "22",
                "sourceAddressPrefix": "*",
                "destinationAddressPrefix": "*"
            }
        }
    ]
}
nsg_result = network_client.network_security_groups.begin_create_or_update(
    f"{PREFIX}-rg",
    f"{PREFIX}-nsg",
    nsg_params
).result()
print("Network Security Group created.")

# Create Network Interface
nic_params = {
    "location": LOCATION,
    "ip_configurations": [
        {
            "name": f"{PREFIX}-nic-config",
            "subnet": {"id": subnet_result.id},
            "public_ip_address": {"id": public_ip_result.id}
        }
    ]
}
nic_result = network_client.network_interfaces.begin_create_or_update(
    f"{PREFIX}-rg",
    f"{PREFIX}-nic",
    nic_params
).result()
print("Network Interface created.")

# Read SSH public key
with open(SSH_PUBLIC_KEY_PATH, "r") as ssh_file:
    ssh_public_key = ssh_file.read().strip()

# Create Virtual Machine
vm_params = {
    "location": LOCATION,
    "hardware_profile": {"vm_size": "Standard_B1s"},
    "storage_profile": {
        "image_reference": {
            "publisher": "Canonical",
            "offer": "UbuntuServer",
            "sku": "18.04-LTS",
            "version": "latest"
        },
        "os_disk": {
            "name": f"{PREFIX}-os-disk",
            "caching": "ReadWrite",
            "create_option": "FromImage",
            "managed_disk": {"storage_account_type": "Standard_LRS"}
        }
    },
    "os_profile": {
        "computer_name": f"{PREFIX}-vm",
        "admin_username": "azureuser",
        "linux_configuration": {
            "disable_password_authentication": True,
            "ssh": {
                "public_keys": [
                    {
                        "path": "/home/azureuser/.ssh/authorized_keys",
                        "key_data": ssh_public_key
                    }
                ]
            }
        }
    },
    "network_profile": {
        "network_interfaces": [{"id": nic_result.id}]
    }
}
vm_result = compute_client.virtual_machines.begin_create_or_update(
    f"{PREFIX}-rg",
    f"{PREFIX}-vm",
    vm_params
).result()
print("Virtual Machine created.")