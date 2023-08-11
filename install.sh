#!/bin/bash

#####################################################
#This shell script is used for sing-box installation
#Usage：
#
#Author:masheep
#Date:2023-08-05
#Version:0.0.1
#####################################################

#Some basic definitions
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

#os
OS_RELEASE=''

#arch
OS_ARCH=''

#sing-box version
SING_BOX_VERSION=''

#script version
SING_BOX_ONEKEY_VERSION='0.0.1'

#package download path
DOWNLAOD_PATH='/usr/local/sing-box'

#backup config path
CONFIG_BACKUP_PATH='/usr/local/etc'

#config install path
CONFIG_FILE_PATH='/usr/local/etc/sing-box'

#binary install path sing-box二进制文件
BINARY_FILE_PATH='/usr/local/bin/sing-box'

#scritp install path sing-box脚本文件，输入sing-box-onekey即可打开脚本
SCRIPT_FILE_PATH='/usr/local/sbin/sing-box-onekey'

#service install path
SERVICE_FILE_PATH='/etc/systemd/system/sing-box.service'

#log file save path
DEFAULT_LOG_FILE_SAVE_PATH='/usr/local/sing-box/sing-box.log'

#客户端配置文件
CLIENT_FILE_PATH='/root/sing-box'

# 远端服务端配置
REMOTE_SERVER_URL='https://raw.githubusercontent.com/vveg26/sing-box-onekey/main/config/server_config.json'
# 远端客户端配置
REMOTE_CLIENT_URL='https://raw.githubusercontent.com/vveg26/sing-box-onekey/main/config/client_config.json'
#sing-box status define
declare -r SING_BOX_STATUS_RUNNING=1
declare -r SING_BOX_STATUS_NOT_RUNNING=0
declare -r SING_BOX_STATUS_NOT_INSTALL=255

#log file size which will trigger log clear
#here we set it as 25M
declare -r DEFAULT_LOG_FILE_DELETE_TRIGGER=25

#utils
function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function PINK() {
    echo -e "${pink} $* ${plain}"
}
function BLUE() {
    echo -e "${blue} $* ${plain}"
}

# 显示作者信息框
show_author_info() {
    # 设置作者信息
    author="Masheep"
    email="vveg26@outlook.com"
    website="https://blog.piig.top"

    # 显示作者信息框
    echo "======================================================="
    PINK " sing-box一键脚本自用版"
    echo "======================================================="
    echo "作者: $author"
    echo "邮箱: $email"
    echo "网站: $website"
    echo "油管: https://www.youtube.com/@mianyang"
    echo "项目地址: https://github.com/vveg26/sing-box-onekey"
    echo "========================================================"
}

#提示信息
show_notice() {
    local message="$1"

    PINK "###########################################################################################"
    PINK "                                                                                          "
    PINK "                        ${message}                                                      "
    PINK "                                                                                          "
    PINK "###########################################################################################"
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

#Root check
[[ $EUID -ne 0 ]] && LOGE "请使用root用户运行该脚本" && exit 1

#System check
os_check() {
    LOGI "检测当前系统中..."
    if [[ -f /etc/redhat-release ]]; then
        OS_RELEASE="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    else
        LOGE "系统检测错误,请联系脚本作者!" && exit 1
    fi
    LOGI "系统检测完毕,当前系统为:${OS_RELEASE}"
}

#arch check
arch_check() {
    LOGI "检测当前系统架构中..."
    OS_ARCH=$(arch)
    LOGI "当前系统架构为 ${OS_ARCH}"

    if [[ ${OS_ARCH} == "x86_64" || ${OS_ARCH} == "x64" || ${OS_ARCH} == "amd64" ]]; then
        OS_ARCH="amd64"
    elif [[ ${OS_ARCH} == "aarch64" || ${OS_ARCH} == "arm64" ]]; then
        OS_ARCH="arm64"
    else
        OS_ARCH="amd64"
        LOGE "检测系统架构失败，使用默认架构: ${OS_ARCH}"
    fi
    LOGI "系统架构检测完毕,当前系统架构为:${OS_ARCH}"
}

#sing-box status check,-1 means didn't install,0 means failed,1 means running
status_check() {
    if [[ ! -f "${SERVICE_FILE_PATH}" ]]; then
        return ${SING_BOX_STATUS_NOT_INSTALL}
    fi
    temp=$(systemctl status sing-box | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return ${SING_BOX_STATUS_RUNNING}
    else
        return ${SING_BOX_STATUS_NOT_RUNNING}
    fi
}

#check config provided by sing-box core
config_check() {
    if [[ ! -f "${CONFIG_FILE_PATH}/config.json" ]]; then
        LOGE "${CONFIG_FILE_PATH}/config.json 不存在,配置检查失败"
        return
    else
        info=$(${BINARY_FILE_PATH} check -c ${CONFIG_FILE_PATH}/config.json)
        if [[ $? -ne 0 ]]; then
            LOGE "配置检查失败,请查看日志"
        else
            LOGI "恭喜:配置检查通过"
        fi
    fi
}
# 设置启动脚本
set_as_entrance() {
    if [[ ! -f "${SCRIPT_FILE_PATH}" ]]; then
        wget --no-check-certificate -O ${SCRIPT_FILE_PATH} https://raw.githubusercontent.com/vveg26/sing-box-onekey/main/install.sh
        chmod +x ${SCRIPT_FILE_PATH}
    fi
}

#show sing-box status
show_status() {
    status_check
    case $? in
    0)
        show_sing_box_version
        echo -e "[INF] sing-box状态: ${yellow}未运行${plain}"
        show_enable_status
        LOGD "配置文件路径:${CONFIG_FILE_PATH}/config.json"
        LOGD "可执行文件路径:${BINARY_FILE_PATH}"
        PINK "客户端配置文件路径:${CLIENT_FILE_PATH}/"
        ;;
    1)
        show_sing_box_version
        echo -e "[INF] sing-box状态: ${green}已运行${plain}"
        show_enable_status
        show_running_status
        LOGD "配置文件路径:${CONFIG_FILE_PATH}/config.json"
        LOGD "可执行文件路径:${BINARY_FILE_PATH}"
        PINK "客户端配置文件路径:${CLIENT_FILE_PATH}/"
        ;;
    255)
        echo -e "[INF] sing-box状态: ${red}未安装${plain}"
        ;;
    esac
}

