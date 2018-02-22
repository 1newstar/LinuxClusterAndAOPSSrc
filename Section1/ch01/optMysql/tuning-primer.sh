#!/bin/sh
# vim: ts=8
#########################################################################
#									#
#	MySQL performance tuning primer script				#
#	Writen by: Matthew Montgomery					#
#	Report bugs to: https://bugs.launchpad.net/mysql-tuning-primer	#
#	Inspired by: MySQLARd (http://gert.sos.be/demo/mysqlar/)	#
#	Version: 1.6-r1		Released: 2011-08-06			#
#	Licenced under GPLv2                                            #
#									#
#########################################################################

#########################################################################
#									#
#	Usage: ./tuning-primer.sh [ mode ] 				#用法
#									#
#	Available Modes: 						#
#		all : 		perform all checks (default)		#检查所有
#		prompt : 	prompt for login credintials and socket	#认证
#				and execution mode			#
# 		mem, memory : 	run checks for tunable options which	#内存检测
#				effect memory usage			#
#		disk, file :	run checks for options which effect	#磁盘检测
#				i/o performance or file handle limits	#
#		innodb :	run InnoDB checks /* to be improved */	# Innodb检测
#		misc : 		run checks for that don't categorise	#misc检测
#				well Slow Queries, Binary logs,		#
#				Used Connections and Worker Threads	#
#########################################################################
#									#
# Set this socket variable ONLY if you have multiple instances running	# 
# or we are unable to find your socket, and you don't want to to be	#
# prompted for input each time you run this script.			#
#									#
#########################################################################
######
#	 导入依赖模块 
######
#【色彩化打印】
source ./colorPrint.sh
#【banner工具】
source ./banner.sh

socket=

######
#	 检查mysql的sock文件mysql.sock 
######
check_for_socket () 
{
	if [ -z "$socket" ] ; then
		# Use ~/my.cnf version
		if [ -f ~/.my.cnf ] ; then
			cnf_socket=$(grep ^socket ~/.my.cnf | awk -F \= '{ print $2 }' | head -1)
		fi

		if [ -S "$cnf_socket" ] ; then
			socket=$cnf_socket
		elif [ -S /var/lib/mysql/mysql.sock ] ; then
			socket=/var/lib/mysql/mysql.sock
		elif [ -S /var/run/mysqld/mysqld.sock ] ; then
			socket=/var/run/mysqld/mysqld.sock
		elif [ -S /tmp/mysql.sock ] ; then
			socket=/tmp/mysql.sock
		else
			if [ -S "$ps_socket" ] ; then
			socket=$ps_socket
			fi
		fi
	fi

	if [ -S "$socket" ] ; then
		echo UP > /dev/null
	else	#未找到mysql.sock文件，直接退出
		fnColorEcho "No valid socket file \"$socket\" found!" boldred
		fnColorEcho "The mysqld process is not running or it is installed in a custom location." red
		fnColorEcho "If you are sure mysqld is running, execute script in \"prompt\" mode or set " red
		fnColorEcho "the socket= variable at the top of this script" red
		exit 1
	fi
}

######
#	 检查认证密码 
######
check_for_plesk_passwords () 
{
	if [ -f /etc/psa/.psa.shadow ] ; then
	        mysql="mysql -S $socket -u admin -p$(cat /etc/psa/.psa.shadow)"
	        mysqladmin="mysqladmin -S $socket -u admin -p$(cat /etc/psa/.psa.shadow)"
	else
	        mysql="mysql"
	        mysqladmin="mysqladmin"
	        # mysql="mysql -S $socket"
	        # mysqladmin="mysqladmin -S $socket"
	fi
}

######
#	 检查登陆状态 
######
check_mysql_login () {
## -- Test for running mysql -- ##

	is_up=$($mysqladmin ping 2>&1)
	if [ "$is_up" = "mysqld is alive" ] ; then
		echo UP > /dev/null
	 	# echo $is_up
	elif [ "$is_up" != "mysqld is alive" ] ; then
		printf "\n"
		fnColorEcho "Using login values from ~/.my.cnf" 
		fnColorEcho "- INITIAL LOGIN ATTEMPT FAILED -" boldred
		if [ -z $prompted ] ; then
		find_webmin_passwords
		else
			return 1
		fi
		
	else 
		fnColorEcho "Unknow exit status" red
		exit -1
	fi
}

######
#	 最后登陆尝试 
######
final_login_attempt () 
{
        is_up=$($mysqladmin ping 2>&1)
        if [ "$is_up" = "mysqld is alive" ] ; then
                echo UP > /dev/null
        elif [ "$is_up" != "mysqld is alive" ] ; then
                fnColorEcho "- FINAL LOGIN ATTEMPT FAILED -" boldred
		fnColorEcho "Unable to log into socket: $socket" boldred
                exit 1
        fi
}

######
#	 第二次登陆失败处理 
######
second_login_failed () 
{
## -- create a ~/.my.cnf and exit when all else fails -- ##

	fnColorEcho "Could not auto detect login info!"
	fnColorEcho "Found potential sockets: $found_socks"
	fnColorEcho "Using: $socket" red
	read -p "Would you like to provide a different socket?: [y/N] " REPLY
		case $REPLY in 
			yes | y | Y | YES)
			read -p "Socket: " socket
			;;
		esac
	read -p "Do you have your login handy ? [y/N] : " REPLY
	case $REPLY in 
		yes | y | Y | YES)
		answer1='yes'
		read -p "User: " user
		read -rp "Password: " pass
		if [ -z $pass ] ; then
		export mysql="$mysql -S$socket -u$user"
		export mysqladmin="$mysqladmin -S$socket -u$user"
		else
		export mysql="$mysql -S$socket -u$user -p$pass"
		export mysqladmin="$mysqladmin -S$socket -u$user -p$pass"
		fi
		;;
		*)
		fnColorEcho "Please create a valid login to MySQL"
		fnColorEcho "Or, set correct values for  'user=' and 'password=' in ~/.my.cnf"
		;;
	esac
	fnColorEcho " "
	read -p "Would you like me to create a ~/.my.cnf file for you? [y/N] : " REPLY
        case $REPLY in
	        yes | y | Y | YES)
		answer2='yes'
		if [ ! -f ~/.my.cnf ] ; then
			umask 077
			printf "[client]\nuser=$user\npassword=$pass\nsocket=$socket" > ~/.my.cnf
			if [ "$answer1" != 'yes' ] ; then
				exit 1
			else
				final_login_attempt
				return 0
			fi
		else
			printf "\n"
			fnColorEcho "~/.my.cnf already exists!" boldred
			printf "\n"
			read -p "Replace ? [y/N] : " REPLY
			if [ "$REPLY" = 'y' ] || [ "$REPLY" = 'Y' ] ; then 
			printf "[client]\nuser=$user\npassword=$pass\socket=$socket" > ~/.my.cnf
				if [ "$answer1" != 'yes' ] ; then
					exit 1
				else
					final_login_attempt
					return 0
				fi
			else
				fnColorEcho "Please set the 'user=' and 'password=' and 'socket=' values in ~/.my.cnf"
				exit 1
			fi
		fi
		;;
		*)
		if [ "$answer1" != 'yes' ] ; then
			exit 1
		else
			final_login_attempt
			return 0
		fi
		;;
	esac
}

