#!/bin/bash
# 生物信息学脚本工具箱 - 学校精简版
# 基于 kejilion/sh v4.5.7 裁剪，仅保留：1.系统信息查询 2.系统更新 3.系统清理 00.脚本更新 0.退出
# 原项目: https://github.com/kejilion/sh
sh_v="4.5.7"


gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_bai='\033[0m'
gl_kjlan='\033[96m'


canshu="default"
permission_granted="false"
ENABLE_STATS="true"


# 收集功能埋点信息的函数，记录当前脚本版本号，使用时间，系统版本，CPU架构，机器所在国家和用户使用的功能名称，绝对不涉及任何敏感信息，请放心！请相信我！
# 为什么要设计这个功能，目的更好的了解用户喜欢使用的功能，进一步优化功能推出更多符合用户需求的功能。
# 全文可搜搜 send_stats 函数调用位置，透明开源，如有顾虑可拒绝使用。

send_stats() {
	if [ "$ENABLE_STATS" == "false" ]; then
		return
	fi

	local country=$(curl -s ipinfo.io/country)
	local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')
	local cpu_arch=$(uname -m)

	(
		curl -s -X POST "https://api.kejilion.pro/api/log" \
			-H "Content-Type: application/json" \
			-d "{\"action\":\"$1\",\"timestamp\":\"$(date -u '+%Y-%m-%d %H:%M:%S')\",\"country\":\"$country\",\"os_info\":\"$os_info\",\"cpu_arch\":\"$cpu_arch\",\"version\":\"$sh_v\"}" \
		&>/dev/null
	) &

}


yinsiyuanquan2() {

if grep -q '^ENABLE_STATS="false"' /usr/local/bin/k > /dev/null 2>&1; then
	sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' ~/kejilion.sh
elif grep -q '^ENABLE_STATS="false"' ~/kejilion.sh.bak > /dev/null 2>&1; then
	sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' ~/kejilion.sh
fi

}


canshu_v6() {
	if grep -q '^canshu="V6"' /usr/local/bin/k > /dev/null 2>&1; then
		sed -i 's/^canshu="default"/canshu="V6"/' ~/kejilion.sh
	elif grep -q '^canshu="V6"' ~/kejilion.sh.bak > /dev/null 2>&1; then
		sed -i 's/^canshu="default"/canshu="V6"/' ~/kejilion.sh
	fi
}


CheckFirstRun_true() {
	if grep -q '^permission_granted="true"' /usr/local/bin/k > /dev/null 2>&1; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/kejilion.sh
	elif grep -q '^permission_granted="true"' ~/kejilion.sh.bak > /dev/null 2>&1; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/kejilion.sh
	fi
}


quanju_canshu() {
if [ "$canshu" = "CN" ] || [ "$canshu" = "V6" ]; then
	gh_proxy="https://gh.kejilion.pro/"
else
	gh_proxy="https://"
fi

}
quanju_canshu


