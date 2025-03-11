# Define the Azure provider configuration
provider "azurerm" {
  # Enable Azure Resource Manager features (required, even if empty)
  features {}
  # Specify the Azure subscription ID to deploy resources into
  subscription_id = "3f79a68d-cf0d-4291-a31f-185897f7fda1"
}

# Declare a variable for a prefix to ensure consistent naming across resources
variable "prefix" {
  # Default value for the prefix, can be overridden when running Terraform
  default = "OmerDevops"
}

# Create an Azure Resource Group to organize all resources
resource "azurerm_resource_group" "rg" {
  # Name of the resource group, dynamically includes the prefix variable
  name = "${var.prefix}-rg"
  # Specify the Azure region where the resource group will be created
  location = "East US"
}

# Create a Virtual Network (VNet) for networking resources
resource "azurerm_virtual_network" "main" {
  # Name of the VNet, prefixed for consistency
  name = "${var.prefix}-network"
  # Define the IP address range for the VNet (CIDR block)
  address_space = ["10.0.0.0/16"]
  # Use the same location as the resource group
  location = azurerm_resource_group.rg.location
  # Associate the VNet with the resource group
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet within the Virtual Network
resource "azurerm_subnet" "internal" {
  # Name of the subnet
  name = "internal"
  # Link the subnet to the resource group
  resource_group_name = azurerm_resource_group.rg.name
  # Link the subnet to the VNet created above
  virtual_network_name = azurerm_virtual_network.main.name
  # Define the IP address range for the subnet (must be within VNet's address space)
  address_prefixes = ["10.0.2.0/24"]
}

# Create a public IP address for the VM to be accessible from the internet
resource "azurerm_public_ip" "public_ip" {
  # Name of the public IP, prefixed for consistency
  name = "${var.prefix}-public-ip"
  # Use the same location as the resource group
  location = azurerm_resource_group.rg.location
  # Associate the public IP with the resource group
  resource_group_name = azurerm_resource_group.rg.name
  # Use dynamic allocation (IP assigned by Azure at runtime)
  allocation_method = "Dynamic"
  # Specify the SKU as Basic (cheaper, suitable for small-scale use)
  sku = "Basic"
}

# Create a Network Security Group (NSG) to define network traffic rules
resource "azurerm_network_security_group" "nsg" {
  # Name of the NSG, prefixed for consistency
  name = "${var.prefix}-nsg"
  # Use the same location as the resource group
  location = azurerm_resource_group.rg.location
  # Associate the NSG with the resource group
  resource_group_name = azurerm_resource_group.rg.name

  # Define a security rule to allow inbound SSH traffic
  security_rule {
    # Name of the rule
    name = "SSH"
    # Priority determines the order of rule evaluation (lower numbers = higher priority)
    priority = 1001
    # Rule applies to inbound traffic
    direction = "Inbound"
    # Allow traffic matching this rule
    access = "Allow"
    # Rule applies to TCP protocol (used by SSH)
    protocol = "Tcp"
    # Allow traffic from any source port
    source_port_range = "*"
    # Allow traffic to port 22 (default SSH port)
    destination_port_range = "22"
    # Allow traffic from any source IP
    source_address_prefix = "*"
    # Allow traffic to any destination IP within the subnet
    destination_address_prefix = "*"
  }
}

# Create a Network Interface Card (NIC) to connect the VM to the network
resource "azurerm_network_interface" "nic" {
  # Name of the NIC, prefixed for consistency
  name = "${var.prefix}-nic"
  # Use the same location as the resource group
  location = azurerm_resource_group.rg.location
  # Associate the NIC with the resource group
  resource_group_name = azurerm_resource_group.rg.name

  # Define the IP configuration for the NIC
  ip_configuration {
    # Name of the IP configuration
    name = "${var.prefix}-nic-config"
    # Link the NIC to the internal subnet
    subnet_id = azurerm_subnet.internal.id
    # Dynamically assign a private IP from the subnet
    private_ip_address_allocation = "Dynamic"
    # Associate the public IP with this NIC for external access
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

# Declare a variable for the SSH public key path
variable "ssh_public_key" {
  # Default path to the SSH public key file (can be overridden)
  default = "~/.ssh/id_rsa.pub"
}

# Create a small Linux Virtual Machine (VM)
resource "azurerm_linux_virtual_machine" "vm" {
  # Name of the VM, prefixed for consistency
  name = "${var.prefix}-vm"
  # Use the same location as the resource group
  location = azurerm_resource_group.rg.location
  # Associate the VM with the resource group
  resource_group_name = azurerm_resource_group.rg.name
  # Link the VM to the NIC for network connectivity
  network_interface_ids = [azurerm_network_interface.nic.id]
  # Specify the VM size (Standard_B1s is a small, cost-effective instance)
  size = "Standard_B1s"

  # Configure the OS disk for the VM
  os_disk {
    # Name of the OS disk
    name = "${var.prefix}-os-disk"
    # Enable read/write caching for better performance
    caching = "ReadWrite"
    # Use Standard Locally Redundant Storage (cost-effective storage option)
    storage_account_type = "Standard_LRS"
  }

  # Specify the Ubuntu image to use for the VM
  source_image_reference {
    # Publisher of the image (Canonical = Ubuntu)
    publisher = "Canonical"
    # Offer specifies the product (Ubuntu Server)
    offer = "UbuntuServer"
    # SKU specifies the version of Ubuntu (18.04 LTS)
    sku = "18.04-LTS"
    # Use the latest version of the specified image
    version = "latest"
  }

  # Set the admin username for the VM
  admin_username = "azureuser"

  # Configure SSH access using a public key
  admin_ssh_key {
    # Username for SSH access (matches admin_username)
    username = "azureuser"
    # Read the SSH public key from the file specified in the variable
    public_key = file(var.ssh_public_key)
  }

  # Disable password authentication, forcing SSH key-based login only
  disable_password_authentication = true
}
