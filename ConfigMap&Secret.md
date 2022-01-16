# Secret

一些重要数据，例如密码、TOKEN，我们可以放到 secret 中。文档，配置证书

比如：TLS Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-tls
type: kubernetes.io/tls
data:
  # 此例中的数据被截断
  tls.crt: |
    MIIC2DCCAcCgAwIBAgIBATANBgkqh ...
  tls.key: |
    MIIEpgIBAAKCAQEA7yn3bRHQ5FHMQ ...
```

你可以像这样创建一个 secret

```sh
kubectl create secret tls my-tls-secret \
  --cert=path/to/cert/file \
  --key=path/to/key/file
```

这里的公钥/私钥对都必须事先已存在。用于 --cert 的公钥证书必须是 .PEM 编码的 （Base64 编码的 DER 格式），且与 --key 所给定的私钥匹配。 私钥必须是通常所说的 PEM 私钥格式，且未加密。对这两个文件而言，PEM 格式数据 的第一行和最后一行（例如，证书所对应的 --------BEGIN CERTIFICATE----- 和 -------END CERTIFICATE----）都不会包含在其中。

### 存放 MongoDB 的用户名密码

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongo-secret
# 默认类型 Opaque 用户定义的任意键值对数据，更多类型介绍 https://kubernetes.io/zh/docs/concepts/configuration/secret/#secret-types
type: Opaque
data:
  # 数据要 base64。https://tools.fun/base64.html
  # echo -n 'username' | base64
  # echo -n 'password' | base64
  mongo-root-username: dXNlcm5hbWU=
  mongo-root-password: cGFzc3dvcmQ=
```
