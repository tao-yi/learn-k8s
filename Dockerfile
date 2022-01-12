FROM node:12-alpine

RUN npm i

# 指定工作目录
WORKDIR /usr/src/app

COPY ./app/package*.json ./

# RUN 是在 docker build 时执行
RUN npm install

COPY ./app .

# 仅仅只是声明端口
# 帮助镜像使用者理解这个镜像服务的守护端口，以方便配置映射
EXPOSE 8080

CMD [ "npm", "start" ]

# ENTRYPOINT []
# 类似于 CMD 指令，在docker run 时运行
# 但其不会被 docker run 的命令行参数指定的指令所覆盖
# 而且这些命令行参数会被当作参数送给 ENTRYPOINT 指令指定的程序。
