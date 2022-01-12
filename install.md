## 准备 3 台服务器

1 台 master，2 台 node

- `VPC`：云服务器需要加入 VPC

比如 `172.31.0.0/16`，分配给云服务器在这个网段范围内的内网 ip 地址。如果有 3 台服务器，它们被随机分配了 3 个内网 IP 地址: 172.31.0.10, 172.31.0.7, 172.31.0.15。

在这 3 台机器上创建的 pod，也许要一个独立的网段 (`CIDR`)，比如 `192.168.0.0/16`。那么所有的 pod 会分配到这个范围内的 ip 地址。

- `service-cidr` ：在创建集群时可以指定 service 的网段，比如 `192.168.252.0/22`
- `pod-network-cidr`：和 service 网段必须相互隔离。比如 `172.31.0.0/16`

```sh
$ sudo vi /etc/hosts
# 所有节点都修改 hosts
xxx.xx.xx.xx master
xxx.xx.xxxx node1
xxx.xx.xx.xx node2


# ssh连接3台服务器
$ ssh root@master
$ ssh root@node1
$ ssh root@node2



# 修改机器的hostname
$ hostnamectl set-hostname master
$ hostnamectl set-hostname node1
$ hostnamectl set-hostname node2

# 所有节点关闭 SELinux
$ setenforce 0
$ sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

# 所有节点确保防火墙关闭
$ systemctl stop firewalld
$ systemctl disable firewalld

# 所有节点开启网络时间同步
$ systemctl status chronyd
$ systemctl start chronyd
$ systemctl enable chronyd

# 修改linux的内核采纳数，添加网桥过滤和地址转发功能
# 编辑 /etc/sysctl.d/kubernetes.conf 文件，添加如下配置：
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1

# 重新加载配置
$ sysctl -p

# 加载网桥过滤模块
$ modprobe br_netfilter
# 查看网桥过滤模块是否加载成功
$ lsmod | grep br_netfilter

# 添加 k8s 安装源
$ cat <<EOF > kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

$ mv kubernetes.repo /etc/yum.repos.d/

# 添加 Docker 安装源
$ yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 安装所需节点
$ yum install -y kubelet kubeadm kubectl docker-ce

# 启动 kubelet、docker，并设置开机启动（所有节点）
$ systemctl enable kubelet
$ systemctl start kubelet
$ systemctl enable docker
$ systemctl start docker

# kubernetes 官方推荐 docker 等使用 systemd 作为 cgroupdriver，否则 kubelet 启动不了
$ vi /etc/docker/daemon.json

{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://ud6340vz.mirror.aliyuncs.com"]
}

# 重启生效
$ systemctl daemon-reload
$ systemctl restart docker

# 映射主节点域名和ip
$ vi /etc/hosts
xxx.xx.x.xx cluster-endpoint

# 初始化主节点, pod-network-cidr是3台节点所使用的vpc网段，失败了可以用 kubeadm reset 重置
$ kubeadm init --image-repository=registry.aliyuncs.com/google_containers \
  --pod-network-cidr=192.168.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=xxx.xx.x.xx \
  --control-plane-endpoint=cluster-endpoint

# --pod-network-cidr=192.168.0.0/16 表示k8s会给pod分配这个网段范围内的ip地址

# 然后你可以看见控制台输出如下信息
# Your Kubernetes control-plane has initialized successfully!

# To start using your cluster, you need to run the following as a regular user:
# 复制授权文件，以便 kubectl 可以有权限访问集群
#   mkdir -p $HOME/.kube
#   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#   sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Alternatively, if you are the root user, you can run:

#   export KUBECONFIG=/etc/kubernetes/admin.conf

# You should now deploy a pod network to the cluster.
# Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
#   https://kubernetes.io/docs/concepts/cluster-administration/addons/

# Then you can join any number of worker nodes by running the following on each as root:

# kubeadm join xxx.xx.x.x:6443 --token qo2wuq.0tk8sa6v206tpfir \
# 	--discovery-token-ca-cert-hash sha256:5a5ac8a75083f63bf4c6e76beaefdb8cb3d6de67aa2773994473ecc6970ba0f0

# 在工作节点上执行join
$ kubeadm join xxx.xx.x.x:6443 --token qo2wuq.0tk8sa6v206tpfir --discovery-token-ca-cert-hash sha256:5a5ac8a75083f63bf4c6e76beaefdb8cb3d6de67aa2773994473ecc6970ba0f0

# 你会看到如下输出
# This node has joined the cluster:
# * Certificate signing request was sent to apiserver and a response was received.
# * The Kubelet was informed of the new secure connection details.

# Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

# 现在可以产看节点
$ kubectl get node

# 可以看到，3台节点的状态都是NotReady
NAME     STATUS     ROLES                  AGE     VERSION
master   NotReady   control-plane,master   8m53s   v1.23.1
node1    NotReady   <none>                 5m21s   v1.23.1
node2    NotReady   <none>                 5m10s   v1.23.1

# 我们需要安装网络插件，主节点执行
$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 或者安装calico插件
$ curl https://docs.projectcalico.org/manifests/calico.yaml -O

$ kubectl apply -f calico.yaml

# 查看flannel成功安装并跑起来
$ kubectl get pod -n kube-system
# 可以看到flannel已经成功跑起来了
kube-flannel-ds-6hfls            1/1     Running   0          15s
kube-flannel-ds-7bq8n            1/1     Running   0          15s
kube-flannel-ds-v992z            1/1     Running   0          15s
```

### 部署 k8s dashboard

```sh
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml

# 或者先下载这个文件
$ wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml

$ kubectl apply -f dashboard.yaml

# 设置访问端口
$ kubectl edit svc kubernetes-dashboard -n kubernetes-dashboard
# 将 type: ClusterIP 改成 type: NodePort

# 找到dashboard的service的端口，在安全组中开放这个端口
$ kubectl get svc -A  | grep kubernetes-dashboard
kubernetes-dashboard   kubernetes-dashboard        NodePort    10.109.120.115   <none>        443:30591/TCP

```

创建一个访问账号，准备一个 yaml 文件

```yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin-user
    namespace: kubernetes-dashboard
```

```sh
#获取访问令牌
$ kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
```

### 疑难解答

如果 `kubeadm init` 报错 ipv4.ip_forward 未开启

```sh
$ sysctl -w net.ipv4.ip_forward=1
```

```sh
# 如果在在子节点上执行报错
$ kubectl get node
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

解决方案：将主节点（master 节点）中的【/etc/kubernetes/admin.conf】文件拷贝到从节点相同目录下:

```sh
$ scp -r /etc/kubernetes/admin.conf node1:/etc/kubernetes/admin.conf
$ scp -r /etc/kubernetes/admin.conf node2:/etc/kubernetes/admin.conf

# 配置环境变量
$ echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bash_profile
# 立即生效
$ source ~/.bash_profile
```

# 如果 kubeadm 的 discovery-token 令牌过期或者找不到了

```sh
# 重新生成一个
$ kubeadm token create --print-join-command
```