install() {
	if [ $# -eq 0 ]; then
		echo "未提供软件包参数!"
		return 1
	fi

	for package in "$@"; do
		if ! command -v "$package" &>/dev/null; then
			echo -e "${gl_kjlan}正在安装 $package...${gl_bai}"
			if command -v dnf &>/dev/null; then
				dnf -y update
				dnf install -y epel-release
				dnf install -y "$package"
			elif command -v yum &>/dev/null; then
				yum -y update
				yum install -y epel-release
				yum install -y "$package"
			elif command -v apt &>/dev/null; then
				apt update -y
				apt install -y "$package"
			elif command -v apk &>/dev/null; then
				apk update
				apk add "$package"
			elif command -v pacman &>/dev/null; then
				pacman -Syu --noconfirm
				pacman -S --noconfirm "$package"
			elif command -v zypper &>/dev/null; then
				zypper refresh
				zypper install -y "$package"
			elif command -v opkg &>/dev/null; then
				opkg update
				opkg install "$package"
			elif command -v pkg &>/dev/null; then
				pkg update
				pkg install -y "$package"
			else
				echo "未知的包管理器!"
				return 1
			fi
		fi
	done
}


remove() {
	if [ $# -eq 0 ]; then
		echo "未提供软件包参数!"
		return 1
	fi

	for package in "$@"; do
		echo -e "${gl_kjlan}正在卸载 $package...${gl_bai}"
		if command -v dnf &>/dev/null; then
			dnf remove -y "$package"
		elif command -v yum &>/dev/null; then
			yum remove -y "$package"
		elif command -v apt &>/dev/null; then
			apt purge -y "$package"
		elif command -v apk &>/dev/null; then
			apk del "$package"
		elif command -v pacman &>/dev/null; then
			pacman -Rns --noconfirm "$package"
		elif command -v zypper &>/dev/null; then
			zypper remove -y "$package"
		elif command -v opkg &>/dev/null; then
			opkg remove "$package"
		elif command -v pkg &>/dev/null; then
			pkg delete -y "$package"
		else
			echo "未知的包管理器!"
			return 1
		fi
	done
}


# 通用 systemctl 函数，适用于各种发行版
systemctl() {
	local COMMAND="$1"
	local SERVICE_NAME="$2"

	if command -v apk &>/dev/null; then
		service "$SERVICE_NAME" "$COMMAND"
	else
		/bin/systemctl "$COMMAND" "$SERVICE_NAME"
	fi
}


break_end() {
	  echo -e "${gl_lv}操作完成${gl_bai}"
	  echo "按任意键继续..."
	  read -n 1 -s -r -p ""
	  echo ""
	  clear
}


ip_address() {

get_public_ip() {
	curl -s https://ipinfo.io/ip && echo
}

get_local_ip() {
	ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || \
	hostname -I 2>/dev/null | awk '{print $1}' || \
	ifconfig 2>/dev/null | grep -E 'inet [0-9]' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1
}

public_ip=$(get_public_ip)
isp_info=$(curl -s --max-time 3 http://ipinfo.io/org)


if echo "$isp_info" | grep -Eiq 'CHINANET|mobile|unicom|telecom'; then
  ipv4_address=$(get_local_ip)
else
  ipv4_address="$public_ip"
fi


# ipv4_address=$(curl -s https://ipinfo.io/ip && echo)
ipv6_address=$(curl -s --max-time 1 https://v6.ipinfo.io/ip && echo)

}


output_status() {
	output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
		$1 ~ /^(eth|ens|enp|eno)[0-9]+/ {
			rx_total += $2
			tx_total += $10
		}
		END {
			rx_units = "Bytes";
			tx_units = "Bytes";
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "K"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "M"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "G"; }

			if (tx_total > 1024) { tx_total /= 1024; tx_units = "K"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "M"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "G"; }

			printf("%.2f%s %.2f%s\n", rx_total, rx_units, tx_total, tx_units);
		}' /proc/net/dev)

	rx=$(echo "$output" | awk '{print $1}')
	tx=$(echo "$output" | awk '{print $2}')

}


current_timezone() {
	if grep -q 'Alpine' /etc/issue; then
	   date +"%Z %z"
	else
	   timedatectl | grep "Time zone" | awk '{print $3}'
	fi

}


# 修复dpkg中断问题
fix_dpkg() {
	pkill -9 -f 'apt|dpkg'
	rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
	DEBIAN_FRONTEND=noninteractive dpkg --configure -a
}


check_crontab_installed() {
	if ! command -v crontab >/dev/null 2>&1; then
		install_crontab
	fi
}


install_crontab() {
	local package_manager

	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
			ubuntu|debian|kali)
				apt update
				apt install -y cron
				systemctl enable cron
				systemctl start cron
				;;
			centos|rhel|almalinux|rocky|fedora)
				if command -v dnf >/dev/null 2>&1; then
					package_manager=dnf
				elif command -v yum >/dev/null 2>&1; then
					package_manager=yum
				else
					echo "错误: 未找到 DNF/YUM，无法安装 cronie"
					return 1
				fi
				"$package_manager" install -y cronie || return 1
				/bin/systemctl enable --now crond.service || return 1
				command -v crontab >/dev/null 2>&1 || return 1
				/bin/systemctl is-active --quiet crond.service || return 1
				;;
			alpine)
				apk add --no-cache cronie
				rc-update add crond
				rc-service crond start
				;;
			arch|manjaro)
				pacman -S --noconfirm cronie
				systemctl enable cronie
				systemctl start cronie
				;;
			opensuse|suse|opensuse-tumbleweed)
				zypper install -y cron
				systemctl enable cron
				systemctl start cron
				;;
			iStoreOS|openwrt|ImmortalWrt|lede)
				opkg update
				opkg install cron
				/etc/init.d/cron enable
				/etc/init.d/cron start
				;;
			FreeBSD)
				pkg install -y cronie
				sysrc cron_enable="YES"
				service cron start
				;;
			*)
				echo "不支持的发行版: $ID"
				return
				;;
		esac
	else
		echo "无法确定操作系统。"
		return
	fi

	command -v crontab >/dev/null 2>&1 || return 1
	echo -e "${gl_lv}crontab 已安装且 cron 服务正在运行。${gl_bai}"
}


