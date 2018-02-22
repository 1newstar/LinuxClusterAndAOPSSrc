#!/bin/sh

######
#	 banner 工具 
######
#【色彩打印】
source ./colorPrint.sh

######
#	 打印 banner 
######
fnPrintBanner () 
{
	fnColorEcho "	-- MYSQL PERFORMANCE TUNING PRIMER --" boldblue
	fnColorEcho "	     - By: Matthew Montgomery -" black
}
