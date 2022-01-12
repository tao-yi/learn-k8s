# Ingress

Kubernetes 提供了 Ingress 资源对象。Ingress 只需要一个 NodePort 或者一个 LoadBalancer 就可以满足暴露多个 Service 的需求。

Ingress 是对集群中服务的外部访问进行管理的 API 对象，典型的访问方式是 HTTP。

Ingress 可提供负载均衡，SSL，域名 hosting。

Ingress 公开了从集群外部到集群内服务的 HTTP 和 HTTPS 路由。 流量路由由 Ingress 资源上定义的规则控制。

```
client => ingress => service => pod
```

Service 提供了对一组 Pod 的负载均衡，但是生产环境中可能会有很多组 Pod。每一组 Pod 都有一个 Service 负责 Pod 间的负载均衡。

Ingress 作为 Service 的统一网关入口，所有请求的流量都进入 Ingress。

- `ClusterIP` 是默认的 kubernetes service 类型。它允许你在集群中内部访问集群中的节点。外部无法访问。
- `NodePort` 是从外部访问 Service 最原始的方式。它开启一个指定端口，将所有访问该端口的流量转发给这个 service。缺点是每个 service 都必须有一个对应的端口，范围在 30000 ~ 32767。
- `LoadBalancer` 是将 service 暴露给外网的标准方式，它会开启一个负载均衡器，提供一个 IP 地址并且将所有访问它的流量转发给你的 service。如果你想直接暴露一个 Service，这是默认的方式。LoadBalancer 需要对外暴露端口，不安全。无法根据域名、路径转发流量到不同 Service，多个 Service 则需要开多个 LoadBalancer。功能单一，无法配置 https。
- `Ingress` 作为所有 Service 的网关，是集群的入口。

要使用 Ingress，需要一个负载均衡器 + Ingress Controller。

- `ingress` 是 kubernetes 中的一个对象，作用是定义请求如何转发到 service 的规则
- `ingress controller` 是具体实现反向代理和负载均衡的程序，对 ingress 定义的规则进行解析，并且根据配置的规则来实现请求转发，实现的方式有很多，比如 `Nginx`, `HAproxy`, `Istio` 等等。
  Ingress Controller 是 Ingress 的实现，它是另一组 Pods 跑在集群中

- evaluates all the rules
- manages redirections
- entrypoint to cluster
- many third-party implementations

> 我们创建 Ingress 资源，在其中定义映射规则，Ingress Controller 通过监听这些配置规则并转化成 Nginx 的反向代理配置，然后对外提供服务。

### Ingress 的工作原理

1. 用户编写 Ingress 规则，说明哪个域名对应 kubernetes 集群中的哪个 Service
2. Ingress 控制器动态感知 Ingress 服务规则的变化，然后生成一段对应的 Nginx 配置
3. Ingress 控制器会将生成的 Nginx 配置写入到一个运行着的 Nginx 服务中，并动态更新
4. 到此为止，真正负责负载均衡和反向代理的是 Nginx，其内部配置了用户定义的规则

## 安装 ingress-nginx

https://github.com/kubernetes/ingress-nginx/blob/main/docs/deploy/index.md#bare-metal-clusters

```sh
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.0/deploy/static/provider/baremetal/deploy.yaml
```

```sh
# 安装完成后，查看暴露的接口
$ kubectl get svc -A
NAMESPACE     NAME                                   TYPE         CLUSTER-IP     EXTERNAL-IP     PORT(S)            AGE
ingress-nginx ingress-nginx-nginx-ingress-controller LoadBalancer 192.168.253.71 42.192.177.193  80:32573/TCP,443:31403/TCP   82s
```

配置 ingress-nginx

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
  name: ingress-host-bar
spec:
  ingressClassName: nginx
  rules:
    - host: "hello.atguigu.com"
      http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: hello-server
                port:
                  number: 8000
    - host: "demo.atguigu.com"
      http:
        paths:
          - pathType: Prefix
            path: "/nginx(/|$)(.*)"
            backend:
              service:
                name: nginx-demo
                port:
                  number: 8000
```