#show sing-box running status
show_running_status() {
    status_check
    if [[ $? == ${SING_BOX_STATUS_RUNNING} ]]; then
        local pid=$(pidof sing-box)
        local runTime=$(systemctl status sing-box | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        local memCheck=$(cat /proc/${pid}/status | grep -i vmrss | awk '{print $2,$3}')
        LOGI "#####################"
        LOGI "进程ID:${pid}"
        LOGI "运行时长：${runTime}"
        LOGI "内存占用:${memCheck}"
        LOGI "#####################"
    else
        LOGE "sing-box未运行"
    fi
}

#show sing-box version
show_sing_box_version() {
    LOGI "版本信息:$(${BINARY_FILE_PATH} version)"
}

#show sing-box enable status,enabled means sing-box can auto start when system boot on
show_enable_status() {
    local temp=$(systemctl is-enabled sing-box)
    if [[ x"${temp}" == x"enabled" ]]; then
        echo -e "[INF] sing-box是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] sing-box是否开机自启: ${red}否${plain}"
    fi
}

#installation path create & delete,1->create,0->delete
create_or_delete_path() {

    if [[ $# -ne 1 ]]; then
        LOGE "invalid input,should be one paremete,and can be 0 or 1"
        exit 1
    fi
    if [[ "$1" == "1" ]]; then
        LOGI "Will create ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} for sing-box..."
        rm -rf ${DOWNLAOD_PATH} ${CONFIG_FILE_PATH}
        mkdir -p ${DOWNLAOD_PATH} ${CONFIG_FILE_PATH}
        if [[ $? -ne 0 ]]; then
            LOGE "create ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} for sing-box failed"
            exit 1
        else
            LOGI "create ${DOWNLAOD_PATH} adn ${CONFIG_FILE_PATH} for sing-box success"
        fi
    elif [[ "$1" == "0" ]]; then
        LOGI "Will delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH}..."
        rm -rf ${DOWNLAOD_PATH} ${CONFIG_FILE_PATH}
        if [[ $? -ne 0 ]]; then
            LOGE "delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} failed"
            exit 1
        else
            LOGI "delete ${DOWNLAOD_PATH} and ${CONFIG_FILE_PATH} success"
        fi
    fi

}

#install some common utils
install_base() {
    if [[ ${OS_RELEASE} == "ubuntu" || ${OS_RELEASE} == "debian" ]]; then
        apt install wget tar jq iptables -y
    elif [[ ${OS_RELEASE} == "centos" ]]; then
        yum install wget tar jq iptables -y
    fi
}

# 设置默认值的函数
set_default_value() {
    local var_name=${1:?missing argument}
    local default_value=${2:?missing argument}
    local prompt=${3:?missing argument}
    read -rp "${prompt}（默认为${default_value}）：" value
    eval "${var_name}=\${value:-${default_value}}"
}

# 验证输入端口号是否被占用
validate_port() {
    local port=${1:?missing argument}
    while true; do
        if netstat -ant | grep -q ":${port} "; then
            echo "端口已被占用，请重新输入" >&2
        elif ! [[ $port =~ ^[0-9]+$ ]]; then
            echo "端口必须为数字，请重新输入" >&2
        else
            break # 跳出循环
        fi
        read -rp "请输入端口号：" port
    done
    echo "$port"
}

# 验证输入是否为空
validate_input() {
    local value=${1:?missing argument}
    while [[ -z $value ]]; do
        echo "输入不能为空，请重新输入" >&2
        read -rp "请输入值：" value
        continue
    done
    echo "$value"
}

#download sing-box  binary
download_sing-box() {
    LOGD "开始下载sing-box..."
    os_check && arch_check && install_base
    if [[ $# -gt 1 ]]; then
        echo -e "${red}invalid input,plz check your input: $* ${plain}"
        exit 1
    elif [[ $# -eq 1 ]]; then
        SING_BOX_VERSION=$1
        local SING_BOX_VERSION_TEMP="v${SING_BOX_VERSION}"
    else
        local SING_BOX_VERSION_TEMP=$(curl -Ls "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        SING_BOX_VERSION=${SING_BOX_VERSION_TEMP:1}
    fi
    LOGI "将选择使用版本:${SING_BOX_VERSION}"
    local DOWANLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/${SING_BOX_VERSION_TEMP}/sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz"

    #here we need create directory for sing-box
    create_or_delete_path 1
    wget -N --no-check-certificate -O ${DOWNLAOD_PATH}/sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz ${DOWANLOAD_URL}

    if [[ $? -ne 0 ]]; then
        LOGE "Download sing-box failed,plz be sure that your network work properly and can access github"
        create_or_delete_path 0
        exit 1
    else
        LOGI "下载sing-box成功"
    fi
}
# 拉取配置文件
# $1: 配置文件 URL
# $2: 配置文件名
# $3: 存储路径
download_config() {
    local config_url="$1"
    local config_file="$2"
    local storage_path="$3"

    if [[ ! -d "${storage_path}" ]]; then
        mkdir -p "${storage_path}"
    fi

    if [[ -f "${storage_path}/${config_file}" ]]; then
        rm "${storage_path}/${config_file}"
        LOGI "Removed existing configuration file"
    fi

    wget --no-check-certificate -O "${storage_path}/${config_file}" "${config_url}"
    if [[ $? -ne 0 ]]; then
        LOGE "下载sing-box配置模板失败，请检查网络"
        exit 1
    else
        LOGI "下载sing-box配置模板成功"
    fi
}
#backup config，this will be called when update sing-box
backup_config() {
    LOGD "开始备份sing-box配置文件..."
    if [[ ! -f "${CONFIG_FILE_PATH}/config.json" ]]; then
        LOGE "当前无可备份配置文件"
        return 0
    else
        mv ${CONFIG_FILE_PATH}/config.json ${CONFIG_BACKUP_PATH}/config.json.bak
    fi
    LOGD "备份sing-box配置文件完成"
}

#backup config，this will be called when update sing-box
restore_config() {
    LOGD "开始还原sing-box配置文件..."
    if [[ ! -f "${CONFIG_BACKUP_PATH}/config.json.bak" ]]; then
        LOGE "当前无可备份配置文件"
        return 0
    else
        mv ${CONFIG_BACKUP_PATH}/config.json.bak ${CONFIG_FILE_PATH}/config.json
    fi
    LOGD "还原sing-box配置文件完成"
}

#install sing-box,in this function we will download binary,paremete $1 will be used as version if it's given
install_sing-box() {
    set_as_entrance
    LOGD "开始安装sing-box..."
    if [[ $# -ne 0 ]]; then
        download_sing-box $1
    else
        download_sing-box
    fi
    #download_config
    if [[ ! -f "${DOWNLAOD_PATH}/sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz" ]]; then
        clear_sing_box
        LOGE "could not find sing-box packages,plz check dowanload sing-box whether suceess"
        exit 1
    fi
    cd ${DOWNLAOD_PATH}
    #decompress sing-box packages
    tar -xvf sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}.tar.gz && cd sing-box-${SING_BOX_VERSION}-linux-${OS_ARCH}

    if [[ $? -ne 0 ]]; then
        clear_sing_box
        LOGE "解压sing-box安装包失败,脚本退出"
        exit 1
    else
        LOGI "解压sing-box安装包成功"
    fi

    #install sing-box
    install -m 755 sing-box ${BINARY_FILE_PATH}

    if [[ $? -ne 0 ]]; then
        LOGE "install sing-box failed,exit"
        exit 1
    else
        LOGI "install sing-box success"
    fi
    #下载服务端配置文件
    download_config "${REMOTE_SERVER_URL}" "config.json" "${CONFIG_FILE_PATH}"
}
# 设置开机自启服务，开启sing-box
load_sing-box() {
    install_systemd_service && enable_sing-box && start_sing-box
    LOGI "安装sing-box成功,已启动成功"
}
insert_json_data() {
    local source_file=$1
    local destination_file=$2
    local field_name=$3

    # 从源文件中提取指定字段的数据
    local data=$(jq ".$field_name" "$source_file")

    # 检查目标文件中的字段是否为空数组
    local is_empty=$(jq "if .\"$field_name\" == null or .\"$field_name\" == [] then true else false end" "$destination_file")

    if [ "$is_empty" = true ]; then
        # 如果目标字段为空数组或不存在，则直接将提取数据赋值给目标字段
        jq --argjson data "$data" ".\"$field_name\" = \$data" "$destination_file" >temp.json
    else
        # 如果目标字段为非空数组，则将提取的数据追加到现有数组中
        jq --argjson data "$data" ".\"$field_name\" += \$data" "$destination_file" >temp.json
    fi

    mv temp.json "$destination_file"
}
choose_procotol() {
    echo "#############################################################"
    BLUE "#                 请选择你的协议                              #"
    echo "#############################################################"
    echo "-------------------------------------------------------------"
    echo "无需域名和证书"
    PINK " 1. 安装三合一脚本(共用端口与网站共存)"
    PINK " 2. 安装 Reality"
    PINK " 3. 安装Shadowtls v3"
    PINK " 4. 安装 NaiveProxy"
    BLUE " 5. 安装vless ws tls（可开cdn）"
    PINK " 6. 安装 TUIC v5"
    PINK " 7. 安装 Hysteria(可开启端口跳跃)"
    echo "-------------------------------------------------------------"
    echo -e " 0. 退出"
    echo ""
    read -rp "请输入选项 [0-7]: " menuChoice
    case $menuChoice in
    1) install_merge && show_merge ;;
    2) install_reality && insert_reality && show_reality ;;
    3) install_shadowtls && insert_shadowtls && show_shadowtls ;;
    4) install_naive && insert_naive && show_naive ;;
    5) install_vlessws && insert_vlessws && show_vlessws ;;
    6) install_tuic && insert_tuic && show_tuic ;;
    7) install_hysteria && insert_hysteria && show_hysteria ;;
    *) exit 1 ;;
    esac
}

get_cert_info() {

    # 申请证书的代码块
    # 申请证书
    echo -e "${pink}#######################协议证书申请方式如下：####################${plain}" >&2
    echo "" >&2
    echo " 1. 脚本自动申请（默认）" >&2
    echo " 2. 自定义证书路径" >&2
    echo "" >&2
    echo -e "${pink}##############################################################${plain}" >&2
    read -rp "请输入选项 [1-2]: " certInput
    if [[ $certInput == 2 ]]; then
        read -p "请输入公钥文件 crt 的路径：" cert
        echo "公钥文件 crt 的路径：$cert " >&2
        read -p "请输入密钥文件 key 的路径：" key
        echo "密钥文件 key 的路径：$key " >&2
        read -p "请输入证书的域名：" domain
        echo "证书域名：$domain " >&2
    else
        cert="/root/cert.crt"
        key="/root/private.key"
        if [[ -f /root/cert.crt && -f /root/private.key ]] && [[ -s /root/cert.crt && -s /root/private.key ]] && [[ -f /root/ca.log ]]; then
            domain=$(cat /root/ca.log)
            echo "  检测到原有域名：$domain 的证书，正在应用 " >&2
        else
            WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
            if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
                wg-quick down wgcf >/dev/null 2>&1
                systemctl stop warp-go >/dev/null 2>&1
                ip=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p) || ip=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
                wg-quick up wgcf >/dev/null 2>&1
                systemctl start warp-go >/dev/null 2>&1
            else
                ip=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p) || ip=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
            fi

            read -p "请输入需要申请证书的域名(例如www.domain.com)：" domain
            [[ -z $domain ]] && echo "未输入域名，无法执行操作！" >&2 && exit 1
            echo "已输入的域名：${domain} " >&2 && sleep 1
            domainIP=$(curl -sm8 ipget.net/?ip="${domain}")
            if [[ $domainIP == ${ip} ]]; then
                ${PACKAGE_INSTALL[int]} curl wget sudo socat openssl
                if [[ $SYSTEM == "CentOS" ]]; then
                    ${PACKAGE_INSTALL[int]} cronie
                    systemctl start crond
                    systemctl enable crond
                else
                    ${PACKAGE_INSTALL[int]} cron
                    systemctl start cron
                    systemctl enable cron
                fi
                curl https://get.acme.sh | sh -s email=$(date +%s%N | md5sum | cut -c 1-16)@gmail.com >&2
                source ~/.bashrc
                bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade >&2
                bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt >&2
                if [[ -n $(echo ${ip} | grep ":") ]]; then
                    bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6 --insecure >&2
                else
                    bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --insecure >&2
                fi
                bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file /root/private.key --fullchain-file /root/cert.crt --ecc >&2
                if [[ -f /root/cert.crt && -f /root/private.key ]] && [[ -s /root/cert.crt && -s /root/private.key ]]; then
                    echo $domain >/root/ca.log
                    sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
                    echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >>/etc/crontab
                    echo "  证书申请成功! 脚本申请到的证书 (cert.crt) 和私钥 (private.key) 文件已保存到 /root 文件夹下 " >&2
                    echo "  证书crt文件路径如下: /root/cert.crt " >&2
                    echo "  私钥key文件路径如下: /root/private.key " >&2
                fi
            else
                echo " 当前域名解析的IP与当前VPS使用的真实IP不匹配" >&2
                echo " 建议如下：" >&2
                echo " 1. 请确保CloudFlare小云朵为关闭状态(仅限DNS), 其他域名解析或CDN网站设置同理" >&2
                echo " 2. 请检查DNS解析设置的IP是否为VPS的真实IP" >&2
                echo " 3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问" >&2
            fi
        fi
    fi

    # 返回域名、密钥和证书的值
    printf "%s %s %s" "$domain" "$key" "$cert"
}

