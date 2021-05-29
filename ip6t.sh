#! /bin/bash
[[ "$EUID" -ne '0' ]] && echo "Error:This script must be run as root!" && exit 1;

turnOnNat(){
    # 开启端口转发
    echo "1. 端口转发开启  【成功】"
    sed -n '/^net.ipv4.ip_forward=1/'p /etc/sysctl.conf | grep -q "net.ipv4.ip_forward=1"
    if [ $? -ne 0 ]; then
        echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p
    fi

    sed -n '/^net.ipv6.conf.all.forwarding=1/'p /etc/sysctl.conf | grep -q "net.ipv6.conf.all.forwarding=1"
    if [ $? -ne 0 ]; then
        echo -e "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf && sysctl -p
    fi

    #开放FORWARD链
    echo "2. 开放ip6tbales中的FORWARD链  【成功】"
    arr1=(`ip6tables -L FORWARD -n  --line-number |grep "REJECT"|grep "0.0.0.0/0"|sort -r|awk '{print $1,$2,$5}'|tr " " ":"|tr "\n" " "`)  #16:REJECT:0.0.0.0/0 15:REJECT:0.0.0.0/0
    for cell in ${arr1[@]}
    do
        arr2=(`echo $cell|tr ":" " "`)  #arr2=16 REJECT 0.0.0.0/0
        index=${arr2[0]}
        echo 删除禁止FOWARD的规则$index
        ip6tables -D FORWARD $index
    done
    ip6tables --policy FORWARD ACCEPT
}
turnOnNat


dnat(){
    echo "本机所有公网IPv6地址:" 
    ip -o -6 addr list | grep -Ev '\s(docker|lo|link)' | awk '{print $4}' | cut -d/ -f1
    echo -n "输入 本机IPv6地址:";read localIP
    echo -n "输入 本机端口:";read localport
    echo -n "输入 目标地址:";read remote
    echo -n "输入 目标端口:";read remoteport
    ip6tables -t nat -A PREROUTING -p tcp --dport $localport -j DNAT --to-destination [$remote]:$remoteport
    ip6tables -t nat -A PREROUTING -p udp --dport $localport -j DNAT --to-destination [$remote]:$remoteport
    ip6tables -t nat -A POSTROUTING -p tcp -d $remote --dport $remoteport -j SNAT --to-source $localIP
    ip6tables -t nat -A POSTROUTING -p udp -d $remote --dport $remoteport -j SNAT --to-source $localIP
    echo "添加转发成功"
}

rmDnat(){
    ip6tables -t nat -nL --line-number
    echo -n "输入 删除PREROUTING编号(多个编号用空格分隔):";read -a pre_nums
    pre_nums=$(echo ${pre_nums[*]} | tr ' ' '\n' | sort -nr)
    echo -n "输入 删除POSTROUTING编号(多个编号用空格分隔):";read -a post_nums
    post_nums=$(echo ${post_nums[*]} | tr ' ' '\n' | sort -nr)
    for pre_num in ${pre_nums[@]}
    do
        ip6tables -t nat -D PREROUTING ${pre_num}
    done
    for post_num in ${post_nums[@]}
    do
        ip6tables -t nat -D POSTROUTING ${post_num}
    done
    echo "删除转发成功"
}

rmallDnat(){
    ip6tables -P INPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -t nat -F
    ip6tables -t mangle -F
    ip6tables -F
    ip6tables -X
    echo "删除所有转发成功" 
}

lsDnat(){
    ip6tables -t nat -nL --line-number
}
echo  -e "${red}你要做什么呢（请输入数字）？Ctrl+C 退出本脚本${black}"
select todo in 增加转发规则 删除转发规则 列出所有转发规则 删除所有转发规则
do
    case $todo in
    增加转发规则)
        dnat
        #break
        ;;
    删除转发规则)
        rmDnat
        #break
        ;;
    # 增加到IP的转发)
    #     addSnat
    #     #break
    #     ;;
    # 删除到IP的转发)
    #     rmSnat
    #     #break
    #     ;;
    列出所有转发规则)
        lsDnat
        ;;
    删除所有转发规则)
        rmallDnat
        ;;
    *)
        echo "如果要退出，请按Ctrl+C"
        ;;
    esac
done

