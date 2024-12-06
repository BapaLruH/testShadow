#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
blue() { echo -e "\033[36m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
# check root
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

[[ $EUID -ne 0 ]] && echo -e "${red}error: ${plain}  You must use the root user to run this script！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /etc/system-release-cpe | grep -Eqi "amazon_linux"; then
    release="amazon_linux"
else
    echo -e "${red}The system version is not detected, please contact the script author！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or later system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use a system of Debian 8 or later！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"amazon_linux" ]]; then
    if [[ ${os_version} -lt 2 ]]; then
        echo -e "${red}Please use Amazon Linux 2 or later system！${plain}\n" && exit 1
    fi
fi

xrayui() {
    cat >/root/xrayuil.sh <<-\EOF
#!/bin/bash
xui=`ps -aux |grep "xray-ui" |grep -v "grep" |wc -l`
xray=`ps -aux |grep "xray-linux" |grep -v "grep" |wc -l`
sleep 1
if [ $xui = 0 ];then
xray-ui restart
fi
if [ $xray = 0 ];then
xray-ui restart
fi
EOF
    chmod +x /root/xrayuil.sh
    sed -i '/xrayuil.sh/d' /etc/crontab >/dev/null 2>&1
    echo "*/1 * * * * root bash /root/xrayuil.sh >/dev/null 2>&1" >>/etc/crontab
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [default$2]: " temp
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

confirm_restart() {
    confirm "Whether to restart the panel, the restart panel will also restart xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    wget -N https://raw.githubusercontent.com/BapaLruH/testShadow/main/install.sh && bash install.sh
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "arch: $(arch)"

update() {
    confirm "This function will force the current latest version to be reinstalled, and the data will not be lost. Whether to continue or not?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}cancelled${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    if [[ x"${release}" == x"centos" ]]; then
        setenforce 0 >/dev/null 2>&1
    fi
    systemctl stop xray-ui
    curl -sS -H "Accept: application/vnd.github.v3+json" -o "/tmp/tmp_file" 'https://api.github.com/repos/qist/xray-ui/releases/latest'
    releases_version=($(sed 'y/,/\n/' "/tmp/tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}'))
    rm /tmp/tmp_file -f
    mkdir -p /tmp/xray
    cd /tmp/xray
    if [ $# == 0 ]; then
        wget --no-check-certificate -O /tmp/xray/xray-ui-linux-$(arch).tar.gz https://github.com/qist/xray-ui/releases/download/${releases_version}/xray-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading xray-ui failed, please make sure your server can download the Github file${plain}"
            rm -f install.sh
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/qist/xray-ui/releases/download/${releases_version}/xray-ui-linux-$(arch).tar.gz"
        echo -e "Start installing xray-ui v$1"
        wget --no-check-certificate -O /tmp/xray/xray-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download xray-ui v$1, please make sure this version exists${plain}"
            rm -f install.sh
            exit 1
        fi
    fi
    if [[ -e /usr/local/xray-ui/xray-ui ]]; then
        rm /usr/local/xray-ui/xray-ui -f
        rm /usr/local/xray-ui/xray-ui.service -f
    fi
    tar zxvf xray-ui-linux-$(arch).tar.gz
    mv /tmp/xray/xray-ui/{xray-ui,xray-ui.service} /usr/local/xray-ui/
    rm /tmp/xray -rf
    cd /usr/local/xray-ui
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi
    chmod +x xray-ui bin/xray-linux-$(arch)
    \cp -f xray-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/xray-ui https://raw.githubusercontent.com/BapaLruH/testShadow/main/xray-ui.sh
    chmod +x /usr/bin/xray-ui
    #chmod +x /usr/local/xray-ui/xray-ui.sh
    systemctl daemon-reload
    systemctl enable xray-ui
    systemctl start xray-ui
    xray-ui restart
    echo -e "${green}The update is complete and the panel has been automatically restarted${plain}"
    acp=$(/usr/local/xray-ui/xray-ui setting -show 2>/dev/null)
    green "$acp"
    exit 0
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel, xray will also uninstall?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop xray-ui
    systemctl disable xray-ui
    rm /etc/systemd/system/xray-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/xray-ui/ -rf
    rm /usr/local/xray-ui/ -rf
    rm -f /root/xrayuil.sh
    sed -i '/xrayuil.sh/d' /etc/crontab >/dev/null 2>&1
    sed -i '/xray-ui restart/d' /etc/crontab >/dev/null 2>&1
    sed -i '/xray-ui geoip/d' /etc/crontab >/dev/null 2>&1
    rm /usr/bin/xray-ui -f
    green "xray-ui Successfully uninstalled, see you later！"
}

reset_user() {
    confirm "Are you sure you want to reset the user name and password to random 6-digit characters?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    uauto=$(date +%s%N | md5sum | cut -c 1-6)
    username=$uauto
    pauto=$(date +%s%N | md5sum | cut -c 1-6)
    password=$pauto
    /usr/local/xray-ui/xray-ui setting -username ${username} -password ${password} >/dev/null 2>&1
    green "xray-ui username：${username}"
    green "xray-ui password：${password}"
    confirm_restart
}

generate_random_string() {
    local n=$1
    # 定义数字、大写字母和小写字母的集合
    local characters='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

    # 生成随机字符并限制在指定字符集中
    # 从 /dev/urandom 生成随机字节，使用 tr 进行过滤
    local random_string=$(cat /dev/urandom | tr -dc "$characters" | fold -w "$n" | head -n 1)

    echo "$random_string"
}


reset_path() {
    confirm "Are you sure you want to randomize the access path by 10 characters?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    path_random=$(generate_random_string 10)
    /usr/local/xray-ui/xray-ui setting -webBasePath ${path_random} >/dev/null 2>&1
    green "xray-ui path：${path_random}"
    confirm_restart
}

reset_cert() {
    confirm "Are you sure you want to reset the certificate?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    LOGD "Please enter the certificate path:"
    read -p "Enter your certificate path:" Xray_cert
    LOGD "The certificate path is:${Xray_cert}"
    LOGD "Please enter the key path:"
    read -p "Enter your key path:" Xray_Key
    LOGD "Your key is:${Xray_Key}"
    /usr/local/xray-ui/xray-ui cert -webCert "${Xray_cert}" -webCertKey "${Xray_Key}"
    confirm_restart
}

reset_mTLS() {
    confirm "Are you sure you want to reset the certificate?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    LOGD "Please enter the certificate path:"
    read -p "Enter your certificate path:" Xray_cert
    LOGD "The certificate path is:${Xray_cert}"
    LOGD "Please enter the key path:"
    read -p "Enter your key path:" Xray_Key
    LOGD "Your key is:${Xray_Key}"
    LOGD "Please enter the CA path:"
    read -p "Enter your CA path:" Xray_Ca
    LOGD "Your CA is:${Xray_Ca}"
    /usr/local/xray-ui/xray-ui cert -webCert "${Xray_cert}" -webCertKey "${Xray_Key}" -webCa "${Xray_Ca}"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings? The account data will not be lost, and the user name and password will not be changed." "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/xray-ui/xray-ui setting -reset
    echo -e "All panel settings have been reset to the default values, now please restart the panel and use the default ${green}54321${plain} port to access the panel"
    confirm_restart
}

check_config() {
    info=$(/usr/local/xray-ui/xray-ui setting -show true)
    if [[ $? != 0 ]]; then
        echo -e "get current settings error,please check logs"
        show_menu
    fi
    green "${info}"
}

set_port() {
    echo && echo -n -e "Input port number [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}Cancelled${plain}"
        before_show_menu
    else
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\n The port is occupied, please re-enter the port" && readp "Custom xray-ui port:" port
        done
        /usr/local/xray-ui/xray-ui setting -port ${port} >/dev/null 2>&1
        echo -e "After setting up the port, please restart the panel now and use the newly set port ${green}${port}${plain} to access the panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}The panel is already running and there is no need to start again. If you need to restart, please select restart.${plain}"
    else
        systemctl start xray-ui
        xrayui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}xray-ui Successful startup${plain}"
        else
            echo -e "${red}The panel failed to start, probably because the startup time exceeded two seconds, please check the log information later${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}The panel has stopped, no need to stop again${plain}"
    else
        systemctl stop xray-ui
        rm -f /root/xrayuil.sh
        sed -i '/xrayuil.sh/d' /etc/crontab >/dev/null 2>&1
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}xray-ui stopped successfully with xray${plain}"
        else
            echo -e "${red}The panel failed to stop, and the xray-ui daemon was stopped... Please check it again in a minute, please check the log information later${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart xray-ui
    xrayui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}xray-ui successfully restarted with xray${plain}"
    else
        echo -e "${red}The panel failed to restart, probably because the startup time exceeded two seconds, please check the log information later${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status xray-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable xray-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}xray-ui Set the boot to start successfully${plain}"
    else
        echo -e "${red}xray-ui Failed to set the boot to self-start${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable xray-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}xray-ui Cancel the boot and start successfully${plain}"
    else
        echo -e "${red}xray-ui Failed to cancel the boot and self-start${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u xray-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/xray-ui/xray-ui v2-ui

    before_show_menu
}

x25519() {
    arch=$(arch)
    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        arch="arm64"
    elif [[ $arch == "s390x" ]]; then
        arch="s390x"
    else
        arch="amd64"
    fi
    /usr/local/xray-ui/bin/xray-linux-$(arch) x25519
    echo ""
    exit 0
}

geoip() {
    pushd /usr/local/xray-ui
    ./xray-ui geoip
    echo "Restart and reload the update file"
    systemctl restart xray-ui
    echo ""
    exit 0
}

crontab() {
    sed -i '/xray-ui geoip/d' /etc/crontab
    echo "30 1 * * * root xray-ui geoip >/dev/null 2>&1" >>/etc/crontab
    echo -e ""
    blue "Add regular updates to geoip to scheduled tasks, which are executed by default at 1.30am every day"
    exit 0
}

update_shell() {
    wget --no-check-certificate -O /usr/bin/xray-ui https://raw.githubusercontent.com/BapaLruH/testShadow/main/xray-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}The download script failed, please check whether this function is connected Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/xray-ui
        echo -e "${green}The upgrade script was successful, please re-run the script${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/xray-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status xray-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled xray-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}The panel is installed, please do not repeat the installation${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Please install the panel first${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "xray-ui panel status: ${green}already running${plain}"
        show_enable_status
        ;;
    1)
        echo -e "xray-ui panel status: ${yellow}not running${plain}"
        show_enable_status
        ;;
    2)
        echo -e "xray-ui panel status: ${red}not installed${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to turn on and off: ${green}yes${plain}"
    else
        echo -e "Whether to turn on and off: ${red}No${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray status: ${green}run${plain}"
    else
        echo -e "xray status: ${red}not running${plain}"
    fi
}


install_acme() {
    cd ~
    LOGI "Installing acme..."
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        LOGE "acme Installation failed"
        return 1
    else
        LOGI "acme Successful installation"
    fi
    return 0
}

ssl_cert_issue_main() {
    echo -e "${green}\t1.${plain} Get SSL"
    echo -e "${green}\t2.${plain} Revocation of certificate"
    echo -e "${green}\t3.${plain} Compulsory renewal"
    echo -e "${green}\t0.${plain} Back to main menu"
    read -p "Please select an option: " choice
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        ssl_cert_issue
        ;;
    2)
        local domain=""
        read -p "Please enter the domain name where you want to revoke the certificate: " domain
        ~/.acme.sh/acme.sh --revoke -d ${domain}
        LOGI "Certificate revoked"
        ;;
    3)
        local domain=""
        read -p "Please enter the domain name you want to force renewal: " domain
        ~/.acme.sh/acme.sh --renew -d ${domain} --force
        ;;
    *) echo "Invalid option" ;;
    esac
}

