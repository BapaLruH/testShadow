#!/bin/bash
curl -sS -H "Accept: application/vnd.github.v3+json" -o "/tmp/tmp_file" 'https://api.github.com/repos/qist/xray-ui/releases/latest'
releases_version=($(sed 'y/,/\n/' "/tmp/tmp_file" | grep 'tag_name' | awk -F '"' '{print $4}'))
rm /tmp/tmp_file -f
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
bblue='\033[0;34m'
plain='\033[0m'

red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
blue() { echo -e "\033[36m\033[01m$1\033[0m"; }
white() { echo -e "\033[37m\033[01m$1\033[0m"; }
readp() { read -p "$(yellow "$1")" $2; }
remoteV=${releases_version}
clear
white "Github project  ：github.com/qist/xray-ui"
yellow "Thanks to xray-ui code contributors（vaxilu）"
green "Current installed version： $remoteV"
yellow "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
sleep 2
cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error：${plain} You must use the root user to run this script！\n" && exit 1

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

sys() {
    [ -f /etc/os-release ] && grep -i pretty_name /etc/os-release | cut -d \" -f2 && return
    [ -f /etc/lsb-release ] && grep -i description /etc/lsb-release | cut -d \" -f2 && return
    [ -f /etc/redhat-release ] && awk '{print $0}' /etc/redhat-release && return
}
op=$(sys)
version=$(uname -r | awk -F "-" '{print $1}')
vi=$(systemd-detect-virt)
white "VPS operating system: $(blue "$op") \c" && white " Kernel version: $(blue "$version") \c" && white " CPU architecture : $(blue "$arch") \c" && white " Type of virtualization: $(blue "$vi")"
sleep 2

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit systems (x86), please use 64-bit systems (x86_64), if the detection is incorrect, please contact the author"
    exit -1
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
ports=$(/usr/local/xray-ui/xray-ui 2>&1 | grep tcp | awk '{print $5}' | sed "s/://g")
if [[ -n $ports ]]; then
    green "After testing, xray-ui has been installed"
    echo
    acp=$(/usr/local/xray-ui/xray-ui setting -show 2>/dev/null)
    green "$acp"
    echo
    readp "Whether to reinstall xray-ui directly, please enter the Y/y key and enter.If you do not reinstall, enter the N/n key and enter to exit the script):" ins
    if [[ $ins = [Yy] ]]; then
        systemctl stop xray-ui
        systemctl disable xray-ui
        rm /etc/systemd/system/xray-ui.service -f
        systemctl daemon-reload
        systemctl reset-failed
        rm /etc/xray-ui/ -rf
        rm /usr/local/xray-ui/ -rf
        rm -rf /root/rayuil.sh /root/acme.sh
        sed -i '/xrayuil.sh/d' /etc/crontab
        sed -i '/xray-ui restart/d' /etc/crontab
    else
        exit 1
    fi
fi
install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        if [[ ${os_version} =~ 8 ]]; then
            yum clean all && yum makecache
        fi
        yum install epel-release -y && yum install wget curl tar gzip lsof -y

        setenforce 0 >/dev/null 2>&1
    else
        apt update && apt install wget curl tar lsof gzip -y
    fi
}
generate_random_string() {
    local n=$1
    # Define a collection of numbers, uppercase letters, and lowercase letters
    local characters='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

    # Generate random characters and limit them to the specified character set
    # Generate random bytes from /dev/urandom, use tr to filter
    local random_string=$(cat /dev/urandom | tr -dc "$characters" | fold -w "$n" | head -n 1)

    echo "$random_string"
}

