#!/bin/bash
sh_v="1.1.0"
# 生物信息学脚本工具箱 - 学校精简版
# 基于 kejilion/sh v4.5.7 裁剪，保留：1.系统信息查询 2.系统更新 3.系统清理 4.生物信息环境搭建 00.脚本更新 0.退出
# 项目仓库: https://github.com/randomNaming/bio-project-sh

# 脚本分发地址（服务器 nginx 站点根，更新检查/下载均走此地址）
dist_base="https://bio-sh.nknpq3nl.icu"


gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_bai='\033[0m'
gl_kjlan='\033[96m'


permission_granted="false"


# 脚本更新后，从已安装的旧版本恢复许可同意状态
CheckFirstRun_true() {
	if grep -q '^permission_granted="true"' /usr/local/bin/k > /dev/null 2>&1; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/kejilion.sh
	elif grep -q '^permission_granted="true"' ~/kejilion.sh.bak > /dev/null 2>&1; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/kejilion.sh
	fi
}


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
	echo "用户许可协议: ${dist_base}/AGREEMENT.txt"
	echo -e "----------------------"
	read -e -p "是否同意以上条款？(y/n): " user_input


	if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
		sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/kejilion.sh
		sed -i 's/^permission_granted="false"/permission_granted="true"/' /usr/local/bin/k
	else
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
# 4. 生物信息环境搭建（PspC 推荐安装清单）
# 目标系统 Ubuntu 24.04 LTS，清单：Python 3.10(Conda)、Biopython、SignalP 6.0h、
# CD-HIT 4.8.1、MAFFT 7.526、IQ-TREE 3.1.3、R 4.4+、基础编译环境。
# ConSurf 使用 Web Server，无需本地安装。
# ----------------------------
bio_env_name="bioinfo"
bio_python_ver="3.10"
bio_cdhit_ver="4.8.1"
bio_mafft_ver="7.526"
bio_iqtree_ver="3.1.3"
bio_r_minver="4.4"
bio_sigp_ver="6.0h"
bio_dist_bio="${dist_base}/bio"
bio_apt_updated="0"


bio_init_paths() {
	if [ "$(id -u)" -eq 0 ]; then
		bio_conda_dir="/opt/miniconda3"
		bio_work_dir="/opt/bioinfo-setup"
	elif [ -d "$HOME/miniconda3" ] || [ ! -d "/opt/miniconda3" ]; then
		bio_conda_dir="$HOME/miniconda3"
		bio_work_dir="$HOME/.bioinfo-setup"
	else
		# 管理员已把 Miniconda 装在 /opt，普通用户直接复用
		bio_conda_dir="/opt/miniconda3"
		bio_work_dir="$HOME/.bioinfo-setup"
	fi
	bio_env_bin="$bio_conda_dir/envs/$bio_env_name/bin"
	bio_log_file="$bio_work_dir/install.log"
	mkdir -p "$bio_work_dir"
}


bio_sudo() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		"$@"
	fi
}


bio_apt_ready() {
	[ "$bio_apt_updated" = "1" ] && return 0
	if command -v apt >/dev/null 2>&1; then
		if [ "$(id -u)" -eq 0 ]; then
			fix_dpkg >/dev/null 2>&1
			env DEBIAN_FRONTEND=noninteractive apt update -y
		elif command -v sudo >/dev/null 2>&1; then
			sudo env DEBIAN_FRONTEND=noninteractive apt update -y
		else
			env DEBIAN_FRONTEND=noninteractive apt update -y
		fi
		bio_apt_updated="1"
	fi
}


bio_apt_install() {
	bio_apt_ready
	bio_sudo env DEBIAN_FRONTEND=noninteractive apt install -y "$@"
}


bio_fetch() {
	# bio_fetch <保存路径> <URL> [备用URL]：断点续传 + 多次重试，应对下载中途断流
	local out="$1" url="$2" mirror="$3" attempt
	mkdir -p "$(dirname "$out")"
	for attempt in 1 2 3; do
		if [ "$attempt" -gt 1 ] && [ -s "$out" ]; then
			curl -sSfL -C - --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 1800 -o "$out" "$url" && return 0
		else
			curl -sSfL --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 1800 -o "$out" "$url" && return 0
		fi
		[ "$attempt" -lt 3 ] && sleep 2
	done
	if [ -n "$mirror" ]; then
		echo -e "${gl_huang}官方源下载失败，尝试备用源……${gl_bai}"
		for attempt in 1 2 3; do
			if [ "$attempt" -gt 1 ] && [ -s "$out" ]; then
				curl -sSfL -C - --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 1800 -o "$out" "$mirror" && return 0
			else
				curl -sSfL --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 1800 -o "$out" "$mirror" && return 0
			fi
			[ "$attempt" -lt 3 ] && sleep 2
		done
	fi
	return 1
}


