# Easy Drone EKS Deployer

`drone-eks-deployer` is a [Drone-CI][drone] plugin that allows you to apply specific Kubernetes
manifests to [EKS][eks] clusters.

[drone]: https://drone.io
[eks]: https://aws.amazon.com/eks


## Usage

### Statement for deploy step

Example of step on ```.drone.yml``` file for using this plugin:

```yaml
kind: pipeline
name: default

steps:
  - name: deploy-to-eks
    image: cajanegra/drone-eks-deployer:1.1.6
    settings:
      node_role: arn:aws:iam::123456789:role/eks-node-role # Required
      cluster: arn:aws:eks:us-east-1:123456789:cluster/EKS-cluster-name # Required
      aws_access_key_id: AXHL46D77GKKS87F # Required
      aws_secret_access_key: cfEwOi7DotRlv/Hp0XzxJx413cpTufTJ4Fjqt9DB # Required
      aws_region: us-east-1 # Optional (default: us-east-1)
      manifest: .kube.yml # Optional (default: .kube.yml)
    environment: # Optional vars that can you use on manfifest file (.kube.yml)
      namespace: example-namespace
```

### Example of manifest

This is manifest file ```.kube.yml``` could be used with the previous example

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: '{{ .namespace }}' # This parameter would be replaced by "example-namespace" 
                           # before being applied on the eks cluster
  
  ...
```