CheckFirstRun_false() {
	if grep -q '^permission_granted="false"' /usr/local/bin/k > /dev/null 2>&1; then
		UserLicenseAgreement
	fi
}

# 提示用户同意条款
UserLicenseAgreement() {
	clear
	echo -e "${gl_kjlan}欢迎使用生物信息学脚本工具箱${gl_bai}"
	echo "首次使用脚本，请先阅读并同意用户许可协议。"
	echo "用户许可协议: https://blog.kejilion.pro/user-license-agreement/"
	echo -e "----------------------"
	read -e -p "是否同意以上条款？(y/n): " user_input


	if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
		send_stats "许可同意"
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/kejilion.sh
		sed -i 's/^permission_granted="false"/permission_granted="true"/' /usr/local/bin/k
	else
		send_stats "许可拒绝"
		clear
		exit
	fi
}


# ----------------------------
# 1. 系统信息查询
# ----------------------------
linux_info() {



	clear
	echo -e "${gl_kjlan}正在查询系统信息……${gl_bai}"
	send_stats "系统信息查询"

	ip_address

	local cpu_info=$(lscpu | awk -F': +' '/Model name:/ {print $2; exit}')

	local cpu_usage_percent=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.0f\n", (($2+$4-u1) * 100 / (t-t1))}' \
		<(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat))

	local cpu_cores=$(nproc)

	local cpu_freq=$(cat /proc/cpuinfo | grep "MHz" | head -n 1 | awk '{printf "%.1f GHz\n", $4/1000}')

	local mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2fM (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

	local disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3, $2, $5}')

	local ipinfo=$(curl -s ipinfo.io)
	local country=$(echo "$ipinfo" | grep 'country' | awk -F': ' '{print $2}' | tr -d '",')
	local city=$(echo "$ipinfo" | grep 'city' | awk -F': ' '{print $2}' | tr -d '",')
	local isp_info=$(echo "$ipinfo" | grep 'org' | awk -F': ' '{print $2}' | tr -d '",')

	local load=$(uptime | awk '{print $(NF-2), $(NF-1), $NF}')
	local dns_addresses=$(awk '/^nameserver/{printf "%s ", $2} END {print ""}' /etc/resolv.conf)


	local cpu_arch=$(uname -m)

	local hostname=$(uname -n)

	local kernel_version=$(uname -r)

	local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
	local queue_algorithm=$(sysctl -n net.core.default_qdisc)

	local os_info=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | tr -d '"')

	output_status

	local current_time=$(date "+%Y-%m-%d %I:%M %p")


	local swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dM/%dM (%d%%)", used, total, percentage}')

	local runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

	local timezone=$(current_timezone)

	local tcp_count=$(ss -t | wc -l)
	local udp_count=$(ss -u | wc -l)

	clear
	echo -e "系统信息查询"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}主机名:         ${gl_bai}$hostname"
	echo -e "${gl_kjlan}系统版本:       ${gl_bai}$os_info"
	echo -e "${gl_kjlan}Linux版本:      ${gl_bai}$kernel_version"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}CPU架构:        ${gl_bai}$cpu_arch"
	echo -e "${gl_kjlan}CPU型号:        ${gl_bai}$cpu_info"
	echo -e "${gl_kjlan}CPU核心数:      ${gl_bai}$cpu_cores"
	echo -e "${gl_kjlan}CPU频率:        ${gl_bai}$cpu_freq"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}CPU占用:        ${gl_bai}$cpu_usage_percent%"
	echo -e "${gl_kjlan}系统负载:       ${gl_bai}$load"
	echo -e "${gl_kjlan}TCP|UDP连接数:  ${gl_bai}$tcp_count|$udp_count"
	echo -e "${gl_kjlan}物理内存:       ${gl_bai}$mem_info"
	echo -e "${gl_kjlan}虚拟内存:       ${gl_bai}$swap_info"
	echo -e "${gl_kjlan}硬盘占用:       ${gl_bai}$disk_info"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}总接收:         ${gl_bai}$rx"
	echo -e "${gl_kjlan}总发送:         ${gl_bai}$tx"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}网络算法:       ${gl_bai}$congestion_algorithm $queue_algorithm"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}运营商:         ${gl_bai}$isp_info"
	if [ -n "$ipv4_address" ]; then
		echo -e "${gl_kjlan}IPv4地址:       ${gl_bai}$ipv4_address"
	fi

	if [ -n "$ipv6_address" ]; then
		echo -e "${gl_kjlan}IPv6地址:       ${gl_bai}$ipv6_address"
	fi
	echo -e "${gl_kjlan}DNS地址:        ${gl_bai}$dns_addresses"
	echo -e "${gl_kjlan}地理位置:       ${gl_bai}$country $city"
	echo -e "${gl_kjlan}系统时间:       ${gl_bai}$timezone $current_time"
	echo -e "${gl_kjlan}-------------"
	echo -e "${gl_kjlan}运行时长:       ${gl_bai}$runtime"
	echo



}


