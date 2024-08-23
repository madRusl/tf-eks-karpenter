### Task

```
One of our clients has multiple GPU-intensive AI workloads that run on EKS.

Their CTO heard there is an option to cut GPU costs by enabling GPU Slicing.

We want to help them optimize their cost efficiency.

Research the topic, and describe how they can enable GPU Slicing on their EKS clusters.

Some of the EKS clusters have Karpenter Autoscaler, they’d like to leverage GPU Slicing on these clusters as well. If this is feasible, please provide instructions on how to implement it.
```

### Solution

GPU concurrency can be achieved through:

- MIG
    - virtual partioning of a physical device (has limitations in the number of partitions - "7 slices for A100?" - depends on a GPU device)
    - cpu, memory and error isolation
    - has limitations in configuration (requires a device reboot, not all devices supported?)
- Time Slicing
    - logical partioning (limited by kubelet maxPods and/or context-switching overhead?)
    - dynamic configuration
    - useful when k8s workloads are dynamic and and require multiple processes to access the GPU in parallel
    - better GPU utilisation
    - no memory or error isolation
    - potential issues when configuring time slices for your workload (e.g. context-switching overhead?)
- MPS
    - ?
- DRA (alpha?)
    - ?
- or a combination of the above-mentioned methods (e.g. MIG + TimeSlicing).

Each approach has its own advantages and disadvantages, and it largely depends on the type of workload. Consider the throughput, inference performance, security aspects and availability of your workload.

#### Prerequisites:
install nvidia gpu-operator:

https://github.com/NVIDIA/gpu-operator/tree/main

1. Karpenter nodepool configuration
```yaml
...
kind: Nodepool
metadata:
  name: demo-gpu-provisioner
spec:
  template:
    spec:
      nodeClassRef:
        name: <your-nodeclass-name>
      taints:
        - key: nvidia.com/gpu
          effect: NoSchedule
      # simplified requirements for a demo?
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        # # use spot if applicable?
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot", "on-demand"]
        # https://aws.amazon.com/ec2/instance-explorer
        - key: "instance-type"
          operator: In
          values: ["p4d.24xlarge"]
  disruptions:
    ...
  limits:
    ...
```

NOTE: in case of eks managed node groups label nodes accordingly.
in terraform or via `kubectl label nodes $NODE nvidia.com/mig.config=all-1g.5gb --overwrite`
(or `kubectl label nodes $NODE nvidia.com/mig.config=all-balanced --overwrite` in case of mixed strategy)

2. enable MIG profiles
- gpu-operator should point to this custom config `--set migManager.config.name=<custom-mig-parted-config>`. However, it is also should be possible to select pre-defined profile from gpu-operator chart?


```yaml
kind: ConfigMap
metadata:
  name: mig-parted-config
data:
  config.yaml: |
    version: v1
    mig-configs:
      # A100
      all-1g.5gb:
        - devices: all
          mig-enabled: true
          mig-devices:
            "1g.5gb": 7
```


3. GPU sharing between containers:

- setting specified limits will allow multiple pods to share the same physical GPU device by using different GPU slices.
- fractional `.limits` are not allowed. only integers.
- limits should be equal to resources or ommited?
- example is used with `mixed.strategy: single` on gpu-feature-discovery component.

```yaml
...
kind: Deployment
...
spec:
  containers:
    ...
    resources:
      limits:
        nvidia.com/gpu: 7
        # or if opt to "mixed.strategy: mixed"
        # nvidia.com/mig-1g.5gb: 1
        # nvidia.com/mig-2g.10gb: 1
        # # these profiles are defined in mig-parted configmap?
  ...
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
...
```

Then workload can be scaled:

```bash
kubectl scale deploy deploymentA --replicas X # for mig-1g.5gb
# kubectl scale deploy deploymentB --replicas Y # mig-2g.10gb etc
```

4. Time-Slicing (on top of MIG GPU)

Apply configmap with time-slicing settings, device-plugin should reload configuration.

```yaml
kind: ConfigMap
...
data:
  slice-10: |-
    version: v1
    flages:
      migStrategy: single
    sharing:
      timeSlicing:
        renameByDefault: false
        failRequestGreaterThanOne: true
        resources:
          - name: nvidia.com/gpu
            replicas: 10
```

That should allow k8s workload to schedule 10 replicas per previously defined GPU slice. Check the number of virtual GPUs available on a node:

```bash
kubectl get nodes -l <NODE_LABEL> -o json | jq -r '.items[] | select(.status.capacity."nvidia.com/gpu" != null) | {name: .metadata.name, capacity: .status.capacity}'
```

And scale deployment accordingly

```bash
kubectl scale deploy deploymentA --replicas X
```