ssl_cert_issue() {
    # 首先检查是否安装了 acme.sh
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo "Not found acme.sh , Will be installed"
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "acme Installation failed, please check the log"
            exit 1
        fi
    fi
    # 安装 socat
    case "${release}" in
    ubuntu | debian | armbian)
        apt update && apt install socat -y
        ;;
    centos | almalinux | rocky | oracle)
        yum -y update && yum -y install socat
        ;;
    fedora)
        dnf -y update && dnf -y install socat
        ;;
    arch | manjaro | parch)
        pacman -Sy --noconfirm socat
        ;;
    *)
        echo -e "${red}Unsupported operating system, please install the necessary software packages manually${plain}\n"
        exit 1
        ;;
    esac
    if [ $? -ne 0 ]; then
        LOGE "socat Installation failed, please check the log"
        exit 1
    else
        LOGI "socat Successful installation..."
    fi

    # 获取域名并验证
    local domain=""
    read -p "Please enter your domain name:" domain
    LOGD "Your domain name is:${domain}，Checking..."
    # 判断是否已经存在证书
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')

    if [ ${currentCert} == ${domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        LOGE "The certificate for the domain name already exists in the system and cannot be issued repeatedly. Details of the current certificate:"
        LOGI "$certInfo"
        exit 1
    else
        LOGI "Your domain name can be issued with a certificate..."
    fi

    # 创建存放证书的目录
    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    # 获取需要使用的端口
    local WebPort=80
    read -p "Please select the port to use, the default is port 80:" WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        LOGE "The port number entered is invalid, the default port will be used"
    fi
    LOGI "Will use the port:${WebPort} For certificate issuance, please make sure this port is open..."
    # 用户需手动处理开放端口及结束占用进程
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --listen-v6 --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        LOGE "Certificate issuance failed, please check the log"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGE "The certificate was issued successfully and the certificate is being installed..."
    fi
    # 安装证书
    ~/.acme.sh/acme.sh --installcert -d ${domain} \
        --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${domain}.cer \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem

    if [ $? -ne 0 ]; then
        LOGE "Certificate installation failed, exit"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "The certificate is successfully installed and automatic renewal is turned on..."
        LOGE "Finally, remember to configure the certificate for xray-ui, select 22 to reset the ssl certificate"
    fi

    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        LOGE "Automatic renewal failed, the certificate details are as follows:"
        ls -lah cert/*
        chmod 755 $certPath/*
        exit 1
    else
        LOGI "The automatic renewal is successful, the details of the certificate are as follows:"
        ls -lah cert/*
        chmod 755 $certPath/*
    fi
}
 
ssl_cert_issue_CF() {
    echo -E ""
    LOGD "******Instructions for use******"
    LOGI "This Acme script requires the following information:"
    LOGI "1. Cloudflare Registered email"
    LOGI "2. Cloudflare Global API key"
    LOGI "3. The domain name that has resolved DNS to the current server"
    LOGI "4. The default installation path after the certificate is applied for is /root/cert "
    confirm "Confirmation information?[y/n]" "y"
    if [ $? -eq 0 ]; then
        # 首先检查是否安装了 acme.sh
        if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
            echo "Not found acme.sh , Will be installed"
            install_acme
            if [ $? -ne 0 ]; then
                LOGE "acme Installation failed, please check the log"
                exit 1
            fi
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "Please enter the domain name:"
        read -p "Enter your domain name:" CF_Domain
        LOGD "The domain name is set to:${CF_Domain}"
        LOGD "Please enter the API key:"
        read -p "Enter your key:" CF_GlobalKey
        LOGD "Your API key is:${CF_GlobalKey}"
        LOGD "Please enter the registered email address:"
        read -p "Enter your email:" CF_AccountEmail
        LOGD "Your registered email address is:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "The default CA setting is Lets'encrypt failed, and the script exits..."
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "The certificate issuance failed and the script exits..."
            exit 1
        else
            LOGI "The certificate was issued successfully and is being installed..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
            --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
            --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "The certificate installation failed and the script exits..."
            exit 1
        else
            LOGI "The certificate is successfully installed and automatic update is turned on..."
            LOGE "Finally, remember to configure the certificate for xray-ui, select 22 to reset the ssl certificate"
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "The automatic update setting failed and the script exits..."
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "The certificate has been installed and automatic renewal is turned on. The specific information is as follows:"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
    echo "xray-ui How to use management scripts: "
    echo "------------------------------------------"
    echo "xray-ui              - Display the management menu"
    echo "xray-ui start        - Start the xray-ui panel"
    echo "xray-ui stop         - Stop the xray-ui pane"
    echo "xray-ui restart      - Restart the xray-ui panel"
    echo "xray-ui status       - View xray-ui status"
    echo "xray-ui enable       - Set xray-ui to boot and start"
    echo "xray-ui disable      - Cancel xray-ui boot and start"
    echo "xray-ui log          - View xray-ui log"
    echo "xray-ui v2-ui        - Migrate the v2-ui account data of this machine to xray-ui"
    echo "xray-ui update       - Update the xray-ui panel"
    echo "xray-ui geoip        - Update geoip ip library"
    echo "xray-ui update_shell - Update xray-ui script"
    echo "xray-ui install      - Install the xray-ui panel"
    echo "xray-ui x25519       - REALITY key generation"
    echo "xray-ui ssl_main     - SSL certificate management"
    echo "xray-ui ssl_CF       - Cloudflare SSL certificate"
    echo "xray-ui crontab      - Add geoip to the task plan to be executed at 1.30am every day"
    echo "xray-ui uninstall    - Uninstall the xray-ui panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}xray-ui Panel management script${plain}
  ${green}0.${plain} Exit script
————————————————
  ${green}1.${plain} Install xray-ui
  ${green}2.${plain} Update xray-ui
  ${green}3.${plain} Uninstall xray-ui
————————————————
  ${green}4.${plain} Reset username and password
  ${green}5.${plain} Reset panel settings
  ${green}6.${plain} Set the panel port
  ${green}7.${plain} Current panel settings
————————————————
  ${green}8.${plain} Start xray-ui
  ${green}9.${plain} Stop xray-ui
  ${green}10.${plain} Restart xray-ui
  ${green}11.${plain} View xray-ui status
  ${green}12.${plain} View xray-ui log
————————————————
  ${green}13.${plain} Set up xray-ui boot self-starting
  ${green}14.${plain} Cancel xray-ui boot self-starting
————————————————
  ${green}15.${plain} xray REALITY x25519 generate
  ${green}16.${plain} update xray-ui script
  ${green}17.${plain} update geoip ip library
  ${green}18.${plain} Add geoip to task schedule
  ${green}19.${plain} SSL Certificate management
  ${green}20.${plain} Cloudflare SSL certificate
  ${green}21.${plain} Reset the web path
  ${green}22.${plain} Reset ssl certificate
  ${green}23.${plain} Reset mTLS certificate
 "
    show_status
    echo "------------------------------------------"
    acp=$(/usr/local/xray-ui/xray-ui setting -show 2>/dev/null)
    green "$acp"
    tlsx=$(/usr/local/xray-ui/xray-ui setting -show 2>&1 | grep Certificate file)
    if [ -z "${tlsx}" ]; then
    yellow "The current panel http only supports 127.0.0.1 access. If you access it from outside, please use ssh forwarding or nginx proxy or xray-ui to configure the certificate. Select 22 to configure the certificate."
    yellow "ssh Forward client operation ssh-f-N-L 127.0.0.1:22222 (ssh proxy port unused port): 127.0.0.1:54321 (xray-ui port) root@8.8.8.8 (xray-ui server ip)"
    yellow "Browser access http://127.0.0.1:22222 (ssh proxy port unused port)/path (web access path)"
    fi
    echo "------------------------------------------"
    uiV=$(/usr/local/xray-ui/xray-ui -v)
    curl -sS -H "Accept: application/vnd.github.v3+json" -o "/tmp/tmp_file" 'https://api.github.com/repos/qist/xray-ui/releases/latest'
    remoteV=($(sed 'y/,/\n/' "/tmp/tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}'))
    rm /tmp/tmp_file -f
    localV=${uiV}
    if [ "${localV}" = "${remoteV}" ]; then
        green "The latest version is installed：${uiV} ，If there is an update, it will be automatically prompted here"
    else
        green "Currently installed version：${uiV}"
        yellow "The latest version is detected：${remoteV} ，You can choose 2 to update！"
    fi

    echo && read -p "Please enter a selection [0-23]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        x25519
        ;;
    16)
        update_shell
        ;;
    17)
        geoip
        ;;
    18)
        crontab
        ;;
    19)
        ssl_cert_issue_main
        ;;
    20)
        ssl_cert_issue_CF
        ;;
    21)
        check_install && reset_path
        ;;
    22)
        check_install && reset_cert
        ;;
    23)
        check_install && reset_mTLS
        ;;
    *)
        echo -e "${red}Please enter the correct number [0-23]${plain}"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "x25519")
        x25519 0
        ;;
    "update_shell")
        update_shell 0
        ;;
    "geoip")
        geoip 0
        ;;
    "crontab")
        crontab 0
        ;;
    "ssl_main")
        ssl_cert_issue_main 0
        ;;
    "ssl_CF")
        ssl_cert_issue_CF 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