bio_logged() {
	# bio_logged <描述> <函数> [参数...]：屏幕同步显示的同时，把完整输出落盘到安装日志
	local label="$1" rc=0 fifo tee_pid
	shift
	mkdir -p "$bio_work_dir" 2>/dev/null
	# 日志超过 5MB 时只保留末尾 2000 行，防止无限膨胀
	if [ -f "$bio_log_file" ] && [ "$(wc -c < "$bio_log_file" 2>/dev/null || echo 0)" -gt 5242880 ]; then
		tail -n 2000 "$bio_log_file" > "$bio_log_file.tmp" 2>/dev/null && mv -f "$bio_log_file.tmp" "$bio_log_file"
	fi
	{
		echo ""
		echo "===== $(date '+%Y-%m-%d %H:%M:%S') 开始: $label ====="
	} >> "$bio_log_file" 2>/dev/null
	# FIFO + tee：输出实时上屏，wait 保证函数返回前日志已完整落盘
	fifo="$bio_work_dir/.logfifo.$$"
	mkfifo "$fifo" 2>/dev/null || fifo=""
	if [ -n "$fifo" ]; then
		tee -a "$bio_log_file" < "$fifo" &
		tee_pid=$!
		"$@" > "$fifo" 2>&1 || rc=$?
		wait "$tee_pid"
		rm -f "$fifo"
	else
		# mkfifo 不可用时退化为仅落盘（无实时上屏）
		"$@" >> "$bio_log_file" 2>&1 || rc=$?
	fi
	echo "===== $(date '+%Y-%m-%d %H:%M:%S') 结束: $label (退出码 $rc) =====" >> "$bio_log_file" 2>/dev/null
	return $rc
}


bio_ver_ge() {
	# bio_ver_ge <当前版本> <最低版本>，基于 sort -V 比较
	[ "$(printf '%s\n%s\n' "${1:-0}" "$2" | sort -V | head -n 1)" = "$2" ]
}


bio_register_path() {
	# 把指定 bin 目录写入登录配置，保证可执行程序加入 PATH
	local bin_dir="$1"
	local line="export PATH=\"$bin_dir:\$PATH\""
	if [ "$(id -u)" -eq 0 ] && [ -d /etc/profile.d ]; then
		echo "$line" > /etc/profile.d/bioinfo.sh
	fi
	if ! grep -qF '# bioinfo-env' ~/.bashrc 2>/dev/null; then
		{ echo ""; echo "$line # bioinfo-env"; } >> ~/.bashrc
	fi
}


bio_require_env() {
	if [ ! -x "$bio_env_bin/python" ]; then
		echo -e "${gl_huang}未检测到 $bio_env_name Python 环境，先自动安装 Miniconda + Python $bio_python_ver ……${gl_bai}"
		bio_install_conda || return 1
	fi
	bio_register_path "$bio_env_bin"
	export PATH="$bio_env_bin:$PATH"
}


bio_pip_install() {
	# 优先官方 PyPI，失败自动切换清华 TUNA 镜像
	if "$bio_env_bin/pip" install "$@"; then
		return 0
	fi
	echo -e "${gl_huang}PyPI 官方源安装失败，切换清华 TUNA 镜像重试……${gl_bai}"
	"$bio_env_bin/pip" install -i https://pypi.tuna.tsinghua.edu.cn/simple "$@"
}


bio_install_conda() {
	local arch installer_url mirror_url tmp_sh
	case "$(uname -m)" in
		x86_64) arch="x86_64" ;;
		aarch64|arm64) arch="aarch64" ;;
		*)
			echo -e "${gl_hong}不支持的 CPU 架构: $(uname -m)${gl_bai}"
			return 1
			;;
	esac

	if [ ! -x "$bio_conda_dir/bin/conda" ]; then
		echo -e "${gl_kjlan}安装 Miniconda 到 $bio_conda_dir ……${gl_bai}"
		installer_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$arch.sh"
		mirror_url="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-$arch.sh"
		tmp_sh="$bio_work_dir/miniconda.sh"
		if ! bio_fetch "$tmp_sh" "$installer_url" "$mirror_url"; then
			echo -e "${gl_hong}Miniconda 下载失败，请检查网络后重试${gl_bai}"
			return 1
		fi
		if ! bash "$tmp_sh" -b -p "$bio_conda_dir"; then
			echo -e "${gl_hong}Miniconda 安装失败（目录不可写？）${gl_bai}"
			return 1
		fi
		rm -f "$tmp_sh"
	else
		echo -e "${gl_lv}Miniconda 已存在：$bio_conda_dir${gl_bai}"
	fi

	if [ -x "$bio_env_bin/python" ] && "$bio_env_bin/python" -c 'import sys; sys.exit(0 if sys.version_info[:2] == (3, 10) else 1)' 2>/dev/null; then
		echo -e "${gl_lv}Python $bio_python_ver 环境已就绪：$bio_env_bin${gl_bai}"
	else
		if [ -d "$bio_conda_dir/envs/$bio_env_name" ]; then
			echo -e "${gl_huang}检测到旧的 $bio_env_name 环境（不完整或 Python 版本不符），正在重建……${gl_bai}"
			"$bio_conda_dir/bin/conda" env remove -y -n "$bio_env_name" >/dev/null 2>&1
			rm -rf "$bio_conda_dir/envs/$bio_env_name"
		fi
		echo -e "${gl_kjlan}创建 conda 虚拟环境 $bio_env_name（Python $bio_python_ver）……${gl_bai}"
		if ! "$bio_conda_dir/bin/conda" create -y -n "$bio_env_name" "python=$bio_python_ver"; then
			echo -e "${gl_huang}conda 官方源创建失败，写入清华 TUNA 镜像后重试……${gl_bai}"
			cat > "$bio_conda_dir/.condarc" 2>/dev/null <<EOF
channels:
  - defaults
show_channel_urls: true
default_channels:
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main
  - https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r
EOF
			if ! "$bio_conda_dir/bin/conda" create -y -n "$bio_env_name" "python=$bio_python_ver"; then
				echo -e "${gl_hong}conda 环境创建失败，请检查磁盘空间与网络${gl_bai}"
				return 1
			fi
		fi
	fi

	bio_register_path "$bio_env_bin"
	export PATH="$bio_env_bin:$PATH"
	echo -e "${gl_lv}Python 环境搭建完成：$("$bio_env_bin/python" --version 2>&1)（$bio_env_bin）${gl_bai}"
	echo -e "重新登录后 PATH 自动生效，当前会话已可直接使用。"
}