find_webmin_passwords () {

## -- populate the .my.cnf file using values harvested from Webmin -- ##

	fnColorEcho "Testing for stored webmin passwords:"
	if [ -f /etc/webmin/mysql/config ] ; then
		user=$(grep ^login= /etc/webmin/mysql/config | cut -d "=" -f 2)
		pass=$(grep ^pass= /etc/webmin/mysql/config | cut -d "=" -f 2)
		if [  $user ] && [ $pass ] && [ ! -f ~/.my.cnf  ] ; then
			fnColorEcho "Setting login info as User: $user Password: $pass"
			touch ~/.my.cnf
			chmod 600 ~/.my.cnf
			printf "[client]\nuser=$user\npassword=$pass" > ~/.my.cnf 
			fnColorEcho "Retrying login"
			is_up=$($mysqladmin ping 2>&1)
			if [ "$is_up" = "mysqld is alive"  ] ; then
				echo UP > /dev/null
			else
				second_login_failed
			fi
		echo
		else
			second_login_failed
		echo
		fi
	else
	fnColorEcho " None Found" boldred
		second_login_failed
	fi
}

#########################################################################
#									#
#  Function to pull MySQL status variable				#
#									#
#  Call using :								#
#	mysql_status \'Mysql_status_variable\' bash_dest_variable	#
#									#
#########################################################################

mysql_status () {
	local status=$($mysql -Bse "show /*!50000 global */ status like $1" | awk '{ print $2 }')
	export "$2"=$status
}

#########################################################################
#									#
#  Function to pull MySQL server runtime variable			#
#									#
#  Call using :								#
#	mysql_variable \'Mysql_server_variable\' bash_dest_variable	#
#	- OR -								#
#	mysql_variableTSV \'Mysql_server_variable\' bash_dest_variable	#
#									#
#########################################################################

mysql_variable () {
	local variable=$($mysql -Bse "show /*!50000 global */ variables like $1" | awk '{ print $2 }')
	export "$2"=$variable
}
mysql_variableTSV () {
        local variable=$($mysql -Bse "show /*!50000 global */ variables like $1" | awk -F \t '{ print $2 }')
        export "$2"=$variable
}

float2int () {
        local variable=$(echo "$1 / 1" | bc -l)
        export "$2"=$variable
}

divide () {

# -- Divide two intigers -- #

	usage="$0 dividend divisor '$variable' scale"
	if [ $1 -ge 1 ]	; then
		dividend=$1
	else
		fnColorEcho "Invalid Dividend" red
		echo $usage
		exit 1
	fi
	if [ $2 -ge 1 ] ; then
		divisor=$2
	else
		fnColorEcho "Invalid Divisor" red
		echo $usage
		exit 1
	fi
	if [ ! -n $3 ] ; then
		fnColorEcho "Invalid variable name" red
		echo $usage
		exit 1
	fi
	if [ -z $4 ] ; then
		scale=2
	elif [ $4 -ge 0 ] ; then
		scale=$4
	else
		fnColorEcho "Invalid scale" red
		echo $usage
		exit 1
	fi
	export $3=$(echo "scale=$scale; $dividend / $divisor" | bc -l)
}

human_readable () {

#########################################################################
#									#
#  Convert a value in to human readable size and populate a variable	#
#  with the result.							#
#									#
#  Call using:								#
#	human_readable $value 'variable name' [ places of precision]	#
#									#
#########################################################################

	## value=$1
	## variable=$2
	scale=$3

	if [ $1 -ge 1073741824 ] ; then
		if [ -z $3 ] ; then
			scale=2
		fi
		divide $1 1073741824 "$2" $scale
		unit="G"
	elif [ $1 -ge 1048576 ] ; then
		if [ -z $3 ] ; then 
			scale=0
		fi
		divide $1 1048576 "$2" $scale
	        unit="M"
	elif [ $1 -ge 1024 ] ; then
		if [ -z $3 ] ; then
			scale=0
		fi
		divide $1 1024 "$2" $scale
	        unit="K"
	else
		export "$2"=$1
	        unit="bytes"
	fi
	# let "$2"=$HR
}

human_readable_time () {

########################################################################
#								       #
#	Function to produce human readable time                        #
#								       #
########################################################################

	usage="$0 seconds 'variable'"
	if [ -z $1 ] || [ -z $2 ] ; then
		fnColorEcho $usage red
		exit 1
	fi
	days=$(echo "scale=0 ; $1 / 86400" | bc -l)
	remainder=$(echo "scale=0 ; $1 % 86400" | bc -l)
	hours=$(echo "scale=0 ; $remainder / 3600" | bc -l)
	remainder=$(echo "scale=0 ; $remainder % 3600" | bc -l)
	minutes=$(echo "scale=0 ; $remainder / 60" | bc -l)
	seconds=$(echo "scale=0 ; $remainder % 60" | bc -l)
	export $2="$days days $hours hrs $minutes min $seconds sec"
}

check_mysql_version () {

## -- Print Version Info -- ##

	mysql_variable \'version\' mysql_version
	mysql_variable \'version_compile_machine\' mysql_version_compile_machine
	
if [ "$mysql_version_num" -lt 050000 ]; then
	fnColorEcho "MySQL Version $mysql_version $mysql_version_compile_machine is EOL please upgrade to MySQL 4.1 or later" boldred
else
	fnColorEcho "MySQL Version $mysql_version $mysql_version_compile_machine"
fi


}

post_uptime_warning () {

#########################################################################
#									#
#  Present a reminder that mysql must run for a couple of days to	#
#  build up good numbers in server status variables before these tuning	#
#  suggestions should be used.						#
#									#
#########################################################################

	mysql_status \'Uptime\' uptime
	mysql_status \'Threads_connected\' threads
	queries_per_sec=$(($questions/$uptime))
	human_readable_time $uptime uptimeHR

	fnColorEcho "Uptime = $uptimeHR"
	fnColorEcho "Avg. qps = $queries_per_sec"
	fnColorEcho "Total Questions = $questions"
	fnColorEcho "Threads Connected = $threads"
	echo

	if [ $uptime -gt 172800 ] ; then
		fnColorEcho "Server has been running for over 48hrs."
		fnColorEcho "It should be safe to follow these recommendations"
	else
		fnColorEchoInline "Warning: " boldred
		fnColorEcho "Server has not been running for at least 48hrs." boldred
		fnColorEcho "It may not be safe to use these recommendations" boldred

	fi
	echo ""
	fnColorEcho "To find out more information on how each of these" red
	fnColorEcho "runtime variables effects performance visit:" red
	if [ "$major_version" = '3.23' ] || [ "$major_version" = '4.0' ] || [ "$major_version" = '4.1' ] ; then
	fnColorEcho "http://dev.mysql.com/doc/refman/4.1/en/server-system-variables.html" boldblue
	elif [ "$major_version" = '5.0' ] || [ "$mysql_version_num" -gt '050100' ]; then
	fnColorEcho "http://dev.mysql.com/doc/refman/$major_version/en/server-system-variables.html" boldblue	
	else
	fnColorEcho "UNSUPPORTED MYSQL VERSION" boldred
	exit 1
	fi
	fnColorEcho "Visit http://www.mysql.com/products/enterprise/advisors.html" boldblue
	fnColorEcho "for info about MySQL's Enterprise Monitoring and Advisory Service" boldblue
}

