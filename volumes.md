# Volumes

Docker 有 volume 的概念，docker 的 volume 是直接挂载在磁盘上的（或者是另一个 container 的磁盘上），它的功能非常有限。

Kubernetes 支持多种类型的 volumes.

> Persistent volumes exist beyond the lifetime of a pod. When a pod ceases to exist, Kubernetes destroys ephemeral volumes; however, Kubernetes does not destroy persistent volumes. For any kind of volume in a given pod, data is preserved across container restarts.

## 基础 volume 类型

- `EmptyDir` 是最基础的 Volume 类型，一个 `EmptyDir` 就是 Host 上的一个空目录

  - `EmptyDir` 是在 Pod 被分配到 Node 时创建的，它的初始内容为空，无需指定宿主机上对应的目录文件，因为 kubernetes 是自动分配一个目录，当 Pod 销毁时，EmptyDir 中的数据也会被永久删除

- `HostPath` 是将 Node 主机中的一个实际目录挂载到 Pod 中，以供容器使用，这样就保证即使 Pod 销毁了,数据依然存在 Node 主机上。

HostPath 可以解决数据持久化的问题，但是一旦 Node 节点故障了，或者 Pod 转移到了别的节点，此时又出现问题了。这就需要准备一个网络存储系统 `NFS`

- `NFS` 是一个网络文件存储徐彤，可以搭建一台 `NFS` 服务器，然后将 Pod 中的存储直接连接到 `NFS` 系统上，这样无论 Pod 在哪个节点上，只要能与 NFS 保持通信，就可以访问数据。

## 高级存储

为了能够屏蔽底层存储实现的细节，方便使用，kubernetes 引入了 `PV` 和 `PVC` 两种资源对象。

- `PV` Persistent Volumne 是持久化卷的意思，是对底层的共享存储的一种抽象，一般情况下 PV 由 kubernetes 管理员进行创建了配置，它与底层具体的共享存储技术有关，并通过插件完成与共享存储的对接。
- `PVC` Persistent Volume Claim 是持久卷声明的意思，是用户对存储需求的一种声明。PVC 其实就是用户向 kubernetes 系统发出的一种资源需求申请。

### 搭建 nfs

在 worker node 中选择一个主节点作为 nfs 的主节点，让其他节点同步这个主节点的数据。

#### 主节点

```sh
$ yum install nfs-utils -y

# 在数据主节点上执行
# 将/nfs/data 这个目录暴露给172.31.0.0/16网段中的所有主机
$ echo "/nfs/data/ 172.31.0.0/16(insecure,rw,sync,no_root_squash)" > /etc/exports

# 创建共享目录
$ mkdir -p /nfs/data

$ systemctl enable rpcbind --now
$ systemctl enable nfs-server --now
# 配置生效
$ exportfs -r

```

#### 从节点

```sh
# 查看主节点上哪些目录可以挂载
$ showmount -e 172.31.0.10 # 主节点IP
Export list for 172.31.0.10:
/nfs/data 172.31.0.0/16

# 给从节点也创建挂载目录
$ mkdir -p /nfs/data

# 同步主节点的目录，将从节点的 /nfs/data 挂载到主节点的 /nfs/data 上
$ mount -t nfs 172.31.0.10:/nfs/data /nfs/data

# 在任何一个节点中创建文件
$ cd /nfs/data
$ touch helloworld.txt
# 在其他节点也能看到
$ ls /nfs/data
```

### 原生方式数据挂载

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-pv-demo
  name: nginx-pv-demo
  namespace: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-pv-demo
  template:
    metadata:
      labels:
        app: nginx-pv-demo
    spec:
      containers:
        - image: nginx
          name: nginx
          volumeMounts: # 挂载到数据卷
            - name: html-volume
              mountPath: /usr/share/nginx/html # 将Pod内部的路径挂载到名为html的外部数据卷
      volumes:
        - name: html-volume
          nfs:
            server: 172.31.0.10 # nfs主节点的ip
            path: /nfs/data # 挂载到外部的nfs的目录
```

### PV

将 Pod 需要持久化的数据保存到指定位置

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv2
spec:
  nfs: # 存储类型，与底层真正存储对应
  capacity: # 存储能力，目前只支持存储空间的设置
    storage: 2Gi
  accessModes: # 访问模式
  storageClassName: # 存储类别
  persistentVolumeReclaimPolicy: # 回收策略
```

#### 访问模式（accessModes）

用于描述用户应用对存储资源的访问权限，访问权限包括下面几种方式：

- `ReadWriteOnce`（RWO）：读写权限，但是只能被单个节点挂载
- `ReadOnlyMany`（ROX）： 只读权限，可以被多个节点挂载
- `ReadWriteMany`（RWX）：读写权限，可以被多个节点挂载

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv01-10m
spec:
  capacity:
    storage: 10M
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  nfs:
    path: /nfs/data/01
    server: 172.31.0.10
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv02-1gi
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  nfs:
    path: /nfs/data/02
    server: 172.31.0.10
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv03-3gi
spec:
  capacity:
    storage: 3Gi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  nfs:
    path: /nfs/data/03
    server: 172.31.0.10
```

### PVC

PVC 是资源的申请，用来声明对存储空间、访问模式、存储类别需求信息。
PVC 其实就是对 PV 的申请。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc
  namespace: dev
spec:
  accessModes: # 访问模式
  selector: # 采用标签对PV选择
  storageClassName: # 存储类别
  resources: # 请求空间
    requests:
      storage: 5Gi
```

创建 PVC 来申请 PV，PVC 会寻找合适的 PV 进行绑定

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nginx-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 200Mi
  storageClassName: nfs
```

```sh
# 查看PV和PVC的状态
$ kubectl get pv,pvc
NAME                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM               STORAGECLASS   REASON   AGE
persistentvolume/pv01-10m   10M        RWX            Retain           Available                       nfs                     4m43s
persistentvolume/pv02-1gi   1Gi        RWX            Retain           Bound       default/nginx-pvc   nfs                     4m43s
persistentvolume/pv03-3gi   3Gi        RWX            Retain           Available                       nfs                     4m43s

NAME                              STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/nginx-pvc   Bound    pv02-1gi   1Gi        RWX            nfs            4s

# 可以看到PVC绑定到了pv02-1gi这个PV上，它们的Status变成了 Bound
```

创建 Pod 绑定 PVC

`depl-pvc.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-deploy-pvc
  name: nginx-deploy-pvc
spec:
  replicas: 6
  selector:
    matchLabels:
      app: nginx-deploy-pvc
  template:
    metadata:
      labels:
        app: nginx-deploy-pvc
    spec:
      containers:
        - image: nginx
          name: nginx
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          persistentVolumeClaim:
            claimName: nginx-pvc
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nginx-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs
```

```sh
$ kubectl apply -f depl-pvc.yaml
```