bio_install_biopython() {
	bio_require_env || return 1
	if "$bio_env_bin/python" -c 'import Bio' >/dev/null 2>&1; then
		echo -e "${gl_lv}Biopython 已安装：v$("$bio_env_bin/python" -c 'import Bio; print(Bio.__version__)' 2>/dev/null)${gl_bai}"
		return 0
	fi
	echo -e "${gl_kjlan}安装 Biopython ……${gl_bai}"
	if ! bio_pip_install biopython; then
		echo -e "${gl_hong}Biopython 安装失败${gl_bai}"
		return 1
	fi
	echo -e "${gl_lv}Biopython 安装完成：v$("$bio_env_bin/python" -c 'import Bio; print(Bio.__version__)' 2>/dev/null)${gl_bai}"
}


bio_install_signalp() {
	bio_require_env || return 1

	# 已安装且模型权重齐全则跳过
	local sigp_dir
	sigp_dir=$("$bio_env_bin/python" -c 'import signalp, os; print(os.path.dirname(signalp.__file__))' 2>/dev/null)
	if [ -x "$bio_env_bin/signalp" ] && [ -n "$sigp_dir" ] && [ -n "$(ls -A "$sigp_dir/model_weights" 2>/dev/null)" ]; then
		echo -e "${gl_lv}SignalP 已安装：$("$bio_env_bin/signalp" --version 2>&1 | head -n 1)${gl_bai}"
		return 0
	fi

	echo -e "${gl_huang}SignalP $bio_sigp_ver 由丹麦技术大学（DTU）发布，仅限学术研究使用。${gl_bai}"
	echo -e "继续安装即表示你已确认符合 DTU 学术使用许可。"
	read -e -p "是否继续？(y/n): " bio_yn
	case "$bio_yn" in
		y|Y) ;;
		*)
			echo "已取消，可稍后在菜单中单独重试。"
			return 1
			;;
	esac

	local tarball="$bio_work_dir/signalp-$bio_sigp_ver.tar.gz"
	local models_tar="$bio_work_dir/signalp-$bio_sigp_ver.models.tar.gz"

	# DTU 官网需人工申请下载，包体由校内分发服务器或用户手动放置提供
	if [ ! -s "$tarball" ]; then
		echo -e "${gl_kjlan}下载 SignalP $bio_sigp_ver 安装包（校内源）……${gl_bai}"
		if ! bio_fetch "$tarball" "$bio_dist_bio/signalp-$bio_sigp_ver.tar.gz"; then
			echo -e "${gl_hong}无法自动获取 SignalP 安装包。${gl_bai}"
			echo -e "请访问 ${gl_huang}https://services.healthtech.dtu.dk/services/SignalP-6.0/${gl_bai} Downloads 页签，"
			echo -e "填写姓名/邮箱并同意学术许可后，下载以下两个文件并放到 ${gl_huang}$bio_work_dir/${gl_bai}（保持文件名不变）："
			echo -e "  1. signalp-$bio_sigp_ver.tar.gz"
			echo -e "  2. signalp-$bio_sigp_ver.models.tar.gz"
			echo -e "放置后重新运行本项，脚本会自动完成剩余步骤。"
			echo -e "管理员也可把两个包上传到 ${gl_huang}$bio_dist_bio/${gl_bai}，全校即可一键自动安装。"
			return 1
		fi
	fi
	if [ ! -s "$models_tar" ]; then
		echo -e "${gl_kjlan}下载 SignalP 模型权重包（校内源）……${gl_bai}"
		bio_fetch "$models_tar" "$bio_dist_bio/signalp-$bio_sigp_ver.models.tar.gz" || rm -f "$models_tar"
		if [ ! -s "$models_tar" ]; then
			echo -e "${gl_hong}模型权重包获取失败，请手动下载 signalp-$bio_sigp_ver.models.tar.gz 放到 ${gl_huang}$bio_work_dir/${gl_bai}"
			return 1
		fi
	fi

	echo -e "${gl_kjlan}安装依赖（numpy <2 + CPU 版 PyTorch，体积较大，请耐心等待）……${gl_bai}"
	bio_pip_install "numpy<2" || return 1
	if ! "$bio_env_bin/pip" install torch --index-url https://download.pytorch.org/whl/cpu 2>/dev/null; then
		echo -e "${gl_huang}PyTorch CPU 专用源失败，改用 PyPI……${gl_bai}"
		bio_pip_install torch || return 1
	fi

	echo -e "${gl_kjlan}安装 SignalP Python 包 ……${gl_bai}"
	local pkg_dir="$bio_work_dir/signalp-6-package"
	rm -rf "$pkg_dir"
	tar -zxf "$tarball" -C "$bio_work_dir" || { echo -e "${gl_hong}SignalP 安装包解压失败${gl_bai}"; return 1; }
	[ -d "$pkg_dir" ] || pkg_dir=$(find "$bio_work_dir" -maxdepth 1 -type d -name 'signalp*6*' ! -name '*models*' 2>/dev/null | head -n 1)
	if [ -z "$pkg_dir" ] || [ ! -d "$pkg_dir" ]; then
		echo -e "${gl_hong}未找到 SignalP 包目录，解压结果异常${gl_bai}"
		return 1
	fi

	bio_pip_install "$pkg_dir/" || { echo -e "${gl_hong}SignalP pip 安装失败${gl_bai}"; return 1; }

	echo -e "${gl_kjlan}放置模型权重文件……${gl_bai}"
	sigp_dir=$("$bio_env_bin/python" -c 'import signalp, os; print(os.path.dirname(signalp.__file__))' 2>/dev/null)
	if [ -z "$sigp_dir" ]; then
		echo -e "${gl_hong}无法定位 signalp 包目录，请手动放置模型权重${gl_bai}"
		return 1
	fi
	tar -zxf "$models_tar" -C "$bio_work_dir" || { echo -e "${gl_hong}模型权重解压失败${gl_bai}"; return 1; }
	local models_src=""
	[ -d "$pkg_dir/models" ] && models_src="$pkg_dir/models"
	[ -z "$models_src" ] && [ -d "$bio_work_dir/models" ] && models_src="$bio_work_dir/models"
	if [ -z "$models_src" ] || [ -z "$(ls -A "$models_src" 2>/dev/null)" ]; then
		echo -e "${gl_hong}未在压缩包中找到模型权重目录${gl_bai}"
		return 1
	fi
	mkdir -p "$sigp_dir/model_weights"
	mv -f "$models_src"/* "$sigp_dir/model_weights/" || { echo -e "${gl_hong}模型权重移动失败${gl_bai}"; return 1; }

	if "$bio_env_bin/signalp" --version >/dev/null 2>&1; then
		echo -e "${gl_lv}SignalP 安装完成：$("$bio_env_bin/signalp" --version 2>&1 | head -n 1)${gl_bai}"
	else
		echo -e "${gl_hong}SignalP 安装后验证失败，请检查上方日志${gl_bai}"
		return 1
	fi
}


bio_install_cdhit() {
	if command -v cd-hit >/dev/null 2>&1; then
		local cur
		cur=$(cd-hit -h 2>&1 | grep -oiE 'version [0-9.]+' | head -n 1 | grep -oE '[0-9]+\.[0-9.]+')
		if bio_ver_ge "$cur" "$bio_cdhit_ver"; then
			echo -e "${gl_lv}CD-HIT 已安装：v$cur${gl_bai}"
			return 0
		fi
		echo -e "${gl_huang}CD-HIT 版本低于 $bio_cdhit_ver（当前 ${cur:-未知}），尝试升级……${gl_bai}"
	fi
	echo -e "${gl_kjlan}通过 apt 安装 CD-HIT $bio_cdhit_ver ……${gl_bai}"
	bio_apt_install cd-hit || { echo -e "${gl_hong}CD-HIT 安装失败${gl_bai}"; return 1; }
	local new_ver
	new_ver=$(cd-hit -h 2>&1 | grep -oiE 'version [0-9.]+' | head -n 1 | grep -oE '[0-9]+\.[0-9.]+')
	echo -e "${gl_lv}CD-HIT 安装完成：v${new_ver:-未知}${gl_bai}"
}


bio_install_mafft() {
	if command -v mafft >/dev/null 2>&1; then
		local cur
		cur=$(mafft --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
		if bio_ver_ge "$cur" "$bio_mafft_ver"; then
			echo -e "${gl_lv}MAFFT 已安装：v$cur${gl_bai}"
			return 0
		fi
		echo -e "${gl_huang}MAFFT 版本低于 $bio_mafft_ver（当前 ${cur:-未知}），尝试升级……${gl_bai}"
	fi
	echo -e "${gl_kjlan}通过 apt 安装 MAFFT ……${gl_bai}"
	bio_apt_install mafft || { echo -e "${gl_hong}MAFFT 安装失败${gl_bai}"; return 1; }
	local new_ver
	new_ver=$(mafft --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
	if bio_ver_ge "$new_ver" "$bio_mafft_ver"; then
		echo -e "${gl_lv}MAFFT 安装完成：v$new_ver${gl_bai}"
		return 0
	fi
	# apt 源版本不足时回退 MAFFT 官方 deb（仅提供 x86_64）
	if [ "$(uname -m)" != "x86_64" ]; then
		echo -e "${gl_huang}系统源 MAFFT 版本为 ${new_ver:-未知}，官方 deb 仅支持 x86_64，请手动确认${gl_bai}"
		return 1
	fi
	echo -e "${gl_kjlan}改用 MAFFT 官方 $bio_mafft_ver deb 包安装（系统源版本：${new_ver:-未知}）……${gl_bai}"
	local deb="$bio_work_dir/mafft_${bio_mafft_ver}-1_amd64.deb"
	if ! bio_fetch "$deb" "https://mafft.cbrc.jp/alignment/software/mafft_${bio_mafft_ver}-1_amd64.deb"; then
		echo -e "${gl_hong}MAFFT 官方包下载失败${gl_bai}"
		return 1
	fi
	bio_apt_install "$deb" || { echo -e "${gl_hong}MAFFT deb 安装失败${gl_bai}"; return 1; }
	echo -e "${gl_lv}MAFFT 安装完成：$(mafft --version 2>&1 | head -n 1)${gl_bai}"
}


bio_install_iqtree() {
	if command -v iqtree3 >/dev/null 2>&1; then
		local cur
		cur=$(iqtree3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
		if [ "$cur" = "$bio_iqtree_ver" ]; then
			echo -e "${gl_lv}IQ-TREE 已安装：v$cur${gl_bai}"
			return 0
		fi
	fi
	local arch candidates c tarball url
	case "$(uname -m)" in
		x86_64) arch="intel" ;;
		aarch64|arm64) arch="arm" ;;
		*)
			echo -e "${gl_hong}不支持的 CPU 架构: $(uname -m)${gl_bai}"
			return 1
			;;
	esac
	# 官方仓库为 iqtree/iqtree3，资产名随版本变化，依次尝试候选包
	if [ "$arch" = "intel" ]; then
		candidates="iqtree-$bio_iqtree_ver-Linux-intel.tar.gz iqtree-$bio_iqtree_ver-Linux.tar.gz"
	else
		candidates="iqtree-$bio_iqtree_ver-Linux-arm.tar.gz iqtree-$bio_iqtree_ver-Linux.tar.gz"
	fi
	tarball=""
	for c in $candidates; do
		url="https://github.com/iqtree/iqtree3/releases/download/v$bio_iqtree_ver/$c"
		echo -e "${gl_kjlan}下载 IQ-TREE $bio_iqtree_ver 官方二进制：$c ……${gl_bai}"
		if bio_fetch "$bio_work_dir/$c" "$url"; then
			tarball="$bio_work_dir/$c"
			break
		fi
		rm -f "$bio_work_dir/$c"
	done
	if [ -z "$tarball" ]; then
		echo -e "${gl_hong}IQ-TREE 下载失败，请检查网络或手动下载后安装：${gl_bai}"
		echo -e "  https://github.com/iqtree/iqtree3/releases/tag/v$bio_iqtree_ver"
		return 1
	fi
	local ext_dir="$bio_work_dir/iqtree-extract"
	rm -rf "$ext_dir"
	mkdir -p "$ext_dir"
	tar -zxf "$tarball" -C "$ext_dir" || { echo -e "${gl_hong}IQ-TREE 解压失败${gl_bai}"; return 1; }
	local src_bin
	src_bin=$(find "$ext_dir" -type f -name 'iqtree3*' ! -name '*static*' 2>/dev/null | head -n 1)
	if [ -z "$src_bin" ]; then
		echo -e "${gl_hong}未在压缩包中找到 IQ-TREE 可执行文件${gl_bai}"
		return 1
	fi

	local dest_dir
	if [ "$(id -u)" -eq 0 ] || [ -w /usr/local/bin ]; then
		dest_dir="/usr/local/bin"
	else
		dest_dir="$HOME/.local/bin"
		mkdir -p "$dest_dir"
		case ":$PATH:" in
			*":$dest_dir:"*) ;;
			*)
				bio_register_path "$dest_dir"
				export PATH="$dest_dir:$PATH"
				;;
		esac
	fi
	bio_sudo cp -f "$src_bin" "$dest_dir/iqtree3" || { echo -e "${gl_hong}IQ-TREE 部署失败${gl_bai}"; return 1; }
	bio_sudo chmod 755 "$dest_dir/iqtree3"
	bio_sudo ln -sf "$dest_dir/iqtree3" "$dest_dir/iqtree" 2>/dev/null
	hash -r
	echo -e "${gl_lv}IQ-TREE 安装完成：$(iqtree3 --version 2>&1 | head -n 1)${gl_bai}"
}


bio_install_r() {
	if command -v R >/dev/null 2>&1; then
		local cur
		cur=$(R --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
		if bio_ver_ge "$cur" "$bio_r_minver"; then
			echo -e "${gl_lv}R 已安装：v$cur${gl_bai}"
			return 0
		fi
		echo -e "${gl_huang}R 版本低于 $bio_r_minver（当前 ${cur:-未知}），尝试升级……${gl_bai}"
	fi

	if ! command -v apt >/dev/null 2>&1; then
		# 非 apt 发行版走通用安装
		if command -v dnf >/dev/null 2>&1; then
			bio_sudo dnf install -y R && echo -e "${gl_lv}R 安装完成：$(R --version 2>&1 | head -n 1)${gl_bai}" && return 0
		elif command -v yum >/dev/null 2>&1; then
			bio_sudo yum install -y R && echo -e "${gl_lv}R 安装完成：$(R --version 2>&1 | head -n 1)${gl_bai}" && return 0
		fi
		echo -e "${gl_hong}无法识别包管理器，请手动安装 R${gl_bai}"
		return 1
	fi

	# Ubuntu/Debian：系统源自带版本偏旧，先走 CRAN 官方源拿 4.4+
	local codename
	codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release 2>/dev/null | cut -d= -f2)
	if [ -n "$codename" ]; then
		echo -e "${gl_kjlan}添加 CRAN 官方 apt 源（$codename-cran40）安装 R $bio_r_minver+ ……${gl_bai}"
		bio_apt_install curl ca-certificates gpg >/dev/null 2>&1
		bio_sudo mkdir -p /etc/apt/keyrings
		if curl -fsSL --connect-timeout 15 --max-time 60 "https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc" | bio_sudo tee /etc/apt/keyrings/cran40.asc >/dev/null &&
			echo "deb [signed-by=/etc/apt/keyrings/cran40.asc] https://cloud.r-project.org/bin/linux/ubuntu ${codename}-cran40/" | bio_sudo tee /etc/apt/sources.list.d/cran40.list >/dev/null; then
			bio_apt_updated="0"
			bio_apt_ready
			if bio_apt_install r-base; then
				local rv
				rv=$(R --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
				echo -e "${gl_lv}R 安装完成：v${rv:-未知}${gl_bai}"
				return 0
			fi
		fi
		echo -e "${gl_huang}CRAN 源配置失败，回退系统 apt 源安装……${gl_bai}"
	fi

	if bio_apt_install r-base; then
		local rv2
		rv2=$(R --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
		if bio_ver_ge "$rv2" "$bio_r_minver"; then
			echo -e "${gl_lv}R 安装完成：v$rv2${gl_bai}"
		else
			echo -e "${gl_huang}R 已安装但版本 v${rv2:-未知} 低于建议的 $bio_r_minver.x，请按需手动升级${gl_bai}"
		fi
		return 0
	fi
	echo -e "${gl_hong}R 安装失败${gl_bai}"
	return 1
}


bio_install_buildtools() {
	echo -e "${gl_kjlan}安装基础编译环境及常用依赖……${gl_bai}"
	if command -v apt >/dev/null 2>&1; then
		bio_apt_install build-essential gcc g++ make wget curl git unzip bzip2 xz-utils ca-certificates file pkg-config perl || {
			echo -e "${gl_hong}基础编译环境安装失败${gl_bai}"
			return 1
		}
	elif command -v dnf >/dev/null 2>&1; then
		bio_sudo dnf install -y gcc gcc-c++ make wget curl git unzip bzip2 xz-utils file perl
	elif command -v yum >/dev/null 2>&1; then
		bio_sudo yum install -y gcc gcc-c++ make wget curl git unzip bzip2 xz-utils file perl
	else
		echo -e "${gl_hong}暂不支持该发行版，请手动安装 gcc/make/wget/curl/git${gl_bai}"
		return 1
	fi
	echo -e "${gl_lv}基础编译环境就绪：gcc $(gcc -dumpversion 2>/dev/null)、$(git --version 2>/dev/null)${gl_bai}"
}


bio_row() {
	# bio_row <组件名> <0=已装/1=未装> <版本信息>
	if [ "$2" = "0" ]; then
		echo -e "  ${gl_lv}[已安装]${gl_bai} $1 ${gl_huang}$3${gl_bai}"
	else
		echo -e "  ${gl_hong}[未安装]${gl_bai} $1"
	fi
}


bio_check_status() {
	bio_init_paths
	local cur
	echo -e "${gl_kjlan}生物信息学分析环境体检（PspC 清单）${gl_bai}"
	echo "----------------------------------------"

	if [ -x "$bio_env_bin/python" ]; then
		local path_state
		case ":$PATH:" in
			*":$bio_env_bin:"*) path_state="PATH 已生效" ;;
			*) path_state="PATH 重新登录后生效" ;;
		esac
		bio_row "Miniconda + Python $bio_python_ver（$bio_env_name 环境）" 0 "$("$bio_env_bin/python" --version 2>&1)，$path_state"
	else
		bio_row "Miniconda + Python $bio_python_ver（$bio_env_name 环境）" 1
	fi

	if "$bio_env_bin/python" -c 'import Bio' >/dev/null 2>&1; then
		bio_row "Biopython（FASTA 读取/序列处理）" 0 "v$("$bio_env_bin/python" -c 'import Bio; print(Bio.__version__)' 2>/dev/null)"
	else
		bio_row "Biopython（FASTA 读取/序列处理）" 1
	fi

	if [ -x "$bio_env_bin/signalp" ]; then
		bio_row "SignalP $bio_sigp_ver（信号肽预测）" 0 "$("$bio_env_bin/signalp" --version 2>&1 | head -n 1)"
	else
		bio_row "SignalP $bio_sigp_ver（信号肽预测）" 1
	fi

	if command -v cd-hit >/dev/null 2>&1; then
		cur=$(cd-hit -h 2>&1 | grep -oiE 'version [0-9.]+' | head -n 1 | grep -oE '[0-9]+\.[0-9.]+')
		bio_row "CD-HIT（序列去冗余）" 0 "v${cur:-未知}"
	else
		bio_row "CD-HIT（序列去冗余）" 1
	fi

	if command -v mafft >/dev/null 2>&1; then
		cur=$(mafft --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
		bio_row "MAFFT（多序列比对）" 0 "v${cur:-未知}"
	else
		bio_row "MAFFT（多序列比对）" 1
	fi

	if command -v iqtree3 >/dev/null 2>&1; then
		cur=$(iqtree3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
		bio_row "IQ-TREE（系统发育树）" 0 "v${cur:-未知}"
	else
		bio_row "IQ-TREE（系统发育树）" 1
	fi

	if command -v R >/dev/null 2>&1; then
		cur=$(R --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
		bio_row "R（统计/绘图）" 0 "v${cur:-未知}"
	else
		bio_row "R（统计/绘图）" 1
	fi

	if command -v gcc >/dev/null 2>&1 && command -v make >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
		bio_row "基础编译环境（gcc/make/git/wget/curl 等）" 0 "gcc v$(gcc -dumpversion 2>/dev/null)"
	else
		bio_row "基础编译环境（gcc/make/git/wget/curl 等）" 1
	fi

	echo -e "  ${gl_kjlan}[免安装]${gl_bai} ConSurf（蛋白保守性分析）使用 Web Server: https://consurf.tau.ac.cn"
	if [ ! -x "$bio_env_bin/signalp" ]; then
		echo -e "  ${gl_huang}提示：SignalP 手动安装包请放置于 $bio_work_dir/${gl_bai}"
	fi
	echo "----------------------------------------"
}


bio_install_all() {
	local fail=0
	echo -e "${gl_kjlan}开始一键安装 PspC 生物信息学分析环境……${gl_bai}"
	echo -e "预计 20-60 分钟（取决于网络）；SignalP 步骤需确认一次学术许可。"
	echo -e "安装顺序：基础编译环境 → Python 环境 → Biopython → CD-HIT → MAFFT → IQ-TREE → R → SignalP"
	echo "----------------------------------------"

	bio_install_buildtools || fail=$((fail+1))
	echo "----------------------------------------"
	bio_install_conda || fail=$((fail+1))
	echo "----------------------------------------"
	bio_install_biopython || fail=$((fail+1))
	echo "----------------------------------------"
	bio_install_cdhit || fail=$((fail+1))
	echo "----------------------------------------"
	bio_install_mafft || fail=$((fail+1))
	echo "----------------------------------------"
	bio_install_iqtree || fail=$((fail+1))
	echo "----------------------------------------"
	bio_install_r || fail=$((fail+1))
	echo "----------------------------------------"
	bio_install_signalp || fail=$((fail+1))
	echo "----------------------------------------"

	if [ "$fail" = "0" ]; then
		echo -e "${gl_lv}全部组件安装完成！${gl_bai}"
	else
		echo -e "${gl_huang}安装结束，其中 $fail 项失败，可从菜单单独重试。${gl_bai}"
	fi
	echo -e "${gl_kjlan}环境体检结果：${gl_bai}"
	bio_check_status
}


bio_view_log() {
	if [ ! -f "$bio_log_file" ]; then
		echo -e "${gl_huang}暂无安装日志（尚未执行过安装）：$bio_log_file${gl_bai}"
		return 0
	fi
	echo -e "${gl_kjlan}安装日志尾部 100 行${gl_bai}"
	echo -e "完整日志文件: ${gl_huang}$bio_log_file${gl_bai}"
	echo "----------------------------------------"
	tail -n 100 "$bio_log_file"
	echo "----------------------------------------"
	echo -e "查看完整日志: ${gl_huang}less -R $bio_log_file${gl_bai}"
}


bioinfo_menu() {
	bio_init_paths
	while true; do
		clear
		echo -e "${gl_kjlan}"
		echo "========================================"
		echo " 生物信息学分析环境搭建（PspC 清单）"
		echo "========================================"
		echo -e "目标系统: Ubuntu 24.04 LTS    环境目录: ${gl_huang}$bio_env_bin${gl_bai}"
		echo -e "安装日志: ${gl_huang}$bio_log_file${gl_bai}"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "${gl_kjlan}1.   ${gl_bai}一键安装全部环境（推荐首次使用）"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "${gl_kjlan}2.   ${gl_bai}Miniconda + Python $bio_python_ver 基础环境"
		echo -e "${gl_kjlan}3.   ${gl_bai}Biopython（FASTA 读取/序列处理）"
		echo -e "${gl_kjlan}4.   ${gl_bai}SignalP $bio_sigp_ver（信号肽预测，需学术许可）"
		echo -e "${gl_kjlan}5.   ${gl_bai}CD-HIT $bio_cdhit_ver（序列去冗余）"
		echo -e "${gl_kjlan}6.   ${gl_bai}MAFFT $bio_mafft_ver（多序列比对）"
		echo -e "${gl_kjlan}7.   ${gl_bai}IQ-TREE $bio_iqtree_ver（系统发育树）"
		echo -e "${gl_kjlan}8.   ${gl_bai}R $bio_r_minver.x+（统计/绘图）"
		echo -e "${gl_kjlan}9.   ${gl_bai}基础编译环境及常用依赖"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "${gl_kjlan}10.  ${gl_bai}环境体检（查看安装状态与版本）"
		echo -e "${gl_kjlan}11.  ${gl_bai}查看安装日志（排障）"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		echo -e "${gl_kjlan}0.   ${gl_bai}返回主菜单"
		echo -e "${gl_kjlan}------------------------${gl_bai}"
		read -e -p "请输入你的选择: " choice
		case $choice in
			1) clear; bio_logged "一键安装全部环境" bio_install_all ;;
			2) clear; bio_logged "Miniconda + Python $bio_python_ver 环境" bio_install_conda ;;
			3) clear; bio_logged "Biopython" bio_install_biopython ;;
			4) clear; bio_logged "SignalP $bio_sigp_ver" bio_install_signalp ;;
			5) clear; bio_logged "CD-HIT $bio_cdhit_ver" bio_install_cdhit ;;
			6) clear; bio_logged "MAFFT $bio_mafft_ver" bio_install_mafft ;;
			7) clear; bio_logged "IQ-TREE $bio_iqtree_ver" bio_install_iqtree ;;
			8) clear; bio_logged "R $bio_r_minver.x+" bio_install_r ;;
			9) clear; bio_logged "基础编译环境及常用依赖" bio_install_buildtools ;;
			10) clear; bio_check_status ;;
			11) clear; bio_view_log ;;
			0) break ;;
			*) echo "无效的输入!" ;;
		esac
		break_end
	done
}


# ----------------------------
# 00. 脚本更新
# ----------------------------
kejilion_update() {

cd ~
while true; do
	clear
	echo "更新日志"
	echo "------------------------"
	echo "全部日志: ${dist_base}/kejilion_sh_log.txt"
	echo "------------------------"

	curl -s --max-time 15 "${dist_base}/kejilion_sh_log.txt" | tail -n 30
	# 只下载文件头部获取版本号，避免下载整个脚本
	local sh_v_new=$(curl -s --max-time 15 -r 0-200 "${dist_base}/kejilion.sh" | grep -o 'sh_v="[0-9.]*"' | head -1 | cut -d '"' -f 2)

	if [ -z "$sh_v_new" ]; then
		echo -e "${gl_hong}无法获取最新版本信息，请检查网络连接${gl_bai}"
	elif [ "$sh_v" = "$sh_v_new" ]; then
		echo -e "${gl_lv}你已经是最新版本！${gl_huang}v$sh_v${gl_bai}"
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
			# 备份当前脚本
			cp -f ~/kejilion.sh ~/kejilion.sh.bak 2>/dev/null

			# 下载到临时文件，校验后再替换
			local tmp_file=$(mktemp ~/kejilion_tmp.XXXXXX)
			if curl -sS --max-time 60 --fail -o "$tmp_file" "${dist_base}/kejilion.sh" && \
			   [ -s "$tmp_file" ] && \
			   head -1 "$tmp_file" | grep -q '^#!/bin/bash'; then
				chmod +x "$tmp_file"
				mv -f "$tmp_file" ~/kejilion.sh
				CheckFirstRun_true
				cp -f ~/kejilion.sh /usr/local/bin/k > /dev/null 2>&1
				ln -sf /usr/local/bin/k /usr/bin/k > /dev/null 2>&1
				echo -e "${gl_lv}脚本已更新到最新版本！${gl_huang}v$sh_v_new${gl_bai}"
			else
				rm -f "$tmp_file"
				# 恢复备份
				if [ -f ~/kejilion.sh.bak ]; then
					mv -f ~/kejilion.sh.bak ~/kejilion.sh
				fi
				echo -e "${gl_hong}更新失败！下载出错或文件校验不通过，已恢复原版本${gl_bai}"
			fi
			break_end
			~/kejilion.sh
			exit
			;;
		2)
			clear
			# 自动更新任务：下载到临时文件 → 校验 → 备份 → 替换 → 恢复许可状态 → 部署 k 命令
			SH_Update_task="cd ~ && tmp=\$(mktemp ~/kejilion_tmp.XXXXXX) && curl -sS --max-time 60 --fail -o \"\$tmp\" ${dist_base}/kejilion.sh && [ -s \"\$tmp\" ] && head -1 \"\$tmp\" | grep -q '^#!/bin/bash' && cp -f ~/kejilion.sh ~/kejilion.sh.bak 2>/dev/null && chmod +x \"\$tmp\" && mv -f \"\$tmp\" ~/kejilion.sh"
			# 从旧脚本恢复许可同意状态
			SH_Update_task="$SH_Update_task && grep -q 'permission_granted=\"true\"' ~/kejilion.sh.bak 2>/dev/null && sed -i 's/permission_granted=\"false\"/permission_granted=\"true\"/' ~/kejilion.sh"
			# 部署到 /usr/local/bin/k 和 /usr/bin/k
			SH_Update_task="$SH_Update_task; cp -f ~/kejilion.sh /usr/local/bin/k 2>/dev/null; ln -sf /usr/local/bin/k /usr/bin/k 2>/dev/null"
			# 下载失败时清理临时文件
			SH_Update_task="$SH_Update_task || rm -f \"\$tmp\" 2>/dev/null"

			check_crontab_installed
			(crontab -l | grep -v "kejilion.sh") | crontab -
			(crontab -l 2>/dev/null; echo "$(shuf -i 0-59 -n 1) 2 * * * bash -c '$SH_Update_task'") | crontab -
			echo -e "${gl_lv}自动更新已开启，每天凌晨2点脚本会自动更新！${gl_bai}"
			break_end
			;;
		3)
			clear
			(crontab -l | grep -v "kejilion.sh") | crontab -
			echo -e "${gl_lv}自动更新已关闭${gl_bai}"
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
echo -e "${gl_kjlan}4.   ${gl_bai}生物信息环境搭建"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}00.  ${gl_bai}脚本更新"
echo -e "${gl_kjlan}------------------------${gl_bai}"
echo -e "${gl_kjlan}0.   ${gl_bai}退出脚本"
echo -e "${gl_kjlan}------------------------${gl_bai}"
read -e -p "请输入你的选择: " choice

case $choice in
  1) linux_info ;;
  2) clear ; linux_update ;;
  3) clear ; linux_clean ;;
  4) bioinfo_menu ;;
  00) kejilion_update ;;
  0) clear ; exit ;;
  *) echo "无效的输入!" ;;
esac
	break_end
done
}


# ----------------------------
# 自举安装：兼容两种拉取方式
#   bash <(curl -sL https://bio-sh.nknpq3nl.icu)               进程替换，源是管道需重新下载落盘
#   curl -sL URL -o ~/kejilion.sh && bash ~/kejilion.sh        本地文件，直接复制自身
# ----------------------------
install_self() {
	local target="$HOME/kejilion.sh"
	local src="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)"

	# 进程替换/管道执行时源路径形如 /dev/fd/63，不能作为安装源
	case "$src" in
		/dev/fd/*|/proc/self/fd/*) src="" ;;
	esac

	if [ -n "$src" ] && [ -f "$src" ] && [ "$src" != "$target" ]; then
		cp -f "$src" "$target"
	elif [ ! -f "$target" ]; then
		echo -e "${gl_kjlan}正在下载脚本到本地……${gl_bai}"
		if ! curl -sSfL --max-time 60 "${dist_base}/kejilion.sh" -o "$target"; then
			echo -e "${gl_hong}安装失败：无法从 ${dist_base} 下载脚本${gl_bai}"
			return 1
		fi
	fi
	chmod +x "$target"

	# 部署 k 快捷命令（需 root 或 /usr/local/bin 可写；失败不阻塞脚本使用）
	if [ "$(id -u)" -eq 0 ] || [ -w /usr/local/bin ]; then
		cp -f "$target" /usr/local/bin/k
		chmod +x /usr/local/bin/k
		ln -sf /usr/local/bin/k /usr/bin/k 2>/dev/null
	fi
}

sed -i '/^alias k=/d' ~/.bashrc > /dev/null 2>&1
sed -i '/^alias k=/d' ~/.profile > /dev/null 2>&1
sed -i '/^alias k=/d' ~/.bash_profile > /dev/null 2>&1
install_self

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
			install "$@"
			;;
		remove|del|uninstall|卸载)
			shift
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
		env|环境)
			bioinfo_menu
			;;
		*)
			echo "未知命令: $1"
			echo "直接运行 k 进入菜单"
			;;
	esac
fi
