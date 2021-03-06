# Namespace

名称空间用来隔离资源

默认情况下，kubernetes 集群中的所有 pod 都是可以相互访问的，但是在实际中，可能不想让两个 pod 之间进行互相的访问，那此时就可以将两个 pod 划分到不同的 namespace 下，kubernetes 通过将集群内部的资源分配到不同的 Namespace 中，可以形成逻辑上的“组”，以方便不同的资源进行隔离使用和管理。

```sh
# 创建命名空间
$ kubectl create ns hello
# 删除
$ kubectl delete ns hello
```

通过 yaml 文件

```sh
$ vi hello-ns.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hello
```

```sh
$ kubectl apply -f hello-ns.yaml
namespace/hello created

$ kubectl delete -f hello-ns.yaml
```

# Pod

运行中的一组容器，Pod 是 kubernetes 中应用的最小单位.

一个 Pod 可以跑一个或多个 container，通常跑一个 container，或者加上一个 sidecar 服务容器

```sh
# 创建一个pod
$ kubectl run mynginx --image=nginx
# 删除
$ kubectl delete pod mynginx
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: myapp
  name: myapp
  namespace: default
spec:
  containers:
    - image: nginx
      name: mynginx
```

```sh
$ kubectl apply -f pod.yaml
$ kubectl delete -f pod.yaml

# 进入容器内 kubectl exec [POD] -- [COMMAND]
$ kubectl exec myapp -- /bin/bash

# k8s会给每个Pod分配一个ip
$ kubectl get pod -o wide

# 集群中的任意一个node都可以通过Pod的IP访问到这个pod
```

多容器的 Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: myapp1
  name: myapp1
spec:
  containers:
    - image: nginx
      name: nginx
    - image: tomcat:8.5.68
      name: tomcat
```

# Deployments

控制 Pod，创建 Pod 的多个副本。

```sh
$ kubectl create deployment mynginx --image=nginx
# 通过 deployment 创建的Pod被删除后，k8s会重新创建一个Pod

# 删除Deployment，Pod才会被永远删除
$ kubectl delete deploy mynginx

# 创建3个Pod
$ kubectl create deploy my-dep --image=nginx --replicas=3

# 查看yaml格式
$ kubectl get deploy nginx-mongodb-deploy -o yaml
```

使用配置文件创建 Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: my-dep
  name: my-dep
spec:
  replicas: 3
  # 用来查找关联的 Pod，所有标签都匹配才行
  selector:
    matchLabels:
      app: my-dep
  template:
    metadata:
      labels:
        app: my-dep
    spec:
      # 定义容器，可以多个
      containers:
        - image: nginx
          name: nginx
```

### 扩容

```sh
# 通过命令扩容
$ kubectl scale --replicas=5 deployment/my-dep

# 通过修改yml扩容
$ kubectl edit deployment my-dep
spec:
  replicas: 5 # 3改成5
```

### 滚动更新

不停机更新，杀死一个老版本 Pod，启动一个新版本 Pod

```sh
# 更新版本
$ kubectl set image deploy/my-dep nginx=nginx:1.16.2 --record

# 查看历史记录
$ kubectl rollout history deployment/my-dep

# 查看某个历史详情
$ kubectl rollout history deployment/my-dep --revision=2

# 回滚(回到上次)
$ kubectl rollout undo deployment/my-dep

# 回滚(回到指定版本)
kubectl rollout undo deployment/my-dep --to-revision=2
```

### Workload

除了 `Deployment`， k8s 还有 `StatefulSet`, `DaemonSet`, `Job` 等类型的资源。我们都称为工作负载 `Workload`

- `Deployment` 无状态应用部署，比如微服务，提供 ReplicaSet 功能
- `StatefulSet` 有状态应用，比如 redis，提供稳定的存储，网络等功能
- `DaemonSet` 守护型应用部署，比如日志收集组件，在每个机器都运行一份
- `Job/CronJob` 定时任务部署，比如垃圾清理组件，可以在指定时间运行

在 k8s 中，我们不直接控制 Pod，而是通过 Workload 来控制 Pod。

#### DaemonSet

保证集群中的每一台节点都运行一个副本，一般适用于日志收集，节点监控等。

DamonSet 控制器的特点：

- 每当向集群中添加一个 node 时，指定的 pod 副本也将添加到该节点上
- 当节点从集群中移除时，pod 也就被垃圾回收了

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: # rs名称
  namespace: #命名空间
  labels:
    controller: daemonset
spec:
  revisionHistoryLimit: 3 # 保留历史版本
  updateStrategy: # 更新策略
    type: RollingUpdate # 滚动更新策略
    rollingUpdate: # 滚动更新
      maxUnavailable: 1 # 最大不可用状态的Pod的最大值
  selector:
    matchLabels:
      app: nginx-pod
    matchExpressions:
      - {key:app, operator:In, values:[nginx-pod]}
  template:
    metadata:
      labels:
        app: nginx-pod
    spec:
      containers:
        - name: nginx
          image: nginx:1.17
          ports:
            - containerPort: 80
```