install_xray-ui() {
    systemctl stop xray-ui
    cd /usr/local/
    if [ $# == 0 ]; then
        wget --no-check-certificate -O /usr/local/xray-ui-linux-$(arch).tar.gz https://github.com/qist/xray-ui/releases/download/${releases_version}/xray-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading xray-ui failed, please make sure your server can download the Github file${plain}"
            rm -f install.sh
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/qist/xray-ui/releases/download/${releases_version}/xray-ui-linux-$(arch).tar.gz"
        echo -e "Start installation xray-ui v$1"
        wget  --no-check-certificate -O /usr/local/xray-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download xray-ui v$1, please make sure this version exists${plain}"
            rm -f install.sh
            exit 1
        fi
    fi

    if [[ -e /usr/local/xray-ui/ ]]; then
        rm /usr/local/xray-ui/ -rf
    fi

    tar -zxvf xray-ui-linux-$(arch).tar.gz
    rm xray-ui-linux-$(arch).tar.gz -f
    cd xray-ui
    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi   
    chmod +x xray-ui bin/xray-linux-$(arch)
    cp -f xray-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/xray-ui https://raw.githubusercontent.com/BapaLruH/testShadow/main/xray-ui.sh
    chmod +x /usr/bin/xray-ui
    systemctl daemon-reload
    systemctl enable xray-ui
    systemctl start xray-ui
    sleep 2
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
    sed -i '/xrayuil.sh/d' /etc/crontab
    echo "*/1 * * * * root bash /root/xrayuil.sh >/dev/null 2>&1" >>/etc/crontab
    sed -i '/xray-ui restart/d' /etc/crontab
    echo "0 1 1 * *  root xray-ui restart >/dev/null 2>&1" >>/etc/crontab
    sleep 1
    echo -e ""
    blue "The following settings are recommended to be customized to prevent the account password path and port from being leaked"
    echo -e ""
    readp "Set the xray-ui login user name (enter to skip to random 6 characters)：" username
    if [[ -z ${username} ]]; then
        uauto=$(date +%s%N | md5sum | cut -c 1-6)
        username=$uauto
    fi
    sleep 1
    green "xray-ui username：${username}"
    echo -e ""
    readp "Set the xray-ui login password (enter and skip to random 6 characters)：" password
    if [[ -z ${password} ]]; then
        pauto=$(date +%s%N | md5sum | cut -c 1-6)
        password=$pauto
    fi
    green "xray-ui password：${password}"
    /usr/local/xray-ui/xray-ui setting -username ${username} -password ${password} >/dev/null 2>&1
    sleep 1
    echo -e ""
    readp "Set the xray-ui login port [1-65535] (enter to skip to a random port between 2000-65535)：" port
    if [[ -z $port ]]; then
        port=$(shuf -i 2000-65535 -n 1)
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\nThe port is occupied, please re-enter the port" && readp "Custom xray-ui port:" port
        done
    else
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]] && yellow "\nThe port is occupied, please re-enter the port" && readp "Custom xray-ui port:" port
        done
    fi
    /usr/local/xray-ui/xray-ui setting -port $port >/dev/null 2>&1
    green "xray-ui port：${port}"
    sleep 1
    echo -e ""
    readp "Set the xray-ui web path (enter and skip to random 10 characters)：" path
    if [[ -z ${path} ]]; then
        path=$(generate_random_string 10)
    fi
    /usr/local/xray-ui/xray-ui setting -webBasePath $path >/dev/null 2>&1
    green "xray-ui web path：${path}"
    sleep 1
    xray-ui restart
    xuilogin() {
        v4=$(curl -s4m8 http://ip.sb -k)
        v6=$(curl -s6m8 http://ip.sb -k)
        if [[ -z $v4 ]]; then
            int="${green}Please copy in the browser address bar${plain}  ${bblue}[$v6]:$ports/$path${plain}  ${green}Enter the xray-ui login interface \n current xray-ui login user name：${plain}${bblue}${username}${plain}${green} \nCurrent xray-ui login password：${plain}${bblue}${password}${plain}"
        elif [[ -n $v4 && -n $v6 ]]; then
            int="${green}Please copy in the browser address bar${plain}  ${bblue}$v4:$ports/$path${plain}  ${yellow}or${plain}  ${bblue}[$v6]:$ports/$path${plain}  ${green}Enter the xray-ui login interface \n current xray-ui login user name：${plain}${bblue}${username}${plain}${green} \nCurrent xray-ui login password：${plain}${bblue}${password}${plain}"
        else
            int="${green}Please copy in the browser address bar${plain}  ${bblue}$v4:$ports/$path${plain}  ${green}Enter the xray-ui login interface \n current xray-ui login user name：${plain}${bblue}${username}${plain}${green} \nCurrent xray-ui login password：${plain}${bblue}${password}${plain}"
        fi
    }
ssh_forwarding() {
    # 获取 IPv4 和 IPv6 地址
    v4=$(curl -s4m8 http://ip.sb -k)
    v6=$(curl -s6m8 http://ip.sb -k)

    echo -e ""
    read -p "Set the xray-ui ssh forwarding port [1-65535] (enter to skip to a random port between 2000-65535)：" ssh_port

    # If no port is entered, a port between 2000-65535 is randomly generated
    if [[ -z $ssh_port ]]; then
        ssh_port=$(shuf -i 2000-65535 -n 1)
    fi

    # Check if the port is occupied until an unoccupied port is found
    while [[ -n $(ss -ntlp | awk '{print $4}' | grep -w ":$ssh_port") ]]; do
        echo -e "\nport $ssh_port Occupied, please re-enter the port"
        read -p "Custom xray-ui ssh forwarding port:" ssh_port
        if [[ -z $ssh_port ]]; then
            ssh_port=$(shuf -i 2000-65535 -n 1)
        fi
    done

    # Check the IP and output the corresponding SSH and browser access information
    if [[ -z $v4 ]]; then
        # echo -e "${green}请在 xray-ui 服务器系统输入${plain} ${bblue}ssh  -f -N -L [::]:$ssh_port:127.0.0.1:$ports root@127.0.0.1${plain} 输入 root 密码进行转发 不建议使用"
        # echo -e "${green}请在浏览器地址栏复制${plain} ${bblue}[$v6]:$ssh_port/$path${plain} ${green}进入 xray-ui 登录界面"
        echo -e "${green}High client forwarding security${plain} ${bblue}ssh  -f -N -L [::]:$ssh_port:127.0.0.1:$ports root@[$v6]${plain} Enter the root password for forwarding"
        echo -e "${green}Please copy in the browser address bar${plain} ${bblue}[::1]:$ssh_port/$path${plain} ${green}Enter the xray-ui login interface"
        echo -e "${green}Current xray-ui login user name：${plain}${bblue}${username}${plain}"
        echo -e "${green}Current xray-ui login password：${plain}${bblue}${password}${plain}"
        yellow "If you do not use ssh forwarding, please configure the nginx https proxy or xray-ui configuration certificate"
    elif [[ -n $v4 && -n $v6 ]]; then
        # echo -e "${green}请在  xray-ui 服务器系统输入${plain} ${bblue}ssh  -f -N -L 0.0.0.0:$ssh_port:127.0.0.1:$ports root@127.0.0.1${plain} ${yellow}或者 ${bblue}ssh  -f -N -L [::]:$ssh_port:127.0.0.1:$ports root@127.0.0.1${plain} 输入 root 密码进行转发 不建议使用"
        # echo -e "${green}请在浏览器地址栏复制${plain} ${bblue}$v4:$ssh_port/$path${plain} ${yellow}或者${plain} ${bblue}[$v6]:$ssh_port/$path${plain} ${green}进入 xray-ui 登录界面"
        echo -e "${green}High client forwarding security ${plain} ${bblue}ssh  -f -N -L 0.0.0.0:$ssh_port:127.0.0.1:$ports root@$v4${plain} ${yellow}or ${bblue}ssh  -f -N -L [::]:$ssh_port:127.0.0.1:$ports root@[$v6]${plain} Enter the root password for forwarding"
        echo -e "${green}Please copy in the browser address bar${plain} ${bblue}127.0.0.1:$ssh_port/$path${plain} ${yellow}or${plain} ${bblue}[::1]:$ssh_port/$path${plain} ${green}进入 xray-ui 登录界面"
        echo -e "${green}Current xray-ui login user name：${plain}${bblue}${username}${plain}"
        echo -e "${green}Current xray-ui login password：${plain}${bblue}${password}${plain}"
        yellow "If you do not use ssh forwarding, please configure the nginx https proxy or xray-ui configuration certificate"
    else
        # echo -e "${green}请在  xray-ui 服务器系统输入${plain} ${bblue}ssh  -f -N -L 0.0.0.0:$ssh_port:127.0.0.1:$ports root@127.0.0.1${plain} 输入 root 密码进行转发 "
        # echo -e "${green}请在浏览器地址栏复制${plain} ${bblue}$v4:$ssh_port/$path${plain} ${green}进入 xray-ui 登录界面"
        echo -e "${green}High client forwarding security${plain} ${bblue}ssh  -f -N -L 0.0.0.0:$ssh_port:127.0.0.1:$ports root@$v4${plain} Enter the root password for forwarding"
        echo -e "${green}Please copy in the browser address bar${plain} ${bblue}127.0.0.1:$ssh_port/$path${plain} ${green}Enter the xray-ui login interface"
        echo -e "${green}Current xray-ui login user name：${plain}${bblue}${username}${plain}"
        echo -e "${green}Current xray-ui login password：${plain}${bblue}${password}${plain}"
        yellow "If you do not use ssh forwarding, please configure the nginx https proxy or xray-ui configuration certificate"
    fi
    }
    ports=$(/usr/local/xray-ui/xray-ui 2>&1 | grep "tcp" | awk '{print $5}' | cut -d':' -f2)
    if [[ -n $ports ]]; then
        echo -e ""
        yellow "xray-ui $remoteV The installation is successful, please wait 3 seconds, detect the IP environment, and output the xray-ui login information……"
        ssh_forwarding
        yellow "The following is the xray-ui tls mTLS configuration information"
        yellow "Certificate management xray-ui ssl_main cf certificate application xray-ui ssl_CF"
        yellow "TLS configuration/usr/local/xray-ui/xray-ui cert-webCert/root/cert/your domain name/full chain.pem-webCertKey /root/cert/your domain name/privkey.pem restart xray-ui restart takes effect"
        yellow "mTLS configuration/usr/local/xray-ui/xray-ui cert-webCert/root/cert/your domain name/full chain.pem-webCertKey /root/cert/your domain name/privkey.pem -webCa /root/cert/ca.cer restart xray-ui restart takes effect"
        yellow "Visit: https:// Your domain name:$ports/$path"
        yellow "mTLS windows use....."
        yellow "Generate windows client certificate client.p12..."
        yellow "openssl pkcs12 -export -out client.p12-inkey /root/cert/Your domain name/privkey.pem -in  /root/cert/${domain}.cer -certfile /root/cert/ca.cer"
        yellow "client.p12: windows remember to set a password for the client certificate. A password is required to import the certificate."
        yellow "client.p12 File import on the windows system desktop, double-click to open->Import->Next->put all certificates in the following storage->Personal->Complete If the import fails, search for certificates in the start menu to open management user certificate management->Personal->All tasks->Import->Enter password"
    
    else
        red "xray-ui The installation failed, please check the log and run xray-ui log"
    fi
    sleep 1
    echo -e ""
    echo -e "$int"
    echo -e ""
    echo -e "xray-ui How to use management scripts: "
    echo -e "----------------------------------------------"
    echo -e "xray-ui              - Show management menu"
    echo -e "xray-ui start        - Start the xray-ui panel"
    echo -e "xray-ui stop         - Stop the xray-ui panel"
    echo -e "xray-ui restart      - Restart the xray-ui panel"
    echo -e "xray-ui status       - View xray-ui status"
    echo -e "xray-ui enable       - Set xray-ui to boot and start"
    echo -e "xray-ui disable      - Cancel xray-ui boot and start"
    echo -e "xray-ui log          - View xray-ui log"
    echo -e "xray-ui v2-ui        - Migrate the v2-ui account data of this machine to xray-ui"
    echo -e "xray-ui update       - Update the xray-ui panel"
    echo -e "xray-ui geoip        - Update geoip ip library"
    echo -e "xray-ui update_shell - Update xray-ui script"
    echo -e "xray-ui install      - Install the xray-ui panel"
    echo -e "xray-ui x25519       - REALITY key generation"
    echo -e "xray-ui ssl_main     - SSL certificate management"
    echo -e "xray-ui ssl_CF       - Cloudflare SSL certificate"
    echo -e "xray-ui crontab      - Add geoip to the task plan to be executed at 1.30am every day"
    echo -e "xray-ui uninstall    - Uninstall the xray-ui panel"
    echo -e "----------------------------------------------"
    rm -f install.sh
}

echo -e "${green}Necessary dependencies to start installing xray-ui${plain}"
install_base
echo -e "${green}Start installing xray-ui core components${plain}"
install_xray-ui $1