# ----------------------------
# 2. 系统更新
# ----------------------------
linux_update() {
	echo -e "${gl_kjlan}正在系统更新...${gl_bai}"
	if command -v dnf &>/dev/null; then
		dnf -y update
	elif command -v yum &>/dev/null; then
		yum -y update
	elif command -v apt &>/dev/null; then
		fix_dpkg
		DEBIAN_FRONTEND=noninteractive apt update -y
		DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
	elif command -v apk &>/dev/null; then
		apk update && apk upgrade
	elif command -v pacman &>/dev/null; then
		pacman -Syu --noconfirm
	elif command -v zypper &>/dev/null; then
		zypper refresh
		zypper update
	elif command -v opkg &>/dev/null; then
		opkg update
	else
		echo "未知的包管理器!"
		return
	fi
}


# ----------------------------
# 3. 系统清理
# ----------------------------
linux_clean() {
	echo -e "${gl_kjlan}正在系统清理...${gl_bai}"
	if command -v dnf &>/dev/null; then
		rpm --rebuilddb
		dnf autoremove -y
		dnf clean all
		dnf makecache
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v yum &>/dev/null; then
		rpm --rebuilddb
		yum autoremove -y
		yum clean all
		yum makecache
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v apt &>/dev/null; then
		fix_dpkg
		apt autoremove --purge -y
		apt clean -y
		apt autoclean -y
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v apk &>/dev/null; then
		echo "清理包管理器缓存..."
		apk cache clean
		echo "删除系统日志..."
		rm -rf /var/log/*
		echo "删除APK缓存..."
		rm -rf /var/cache/apk/*
		echo "删除临时文件..."
		rm -rf /tmp/*

	elif command -v pacman &>/dev/null; then
		pacman -Rns $(pacman -Qdtq) --noconfirm
		pacman -Scc --noconfirm
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v zypper &>/dev/null; then
		zypper clean --all
		zypper refresh
		journalctl --rotate
		journalctl --vacuum-time=1s
		journalctl --vacuum-size=500M

	elif command -v opkg &>/dev/null; then
		echo "删除系统日志..."
		rm -rf /var/log/*
		echo "删除临时文件..."
		rm -rf /tmp/*

	elif command -v pkg &>/dev/null; then
		echo "清理未使用的依赖..."
		pkg autoremove -y
		echo "清理包管理器缓存..."
		pkg clean -y
		echo "删除系统日志..."
		rm -rf /var/log/*
		echo "删除临时文件..."
		rm -rf /tmp/*

	else
		echo "未知的包管理器!"
		return
	fi
	return
}


# ----------------------------
# 00. 脚本更新
# ----------------------------
kejilion_update() {

send_stats "脚本更新"
cd ~
while true; do
	clear
	echo "更新日志"
	echo "------------------------"
	echo "全部日志: ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/kejilion_sh_log.txt"
	echo "------------------------"

	curl -s --max-time 15 ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/kejilion_sh_log.txt | tail -n 30
	# 只下载前5行获取版本号，避免下载整个脚本
	local sh_v_new=$(curl -s --max-time 15 -r 0-200 ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/kejilion.sh | grep -o 'sh_v="[0-9.]*"' | head -1 | cut -d '"' -f 2)

	if [ -z "$sh_v_new" ]; then
		echo -e "${gl_hong}无法获取最新版本信息，请检查网络连接${gl_bai}"
	elif [ "$sh_v" = "$sh_v_new" ]; then
		echo -e "${gl_lv}你已经是最新版本！${gl_huang}v$sh_v${gl_bai}"
		send_stats "脚本已经最新了，无需更新"
	else
		echo "发现新版本！"
		echo -e "当前版本 v$sh_v        最新版本 ${gl_huang}v$sh_v_new${gl_bai}"
	fi


	local cron_job="kejilion.sh"
	local existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

	if [ -n "$existing_cron" ]; then
		echo "------------------------"
		echo -e "${gl_lv}自动更新已开启，每天凌晨2点脚本会自动更新！${gl_bai}"
	fi

	echo "------------------------"
	echo "1. 现在更新            2. 开启自动更新            3. 关闭自动更新"
	echo "------------------------"
	echo "0. 返回主菜单"
	echo "------------------------"
	read -e -p "请输入你的选择: " choice
	case "$choice" in
		1)
			clear
			local country=$(curl -s --max-time 5 ipinfo.io/country)
			local download_url
			if [ "$country" = "CN" ]; then
				download_url="${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/cn/kejilion.sh"
			else
				download_url="${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/kejilion.sh"
			fi

			# 备份当前脚本
			cp -f ~/kejilion.sh ~/kejilion.sh.bak 2>/dev/null

			# 下载到临时文件，校验后再替换
			local tmp_file=$(mktemp ~/kejilion_tmp.XXXXXX)
			if curl -sS --max-time 60 --fail -o "$tmp_file" "$download_url" && \
			   [ -s "$tmp_file" ] && \
			   head -1 "$tmp_file" | grep -q '^#!/bin/bash'; then
				chmod +x "$tmp_file"
				mv -f "$tmp_file" ~/kejilion.sh
				canshu_v6
				CheckFirstRun_true
				yinsiyuanquan2
				cp -f ~/kejilion.sh /usr/local/bin/k > /dev/null 2>&1
				ln -sf /usr/local/bin/k /usr/bin/k > /dev/null 2>&1
				echo -e "${gl_lv}脚本已更新到最新版本！${gl_huang}v$sh_v_new${gl_bai}"
				send_stats "脚本已经最新$sh_v_new"
			else
				rm -f "$tmp_file"
				# 恢复备份
				if [ -f ~/kejilion.sh.bak ]; then
					mv -f ~/kejilion.sh.bak ~/kejilion.sh
				fi
				echo -e "${gl_hong}更新失败！下载出错或文件校验不通过，已恢复原版本${gl_bai}"
				send_stats "脚本更新失败"
			fi
			break_end
			~/kejilion.sh
			exit
			;;
		2)
			clear
			local country=$(curl -s --max-time 5 ipinfo.io/country)
			local ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
			local cron_proxy cron_sed_cmd
			if [ "$country" = "CN" ]; then
				cron_proxy="https://gh.kejilion.pro/"
				cron_sed_cmd="sed -i 's/canshu=\"default\"/canshu=\"CN\"/g' ~/kejilion.sh"
			elif [ -n "$ipv6_address" ]; then
				cron_proxy="https://gh.kejilion.pro/"
				cron_sed_cmd="sed -i 's/canshu=\"default\"/canshu=\"V6\"/g' ~/kejilion.sh"
			else
				cron_proxy="https://"
				cron_sed_cmd=""
			fi

			# 构建健壮的自动更新命令：下载到临时文件 → 校验 → 备份 → 替换 → 恢复本地设置 → 部署
			SH_Update_task="cd ~ && tmp=\$(mktemp ~/kejilion_tmp.XXXXXX) && curl -sS --max-time 60 --fail -o \"\$tmp\" ${cron_proxy}raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && [ -s \"\$tmp\" ] && head -1 \"\$tmp\" | grep -q '^#!/bin/bash' && cp -f ~/kejilion.sh ~/kejilion.sh.bak 2>/dev/null && chmod +x \"\$tmp\" && mv -f \"\$tmp\" ~/kejilion.sh"
			# 追加设置恢复
			if [ -n "$cron_sed_cmd" ]; then
				SH_Update_task="$SH_Update_task && $cron_sed_cmd"
			fi
			# 从旧脚本恢复 permission_granted 和 ENABLE_STATS 设置
			SH_Update_task="$SH_Update_task && grep -q 'permission_granted=\"true\"' ~/kejilion.sh.bak 2>/dev/null && sed -i 's/permission_granted=\"false\"/permission_granted=\"true\"/' ~/kejilion.sh; grep -q 'ENABLE_STATS=\"false\"' ~/kejilion.sh.bak 2>/dev/null && sed -i 's/ENABLE_STATS=\"true\"/ENABLE_STATS=\"false\"/' ~/kejilion.sh"
			# 部署到 /usr/local/bin/k 和 /usr/bin/k
			SH_Update_task="$SH_Update_task; cp -f ~/kejilion.sh /usr/local/bin/k 2>/dev/null; ln -sf /usr/local/bin/k /usr/bin/k 2>/dev/null"
			# 下载失败时清理临时文件
			SH_Update_task="$SH_Update_task || rm -f \"\$tmp\" 2>/dev/null"

			check_crontab_installed
			(crontab -l | grep -v "kejilion.sh") | crontab -
			(crontab -l 2>/dev/null; echo "$(shuf -i 0-59 -n 1) 2 * * * bash -c '$SH_Update_task'") | crontab -
			echo -e "${gl_lv}自动更新已开启，每天凌晨2点脚本会自动更新！${gl_bai}"
			send_stats "开启脚本自动更新"
			break_end
			;;
		3)
			clear
			(crontab -l | grep -v "kejilion.sh") | crontab -
			echo -e "${gl_lv}自动更新已关闭${gl_bai}"
			send_stats "关闭脚本自动更新"
			break_end
			;;
		*)
			kejilion_sh
			;;
	esac
done

}


# ----------------------------
# 主菜单
# ----------------------------
kejilion_sh() {
while true; do
clear
echo -e "${gl_kjlan}"
echo "========================================"
echo -e " 生物信息学脚本工具箱 v$sh_v"
echo "========================================"
echo -e "命令行输入${gl_huang}k${gl_kjlan}可快速启动脚本${gl_bai}"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}1.   ${gl_bai}系统信息查询"
echo -e "${gl_kjlan}2.   ${gl_bai}系统更新"
echo -e "${gl_kjlan}3.   ${gl_bai}系统清理"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}00.  ${gl_bai}脚本更新"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}0.   ${gl_bai}退出脚本"
echo -e "${gl_kjlan}------------------------${gl_bai}"
read -e -p "请输入你的选择: " choice

case $choice in
  1) linux_info ;;
  2) clear ; send_stats "系统更新" ; linux_update ;;
  3) clear ; send_stats "系统清理" ; linux_clean ;;
  00) kejilion_update ;;
  0) clear ; exit ;;
  *) echo "无效的输入!" ;;
esac
	break_end
done
}


# ----------------------------
# 自安装与首启许可（保留原框架行为）
# ----------------------------
canshu_v6
CheckFirstRun_true
yinsiyuanquan2

sed -i '/^alias k=/d' ~/.bashrc > /dev/null 2>&1
sed -i '/^alias k=/d' ~/.profile > /dev/null 2>&1
sed -i '/^alias k=/d' ~/.bash_profile > /dev/null 2>&1
cp -f ./kejilion.sh ~/kejilion.sh > /dev/null 2>&1
cp -f ~/kejilion.sh /usr/local/bin/k > /dev/null 2>&1
ln -sf /usr/local/bin/k /usr/bin/k > /dev/null 2>&1

CheckFirstRun_false


# ----------------------------
# 入口：无参数进菜单，带参数走精简 k 命令
# ----------------------------
if [ "$#" -eq 0 ]; then
	# 如果没有参数，运行交互式逻辑
	kejilion_sh
else
	# 如果有参数，执行相应函数（仅保留与现有功能兼容的快捷命令）
	case $1 in
		install|add|安装)
			shift
			send_stats "安装软件"
			install "$@"
			;;
		remove|del|uninstall|卸载)
			shift
			send_stats "卸载软件"
			remove "$@"
			;;
		update|更新)
			linux_update
			;;
		clean|清理)
			linux_clean
			;;
		info)
			linux_info
			;;
		*)
			echo "未知命令: $1"
			echo "直接运行 k 进入菜单"
			;;
	esac
fi
