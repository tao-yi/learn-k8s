# Namespace

名称空间用来隔离资源

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
  selector:
    matchLabels:
      app: my-dep
  template:
    metadata:
      labels:
        app: my-dep
    spec:
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
