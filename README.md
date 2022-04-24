# Protect Terraform Module Resource(s)

Sometimes, when using 3rd party Terraform modules that create crtical resources
in our infrastructure we want to prevent those resources from being destroyed,
either due to their replacement or explict call to destroy. Terraform provides
a mechanism to protect resources, using lifecycle `prevent_destroy` flag. However,
at the time of this writing (April 2022), similar mechanism does not exist for
modules.

This repository shows an example, how to, under certain conditions, prevent
destroy of resource(s) created by the module. It also demonstrates how to
prevent destroy in "production" environment while allowing it in "development".

## Protect Module Resource(s)

Demonstrated approach is limited to protect only certain module resources. The
requirement for the module is to have an output value that would change when the
resource to be protected is recreated or destroyed. It is possible to protect
multiple resources as long as the module exposes outputs with those resources'
recreate/destroy changing values (e.g. AWS Security Group ID).

The [example module](modules/aws_security_group) creates AWS security group, given
its name. Updating the name forces the resource to be recreated. The example
module allows also in-place update, e.g. by changing value of resource tag.

Assuming the module is managed using the following Terraform statement:

```
module "security_group" {
  source = "../aws_security_group"

  name = "TestSecurityGroup-${var.recreate}"
  tag  = "Value-${var.update}"
}
```

To prevent it from being re-created or destroyed we can use the following resource:

```
resource "null_resource" "module_guardian" {
  triggers = {
    security_group_id = module.security_group.group_id
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

The resource `null_resource.module_guardian` declares implicit dependency on
`module.security_group`. It also sets its lifecycle `prevent_destroy` to `true`
This will cause Terraform to exit with error if the plan results in the need to
re-create or destroy the resource.

The Terraform [null_resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)
gets recreated if the value of `triggers` changes, e.g. when security group ID
changes, which happens when the security group is recreated.

Since Terraform executes the re-create or destroy "plan" in reverse order, if
`module.security_group.group_id` changes, Terraform would first try to re-create
`null_resource.module_guardian` resource. This fails due to `prevent_destroy`
value and effectively protect `module.security_group` from being recreated.

The same thing happens when calling `terraform destroy`. Due to the
`null_resource.module_guardian` dependency on `module.security_group`,
Terraform would first attempt to destroy the former, which fails due to
`prevent_destroy` value.

> Note that using in `null_resource.module_guardian` `depends_on = [module.security_group]`
> and not using `triggers` would only protect the module during `terraform destroy`
> but not when the module resource is re-created.

## Conditionally Protect Module Resource(s)

Sometimes we may want to protect module resources in our Production environment
but we are fine with re-creating or destroying them in the Development environment.

To accomplish that we need to add the following `count` statement to our
`null_resource.module_guardian`:

```
resource "null_resource" "module_guardian" {
  count = var.env == "pro" ? 1 : 0

  triggers = {
    security_group_id = module.security_group.group_id
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

If the value of `env` variable is `pro`, the `null_resource.module_guardian` is
created and its `prevent_destroy` protects the selected module resource(s) as
described in the previous section. For any other value, `null_resource.module_guardian`
is not created and therefore module resource(s) can be freely re-created or
destroyed.

> Note that the conditional protection is static. If you still want to destroy
> protected resource you have to manually update `prevent_destroy` value to `false`.

## Putting It All Together

The examples assume that you have valid AWS credentials that are configured in
profile called `personal`.

Even though the examples use `terragrunt`, it is not required. In our context
`terragrunt apply` executed in the appropriate [config](config)
subfolder is equivalent to `terraform apply -var env=pro` or `terraform apply -var env=dev`
run in [modules/main](modules/main) folder.

### "dev" Environment

In "dev" environment the security group created by the module is not protected.

To create the resources:

```
(cd config/dev && terragrunt apply)
```

To update the security group without recreating it:

```
(cd config/dev && terragrunt apply -var update=1)
```

To update the security group's name which results in the group being recreated:

```
(cd config/dev && terragrunt apply -var recreate=1)
```

Finally, to destroy the resources:

```
(cd config/dev && terragrunt destroy)
```

All the operations above should run successfully.

### "pro" Environment

In "pro" environment the security group created by the module is protected.
Therefore any changes that would result in the group being re-created or destoryed
cause Terraform to fail before.

To create the resources:

```
(cd config/pro && terragrunt apply)
```

To update the security group without recreating it:

```
(cd config/pro && terragrunt apply -var update=1)
```

This operation works as it does not result in the module re-creating the security
group.

To update the security group's name which results in the group being recreated:

```
(cd config/pro && terragrunt apply -var recreate=1)
```

This operation fails as it causes `null_resource.module_guardian` to be
re-created first but the resource is protected by `prevent_destroy`.

Finally, to destroy the resources:

```
(cd config/pro && terragrunt destroy)
```

This operation fails as it causes `null_resource.module_guardian` to be
destroyed first but the resource is protected by `prevent_destroy`.

