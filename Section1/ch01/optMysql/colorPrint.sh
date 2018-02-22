#!/bin/sh

######
#	 颜色打印 
######
#颜色常量
export black='\033[0m'
export boldblack='\033[1;0m'
export red='\033[31m'
export boldred='\033[1;31m'
export green='\033[32m'
export boldgreen='\033[1;32m'
export yellow='\033[33m'
export boldyellow='\033[1;33m'
export blue='\033[34m'
export boldblue='\033[1;34m'
export magenta='\033[35m'
export boldmagenta='\033[1;35m'
export cyan='\033[36m'
export boldcyan='\033[1;36m'
export white='\033[37m'
export boldwhite='\033[1;37m'

## -- 色彩化打印函数 -- ##
	# Color-echo.
	# Argument $1 = message 第一个参数是要打印的信息
	# Argument $2 = color	第二个参数是要显示的颜色
fnColorEcho ()
{
	#如果未传入要打印的信息，指定默认信息
	local default_msg="No message passed."
	message=${1:-$default_msg}	# Defaults to default message.
	#如果未传入颜色，指定默认色
	color=${2:-black}

	#打印颜色块
	fnPrintColor $color
	#打印消息,且换行
  	printf "%s\n"  "$message"

	tput sgr0			# Reset to normal.
	printf "$black"

	return
}


######
#	 色彩打印函数，不换行 
#       $1 = message    要打印的消息
#       $2 = color      要显示的颜色
######
fnColorEchoInline ()		
{
	#指定默认消息
	local default_msg="No message passed."
	message=${1:-$default_msg}
	#指定默认颜色为黑色
	color=${2:-black}

	#打印颜色块
	fnPrintColor $color
	#打印消息
	printf "%s"  "$message"

	tput sgr0			# Reset to normal.
	printf "$black"
	return
}

######
#	 打印颜色块 
######
fnPrintColor()
{
	#指定默认颜色为黑色
	color=${1:-black}

	case $color in
		black)
			printf "$black" ;;
		boldblack)
			printf "$boldblack" ;;
		red)
			printf "$red" ;;
		boldred)
			printf "$boldred" ;;
		green)
			printf "$green" ;;
		boldgreen)
			printf "$boldgreen" ;;
		yellow)
			printf "$yellow" ;;
		boldyellow)
			printf "$boldyellow" ;;
		blue)
			printf "$blue" ;;
		boldblue)
			printf "$boldblue" ;;
		magenta)
			printf "$magenta" ;;
		boldmagenta)
			printf "$boldmagenta" ;;
		cyan)
			printf "$cyan" ;;
		boldcyan)
			printf "$boldcyan" ;;
		white)
			printf "$white" ;;
		boldwhite)
			printf "$boldwhite" ;;
	esac

	return
}