check_slow_queries () {

## -- Slow Queries -- ## 

	fnColorEcho "SLOW QUERIES" boldblue

	mysql_status \'Slow_queries\' slow_queries
	mysql_variable \'long_query_time\' long_query_time
	mysql_variable \'log%queries\' log_slow_queries
	
	prefered_query_time=5
	if [ -e /etc/my.cnf ] ; then
		if [ -z $log_slow_queries ] ; then
			log_slow_queries=$(grep log-slow-queries /etc/my.cnf)
		fi
	fi

	if [ "$log_slow_queries" = 'ON' ] ; then
		fnColorEcho "The slow query log is enabled."
	elif [ "$log_slow_queries" = 'OFF' ] ; then
		fnColorEchoInline "The slow query log is "
		fnColorEchoInline "NOT" boldred
		fnColorEcho " enabled."
	elif [ -z $log_slow_queries ] ; then
		fnColorEchoInline "The slow query log is "
		fnColorEchoInline "NOT" boldred
		fnColorEcho " enabled."
	else
		fnColorEcho "Error: $log_slow_queries" boldred
	fi
	fnColorEcho "Current long_query_time = $long_query_time sec."
	fnColorEchoInline "You have "
	fnColorEchoInline "$slow_queries" boldred 
	fnColorEchoInline " out of "
	fnColorEchoInline "$questions" boldred
	fnColorEcho " that take longer than $long_query_time sec. to complete"
	
	float2int long_query_time long_query_timeInt

	if [ $long_query_timeInt -gt $prefered_query_time ] ; then
                fnColorEcho "Your long_query_time may be too high, I typically set this under $prefered_query_time sec." red
	else
		fnColorEcho "Your long_query_time seems to be fine" green
	fi 

}

check_binary_log () {

## -- Binary Log -- ##

	fnColorEcho "BINARY UPDATE LOG" boldblue

	mysql_variable \'log_bin\' log_bin
	mysql_variable \'max_binlog_size\' max_binlog_size
	mysql_variable \'expire_logs_days\' expire_logs_days
	mysql_variable \'sync_binlog\' sync_binlog
	#  mysql_variable \'max_binlog_cache_size\' max_binlog_cache_size

	if [ "$log_bin" = 'ON' ] ; then
		fnColorEcho "The binary update log is enabled"
		if [ -z "$max_binlog_size" ] ; then
			fnColorEcho "The max_binlog_size is not set. The binary log will rotate when it reaches 1GB." red
		fi
		if [ "$expire_logs_days" -eq 0 ] ; then
			fnColorEcho "The expire_logs_days is not set." boldred
			fnColorEchoInline "The mysqld will retain the entire binary log until " red
			fnColorEcho "RESET MASTER or PURGE MASTER LOGS commands are run manually" red
			fnColorEcho "Setting expire_logs_days will allow you to remove old binary logs automatically"  yellow
			fnColorEcho "See http://dev.mysql.com/doc/refman/$major_version/en/purge-master-logs.html" yellow
		fi
		if [ "$sync_binlog" = 0 ] ; then
			fnColorEcho "Binlog sync is not enabled, you could loose binlog records during a server crash" red
		fi
	else
		fnColorEchoInline "The binary update log is "
		fnColorEchoInline "NOT " boldred
		fnColorEcho "enabled."
		fnColorEcho "You will not be able to do point in time recovery" red
		fnColorEcho "See http://dev.mysql.com/doc/refman/$major_version/en/point-in-time-recovery.html" yellow
	fi
}

check_used_connections () {

## -- Used Connections -- ##

	mysql_variable \'max_connections\' max_connections
	mysql_status \'Max_used_connections\' max_used_connections
	mysql_status \'Threads_connected\' threads_connected

	connections_ratio=$(($max_used_connections*100/$max_connections))

	fnColorEcho "MAX CONNECTIONS" boldblue
	fnColorEcho "Current max_connections = $max_connections"
	fnColorEcho "Current threads_connected = $threads_connected"
	fnColorEcho "Historic max_used_connections = $max_used_connections"
	fnColorEchoInline "The number of used connections is "
	if [ $connections_ratio -ge 85 ] ; then
		txt_color=red
		error=1
	elif [ $connections_ratio -le 10 ] ; then
		txt_color=red
		error=2
	else
		txt_color=green
		error=0
	fi
	# fnColorEchoInline "$max_used_connections " $txt_color
	# fnColorEchoInline "which is "
	fnColorEchoInline "$connections_ratio% " $txt_color
	fnColorEcho "of the configured maximum."

	if [ $error -eq 1 ] ; then
		fnColorEcho "You should raise max_connections" $txt_color
	elif [ $error -eq 2 ] ; then
		fnColorEcho "You are using less than 10% of your configured max_connections." $txt_color
		fnColorEcho "Lowering max_connections could help to avoid an over-allocation of memory" $txt_color
		fnColorEcho "See \"MEMORY USAGE\" section to make sure you are not over-allocating" $txt_color
	else 
		fnColorEcho "Your max_connections variable seems to be fine." $txt_color
	fi
	unset txt_color
}

check_threads() {

## -- Worker Threads -- ##

	fnColorEcho "WORKER THREADS" boldblue

	mysql_status \'Threads_created\' threads_created1
	sleep 1
	mysql_status \'Threads_created\' threads_created2

	mysql_status \'Threads_cached\' threads_cached
	mysql_status \'Uptime\' uptime
	mysql_variable \'thread_cache_size\' thread_cache_size

	historic_threads_per_sec=$(($threads_created1/$uptime))
	current_threads_per_sec=$(($threads_created2-$threads_created1))

	fnColorEcho "Current thread_cache_size = $thread_cache_size"
	fnColorEcho "Current threads_cached = $threads_cached"
	fnColorEcho "Current threads_per_sec = $current_threads_per_sec"
	fnColorEcho "Historic threads_per_sec = $historic_threads_per_sec"

	if [ $historic_threads_per_sec -ge 2 ] && [ $threads_cached -le 1 ] ; then
		fnColorEcho "Threads created per/sec are overrunning threads cached" red
		fnColorEcho "You should raise thread_cache_size" red
	elif [ $current_threads_per_sec -ge 2 ] ; then
		fnColorEcho "Threads created per/sec are overrunning threads cached" red
		fnColorEcho "You should raise thread_cache_size" red
	else
		fnColorEcho "Your thread_cache_size is fine" green
	fi
}

