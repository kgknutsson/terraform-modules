# Terraform module for deploying Azure Storage Account resources

Use this module to deploy Azure Storage Account resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```hcl
module "storage_account" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/storage_account"

  config          = local.config
  environment     = var.environment
  resource_group  = module.resource_group

  // Optional
  virtual_network = module.virtual_network
}
```

In addition to required parameters *config*, *environment* and *resource_group*, a *virtual_network* parameter can be used to reference its subnets in network rules (see below).

## Storage Account configuration
Below are the configuration parameters for the Storage Account itself. A single required parameter *account_tier* must be set to either *Standard* or *Premium*. Other optional parameters and their default values.

```yaml
<global|environment>:
  storage_account:
    account_tier: <Standard|Premium>
    account_kind: <BlobStorage|BlockBlobStorage|FileStorage|Storage|StorageV2> # Default: StorageV2
    account_replication_type: <LRS|GRS|RAGRS|ZRS|GZRS|RAGZRS> # Default: LRS
    access_tier: <Hot|Cold> # Default: Hot
    min_tls_version: <TLS1_0|TLS1_1|TLS1_2> # Default: TLS1_2
    shared_access_key_enabled: <true|false> # Default: true
    public_network_access_enabled: <true|false> # Default: true
    is_hns_enabled: <true|false> # Default: false
    sftp_enabled: <true|false> # Default: false
```

### Network rules
Network rules can be used to restrict public network access to the storage account.

```yaml
<global|environment>:
  storage_account:
    network_rules:
      bypass:
        - <Logging|Metrics|AzureServices|None> # Default: None
        ...
      ip_rules:
        - <IP> # Public IP or IP range in CIDR format
        ...
      virtual_network_subnet_ids:
        - <subnet> # Subnet name or Azure id
        ...
```

### Storage containers
Storage containers within the Storage Account.

```yaml
<environment>:
  storage_account:
    storage_containers:
      <name>:
        container_access_type: <blob|container|private> # Default: private
        metadata:
          <key>: <value>
          ...
      ...
```

### Local users
Local users for accessing containers over SFTP.

```yaml
<environment>:
  storage_account:
    local_users:
      <name>:
        home_directory: <path>
        ssh_password_enabled: <true|false> # Default: false
        ssh_key_enabled: <true|false> # Default: false
        ssh_authorized_keys:
          - description: <string>
            key: <SSH public key>
          ...
        permission_scopes:
          <container>:
            permissions:
              - <create|delete|list|read|write>
              ...
          ...
```

## Resources
Below are references to the resources created by this module.

[Terraform Azure Storage Account reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account)

[Terraform Azure Storage Container reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container)

[Terraform Azure Storage Account Local User reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_local_user)
