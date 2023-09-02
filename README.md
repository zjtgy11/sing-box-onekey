## 致谢
- [sing-box](https://github.com/SagerNet/sing-box)
- [sing-box-yes](https://github.com/FranzKafkaYu/sing-box-yes)
- [sing-box-example](https://github.com/chika0801/sing-box-examples)
  
## sing-box-onekey
sing-box一键脚本，一键安装多种协议，支持自动安装和手动配置
## 功能
- 一键自动安装各种协议
- 手动安装所有协议
- 流媒体解锁（不完善）
## 支持协议
### 一键安装
- reality
- naive
- vless ws tls（支持证书申请，可开CDN）对这个协议其实已经可以淘汰了，去年十月这个基本已经用不了了，但是呢，套个cdn还是很稳的，所以保留，至于为什么没有写nginx的一键脚本呢……这个nginx本来就是为了伪装才搞的，但是现在能识别tls in tls了，所以用不用nginx都是没啥区别的，更何况nginx的配置很复杂，一键脚本有点多余了）
- shadowtls
- hysteria（拯救垃圾小鸡）
- tuic v5
- 三合一协议（SNI共用443端口）

### 手动修改配置文件
支持所有sing-box支持的协议

## 安装方式：
```
bash <(curl -Ls https://raw.githubusercontent.com/vveg26/sing-box-onekey/main/install.sh)
```
之后输入sing-box-onekey就可以调用此脚本
### 手动安装
替换配置文件的内容再重启sing-box即可
配置文件例子抓取自[sing-box-example](https://github.com/chika0801/sing-box-examples)
可参考本仓库中的配置文件，仓库中的文件夹中有客户端和服务端配置以及使用说明
## 客户端配置
客户端配置文件都在这个文件夹中
clash-meta配置
sing-box配置（支持clash-api—）
通用链接
| 项目 | |
| :--- | :--- |
| 程序 | /usr/local/bin/sing-box |
| 配置文件路径 | **/usr/local/etc/sing-box/config.json** |
| 脚本路径 |/usr/local/sbin/sing-box-onekey |
| 客户端文件路径 |/root/sing-box/ |

## 使用
使用方法和sing-box-yes一致，他的功能都可以有

