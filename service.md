# Service

将一组 Pods 公开为网络服务的抽象方法。

Service: 提供 Pod 的服务发现，和负载均衡。

```sh
# 创建一个Service使用8000端口将deployment的Pod暴露给外部，负载均衡并转发到Pod的80端口
$ kubectl expose deployment my-dep --port=8000 ---target-port=80
service/my-dep exposed

# 查看Service暴露的端口
$ kubectl get svc -owide
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE     SELECTOR
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP    3h15m   <none>
my-dep       ClusterIP   10.111.86.135   <none>        8000/TCP   56s     app=my-dep

# 此时访问Service的8000端口会负载均衡到3个Pod中
$ curl 10.111.86.135:8000
```

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: my-dep
  name: my-dep
spec:
  selector: # 选择标签为 app=my-dep 的一组pod
    app: my-dep
  ports:
    - port: 8000 # service的端口
      protocol: TCP
      targetPort: 80 # Pod的端口
```

Service 有一个 selector 可以指定某个标签的 Pod

```sh
$ kubectl get pods --show-labels
NAME                      READY   STATUS    RESTARTS   AGE   LABELS
my-dep-6656c6df89-78r7z   1/1     Running   0          64m   app=my-dep,pod-template-hash=6656c6df89
my-dep-6656c6df89-85krs   1/1     Running   0          64m   app=my-dep,pod-template-hash=6656c6df89
my-dep-6656c6df89-d29jd   1/1     Running   0          64m   app=my-dep,pod-template-hash=6656c6df89
```

### NodePort 模式

```sh
# 集群内部访问, 默认就是 ClusterIP
$ kubectl expose deploy my-dep --port=8000 --target-port=80 --type=ClusterIP
# 集群外也可以访问
$ kubectl expose deploy my-dep --port=8000 --target-port=80 --type=NodePort
```

创建 NodePort 类型的 servie 后进行查看

```sh
$ kubectl get svc -owide
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE     SELECTOR
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP          4h24m   <none>
my-dep       NodePort    10.106.251.71   <none>        8000:30831/TCP   49s     app=my-dep
```

可以看到除了 8000 端口以外，还有一个 30831 端口，这是暴露给外部的端口。8000 是集群内部的端口。

NodePort 在范围 30000-32767 之间随机选择一个端口。

NodePort 会在每一台服务器都开放 30831 端口，所以访问任意一台机器的 IP:PORT 都可以访问到集群中的机器。