check_key_buffer_size () {

## -- Key buffer Size -- ##

	fnColorEcho "KEY BUFFER" boldblue

	mysql_status \'Key_read_requests\' key_read_requests
	mysql_status \'Key_reads\' key_reads
	mysql_status \'Key_blocks_used\' key_blocks_used
	mysql_status \'Key_blocks_unused\' key_blocks_unused
	mysql_variable \'key_cache_block_size\' key_cache_block_size
	mysql_variable \'key_buffer_size\' key_buffer_size
        mysql_variable \'datadir\' datadir
        mysql_variable \'version_compile_machine\' mysql_version_compile_machine
	myisam_indexes=$($mysql -Bse "/*!50000 SELECT IFNULL(SUM(INDEX_LENGTH),0) from information_schema.TABLES where ENGINE='MyISAM' */")

	if [ -z $myisam_indexes ] ; then
		myisam_indexes=$(find $datadir -name '*.MYI' -exec du $duflags '{}' \; 2>&1 | awk '{ s += $1 } END { printf("%.0f\n", s )}')
	fi

        if [ $key_reads -eq 0 ] ; then
                fnColorEcho "No key reads?!" boldred
                fnColorEcho "Seriously look into using some indexes" red
                key_cache_miss_rate=0
                key_buffer_free=$(echo "$key_blocks_unused * $key_cache_block_size / $key_buffer_size * 100" | bc -l )
                key_buffer_freeRND=$(echo "scale=0; $key_buffer_free / 1" | bc -l)
        else
                key_cache_miss_rate=$(($key_read_requests/$key_reads))
                if [ ! -z $key_blocks_unused ] ; then
			key_buffer_free=$(echo "$key_blocks_unused * $key_cache_block_size / $key_buffer_size * 100" | bc -l )
                	key_buffer_freeRND=$(echo "scale=0; $key_buffer_free / 1" | bc -l)
                else
                        key_buffer_free='Unknown'
                        key_buffer_freeRND=75
                fi
        fi

	human_readable $myisam_indexes myisam_indexesHR
	fnColorEcho "Current MyISAM index space = $myisam_indexesHR $unit" 

	human_readable  $key_buffer_size key_buffer_sizeHR
	fnColorEcho "Current key_buffer_size = $key_buffer_sizeHR $unit"
	fnColorEcho "Key cache miss rate is 1 : $key_cache_miss_rate"
	fnColorEcho "Key buffer free ratio = $key_buffer_freeRND %" 

	if [ "$major_version" = '5.1' ] && [ $mysql_version_num -lt 050123 ] ; then
		if [ $key_buffer_size -ge 4294967296 ] && ( echo "x86_64 ppc64 ia64 sparc64 i686" | grep -q $mysql_version_compile_machine ) ; then
			fnColorEcho "Using key_buffer_size > 4GB will cause instability in versions prior to 5.1.23 " boldred
			fnColorEcho "See Bug#5731, Bug#29419, Bug#29446" boldred
		fi
	fi
	if [ "$major_version" = '5.0' ] && [ $mysql_version_num -lt 050052 ] ; then
		if [ $key_buffer_size -ge 4294967296 ] && ( echo "x86_64 ppc64 ia64 sparc64 i686" | grep -q $mysql_version_compile_machine ) ; then
			fnColorEcho "Using key_buffer_size > 4GB will cause instability in versions prior to 5.0.52 " boldred
			fnColorEcho "See Bug#5731, Bug#29419, Bug#29446" boldred
		fi
	fi
	if [ "$major_version" = '4.1' -o "$major_version" = '4.0' ] && [ $key_buffer_size -ge 4294967296 ] && ( echo "x86_64 ppc64 ia64 sparc64 i686" | grep -q $mysql_version_compile_machine ) ; then
		fnColorEcho "Using key_buffer_size > 4GB will cause instability in versions prior to 5.0.52 " boldred
		fnColorEcho "Reduce key_buffer_size to a safe value" boldred
		fnColorEcho "See Bug#5731, Bug#29419, Bug#29446" boldred
	fi

	if [ $key_cache_miss_rate -le 100 ] && [ $key_cache_miss_rate -gt 0 ] && [ $key_buffer_freeRND -le 20 ]; then
		fnColorEcho "You could increase key_buffer_size" boldred
		fnColorEcho "It is safe to raise this up to 1/4 of total system memory;"
		fnColorEcho "assuming this is a dedicated database server."
	elif [ $key_buffer_freeRND -le 20 ] && [ $key_buffer_size -le $myisam_indexes ] ; then
		fnColorEcho "You could increase key_buffer_size" boldred
		fnColorEcho "It is safe to raise this up to 1/4 of total system memory;"
		fnColorEcho "assuming this is a dedicated database server."
	elif [ $key_cache_miss_rate -ge 10000 ] || [ $key_buffer_freeRND -le 50  ] ; then
		fnColorEcho "Your key_buffer_size seems to be too high." red 
		fnColorEcho "Perhaps you can use these resources elsewhere" red
	else
		fnColorEcho "Your key_buffer_size seems to be fine" green
	fi
}

check_query_cache () {

## -- Query Cache -- ##

	fnColorEcho "QUERY CACHE" boldblue

	mysql_variable \'version\' mysql_version
	mysql_variable \'query_cache_size\' query_cache_size
	mysql_variable \'query_cache_limit\' query_cache_limit
	mysql_variable \'query_cache_min_res_unit\' query_cache_min_res_unit
	mysql_status \'Qcache_free_memory\' qcache_free_memory
	mysql_status \'Qcache_total_blocks\' qcache_total_blocks
	mysql_status \'Qcache_free_blocks\' qcache_free_blocks
	mysql_status \'Qcache_lowmem_prunes\' qcache_lowmem_prunes

	if [ -z $query_cache_size ] ; then
		fnColorEcho "You are using MySQL $mysql_version, no query cache is supported." red
		fnColorEcho "I recommend an upgrade to MySQL 4.1 or better" red
	elif [ $query_cache_size -eq 0 ] ; then
		fnColorEcho "Query cache is supported but not enabled" red
		fnColorEcho "Perhaps you should set the query_cache_size" red
	else
		qcache_used_memory=$(($query_cache_size-$qcache_free_memory))
		qcache_mem_fill_ratio=$(echo "scale=2; $qcache_used_memory * 100 / $query_cache_size" | bc -l)
		qcache_mem_fill_ratioHR=$(echo "scale=0; $qcache_mem_fill_ratio / 1" | bc -l)

		fnColorEcho "Query cache is enabled" green
		human_readable $query_cache_size query_cache_sizeHR
		fnColorEcho "Current query_cache_size = $query_cache_sizeHR $unit"
		human_readable $qcache_used_memory qcache_used_memoryHR
		fnColorEcho "Current query_cache_used = $qcache_used_memoryHR $unit"
		human_readable $query_cache_limit query_cache_limitHR
		fnColorEcho "Current query_cache_limit = $query_cache_limitHR $unit"
		fnColorEcho "Current Query cache Memory fill ratio = $qcache_mem_fill_ratio %"
		if [ -z $query_cache_min_res_unit ] ; then
			fnColorEcho "No query_cache_min_res_unit is defined.  Using MySQL < 4.1 cache fragmentation can be inpredictable" %yellow
		else
			human_readable $query_cache_min_res_unit query_cache_min_res_unitHR 
			fnColorEcho "Current query_cache_min_res_unit = $query_cache_min_res_unitHR $unit"
		fi
		if [ $qcache_free_blocks -gt 2 ] && [ $qcache_total_blocks -gt 0 ] ; then
			qcache_percent_fragmented=$(echo "scale=2; $qcache_free_blocks * 100 / $qcache_total_blocks" | bc -l)
			qcache_percent_fragmentedHR=$(echo "scale=0; $qcache_percent_fragmented / 1" | bc -l)
			if [ $qcache_percent_fragmentedHR -gt 20 ] ; then
				fnColorEcho "Query Cache is $qcache_percent_fragmentedHR % fragmented" red
				fnColorEcho "Run \"FLUSH QUERY CACHE\" periodically to defragment the query cache memory" red 
				fnColorEcho "If you have many small queries lower 'query_cache_min_res_unit' to reduce fragmentation." red
			fi
		fi

		if [ $qcache_mem_fill_ratioHR -le 25 ] ; then
        	        fnColorEcho "Your query_cache_size seems to be too high." red
	                fnColorEcho "Perhaps you can use these resources elsewhere" red
		fi
		if [ $qcache_lowmem_prunes -ge 50 ] && [ $qcache_mem_fill_ratioHR -ge 80 ]; then
			fnColorEchoInline "However, "
			fnColorEchoInline "$qcache_lowmem_prunes " boldred
			fnColorEcho "queries have been removed from the query cache due to lack of memory"
			fnColorEcho "Perhaps you should raise query_cache_size" boldred
		fi
		fnColorEcho "MySQL won't cache query results that are larger than query_cache_limit in size" yellow
	fi

}