# getIp
getIp() {
    local serverIP=
    serverIP=$(curl -s -4 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    if [[ -z "${serverIP}" ]]; then
        serverIP=$(curl -s -6 http://www.cloudflare.com/cdn-cgi/trace | grep "ip" | awk -F "[=]" '{print $2}')
    fi
    echo "${serverIP}"
}

# install_merge
install_merge() {
    #清除hysteria端口跳跃
    clear_iptables

        
    mkdir -p "${CONFIG_FILE_PATH}/merge"
    install_shadowtls 443
    install_reality 18443 $((shadowtls_port))
    install_vlessws 17443 $((shadowtls_port))
    install_hysteria 20001
    insert_json_data ${CONFIG_FILE_PATH}/shadowtls/shadowtls_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
    insert_json_data ${CONFIG_FILE_PATH}/reality/reality_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
    insert_json_data ${CONFIG_FILE_PATH}/vlessws/vlessws_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
    insert_json_data ${CONFIG_FILE_PATH}/hysteria/hysteria_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
    
    set_default_value your_site_domain "www.domain.com" "请输入你自己的网站SNI分流"
    BLUE "网站域名：$your_site_domain"
    set_default_value your_site_port 16443 "请输入你的网站的端口号SNI分流"
    # 验证端口是否被占用并设置端口
    your_site_port=$(validate_port "$your_site_port")
    BLUE "你的网站端口号：$your_site_port"


    jq --arg your_site_domain "$your_site_domain" \
    --argjson your_site_port "$your_site_port" \
    --arg vlessws_domain "$vlessws_domain" \
    --argjson vlessws_port "$vlessws_port" \
    --arg reality_domain "$reality_domain" \
    --argjson reality_port "$reality_port" \
    '.inbounds[0].handshake_for_server_name = {
        ($your_site_domain): {
            "server": "127.0.0.1",
            "server_port": $your_site_port
        },
        ($vlessws_domain): {
            "server": "127.0.0.1",
            "server_port": $vlessws_port
        },
        ($reality_domain): {
            "server": "127.0.0.1",
            "server_port": $reality_port
        }
        }' "$CONFIG_FILE_PATH/config.json" > temp_config.json && mv temp_config.json "$CONFIG_FILE_PATH/config.json"

    cat <<EOF >${CONFIG_FILE_PATH}/merge/merge_outbounds.json
{
        "outbounds": [
        {
            "tag": "select",
            "type": "selector",
            "default": "urltest",
            "outbounds": [
                "urltest",
                "vlessws",
                "reality",
                "Shadowtls",
                "hysteria"
            ]
        },
        {
        "type": "hysteria",
        "tag": "hysteria",
        "server": "${hysteria_domain}",
        "server_port": ${2:-$((hysteria_port))},
        "up_mbps": 50,
        "down_mbps": 100,
        "auth_str": "${hysteria_auth}",
        "obfs": "${hysteria_obfs}",
        "tls": {
            "enabled": true,
            "server_name": "${hysteria_domain}",
            "alpn": [
                "h3"
            ]
        }
        },
        {
            "server": "$vlessws_domain",
            "server_port": $((shadowtls_port)),
            "tag": "vlessws",
            "tls": {
                "enabled": true,
                "server_name": "$vlessws_domain",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "transport": {
                "headers": {
                    "Host": [
                        "$vlessws_domain"
                    ]
                },
                "path": "${vlessws_path}",
                "type": "ws"
            },
            "type": "vless",
            "uuid": "$vlessws_uuid",
            "packet_encoding": "xudp"
        },
        {
            "server": "$(getIp)",
            "server_port": $((shadowtls_port)),
            "tag": "reality",
            "tls": {
                "enabled": true,
                "server_name": "${reality_domain}",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                },
                "reality": {
                    "enabled": true,
                    "public_key": "${reality_public_key}",
                    "short_id": "${reality_shortid}"
                }
            },
            "type": "vless",
            "uuid": "${reality_uuid}",
            "flow": "xtls-rprx-vision",
            "packet_encoding": "xudp"
        },
        {
            "password": "${ss_pwd}",
            "tag": "Shadowtls",
            "type": "shadowsocks",
            "method": "2022-blake3-chacha20-poly1305",
            "network": "tcp",
            "detour": "ss"
        },
        {
            "password": "${shadowtls_pwd}",
            "server": "$(getIp)",
            "server_port": $((shadowtls_port)),
            "tag": "ss",
            "tls": {
                "enabled": true,
                "server_name": "${shadowtls_domain}",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "type": "shadowtls",
            "version": 3
        },
        {
            "tag": "direct",
            "type": "direct"
        },
        {
            "tag": "block",
            "type": "block"
        },
        {
            "tag": "dns-out",
            "type": "dns"
        },
        {
            "tag": "urltest",
            "type": "urltest",
            "outbounds": [
                "vlessws",
                "reality",
                "Shadowtls",
                "hysteria"
            ]
        }
    ]
}
EOF
    download_config "${REMOTE_CLIENT_URL}" "merge_client.json" "${CLIENT_FILE_PATH}"
    insert_json_data ${CONFIG_FILE_PATH}/merge/merge_outbounds.json ${CLIENT_FILE_PATH}/merge_client.json "outbounds"
    

}
# 插入json文件
show_merge(){
    MERGE_OUTBOUNDS_FILE="${CONFIG_FILE_PATH}/merge/merge_outbounds.json"
    if [ -f "$MERGE_OUTBOUNDS_FILE" ]; then
        if [ "$#" -gt 0 ]; then
            # 如果函数带有参数，则跳过前三个函数
            show_notice "集合sing-box配置"
            cat "${CLIENT_FILE_PATH}/merge_client.json"
        else
            show_vlessws
            show_reality
            show_shadowtls
            show_hysteria
            show_notice "集合sing-box配置"
            cat "${CLIENT_FILE_PATH}/merge_client.json"
        fi
    fi

}




# hysteria入站安装
install_hysteria() {
    #清除hysteria端口跳跃
    clear_iptables
    #创建hysteria
    mkdir -p "${CONFIG_FILE_PATH}/hysteria"
    # hysteria安装
    show_notice "下面开始安装超级快的hysteria协议"
    # 设置默认值为8443
    set_default_value hysteria_port ${1:-8443} "请输入hysteria的端口号"
    # 验证端口是否被占用并设置端口
    hysteria_port=$(validate_port "$hysteria_port")
    BLUE "你的hysteria端口号：$hysteria_port"
    # 读取输入的hysteria-auth
    set_default_value hysteria_auth $(${BINARY_FILE_PATH} generate uuid) "请输入密码"
    BLUE "auth为：$hysteria_auth"
    # 读取输入的hysteria-混淆
    set_default_value hysteria_obfs $(${BINARY_FILE_PATH} generate uuid) "请输入混淆"
    BLUE "obfs为：$hysteria_obfs"
    # 调用函数并将输出赋值给变量
    # 开启端口跳跃默认为20000-50000
    # IPv4
    if confirm "是否开启端口跳跃（缓解qqos和端口封锁）" "y" ; then
        iptables -t nat -A PREROUTING -i eth0 -p udp --dport 20000:50000 -j DNAT --to-destination :$((hysteria_port))
    else
        echo "不开启端口跳跃"
    fi
    

    read -r hysteria_domain hysteria_key hysteria_cert <<<"$(get_cert_info)"

    cat <<EOF >${CONFIG_FILE_PATH}/hysteria/hysteria_inbounds.json
{
    "inbounds": [
    {
    "type": "hysteria",
    "tag": "hysteria-in",

    "sniff": true,
    "sniff_override_destination": true,

    "listen": "::",
    "listen_port": $((hysteria_port)),
    "up_mbps": 100,
    "down_mbps": 100,
    "obfs": "${hysteria_obfs}",
    "users": [
        {
            "auth_str": "${hysteria_auth}"
        }
    ],
    "tls": {
        "enabled": true,
        "alpn": [
            "h3"
        ],
        "server_name": "${hysteria_domain}",
        "certificate_path": "${hysteria_cert}",
        "key_path": "${hysteria_key}"
    }
}
]}

EOF

    cat <<EOF >${CONFIG_FILE_PATH}/hysteria/hysteria_outbounds.json
{
    "outbounds":[
    {
        "tag": "select",
        "type": "selector",
        "default": "urltest",
        "outbounds": [
            "urltest",
            "hysteria"
        ]
    },
    {
        "type": "hysteria",
        "tag": "hysteria",
        "server": "${hysteria_domain}",
        "server_port": ${2:-$((hysteria_port))},
        "up_mbps": 50,
        "down_mbps": 100,
        "auth_str": "${hysteria_auth}",
        "obfs": "${hysteria_obfs}",
        "tls": {
            "enabled": true,
            "server_name": "${hysteria_domain}",
            "alpn": [
                "h3"
            ]
        }
    },
    {
        "tag": "direct",
        "type": "direct"
    },
    {
        "tag": "block",
        "type": "block"
    },
    {
        "tag": "dns-out",
        "type": "dns"
    },
    {
        "tag": "urltest",
        "type": "urltest",
        "outbounds": [
            "hysteria"
        ]
    }
]
}

EOF

}

insert_hysteria() {
    # 调用函数将 hysteriaJson 文件的内容插入到 config.json 的 "inbounds" 数组中
    insert_json_data ${CONFIG_FILE_PATH}/hysteria/hysteria_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
    # 调用函数将 hysteriaJson 文件的内容插入到 config.json 的 "outbounds" 数组中
    download_config "${REMOTE_CLIENT_URL}" "hysteria_client.json" "${CLIENT_FILE_PATH}"
    insert_json_data ${CONFIG_FILE_PATH}/hysteria/hysteria_outbounds.json ${CLIENT_FILE_PATH}/hysteria_client.json "outbounds"
}

# 查看hysteria客户端信息
show_hysteria() {
    # 读取 JSON 文件的特定字段值
    HYSTERIA_OUTBOUNDS_FILE="${CONFIG_FILE_PATH}/hysteria/hysteria_outbounds.json"
    if [ -f "$HYSTERIA_OUTBOUNDS_FILE" ]; then
        hysteria_port=$(jq -r '.outbounds[1].server_port' "$HYSTERIA_OUTBOUNDS_FILE")
        hysteria_obfs=$(jq -r '.outbounds[1].obfs' "$HYSTERIA_OUTBOUNDS_FILE")
        hysteria_auth=$(jq -r '.outbounds[1].auth_str' "$HYSTERIA_OUTBOUNDS_FILE")
        hysteria_domain=$(jq -r '.outbounds[1].tls.server_name' "$HYSTERIA_OUTBOUNDS_FILE")
        show_notice "hysteria通用格式"
        BLUE "地址：${hysteria_domain}"
        BLUE "端口：$((hysteria_port))"
        BLUE "端口跳跃20000-50000"
        BLUE "密码auth：${hysteria_auth}"
        BLUE "混淆obfs：${hysteria_obfs}"
        show_notice "hysteria-sing-box配置"
        cat "${CLIENT_FILE_PATH}/hysteria_client.json"
        show_notice "hysteria-clash-meta配置文件"

        BLUE "proxies:"
        BLUE "  - name: hysteria"
        BLUE "    type: hysteria"
        BLUE "    server: ${hysteria_domain}"
        BLUE "    port: $((hysteria_port))"
        BLUE "    # ports: 1000,2000-3000,4000 # port 不可省略"
        BLUE "    ports: 20000-50000 # port 不可省略"
        BLUE "    auth_str: ${hysteria_auth}"
        BLUE "    auth-str: ${hysteria_auth}"
        BLUE "    obfs: ${hysteria_obfs}"
        BLUE "    alpn:"
        BLUE "      - h3"
        BLUE "    protocol: udp # 支持 udp/wechat-video/faketcp"
        BLUE "    up: \"100 Mbps\" # 若不写单位,默认为 Mbps"
        BLUE "    down: \"100 Mbps\" # 若不写单位,默认为 Mbps"
    fi


}
#清除端口跳跃
clear_iptables(){
        # 读取 JSON 文件的特定字段值
    HYSTERIA_OUTBOUNDS_FILE="${CONFIG_FILE_PATH}/hysteria/hysteria_outbounds.json"
    if [ -f "$HYSTERIA_OUTBOUNDS_FILE" ]; then
        hysteria_port=$(jq -r '.outbounds[1].server_port' "$HYSTERIA_OUTBOUNDS_FILE")
        iptables -t nat -D PREROUTING -i eth0 -p udp --dport 20000:50000 -j DNAT --to-destination :$((hysteria_port))
    fi

}
install_tuic() {
        #清除hysteria端口跳跃
    clear_iptables
    #创建tuic
    mkdir -p "${CONFIG_FILE_PATH}/tuic"

    BLUE "开始安装和前男友一样温柔的tuic"
    # 设置默认值为8443
    set_default_value tuic_port ${1:-8443} "请输入tuic的端口号"
    # 验证端口是否被占用
    tuic_port=$(validate_port "$tuic_port")
    BLUE "你的tuic端口号：$tuic_port"

    # 读取输入的tuic_pwd
    set_default_value tuic_pwd $(${BINARY_FILE_PATH} generate uuid) "请输入密码"
    BLUE "密码为：$tuic_pwd"

    set_default_value tuic_uuid $(${BINARY_FILE_PATH} generate uuid) "请输入uuid"
    BLUE "uuid为：$tuic_uuid"

    read -r tuic_domain tuic_key tuic_cert <<<"$(get_cert_info)"

    cat <<EOF >${CONFIG_FILE_PATH}/tuic/tuic_inbounds.json
{
    "inbounds": [
        {
            "type": "tuic",
            "tag": "tuic-in",
            "listen": "::",
            "listen_port": $((tuic_port)),
            "sniff": true,
            "sniff_override_destination": true,
            "users": [
                {
                    "uuid": "${tuic_uuid}",
                    "password": "${tuic_pwd}"
                }
            ],
            "congestion_control": "bbr",
            "tls": {
                "enabled": true,
                "server_name": "${tuic_domain}",
                "alpn": [
                    "h3"
                ],
                "certificate_path": "${tuic_cert}",
                "key_path": "${tuic_key}"
            }
        }
    ]}

EOF
    cat <<EOF >${CONFIG_FILE_PATH}/tuic/tuic_outbounds.json
    {"outbounds": [
        {
            "tag": "select",
            "type": "selector",
            "default": "urltest",
            "outbounds": [
                "urltest",
                "tuic"
            ]
        },
        {
            "type": "tuic",
            "tag": "tuic",
            "server": "${tuic_domain}",
            "server_port": ${2:-$((tuic_port))},
            "uuid": "${tuic_uuid}",
            "password": "${tuic_pwd}",
            "congestion_control": "bbr",
            "tls": {
                "enabled": true,
                "server_name": "${tuic_domain}",
                "alpn": [
                    "h3"
                ]
            }
        },
        {
            "tag": "direct",
            "type": "direct"
        },
        {
            "tag": "block",
            "type": "block"
        },
        {
            "tag": "dns-out",
            "type": "dns"
        },
        {
            "tag": "urltest",
            "type": "urltest",
            "outbounds": [
                "tuic"
            ]
        }
    ]}

EOF

}
insert_tuic() {
    insert_json_data ${CONFIG_FILE_PATH}/tuic/tuic_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
    download_config "${REMOTE_CLIENT_URL}" "tuic_client.json" "${CLIENT_FILE_PATH}"
    insert_json_data ${CONFIG_FILE_PATH}/tuic/tuic_outbounds.json ${CLIENT_FILE_PATH}/tuic_client.json "outbounds"
}
# 查看tuic客户端信息
show_tuic() {
    # 读取 JSON 文件的特定字段值
    TUIC_OUTBOUNDS_FILE="${CONFIG_FILE_PATH}/tuic/tuic_outbounds.json"
    if [ -f "$TUIC_OUTBOUNDS_FILE" ]; then
        tuic_port=$(jq -r '.outbounds[1].server_port' "$TUIC_OUTBOUNDS_FILE")
        tuic_uuid=$(jq -r '.outbounds[1].uuid' "$TUIC_OUTBOUNDS_FILE")
        tuic_password=$(jq -r '.outbounds[1].password' "$TUIC_OUTBOUNDS_FILE")
        tuic_domain=$(jq -r '.outbounds[1].tls.server_name' "$TUIC_OUTBOUNDS_FILE")
        show_notice "tuic通用格式"
        BLUE "地址：${tuic_domain}"
        BLUE "端口：$((tuic_port))"
        BLUE "uuid：${tuic_auth}"
        BLUE "password：${tuic_obfs}"
        BLUE "alpn: h3"
        BLUE "congestion-controller：bbr"
        BLUE "udp-relay-mode: native"
        show_notice "sing-box配置"
        cat "${CLIENT_FILE_PATH}/tuic_client.json"
        show_notice "clash-meta配置文件"
        tuic_clash=$(
        cat <<EOF
proxies:
  - name: tuic
    server: \${tuic_domain}
    port: \$((tuic_port))
    type: tuic
    uuid: \${tuic_uuid}
    password: \${tuic_pwd}
    alpn: [h3]
    disable-sni: true
    reduce-rtt: true
    request-timeout: 8000
    udp-relay-mode: native
    congestion-controller: bbr
EOF
    )

    echo "$tuic_clash"
    fi



}

install_naive() {
        #清除hysteria端口跳跃
    clear_iptables
    #创建naive
    mkdir -p "${CONFIG_FILE_PATH}/naive"

    BLUE "开始安装和出差在家的老婆一样性感的naiveproxy"
    # 设置默认值为443
    set_default_value naive_port ${1:-443} "请输入naive的端口号"
    # 验证端口是否被占用
    naive_port=$(validate_port "$naive_port")
    BLUE "你的naive端口号：$naive_port"
    set_default_value naive_username $(${BINARY_FILE_PATH} generate uuid) "请输入用户名"
    BLUE "用户名为：$naive_username"
    # 读取输入的naive_pwd
    set_default_value naive_pwd $(${BINARY_FILE_PATH} generate uuid) "请输入密码"
    BLUE "密码为：$naive_pwd"

    read -r naive_domain naive_key naive_cert <<<"$(get_cert_info)"

    cat <<EOF >${CONFIG_FILE_PATH}/naive/naive_inbounds.json
{
    "inbounds": [
        {
            "type": "naive",
            "tag": "naive-in",
            "listen_port": $((naive_port)),
            "sniff": true,
            "sniff_override_destination": true,
            "users": [
                {
                    "username": "${naive_username}",
                    "password": "${naive_pwd}"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "${naive_domain}",
                "certificate_path": "${naive_cert}",
                "key_path": "${naive_key}"
            }
        }
    ]}

EOF

    # 判断文件是否存在并移除旧文件
    if [ -f "${CLIENT_FILE_PATH}/naive.json" ]; then
        rm "${CLIENT_FILE_PATH}/naive.json"
    fi

    echo '{
        "listen": "socks://127.0.0.1:1080",
        "proxy": "https://'${naive_username}':'${naive_pwd}'@'${naive_domain}':'${naive_port}'"
    }' | tee "${CLIENT_FILE_PATH}/naive.json"
    show_notice "安装完成"
}
insert_naive() {
    insert_json_data ${CONFIG_FILE_PATH}/naive/naive_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
}
show_naive() {

    if [ -f "${CONFIG_FILE_PATH}/naive.json" ]; then
        show_notice "naiveproxy配置文件"
        echo ""
        echo -e "${red}！！！注意 naive没有sing-box出站，请使用naive自己的客户端${plain}"
        echo -e "${red}客户端下载地址：https://github.com/klzgrad/naiveproxy/releases${plain}"
        show_notice "配置如下"
        echo -e "naiveproxy json配置，存储于${yellow} ${CONFIG_FILE_PATH}/naive.json ${plain}中 "
        cat "${CONFIG_FILE_PATH}/naive.json"
    fi


}

install_vlessws() {
        #清除hysteria端口跳跃
    clear_iptables
    mkdir -p ${CONFIG_FILE_PATH}/vlessws

    BLUE "开始安装准备淘汰了的协议了vless ws tls"
    # 设置默认值为443
    set_default_value vlessws_port ${1:-443} "请输入vlessws的端口号"
    # 验证端口是否被占用
    vlessws_port=$(validate_port "$vlessws_port")
    BLUE "你的vlessws端口号：$vlessws_port"
    set_default_value vlessws_username $(${BINARY_FILE_PATH} generate uuid) "请输入用户名"
    BLUE "用户名为：$vlessws_username"
    # 读取输入的vlessws_uuid
    set_default_value vlessws_uuid $(${BINARY_FILE_PATH} generate uuid) "请输入uuid"
    BLUE "密码为：$vlessws_uuid"
    # 读取输入的vlessws_path
    set_default_value vlessws_path "masheep" "请输入ws path"
    BLUE "密码为：$vlessws_path"

    read -r vlessws_domain vlessws_key vlessws_cert <<<"$(get_cert_info)"
    cat <<EOF >${CONFIG_FILE_PATH}/vlessws/vlessws_inbounds.json
{
    "inbounds": [
        {   
            "sniff": true,
            "sniff_override_destination": true,
            "type": "vless",
            "tag": "vless-in",
            "listen": "0.0.0.0",
            "listen_port": $((vlessws_port)),
            "users": [
                {
                    "name": "${vlessws_username}",
                    "uuid": "${vlessws_uuid}",
                    "flow": ""
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "${vlessws_domain}",
                "min_version": "1.3",
                "certificate_path": "${vlessws_cert}",
                "key_path": "${vlessws_key}"
            },
            "transport": {
                "type": "ws",
                "path": "${vlessws_path}",
                "early_data_header_name": "Sec-WebSocket-Protocol"
            }
        }
    ]}

EOF

    cat <<EOF >${CONFIG_FILE_PATH}/vlessws/vlessws_outbounds.json
{
    "outbounds": [
        {
            "tag": "select",
            "type": "selector",
            "default": "urltest",
            "outbounds": [
                "urltest",
                "vlessws"
            ]
        },
        {
            "server": "${vlessws_domain}",
            "server_port": ${2:-$((vlessws_port))},
            "tag": "vlessws",
            "tls": {
                "enabled": true,
                "server_name": "${vlessws_domain}",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "transport": {
                "headers": {
                    "Host": [
                        "${vlessws_domain}"
                    ]
                },
                "path": "${vlessws_path}",
                "type": "ws"
            },
            "type": "vless",
            "uuid": "${vlessws_uuid}",
            "packet_encoding": "xudp"
        },
        {
            "tag": "direct",
            "type": "direct"
        },
        {
            "tag": "block",
            "type": "block"
        },
        {
            "tag": "dns-out",
            "type": "dns"
        },
        {
            "tag": "urltest",
            "type": "urltest",
            "outbounds": [
                "vlessws"
            ]
        }
    ]
}

EOF

}
insert_vlessws() {
    
    download_config "${REMOTE_CLIENT_URL}" "vlessws_client.json" "${CLIENT_FILE_PATH}"
    insert_json_data ${CONFIG_FILE_PATH}/vlessws/vlessws_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
    insert_json_data ${CONFIG_FILE_PATH}/vlessws/vlessws_outbounds.json ${CLIENT_FILE_PATH}/vlessws_client.json "outbounds"
}
show_vlessws() {
    # 读取 JSON 文件的特定字段值
    VLESSWS_OUTBOUNDS_FILE="${CONFIG_FILE_PATH}/vlessws/vlessws_outbounds.json"
    if [ -f "$VLESSWS_OUTBOUNDS_FILE" ]; then
        vlessws_port=$(jq -r '.outbounds[1].server_port' "$VLESSWS_OUTBOUNDS_FILE")
        vlessws_uuid=$(jq -r '.outbounds[1].uuid' "$VLESSWS_OUTBOUNDS_FILE")
        vlessws_path=$(jq -r '.outbounds[1].transport.path' "$VLESSWS_OUTBOUNDS_FILE")
        vlessws_domain=$(jq -r '.outbounds[1].tls.server_name' "$VLESSWS_OUTBOUNDS_FILE")
        wslink="${vlessws_uuid}@${vlessws_domain}:${vlessws_port}?encryption=none&security=tls&sni=${vlessws_domain}&alpn=h2%2Chttp%2F1.1&fp=chrome&type=ws&host=${vlessws_domain}&path=/${vlessws_path}#singboxvless"
        show_notice "vless ws tls通用配置参数"
        echo "协议：vless"
        echo "地址：${vlessws_domain}"
        echo "端口：$((vlessws_port))"
        echo "UUID：${vlessws_uuid}"
        echo "加密方式：none"
        echo "传输协议：ws"
        echo "路径：/${vlessws_path}"
        echo "底层传输：tls"
        show_notice "vless ws tls 通用链接格式"
        echo "vless://${wslink}"
        show_notice "sing-box配置文件"
        cat "${CLIENT_FILE_PATH}/vlessws_client.json"
        show_notice "vless ws tls clash-meta配置文件"
        vlessws_clash=$(
        cat <<EOF
proxies:
  - {name: vlessws, server: ${vlessws_domain}, port: $((vlessws_port)), client-fingerprint: chrome, type: vless, uuid: $vlessws_uuid, tls: true, tfo: false, servername: $vlessws_domain, skip-cert-verify: false, network: ws, ws-opts: {path: /$vlessws_path, headers: {Host: $vlessws_domain}}}
EOF
    )

        echo "$vlessws_clash"
    fi

}
#install shadowtls
install_shadowtls() {
        #清除hysteria端口跳跃
    clear_iptables
    # 客户端文件夹
    mkdir -p ${CONFIG_FILE_PATH}/shadowtls

    BLUE "开始安装和女朋友前男友一样神秘的shadowtls"
    # 设置默认值为443
    set_default_value shadowtls_port ${1:-443} "请输入shadowtls的端口号"
    # 验证端口是否被占用
    shadowtls_port=$(validate_port "$shadowtls_port")
    BLUE "你的shadowtls端口号：$shadowtls_port"

    set_default_value shadowtls_username $(${BINARY_FILE_PATH} generate uuid) "请输入用户名"
    BLUE "用户名为：$shadowtls_username"
    # 读取输入的shadowtls_uuid
    set_default_value shadowtls_uuid $(${BINARY_FILE_PATH} generate uuid) "请输入uuid"
    BLUE "密码为：$shadowtls_uuid"

    # 读取输入的shadowtls_pwd
    set_default_value shadowtls_pwd $(${BINARY_FILE_PATH} generate rand --base64 32) "请输入shadowtls密码"
    BLUE "密码为：$shadowtls_pwd"

    # 读取输入的ss_pwd
    set_default_value ss_pwd $(${BINARY_FILE_PATH} generate rand --base64 32) "请输入ss密码"
    BLUE "密码为：$ss_pwd"
    # 读取输入的域名
    set_default_value shadowtls_domain www.apple.com "请输入偷取的域名"
    BLUE "密码为：$shadowtls_domain"

    cat <<EOF >${CONFIG_FILE_PATH}/shadowtls/shadowtls_inbounds.json
{
    "inbounds": [
        {
            "type": "shadowtls",
            "tag": "st-in",
            "listen": "::",
            "listen_port": $((shadowtls_port)),
            "sniff": true,
            "sniff_override_destination": true,
            "version": 3,
            "users": [
                {
                    "name": "$shadowtls_username",
                    "password": "$shadowtls_pwd"
                }
            ],
            "handshake": {
                "server": "$shadowtls_domain",
                "server_port": 443
            },
            "handshake_for_server_name": {},
            "strict_mode": true,
            "detour": "ss-in"
        },
        {
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "127.0.0.1",
            "network": "tcp",
            "method": "2022-blake3-chacha20-poly1305",
            "password": "$ss_pwd"
        }
    ]
}

EOF

    cat <<EOF >${CONFIG_FILE_PATH}/shadowtls/shadowtls_outbounds.json
{
        "outbounds": [
        {
            "tag": "select",
            "type": "selector",
            "default": "urltest",
            "outbounds": [
                "urltest",
                "ShadowTLS v3"
            ]
        },
        {
            "password": "$ss_pwd",
            "tag": "ShadowTLS v3",
            "type": "shadowsocks",
            "method": "2022-blake3-chacha20-poly1305",
            "network": "tcp",
            "detour": "ss"
        },
        {
            "password": "$shadowtls_pwd",
            "server": "$(getIp)",
            "server_port": ${2:-$((shadowtls_port))},
            "tag": "ss",
            "tls": {
                "enabled": true,
                "server_name": "$shadowtls_domain",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "type": "shadowtls",
            "version": 3
        },
        {
            "tag": "direct",
            "type": "direct"
        },
        {
            "tag": "block",
            "type": "block"
        },
        {
            "tag": "dns-out",
            "type": "dns"
        },
        {
            "tag": "urltest",
            "type": "urltest",
            "outbounds": [
                "ShadowTLS v3"
            ]
        }
    ]
}

EOF

}
insert_shadowtls() {
    
    download_config "${REMOTE_CLIENT_URL}" "shadowtls_client.json" "${CLIENT_FILE_PATH}"
    insert_json_data ${CONFIG_FILE_PATH}/shadowtls/shadowtls_outbounds.json ${CLIENT_FILE_PATH}/shadowtls_client.json "outbounds"
    insert_json_data ${CONFIG_FILE_PATH}/shadowtls/shadowtls_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
}
show_shadowtls() {
    # 读取 JSON 文件的特定字段值
    SHADOWTLS_OUTBOUNDS_FILE="${CONFIG_FILE_PATH}/shadowtls/shadowtls_outbounds.json"
    if [ -f "$SHADOWTLS_OUTBOUNDS_FILE" ]; then
        shadowtls_port=$(jq -r '.outbounds[2].server_port' "$SHADOWTLS_OUTBOUNDS_FILE")
        shadowtls_pwd=$(jq -r '.outbounds[2].password' "$SHADOWTLS_OUTBOUNDS_FILE")
        ss_pwd=$(jq -r '.outbounds[1].password' "$SHADOWTLS_OUTBOUNDS_FILE")
        shadowtls_domain=$(jq -r '.outbounds[2].tls.server_name' "$SHADOWTLS_OUTBOUNDS_FILE")

        show_notice "shadowtls sing-box配置文件"
        cat "${CLIENT_FILE_PATH}/shadowtls_client.json"
        show_notice "shadowtls clash-meta配置文件"
        shadowtls_clash=$(
        cat <<EOF
proxies:
  - name: ShadowTLS v3
    type: ss
    server: $(getIp)
    port: $((shadowtls_port))
    cipher: 2022-blake3-chacha20-poly1305
    password: "$ss_pwd"
    plugin: shadow-tls
    client-fingerprint: chrome
    plugin-opts:
        host: "$shadowtls_domain"
        password: "$shadowtls_pwd"
        version: 3
EOF
    )

        echo "$shadowtls_clash"
    fi

}

install_reality() {
        #清除hysteria端口跳跃
    clear_iptables
    # 创建配置文件
    mkdir -p ${CONFIG_FILE_PATH}/reality

    # 读取输入的reality端口号

    BLUE "开始安装和小情人一样神秘的reality"
    # 设置默认值为443
    set_default_value reality_port ${1:-443} "请输入reality的端口号"
    # 验证端口是否被占用
    reality_port=$(validate_port "$reality_port")
    BLUE "你的reality端口号：$reality_port"

    # 读取输入的reality_pwd
    set_default_value reality_domain "www.lovelive-anime.jp" "请输入偷取的域名"
    BLUE "偷取的域名为：$reality_domain"

    set_default_value reality_uuid $(${BINARY_FILE_PATH} generate uuid) "请输入uuid"
    BLUE "uuid为：$reality_uuid"

    read -r reality_private_key reality_public_key <<<"$(${BINARY_FILE_PATH} generate reality-keypair | awk '/PrivateKey/ {private=$2} /PublicKey/ {public=$2} END {print private, public}')"
    PINK "private和publickey已经生成"
    # 读取输入的reality shortid
    # read -p "请输入reality shortid（默认为随机生成）：" reality_shortid
    reality_shortid=${reality_shortid:-$(openssl rand -hex 8)}
    PINK "shortid为 $reality_shortid"

    cat <<EOF >${CONFIG_FILE_PATH}/reality/reality_inbounds.json
{
    "inbounds": [
        {
        "type": "vless",
        "tag": "vless-in",
        "listen": "::",
        "listen_port": $((reality_port)),
        "sniff": true,
        "sniff_override_destination": true, 
        "users": [
            {
            "uuid": "$reality_uuid", 
            "flow": "xtls-rprx-vision"
            }
        ],
        "tls": {
            "enabled": true,
            "server_name": "$reality_domain", 
            "reality": {
            "enabled": true,
            "handshake": {
                "server": "$reality_domain", 
                "server_port": 443
            },
            "private_key": "$reality_private_key", 
            "short_id": [ 
                "$reality_shortid" 
            ]
            }
        }
        }
    ]
}

EOF

    cat <<EOF >${CONFIG_FILE_PATH}/reality/reality_outbounds.json
{
    "outbounds": [
        {
            "tag": "select",
            "type": "selector",
            "default": "urltest",
            "outbounds": [
                "urltest",
                "reality"

            ]
        },
        {
            "server": "$(getIp)",
            "server_port": ${2:-$((reality_port))},
            "tag": "reality",
            "tls": {
                "enabled": true,
                "server_name": "$reality_domain",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                },
                "reality": {
                    "enabled": true,
                    "public_key": "$reality_public_key",
                    "short_id": "$reality_shortid"
                }
            },
            "type": "vless",
            "uuid": "$reality_uuid",
            "flow": "xtls-rprx-vision",
            "packet_encoding": "xudp"
        },
        {
            "tag": "direct",
            "type": "direct"
        },
        {
            "tag": "block",
            "type": "block"
        },
        {
            "tag": "dns-out",
            "type": "dns"
        },
        {
            "tag": "urltest",
            "type": "urltest",
            "outbounds": [
                "reality"
            ]
        }
    ]
}

EOF

}
insert_reality() {
    
    download_config "${REMOTE_CLIENT_URL}" "reality_client.json" "${CLIENT_FILE_PATH}"
    insert_json_data ${CONFIG_FILE_PATH}/reality/reality_inbounds.json ${CONFIG_FILE_PATH}/config.json "inbounds"
    insert_json_data ${CONFIG_FILE_PATH}/reality/reality_outbounds.json ${CLIENT_FILE_PATH}/reality_client.json "outbounds"
}
show_reality() {

    # 读取 JSON 文件的特定字段值
    REALITY_OUTBOUNDS_FILE="${CONFIG_FILE_PATH}/reality/reality_outbounds.json"
    if [ -f "$REALITY_OUTBOUNDS_FILE" ]; then
        reality_port=$(jq -r '.outbounds[1].server_port' "$REALITY_OUTBOUNDS_FILE")
        reality_uuid=$(jq -r '.outbounds[1].uuid' "$REALITY_OUTBOUNDS_FILE")
        reality_public_key=$(jq -r '.outbounds[1].tls.reality.public_key' "$REALITY_OUTBOUNDS_FILE")
        reality_shortid=$(jq -r '.outbounds[1].tls.reality.short_id' "$REALITY_OUTBOUNDS_FILE")
        reality_domain=$(jq -r '.outbounds[1].tls.server_name' "$REALITY_OUTBOUNDS_FILE")

        show_notice "reality sing-box配置文件"
        cat "${CLIENT_FILE_PATH}/reality_client.json"
        show_notice "reality clash-meta配置文件"
        reality_clash=$(
        cat <<EOF
proxies:
  - name: reality
    type: vless
    server: $(getIp)
    port: ${reality_port}
    uuid: ${reality_uuid}
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: ${reality_domain}
    client-fingerprint: chrome
    reality-opts:
        public-key: ${reality_public_key}
        short-id: ${reality_shortid}

EOF
    )
        echo "$reality_clash"
        link="${reality_uuid}@$(getIp):$((reality_port))?security=reality&flow=xtls-rprx-vision&fp=chrome&pbk=${reality_public_key}&sni=${reality_domain}&spx=%2F&sid=${reality_shortid}#VLESS-XTLS-uTLS-REALITY"

        show_notice "reality通用配置参数"
        PINK "地址：$(getIp)"
        PINK "端口：${reality_port}"
        PINK "uuid：${reality_uuid}"
        PINK "TLS：true"
        PINK "xtls：xtls-rprx-vision"
        PINK "sni：${reality_domain}"
        PINK "publickey：${reality_public_key}"
        PINK "shortid：${reality_shortid}"

        show_notice "reality通用链接格式"
        PINK "vless://${link}"
    fi


}
#update sing-box
update_sing-box() {
    LOGD "开始更新sing-box..."
    if [[ ! -f "${SERVICE_FILE_PATH}" ]]; then
        LOGE "当前系统未安装sing-box,请在安装sing-box的前提下使用更新命令"
        show_menu
    fi
    #here we need back up config first,and then restore it after installation
    backup_config
    #get the version paremeter
    if [[ $# -ne 0 ]]; then
        install_sing-box $1 && load_sing-box
    else
        install_sing-box && load_sing-box
    fi
    restore_config
    if ! systemctl restart sing-box; then
        LOGE "update sing-box failed,please check logs"
        show_menu
    else
        LOGI "update sing-box success"
    fi
}

clear_sing_box() {
    LOGD "开始清除sing-box..."
    create_or_delete_path 0 && rm -rf ${SERVICE_FILE_PATH} && rm -rf ${BINARY_FILE_PATH} && rm -rf ${SCRIPT_FILE_PATH}
    LOGD "清除sing-box完毕"
}

#uninstall sing-box
uninstall_sing-box() {
    #清除hysteria端口跳跃
    clear_iptables
    LOGD "开始卸载sing-box..."
    pidOfsing_box=$(pidof sing-box)
    if [ -n ${pidOfsing_box} ]; then
        stop_sing-box
    fi
    clear_sing_box

    if [ $? -ne 0 ]; then
        LOGE "卸载sing-box失败,请检查日志"
        exit 1
    else
        LOGI "卸载sing-box成功"
    fi
}

#install systemd service
install_systemd_service() {
    LOGD "开始安装sing-box systemd服务..."
    if [ -f "${SERVICE_FILE_PATH}" ]; then
        rm -rf ${SERVICE_FILE_PATH}
    fi
    #create service file
    touch ${SERVICE_FILE_PATH}
    if [ $? -ne 0 ]; then
        LOGE "create service file failed,exit"
        exit 1
    else
        LOGI "create service file success..."
    fi
    cat >${SERVICE_FILE_PATH} <<EOF
[Unit]
Description=sing-box Service
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target
Wants=network.target
[Service]
Type=simple
ExecStart=${BINARY_FILE_PATH} run -c ${CONFIG_FILE_PATH}/config.json
Restart=on-failure
RestartSec=30s
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
    chmod 644 ${SERVICE_FILE_PATH}
    systemctl daemon-reload
    LOGD "安装sing-box systemd服务成功"
}

#start sing-box
start_sing-box() {
    if [ -f "${SERVICE_FILE_PATH}" ]; then
        systemctl start sing-box
        sleep 1s
        status_check
        if [ $? == ${SING_BOX_STATUS_NOT_RUNNING} ]; then
            LOGE "start sing-box service failed,exit"
            exit 1
        elif [ $? == ${SING_BOX_STATUS_RUNNING} ]; then
            LOGI "start sing-box service success"
        fi
    else
        LOGE "${SERVICE_FILE_PATH} does not exist,can not start service"
        exit 1
    fi
}

#restart sing-box
restart_sing-box() {
    if [ -f "${SERVICE_FILE_PATH}" ]; then
        systemctl restart sing-box
        sleep 1s
        status_check
        if [ $? == 0 ]; then
            LOGE "restart sing-box service failed,exit"
            exit 1
        elif [ $? == 1 ]; then
            LOGI "restart sing-box service success"
        fi
    else
        LOGE "${SERVICE_FILE_PATH} does not exist,can not restart service"
        exit 1
    fi
}

#stop sing-box
stop_sing-box() {
    LOGD "开始停止sing-box服务..."
    status_check
    if [ $? == ${SING_BOX_STATUS_NOT_INSTALL} ]; then
        LOGE "sing-box did not install,can not stop it"
        exit 1
    elif [ $? == ${SING_BOX_STATUS_NOT_RUNNING} ]; then
        LOGI "sing-box already stoped,no need to stop it again"
        exit 1
    elif [ $? == ${SING_BOX_STATUS_RUNNING} ]; then
        if ! systemctl stop sing-box; then
            LOGE "stop sing-box service failed,plz check logs"
            exit 1
        fi
    fi
    LOGD "停止sing-box服务成功"
}

#enable sing-box will set sing-box auto start on system boot
enable_sing-box() {
    systemctl enable sing-box
    if [[ $? == 0 ]]; then
        LOGI "设置sing-box开机自启成功"
    else
        LOGE "设置sing-box开机自启失败"
    fi
}

#disable sing-box
disable_sing-box() {
    systemctl disable sing-box
    if [[ $? == 0 ]]; then
        LOGI "取消sing-box开机自启成功"
    else
        LOGE "取消sing-box开机自启失败"
    fi
}

#show logs
show_log() {
    status_check
    if [[ $? == ${SING_BOX_STATUS_NOT_RUNNING} ]]; then
        journalctl -u sing-box.service -e --no-pager -f
    else
        local disabled=$(cat ${CONFIG_FILE_PATH}/config.json | jq .log.disabled | tr -d '"')

        if [[ ${disabled} == "true" ]]; then
            LOGI "当前未开启日志,请确认配置"
            exit 1
        else
            local filePath=$(cat ${CONFIG_FILE_PATH}/config.json | jq .log.output | tr -d '"')
            if [[ ! -n ${filePath} || ! -f ${filePath} ]]; then
                LOGE "日志${filePath}不存在,查看sing-box日志失败"
                exit 1
            else
                LOGI "日志文件路径:${DEFAULT_LOG_FILE_SAVE_PATH}"
                tail -f ${DEFAULT_LOG_FILE_SAVE_PATH} -s 3
            fi
        fi
    fi
}

#clear log,the paremter is log file path
clear_log() {
    local filePath=''
    if [[ $# -gt 0 ]]; then
        filePath=$1
    else
        read -p "请输入日志文件路径": filePath
        if [[ ! -n ${filePath} ]]; then
            LOGI "输入的日志文件路径无效,将使用默认的文件路径"
            filePath=${DEFAULT_LOG_FILE_SAVE_PATH}
        fi
    fi
    LOGI "日志路径为:${filePath}"
    if [[ ! -f ${filePath} ]]; then
        LOGE "清除sing-box 日志文件失败,${filePath}不存在,请确认"
        exit 1
    fi
    fileSize=$(ls -la ${filePath} --block-size=M | awk '{print $5}' | awk -F 'M' '{print$1}')
    if [[ ${fileSize} -gt ${DEFAULT_LOG_FILE_DELETE_TRIGGER} ]]; then
        rm $1 && systemctl restart sing-box
        if [[ $? -ne 0 ]]; then
            LOGE "清除sing-box 日志文件失败"
        else
            LOGI "清除sing-box 日志文件成功"
        fi
    else
        LOGI "当前日志大小为${fileSize}M,小于${DEFAULT_LOG_FILE_DELETE_TRIGGER}M,将不会清除"
    fi
}

#enable auto delete log，need file path as
enable_auto_clear_log() {
    LOGI "设置sing-box 定时清除日志..."
    local disabled=false
    disabled=$(cat ${CONFIG_FILE_PATH}/config.json | jq .log.disabled | tr -d '"')
    if [[ ${disabled} == "true" ]]; then
        LOGE "当前系统未开启日志,将直接退出脚本"
        exit 0
    fi
    local filePath=''
    if [[ $# -gt 0 ]]; then
        filePath=$1
    else
        filePath=$(cat ${CONFIG_FILE_PATH}/config.json | jq .log.output | tr -d '"')
    fi
    if [[ ! -f ${filePath} ]]; then
        LOGE "${filePath}不存在,设置sing-box 定时清除日志失败"
        exit 1
    fi
    crontab -l >/tmp/crontabTask.tmp
    echo "0 0 * * 6 sing-box clear ${filePath}" >>/tmp/crontabTask.tmp
    crontab /tmp/crontabTask.tmp
    rm /tmp/crontabTask.tmp
    LOGI "设置sing-box 定时清除日志${filePath}成功"
}

#disable auto dlete log
disable_auto_clear_log() {
    crontab -l | grep -v "sing-box clear" | crontab -
    if [[ $? -ne 0 ]]; then
        LOGI "取消sing-box 定时清除日志失败"
    else
        LOGI "取消sing-box 定时清除日志成功"
    fi
}

#enable bbr
enable_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
}



#for cert issue
ssl_cert_issue() {
    bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/BashScripts/main/SSLAutoInstall/SSLAutoInstall.sh)
}

# enable warp
enable_warp() {


    if [ -f "${CONFIG_FILE_PATH}/config.json" ]; then
        mkdir -p ${CONFIG_FILE_PATH}/warp
        output=$(curl -sLo warp-reg https://github.com/badafans/warp-reg/releases/download/v1.0/main-linux-${OS_ARCH} && chmod +x warp-reg && ./warp-reg && rm warp-reg)

        v6=$(echo "$output" | grep -oP 'v6:\s*\K[^ ]+')
        private_key=$(echo "$output" | grep -oP 'private_key:\s*\K[^ ]+')
        public_key=$(echo "$output" | grep -oP 'public_key:\s*\K[^ ]+')
        reserved=$(echo "$output" | grep -oP 'reserved:\s*\K\[.*?\]' | tr -d '[:space:]')
        curl -sLo /root/warp "https://api.zeroteam.top/warp?format=sing-box" > /dev/null && grep -Eo --color=never '"2606:4700:[0-9a-f:]+/128"|"private_key":"[0-9a-zA-Z\/+]+="|"reserved":\[[0-9]+(,[0-9]+){2}\]' warp && rm warp
        #替换warp规则
        BLUE "不想写全局warp，就写了个简单的流媒体解锁，具体能不能用不保证"
        cat <<EOF >${CONFIG_FILE_PATH}/warp/warp_rules.json
    {
        "route": {
            "rules": [
                {
                    "geosite": "cn",
                    "geoip": "cn",
                    "outbound": "warp-IPv4-out"
                },
                {
                    "geosite": "category-ads-all",
                    "outbound": "block"
                },
                {
                    "geosite": [
                        "openai","netflix","hulu","disney"
                    ],
                    "domain": [
                        "whatismyipaddress.com"
                    ],
                    "outbound": "warp-IPv4-out"}
            ]
        }

    }

EOF
        insert_json_data ${CONFIG_FILE_PATH}/warp/warp_rules.json ${CONFIG_FILE_PATH}/config.json "route"

        #TODO outbounds
        cat <<EOF >${CONFIG_FILE_PATH}/warp/warp_outbounds.json
{
            "outbounds": [{
            "type": "direct",
            "tag": "warp-IPv4-out",
            "detour": "wireguard-out",
            "domain_strategy": "ipv4_only"
        },
        {
            "type": "direct",
            "tag": "warp-IPv6-out",
            "detour": "wireguard-out",
            "domain_strategy": "ipv6_only"
        },
        {
            "type": "wireguard",
            "tag": "wireguard-out",
            "server": "engage.cloudflareclient.com",
            "server_port": 2408,
            "local_address": [
                "172.16.0.2/32",
                "${v6}/128"
            ],
            "private_key": "${private_key}",
            "peer_public_key": "${public_key}",
            "reserved": ${reserved}, 
            "mtu": 1280
        }]
}
EOF
        insert_json_data ${CONFIG_FILE_PATH}/warp/warp_outbounds.json ${CONFIG_FILE_PATH}/config.json "outbounds"

    else
        echo "请先安装sing-box再安装warp"
    fi


}
#展示订阅
show_procotol(){
    show_hysteria
    show_naive
    show_reality
    show_shadowtls
    show_tuic
    show_vlessws
    show_merge "$@"
}
edit_config(){
    show_notice "本方式为直接打开配置文件进行修改"
    PINK "配置文件为路径：${CONFIG_FILE_PATH}/config.json"
    PINK "服务端配置文件参考：https://github.com/malikshi/sing-box-examples"
    BLUE "本仓库配置文件备份：https://github.com/vveg26/sing-box-onekey"
    PINK "直接编辑 ${CONFIG_FILE_PATH}/config.json 将配置文件复制进去即可"
}
#show help
show_help() {
    echo "sing-box-onekey-v${SING_BOX_ONEKEY_VERSION} 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "sing-box-onekey              - 显示快捷菜单 (功能更多)"
    echo "sing-box-onekey start        - 启动 sing-box服务"
    echo "sing-box-onekey stop         - 停止 sing-box服务"
    echo "sing-box-onekey restart      - 重启 sing-box服务"
    echo "sing-box-onekey status       - 查看 sing-box 状态"
    echo "sing-box-onekey enable       - 设置 sing-box 开机自启"
    echo "sing-box-onekey disable      - 取消 sing-box 开机自启"
    echo "sing-box-onekey log          - 查看 sing-box 日志"
    echo "sing-box-onekey clear        - 清除 sing-box 日志"
    echo "sing-box-onekey update       - 更新 sing-box 服务"
    echo "sing-box-onekey install      - 安装 sing-box 服务"
    echo "sing-box-onekey uninstall    - 卸载 sing-box 服务"
    echo "------------------------------------------"
}



#show menu
show_menu() {
    # 显示内容
    # 调用函数显示作者信息框
    show_author_info
    status_check
    is_install=""
    if [[ $? == ${SING_BOX_STATUS_RUNNING} ]]; then
        is_install="重新"
    fi
    echo -e "
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} ${is_install}安装 sing-box 服务
  ${green}2.${plain} 更新 sing-box 服务
  ${green}3.${plain} 卸载 sing-box 服务
  ${green}4.${plain} 启动 sing-box 服务
  ${green}5.${plain} 停止 sing-box 服务
  ${green}6.${plain} 重启 sing-box 服务
  ${green}7.${plain} 查看 sing-box 状态
  ${green}8.${plain} 查看 sing-box 日志
  ${green}9.${plain} 清除 sing-box 日志
  ${green}A.${plain} 检查 sing-box 配置
————————————————
  ${green}B.${plain} 设置 sing-box 开机自启
  ${green}C.${plain} 取消 sing-box 开机自启
  ${green}D.${plain} 设置 sing-box 定时清除日志&重启
  ${green}E.${plain} 取消 sing-box 定时清除日志&重启
————————————————
  ${green}F.${plain} 一键开启 bbr 
  ${green}G.${plain} 一键申请SSL证书
  ${green}H.${plain} 开启warp解锁流媒体
  ${green}I.${plain} 查看安装的协议
————————————————
  ${green}J.${plain} 手动修改配置文件（改端口，改协议等）
 "
    show_status
    echo && read -p "请输入选择[0-I]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_sing-box && choose_procotol && load_sing-box && show_menu
        ;;
    2)
        update_sing-box && show_menu
        ;;
    3)
        uninstall_sing-box && show_menu
        ;;
    4)
        start_sing-box && show_menu
        ;;
    5)
        stop_sing-box && show_menu
        ;;
    6)
        restart_sing-box && show_menu
        ;;
    7)
        show_menu
        ;;
    8)
        show_log && show_menu
        ;;
    9)
        clear_log && show_menu
        ;;
    A)
        config_check && show_menu
        ;;
    B)
        enable_sing-box && show_menu
        ;;
    C)
        disable_sing-box && show_menu
        ;;
    D)
        enable_auto_clear_log
        ;;
    E)
        disable_auto_clear_log
        ;;
    F)
        enable_bbr && show_menu
        ;;
    G)
        ssl_cert_issue
        ;;
    H)
        enable_warp && restart_sing-box && show_menu
        ;;
    I)
        show_procotol
        ;;
    J)
        edit_config
        ;;
    *)
        LOGE "请输入正确的选项 [0-J]"
        ;;
    esac
}

start_to_run() {
    set_as_entrance
    clear
    show_menu
}

main() {
    if [[ $# > 0 ]]; then
        case $1 in
        "start")
            start_sing-box
            ;;
        "stop")
            stop_sing-box
            ;;
        "restart")
            restart_sing-box
            ;;
        "status")
            show_status
            ;;
        "enable")
            enable_sing-box
            ;;
        "disable")
            disable_sing-box
            ;;
        "log")
            show_log
            ;;
        "clear")
            clear_log
            ;;
        "update")
            if [[ $# == 2 ]]; then
                update_sing-box $2
            else
                update_sing-box
            fi
            ;;
        "install")
            if [[ $# == 2 ]]; then
                install_sing-box $2 && choose_procotol && load_sing-box
            else
                install_sing-box && choose_procotol && load_sing-box
            fi
            ;;
        "uninstall")
            uninstall_sing-box
            ;;
        *) show_help ;;
        esac
    else
        start_to_run
    fi
}

main $*
