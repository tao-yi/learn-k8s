# Docker

build a docker image

```sh
# 用当前目录的 Dockerfile 构建一个docker镜像
$ docker build -t <your username>/node-web-app -f Dockerfile .


# 查看刚才创建的那个image，可以看到默认的tag是latest
$ docker images
REPOSITORY                                                    TAG                 IMAGE ID       CREATED          SIZE
nodejs                                                        latest              8475a6da011f   16 seconds ago   91.2MB

# 也可以指定一个tag名s
$ docker build -t <your username>/node-web-app:1.0 -f Dockerfile .

# 可以看到两个镜像，一个是latest，一个是1.0
$ docker images
REPOSITORY                                                    TAG                 IMAGE ID       CREATED              SIZE
nodejs                                                        1.0                 8475a6da011f   About a minute ago   91.2MB
nodejs                                                        latest              8475a6da011f   About a minute ago   91.2MB

# 用docker image创建一个容器并跑起来
$ docker run --name my-nodejs -p 8080:8080 -d <your username>/node-web-app:1.0 -d


# 查看container
$ docker ps
CONTAINER ID   IMAGE                                                                 COMMAND                  CREATED         STATUS         PORTS                                                                                                                                  NAMES
0e54865b9833   teenotes/node-web-app:1.0                                             "docker-entrypoint.s…"   2 minutes ago   Up 9 seconds   0.0.0.0:8080->8080/tcp

# 进入container
$ docker exec -it 0e54865b9833 s
```