check_sort_operations () {

## -- Sort Operations -- ##

	fnColorEcho "SORT OPERATIONS" boldblue

	mysql_status \'Sort_merge_passes\' sort_merge_passes
	mysql_status \'Sort_scan\' sort_scan
	mysql_status \'Sort_range\' sort_range
	mysql_variable \'sort_buffer%\' sort_buffer_size 
	mysql_variable \'read_rnd_buffer_size\' read_rnd_buffer_size 

	total_sorts=$(($sort_scan+$sort_range))
	if [ -z $read_rnd_buffer_size ] ; then
		mysql_variable \'record_buffer\' read_rnd_buffer_size
	fi

	## Correct for rounding error in mysqld where 512K != 524288 ##
	sort_buffer_size=$(($sort_buffer_size+8))
	read_rnd_buffer_size=$(($read_rnd_buffer_size+8))

	human_readable $sort_buffer_size sort_buffer_sizeHR
	fnColorEcho "Current sort_buffer_size = $sort_buffer_sizeHR $unit"

	human_readable $read_rnd_buffer_size read_rnd_buffer_sizeHR
	fnColorEchoInline "Current " 
	if [ "$major_version" = '3.23' ] ; then
		fnColorEchoInline "record_rnd_buffer "
	else
		fnColorEchoInline "read_rnd_buffer_size "
	fi
	fnColorEcho "= $read_rnd_buffer_sizeHR $unit"

	if [ $total_sorts -eq 0 ] ; then 
		fnColorEcho "No sort operations have been performed"
		passes_per_sort=0
	fi
	if [ $sort_merge_passes -ne 0 ] ; then
		passes_per_sort=$(($sort_merge_passes/$total_sorts))
	else
		passes_per_sort=0
	fi

	if [ $passes_per_sort -ge 2 ] ; then
		fnColorEchoInline "On average "
		fnColorEchoInline "$passes_per_sort " boldred
		fnColorEcho "sort merge passes are made per sort operation"
		fnColorEcho "You should raise your sort_buffer_size"
		fnColorEchoInline "You should also raise your "
		if [ "$major_version" = '3.23' ] ; then 
			fnColorEcho "record_rnd_buffer_size"
		else
			fnColorEcho "read_rnd_buffer_size"
		fi
	else
		fnColorEcho "Sort buffer seems to be fine" green
	fi
}

check_join_operations () {

## -- Joins -- ##

	fnColorEcho "JOINS" boldblue

	mysql_status \'Select_full_join\' select_full_join
	mysql_status \'Select_range_check\' select_range_check
	mysql_variable \'join_buffer%\' join_buffer_size
	
	## Some 4K is dropped from join_buffer_size adding it back to make sane ##
	## handling of human-readable conversion ## 

	join_buffer_size=$(($join_buffer_size+4096))

	human_readable $join_buffer_size join_buffer_sizeHR 2

	fnColorEcho "Current join_buffer_size = $join_buffer_sizeHR $unit"
	fnColorEcho "You have had $select_full_join queries where a join could not use an index properly"

	if [ $select_range_check -eq 0 ] && [ $select_full_join -eq 0 ] ; then
		fnColorEcho "Your joins seem to be using indexes properly" green
	fi
	if [ $select_full_join -gt 0 ] ; then
		print_error='true'
		raise_buffer='true'
	fi
	if [ $select_range_check -gt 0 ] ; then
		fnColorEcho "You have had $select_range_check joins without keys that check for key usage after each row" red
		print_error='true'
		raise_buffer='true'
	fi

	## For Debuging ##
	# print_error='true'
	if [ $join_buffer_size -ge 4194304 ] ; then
		fnColorEcho "join_buffer_size >= 4 M" boldred
		fnColorEcho "This is not advised" boldred
		raise_buffer=
	fi

	if [ $print_error ] ; then 
		if [ "$major_version" = '3.23' ] || [ "$major_version" = '4.0' ] ; then
			fnColorEcho "You should enable \"log-long-format\" "
		elif [ "$mysql_version_num" -gt 040100 ]; then
			fnColorEcho "You should enable \"log-queries-not-using-indexes\""
		fi
		fnColorEcho "Then look for non indexed joins in the slow query log."
		if [ $raise_buffer ] ; then
		fnColorEcho "If you are unable to optimize your queries you may want to increase your"
		fnColorEcho "join_buffer_size to accommodate larger joins in one pass."
		printf "\n"
		fnColorEcho "Note! This script will still suggest raising the join_buffer_size when" boldred
		fnColorEcho "ANY joins not using indexes are found." boldred
		fi
	fi

	# XXX Add better tests for join_buffer_size pending mysql bug #15088  XXX #
}

check_tmp_tables () {

## -- Temp Tables -- ##

	fnColorEcho "TEMP TABLES" boldblue

	mysql_status \'Created_tmp_tables\' created_tmp_tables 
	mysql_status \'Created_tmp_disk_tables\' created_tmp_disk_tables
	mysql_variable \'tmp_table_size\' tmp_table_size
	mysql_variable \'max_heap_table_size\' max_heap_table_size


	if [ $created_tmp_tables -eq 0 ] ; then
		tmp_disk_tables=0
	else
		tmp_disk_tables=$((created_tmp_disk_tables*100/(created_tmp_tables+created_tmp_disk_tables)))
	fi
	human_readable $max_heap_table_size max_heap_table_sizeHR
	fnColorEcho "Current max_heap_table_size = $max_heap_table_sizeHR $unit"

	human_readable $tmp_table_size tmp_table_sizeHR 
	fnColorEcho "Current tmp_table_size = $tmp_table_sizeHR $unit"

	fnColorEcho "Of $created_tmp_tables temp tables, $tmp_disk_tables% were created on disk"
	if [ $tmp_table_size -gt $max_heap_table_size ] ; then
		fnColorEcho "Effective in-memory tmp_table_size is limited to max_heap_table_size." yellow
	fi
	if [ $tmp_disk_tables -ge 25 ] ; then
		fnColorEcho "Perhaps you should increase your tmp_table_size and/or max_heap_table_size" boldred
		fnColorEcho "to reduce the number of disk-based temporary tables" boldred
		fnColorEcho "Note! BLOB and TEXT columns are not allow in memory tables." yellow
		fnColorEcho "If you are using these columns raising these values might not impact your " yellow
		fnColorEcho  "ratio of on disk temp tables." yellow
	else
		fnColorEcho "Created disk tmp tables ratio seems fine" green
	fi
}

check_open_files () {

## -- Open Files Limit -- ## 
	fnColorEcho "OPEN FILES LIMIT" boldblue

	mysql_variable \'open_files_limit\' open_files_limit
	mysql_status   \'Open_files\' open_files
	
	if [ -z $open_files_limit ] || [ $open_files_limit -eq 0 ] ; then
		open_files_limit=$(ulimit -n)
		cant_override=1
	else
		cant_override=0
	fi
	fnColorEcho "Current open_files_limit = $open_files_limit files"
	
	open_files_ratio=$(($open_files*100/$open_files_limit))

	fnColorEcho "The open_files_limit should typically be set to at least 2x-3x" yellow 
	fnColorEcho "that of table_cache if you have heavy MyISAM usage." yellow
	if [ $open_files_ratio -ge 75 ] ; then
		fnColorEcho "You currently have open more than 75% of your open_files_limit" boldred
		if [ $cant_override -eq 1 ] ; then
			fnColorEcho "You should set a higer value for ulimit -u in the mysql startup script then restart mysqld" boldred
			fnColorEcho "MySQL 3.23 users : This is just a guess based upon the current shell's ulimit -u value" yellow
		elif [ $cant_override -eq 0 ] ; then
			fnColorEcho "You should set a higher value for open_files_limit in my.cnf" boldred
		else
			fnColorEcho "ERROR can't determine if mysqld override of ulimit is allowed" boldred
			exit 1
		fi
	else
		fnColorEcho "Your open_files_limit value seems to be fine" green
	fi

	

}

check_table_cache () {

## -- Table Cache -- ##

	fnColorEcho "TABLE CACHE" boldblue

	mysql_variable \'datadir\' datadir
	mysql_variable \'table_cache\' table_cache

	## /* MySQL +5.1 version of table_cache */ ## 
	mysql_variable \'table_open_cache\' table_open_cache
	mysql_variable \'table_definition_cache\' table_definition_cache

	mysql_status \'Open_tables\' open_tables
	mysql_status \'Opened_tables\' opened_tables
	mysql_status \'Open_table_definitions\' open_table_definitions
 
	table_count=$($mysql -Bse "/*!50000 SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' */")

	if [ -z "$table_count" ] ; then
		if [ "$UID" != "$socket_owner" ] && [ "$UID" != "0" ] ; then
			fnColorEcho "You are not '$socket_owner' or 'root'" red
			fnColorEcho "I am unable to determine the table_count!" red
		else
			table_count=$(find $datadir 2>&1 | grep -c .frm$)
		fi
	fi
	if [ $table_open_cache ] ; then
		table_cache=$table_open_cache
	fi

	if [ $opened_tables -ne 0 ] && [ $table_cache -ne 0 ] ; then 
		table_cache_hit_rate=$(($open_tables*100/$opened_tables))
		table_cache_fill=$(($open_tables*100/$table_cache))
	elif [ $opened_tables -eq 0 ] && [ $table_cache -ne 0 ] ; then
		table_cache_hit_rate=100
		table_cache_fill=$(($open_tables*100/$table_cache))
	else
		fnColorEcho "ERROR no table_cache ?!" boldred
		exit 1
	fi
	if [ $table_cache ] && [ ! $table_open_cache ] ; then
		fnColorEcho "Current table_cache value = $table_cache tables"
	fi
	if [ $table_open_cache ] ; then
		fnColorEcho "Current table_open_cache = $table_open_cache tables"
		fnColorEcho "Current table_definition_cache = $table_definition_cache tables"
	fi
	if [ $table_count ] ; then
	fnColorEcho "You have a total of $table_count tables"
	fi

	if  [ $table_cache_fill -lt 95 ] ; then
		fnColorEchoInline "You have "
		fnColorEchoInline "$open_tables " green
		fnColorEcho "open tables." 
		fnColorEcho "The table_cache value seems to be fine" green
	elif [ $table_cache_hit_rate -le 85 -o  $table_cache_fill -ge 95 ]; then
		fnColorEchoInline "You have "
		fnColorEchoInline "$open_tables " boldred
		fnColorEcho "open tables."
		fnColorEchoInline "Current table_cache hit rate is " 
		fnColorEcho "$table_cache_hit_rate%" boldred
		fnColorEchoInline ", while "
		fnColorEchoInline "$table_cache_fill% " boldred
		fnColorEcho "of your table cache is in use"
		fnColorEcho "You should probably increase your table_cache" red
	else
		fnColorEchoInline "Current table_cache hit rate is "
		fnColorEchoInline "$table_cache_hit_rate%" green
		fnColorEchoInline ", while "
		fnColorEchoInline "$table_cache_fill% " green
		fnColorEcho "of your table cache is in use"
		fnColorEcho "The table cache value seems to be fine" green
	fi
	if [ $table_definition_cache ] && [ $table_definition_cache -le $table_count ] && [ $table_count -ge 100 ] ; then
		fnColorEcho "You should probably increase your table_definition_cache value." red
	fi
}

check_table_locking () {

## -- Table Locking -- ##

	fnColorEcho "TABLE LOCKING" boldblue

	mysql_status \'Table_locks_waited\' table_locks_waited
	mysql_status \'Table_locks_immediate\' table_locks_immediate
	mysql_variable \'concurrent_insert\' concurrent_insert
	mysql_variable \'low_priority_updates\' low_priority_updates
        if [ "$concurrent_insert" = 'ON' ]; then
                concurrent_insert=1
        elif [ "$concurrent_insert" = 'OFF' ]; then
                concurrent_insert=0
        fi

	fnColorEchoInline "Current Lock Wait ratio = "
	if [ $table_locks_waited -gt 0 ]; then
		immediate_locks_miss_rate=$(($table_locks_immediate/$table_locks_waited))
		fnColorEcho "1 : $immediate_locks_miss_rate" red 
	else
		immediate_locks_miss_rate=99999 # perfect
		fnColorEcho "0 : $questions"
	fi
	if [ $immediate_locks_miss_rate -lt 5000 ] ; then
		fnColorEcho "You may benefit from selective use of InnoDB."
		if [ "$low_priority_updates" = 'OFF' ] ; then
		fnColorEcho "If you have long running SELECT's against MyISAM tables and perform"
		fnColorEcho "frequent updates consider setting 'low_priority_updates=1'"
		fi
		if [ "$mysql_version_num" -gt 050000 ] && [ "$mysql_version_num" -lt 050500 ]; then
			if [ $concurrent_insert -le 1 ] ; then
			fnColorEcho "If you have a high concurrency of inserts on Dynamic row-length tables"
			fnColorEcho "consider setting 'concurrent_insert=2'."
			fi
		elif [ "$mysql_version_num" -gt 050500 ] ; then
			if [ "$concurrent_insert" = 'AUTO' ] || [ "$concurrent_insert" = 'NEVER' ] ; then
			fnColorEcho "If you have a high concurrency of inserts on Dynamic row-length tables"
			fnColorEcho "consider setting 'concurrent_insert=ALWAYS'."
			fi
		fi
	else
		fnColorEcho "Your table locking seems to be fine" green
	fi
}

check_table_scans () {

## -- Table Scans -- ##

	fnColorEcho "TABLE SCANS" boldblue

	mysql_status \'Com_select\' com_select
	mysql_status \'Handler_read_rnd_next\' read_rnd_next
	mysql_variable \'read_buffer_size\' read_buffer_size

	if [ -z $read_buffer_size ] ; then
		mysql_variable \'record_buffer\' read_buffer_size
	fi

 	human_readable $read_buffer_size read_buffer_sizeHR
	fnColorEcho "Current read_buffer_size = $read_buffer_sizeHR $unit"
	
	if [ $com_select -gt 0 ] ; then
		full_table_scans=$(($read_rnd_next/$com_select))
		fnColorEcho "Current table scan ratio = $full_table_scans : 1"
		if [ $full_table_scans -ge 4000 ] && [ $read_buffer_size -le 2097152 ] ; then
			fnColorEcho "You have a high ratio of sequential access requests to SELECTs" red
			fnColorEchoInline "You may benefit from raising " red
			if [ "$major_version" = '3.23' ] ; then 
				fnColorEchoInline "record_buffer " red
			else
				fnColorEchoInline "read_buffer_size " red
			fi
			fnColorEcho "and/or improving your use of indexes." red
		elif [ $read_buffer_size -gt 8388608 ] ; then 
			fnColorEchoInline "read_buffer_size is over 8 MB " red 
			fnColorEcho "there is probably no need for such a large read_buffer" red
		
		else
			fnColorEcho "read_buffer_size seems to be fine" green
		fi
	else
		fnColorEcho "read_buffer_size seems to be fine" green
	fi
}


check_innodb_status () {

## -- InnoDB -- ##

	## See http://bugs.mysql.com/59393

	if [ "$mysql_version_num" -lt 050603 ] ; then
	mysql_variable \'have_innodb\' have_innodb
	fi
	if [ "$mysql_version_num" -lt 050500 ] && [ "$have_innodb" = "YES" ] ; then
	innodb_enabled=1
	fi
	if [ "$mysql_version_num" -ge 050500 ] && [ "$mysql_version_num" -lt 050512 ] ; then 
	mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
		if [ "$ignore_builtin_innodb" = "ON" ] || [ $have_innodb = "NO" ] ; then
		innodb_enabled=0
		else
		innodb_enabled=1
		fi
	elif [ "$major_version"  = '5.5' ] && [ "$mysql_version_num" -ge 050512 ] ; then
	mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
		if [ "$ignore_builtin_innodb" = "ON" ] ; then
		innodb_enabled=0
		else
		innodb_enabled=1
		fi
	elif [ "$mysql_version_num" -ge 050600 ] && [ "$mysql_version_num" -lt 050603 ] ; then
	mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
		if [ "$ignore_builtin_innodb" = "ON" ] || [ $have_innodb = "NO" ] ; then
		innodb_enabled=0
		else
		innodb_enabled=1
		fi
	elif [ "$major_version" = '5.6' ] && [ "$mysql_version_num" -ge 050603 ] ; then
	mysql_variable \'ignore_builtin_innodb\' ignore_builtin_innodb
                if [ "$ignore_builtin_innodb" = "ON" ] ; then
                innodb_enabled=0
                else
                innodb_enabled=1
                fi
	fi
	if [ "$innodb_enabled" = 1 ] ; then
		mysql_variable \'innodb_buffer_pool_size\' innodb_buffer_pool_size
		mysql_variable \'innodb_additional_mem_pool_size\' innodb_additional_mem_pool_size
		mysql_variable \'innodb_fast_shutdown\' innodb_fast_shutdown
		mysql_variable \'innodb_flush_log_at_trx_commit\' innodb_flush_log_at_trx_commit
		mysql_variable \'innodb_locks_unsafe_for_binlog\' innodb_locks_unsafe_for_binlog
		mysql_variable \'innodb_log_buffer_size\' innodb_log_buffer_size
		mysql_variable \'innodb_log_file_size\' innodb_log_file_size
		mysql_variable \'innodb_log_files_in_group\' innodb_log_files_in_group
		mysql_variable \'innodb_safe_binlog\' innodb_safe_binlog
		mysql_variable \'innodb_thread_concurrency\' innodb_thread_concurrency

		fnColorEcho "INNODB STATUS" boldblue
		innodb_indexes=$($mysql -Bse "/*!50000 SELECT IFNULL(SUM(INDEX_LENGTH),0) from information_schema.TABLES where ENGINE='InnoDB' */")
		innodb_data=$($mysql -Bse "/*!50000 SELECT IFNULL(SUM(DATA_LENGTH),0) from information_schema.TABLES where ENGINE='InnoDB' */")
		
		if [ ! -z "$innodb_indexes" ] ; then

		mysql_status \'Innodb_buffer_pool_pages_data\' innodb_buffer_pool_pages_data
		mysql_status \'Innodb_buffer_pool_pages_misc\' innodb_buffer_pool_pages_misc
		mysql_status \'Innodb_buffer_pool_pages_free\' innodb_buffer_pool_pages_free
		mysql_status \'Innodb_buffer_pool_pages_total\' innodb_buffer_pool_pages_total

		mysql_status \'Innodb_buffer_pool_read_ahead_seq\' innodb_buffer_pool_read_ahead_seq
		mysql_status \'Innodb_buffer_pool_read_requests\' innodb_buffer_pool_read_requests

		mysql_status \'Innodb_os_log_pending_fsyncs\' innodb_os_log_pending_fsyncs
		mysql_status \'Innodb_os_log_pending_writes\'	innodb_os_log_pending_writes
		mysql_status \'Innodb_log_waits\' innodb_log_waits

		mysql_status \'Innodb_row_lock_time\' innodb_row_lock_time
		mysql_status \'Innodb_row_lock_waits\' innodb_row_lock_waits

		human_readable $innodb_indexes innodb_indexesHR
		fnColorEcho "Current InnoDB index space = $innodb_indexesHR $unit"
		human_readable $innodb_data innodb_dataHR
		fnColorEcho "Current InnoDB data space = $innodb_dataHR $unit"
		percent_innodb_buffer_pool_free=$(($innodb_buffer_pool_pages_free*100/$innodb_buffer_pool_pages_total))
		fnColorEcho "Current InnoDB buffer pool free = "$percent_innodb_buffer_pool_free" %"

		else
		fnColorEcho "Cannot parse InnoDB stats prior to 5.0.x" red
		$mysql -s -e "SHOW /*!50000 ENGINE */ INNODB STATUS\G"
		fi

		human_readable $innodb_buffer_pool_size innodb_buffer_pool_sizeHR
		fnColorEcho "Current innodb_buffer_pool_size = $innodb_buffer_pool_sizeHR $unit"
		fnColorEcho "Depending on how much space your innodb indexes take up it may be safe"  
		fnColorEcho "to increase this value to up to 2 / 3 of total system memory"
	else
		fnColorEcho "No InnoDB Support Enabled!" boldred
	fi
}

total_memory_used () {

## -- Total Memory Usage -- ##
	fnColorEcho "MEMORY USAGE" boldblue

	mysql_variable \'read_buffer_size\' read_buffer_size
	mysql_variable \'read_rnd_buffer_size\' read_rnd_buffer_size
	mysql_variable \'sort_buffer_size\' sort_buffer_size
	mysql_variable \'thread_stack\' thread_stack
	mysql_variable \'max_connections\' max_connections
	mysql_variable \'join_buffer_size\' join_buffer_size
	mysql_variable \'tmp_table_size\' tmp_table_size
	mysql_variable \'max_heap_table_size\' max_heap_table_size
	mysql_variable \'log_bin\' log_bin
	mysql_status \'Max_used_connections\' max_used_connections

	if [ "$major_version" = "3.23" ] ; then
		mysql_variable \'record_buffer\' read_buffer_size
		mysql_variable \'record_rnd_buffer\' read_rnd_buffer_size
		mysql_variable \'sort_buffer\' sort_buffer_size
	fi

	if [ "$log_bin" = "ON" ] ; then
		mysql_variable \'binlog_cache_size\' binlog_cache_size
	else
		binlog_cache_size=0
	fi

	if [ $max_heap_table_size -le $tmp_table_size ] ; then
		effective_tmp_table_size=$max_heap_table_size
	else
		effective_tmp_table_size=$tmp_table_size
	fi


	per_thread_buffers=$(echo "($read_buffer_size+$read_rnd_buffer_size+$sort_buffer_size+$thread_stack+$join_buffer_size+$binlog_cache_size)*$max_connections" | bc -l)
	per_thread_max_buffers=$(echo "($read_buffer_size+$read_rnd_buffer_size+$sort_buffer_size+$thread_stack+$join_buffer_size+$binlog_cache_size)*$max_used_connections" | bc -l)

        mysql_variable \'innodb_buffer_pool_size\' innodb_buffer_pool_size
        if [ -z $innodb_buffer_pool_size ] ; then
        innodb_buffer_pool_size=0
        fi

        mysql_variable \'innodb_additional_mem_pool_size\' innodb_additional_mem_pool_size
        if [ -z $innodb_additional_mem_pool_size ] ; then
        innodb_additional_mem_pool_size=0
        fi

        mysql_variable \'innodb_log_buffer_size\' innodb_log_buffer_size
        if [ -z $innodb_log_buffer_size ] ; then
        innodb_log_buffer_size=0
        fi

        mysql_variable \'key_buffer_size\' key_buffer_size

        mysql_variable \'query_cache_size\' query_cache_size
        if [ -z $query_cache_size ] ; then
        query_cache_size=0
        fi

	global_buffers=$(echo "$innodb_buffer_pool_size+$innodb_additional_mem_pool_size+$innodb_log_buffer_size+$key_buffer_size+$query_cache_size" | bc -l)


	max_memory=$(echo "$global_buffers+$per_thread_max_buffers" | bc -l)
	total_memory=$(echo "$global_buffers+$per_thread_buffers" | bc -l)

	pct_of_sys_mem=$(echo "scale=0; $total_memory*100/$physical_memory" | bc -l)

	if [ $pct_of_sys_mem -gt 90 ] ; then
		txt_color=boldred
		error=1
	else
		txt_color=
		error=0
	fi	

	human_readable $max_memory max_memoryHR
	fnColorEcho "Max Memory Ever Allocated : $max_memoryHR $unit" $txt_color
	human_readable $per_thread_buffers per_thread_buffersHR
	fnColorEcho "Configured Max Per-thread Buffers : $per_thread_buffersHR $unit" $txt_color
	human_readable $global_buffers global_buffersHR
	fnColorEcho "Configured Max Global Buffers : $global_buffersHR $unit" $txt_color
	human_readable $total_memory total_memoryHR
	fnColorEcho "Configured Max Memory Limit : $total_memoryHR $unit" $txt_color
#	human_readable $effective_tmp_table_size effective_tmp_table_sizeHR 
#	fnColorEcho "Plus $effective_tmp_table_sizeHR $unit per temporary table created"
	human_readable $physical_memory physical_memoryHR
	fnColorEcho "Physical Memory : $physical_memoryHR $unit" $txt_color
	if [ $error -eq 1 ] ; then
		printf "\n"
		fnColorEcho "Max memory limit exceeds 90% of physical memory" $txt_color
	else
		fnColorEcho "Max memory limit seem to be within acceptable norms" green
	fi
	unset txt_color
}

## Required Functions  ## 

login_validation () {
	check_for_socket 		# determine the socket location -- 1st login
	check_for_plesk_passwords	# determine the login method -- 2nd login
	check_mysql_login		# determine if mysql is accepting login -- 3rd login
	export major_version=$($mysql -Bse "SELECT SUBSTRING_INDEX(VERSION(), '.', +2)")
#	export mysql_version_num=$($mysql -Bse "SELECT LEFT(REPLACE(SUBSTRING_INDEX(VERSION(), '-', +1), '.', ''),4)" )
	export mysql_version_num=$($mysql -Bse "SELECT VERSION()" | 
		awk -F \. '{ printf "%02d", $1; printf "%02d", $2; printf "%02d", $3 }')

}

shared_info () {
	export major_version=$($mysql -Bse "SELECT SUBSTRING_INDEX(VERSION(), '.', +2)")
	# export mysql_version_num=$($mysql -Bse "SELECT LEFT(REPLACE(SUBSTRING_INDEX(VERSION(), '-', +1), '.', ''),4)" )
	export mysql_version_num=$($mysql -Bse "SELECT VERSION()" | 
		awk -F \. '{ printf "%02d", $1; printf "%02d", $2; printf "%02d", $3 }')
	mysql_status \'Questions\' questions
#	socket_owner=$(find -L $socket -printf '%u\n')
	socket_owner=$(ls -nH $socket | awk '{ print $3 }')
}
	

get_system_info () {

    export OS=$(uname)
    
    # Get information for various UNIXes
    if [ "$OS" = 'Darwin' ]; then
	ps_socket=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }' | head -1)
	found_socks=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }')
        export physical_memory=$(sysctl -n hw.memsize)
	export duflags=''
    elif [ "$OS" = 'FreeBSD' ] || [ "$OS" = 'OpenBSD' ]; then
	## On FreeBSD must be root to locate sockets.
	ps_socket=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }' | head -1)
	found_socks=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }')
        export physical_memory=$(sysctl -n hw.realmem)
	export duflags=''
    elif [ "$OS" = 'Linux' ] ; then
	## Includes SWAP
        ## export physical_memory=$(free -b | grep -v buffers |  awk '{ s += $2 } END { printf("%.0f\n", s ) }')
	ps_socket=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }' | head -1)
	found_socks=$(netstat -ln | awk '/mysql(.*)?\.sock/ { print $9 }')
	export physical_memory=$(awk '/^MemTotal/ { printf("%.0f", $2*1024 ) }' < /proc/meminfo)
	export duflags='-b'
    elif [ "$OS" = 'SunOS' ] ; then
	ps_socket=$(netstat -an | awk '/mysql(.*)?.sock/ { print $5 }' | head -1)
	found_socks=$(netstat -an | awk '/mysql(.*)?.sock/ { print $5 }') 
	export physical_memory=$(prtconf | awk '/^Memory\ size:/ { print $3*1048576 }')
    fi
    if [ -z $(which bc) ] ; then
	echo "Error: Command line calculator 'bc' not found!"
	exit
    fi
}


## Optional Components Groups ##

banner_info () {
	shared_info
	fnPrintBanner		; echo
	check_mysql_version	; echo
	post_uptime_warning	; echo
}

misc () {
	shared_info
	check_slow_queries	; echo
	check_binary_log	; echo
	check_threads		; echo
	check_used_connections	; echo
	check_innodb_status	; echo
}

memory () {
	shared_info
	total_memory_used	; echo
	check_key_buffer_size	; echo
	check_query_cache	; echo
	check_sort_operations	; echo
	check_join_operations	; echo
}

file () {
	shared_info
	check_open_files	; echo
	check_table_cache	; echo
	check_tmp_tables	; echo
	check_table_scans	; echo
	check_table_locking	; echo
}

all () {
	banner_info
	misc
	memory
	file
}

prompt () {
	prompted='true'
	read -p "Username [anonymous] : " user
	read -rp "Password [<none>] : " pass
	fnColorEcho " "
	read -p "Socket [ /var/lib/mysql/mysql.sock ] : " socket
	if [ -z $socket ] ; then
		export socket='/var/lib/mysql/mysql.sock'
	fi

	if [ -z $pass ] ; then
	export mysql="mysql -S $socket -u$user"
	export mysqladmin="mysqladmin -S $socket -u$user"
	else
        export mysql="mysql -S $socket -u$user -p$pass"
        export mysqladmin="mysqladmin -S $socket -u$user -p$pass"
	fi

	check_for_socket
	check_mysql_login

	if [ $? = 1 ] ; then
		exit 1
	fi
	read -p "Mode to test - banner, file, misc, mem, innodb, [all] : " REPLY
	if [ -z $REPLY ] ; then
		REPLY='all'
	fi
	case $REPLY in
	        banner | BANNER | header | HEADER | head | HEAD)
		banner_info 
		;;
		misc | MISC | miscelaneous )
		misc
		;;
        	mem | memory |  MEM | MEMORY )
		memory
		;; 
		file | FILE | disk | DISK )
		file
		;;
		innodb | INNODB )
		innodb
		;;
		all | ALL )
		fnColorEcho " "
		all
		;;
		* )
		fnColorEcho "Invalid Mode!  Valid options are 'banner', 'misc', 'memory', 'file', 'innodb' or 'all'" boldred
		exit 1
		;;
	esac 
}

## Address environmental differences ##
get_system_info
# echo $ps_socket

if [ -z "$1" ] ; then
	login_validation
	mode='ALL'
elif [ "$1" = "prompt" ] || [ "$1" = "PROMPT" ] ; then
	mode=$1
elif [ "$1" != "prompt" ] || [ "$1" != "PROMPT" ] ; then
	login_validation
	mode=$1
fi

case $mode in 
	all | ALL )
	fnColorEcho " "
	all
	;;
	mem | memory |  MEM | MEMORY )
	fnColorEcho " "
	memory
	;;
	file | FILE | disk | DISK )
	fnColorEcho " "
	file
	;;
	banner | BANNER | header | HEADER | head | HEAD )
	banner_info
	;;
	misc | MISC | miscelaneous )
	fnColorEcho " "
	misc
	;;
	innodb | INNODB )
	banner_info
	check_innodb_status ; echo
	;;
	prompt | PROMPT )
	prompt
	;;
	*)
	fnColorEcho "usage: $0 [ all | banner | file | innodb | memory | misc | prompt ]" boldred
	exit 1  
	;;
esac
