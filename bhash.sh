#! /bin/bash

function chr2bin() {
	local char_code=$(($(printf "%d" "'$1")))
	for ((i=7;i>=0;i--)); do
		printf "%d" "$(((char_code&(1<<i))!=0))"
	done
}

function str2hex() {
	local len="${#1}"
	for ((i=0;i<len;i++)); do
		printf "%02x" "'${1:$i:1}"
	done
}

function bin2hex() {
	local len="${#1}"
	for ((i=0;i<len;i+=64)); do
		local format="%016x"
		if ((i+64>=len)); then format="%0$(((len-i)/4))x"; fi
		#printf "%0$(((len-i)/4))x" "0b${1:$i:64}"
		printf "$format" "0b${1:$i:64}"
	done
	return
	for ((i=0;i<len;i+=4)); do
		printf "%01x" "0b${1:$i:4}"
	done
}

function repeat_char() {
	if (( ${#1}<$2 )); then
		repeat_char $1$1$1$1 $2
	else
		printf "${1:0:$2}"
	fi
	#for ((i=0;i<$2;i++)); do printf "$1"; done
}
function htonl() {
	printf "%d" $(( (($1&0xff)<<24)|
				 (($1&0xff00)<<8)|
				 (($1&0xff0000)>>8)|
				 ($1>>24) ))
}
function htonl64() {
	printf "%d" $(( (($1&0xff)<<56)|(($1&0xff00)<<40)|(($1&0xff0000)<<24)|(($1&0xff000000)<<8)|
		(($1&0xff00000000)>>8)|(($1&0xff0000000000)>>24)|(($1&0xff000000000000)>>40)|($1>>56) ))
}

function md5() {
	local s=( 7 12 17 22  7 12 17 22  7 12 17 22  7 12 17 22
		5  9 14 20  5  9 14 20  5  9 14 20  5  9 14 20
		4 11 16 23  4 11 16 23  4 11 16 23  4 11 16 23
		6 10 15 21  6 10 15 21  6 10 15 21  6 10 15 21)
	local k=( 0xd76aa478 0xe8c7b756 0x242070db 0xc1bdceee
		0xf57c0faf 0x4787c62a 0xa8304613 0xfd469501
		0x698098d8 0x8b44f7af 0xffff5bb1 0x895cd7be
		0x6b901122 0xfd987193 0xa679438e 0x49b40821
		0xf61e2562 0xc040b340 0x265e5a51 0xe9b6c7aa
		0xd62f105d 0x02441453 0xd8a1e681 0xe7d3fbc8
		0x21e1cde6 0xc33707d6 0xf4d50d87 0x455a14ed
		0xa9e3e905 0xfcefa3f8 0x676f02d9 0x8d2a4c8a
		0xfffa3942 0x8771f681 0x6d9d6122 0xfde5380c
		0xa4beea44 0x4bdecfa9 0xf6bb4b60 0xbebfbc70
		0x289b7ec6 0xeaa127fa 0xd4ef3085 0x04881d05
		0xd9d4d039 0xe6db99e5 0x1fa27cf8 0xc4ac5665
		0xf4292244 0x432aff97 0xab9423a7 0xfc93a039
		0x655b59c3 0x8f0ccc92 0xffeff47d 0x85845dd1
		0x6fa87e4f 0xfe2ce6e0 0xa3014314 0x4e0811a1
		0xf7537e82 0xbd3af235 0x2ad7d2bb 0xeb86d391)
	local a0=0x67452301
	local b0=0xefcdab89
	local c0=0x98badcfe
	local d0=0x10325476
	local msglen="$((${#1}>>1))"
	local nz=$((512-((msglen*8+65)%512)))
	msg="${1}8`repeat_char 0 $(((nz-3)/4))``printf '%016x' "$(htonl64 $((msglen<<3)))"`"
	for ((ichunk=0;ichunk<${#msg};ichunk+=128)); do
		local chunk=${msg:$ichunk:128}
		local M=( )
		for ((wp=0;wp<128;wp+=8)); do
			word=$(("0x"${chunk:$wp:8}))
			M+=( $(( ((word&0xff)<<24)|
				 ((word&0xff00)<<8)|
				 ((word&0xff0000)>>8)|
				 (word>>24) )) )
			#M+=( "0x"${chunk:$wp:8} )
		done
		local A=$a0
		local B=$b0
		local C=$c0
		local D=$d0
		for ((i=0;i<64;i++)); do
			local F g
			if ((i<=15)); then
				F=$(( (B&C)|((0xffffffff^B)&D) ))
				g=$i
			elif ((i<=31)); then
				F=$(( (D&B)|((0xffffffff^D)&C) ))
				g=$(((5*i +1)%16))
			elif ((i<=47)); then
				F=$((B^C^D))
				g=$(((3*i +5)%16))
			else
				F=$((C^(B|(0xffffffff^D))))
				g=$(((7*i)%16))
			fi
			F=$(((F+A+${k[$i]}+${M[$g]})&0xffffffff))
			A=$D
			D=$C
			C=$B
			B=$(( (B+ ((((1<<32)-1)&(F<<${s[$i]}))|(F>>(32-${s[$i]}))) )&0xffffffff ))
			#printf "i=%d,A=%08x,B=%08x,C=%08x,D=%08x\n" "$i" "$A" "$B" "$C" "$D"
		done
		a0=$(((a0+A)&0xffffffff))
		b0=$(((b0+B)&0xffffffff))
		c0=$(((c0+C)&0xffffffff))
		d0=$(((d0+D)&0xffffffff))
	done
	printf "%08x%08x%08x%08x" $(htonl "$a0") $(htonl "$b0") $(htonl "$c0") $(htonl "$d0")
}

function sha256() {
	local kvals
	local h0=0x6a09e667
	local h1=0xbb67ae85
	local h2=0x3c6ef372
	local h3=0xa54ff53a
	local h4=0x510e527f
	local h5=0x9b05688c
	local h6=0x1f83d9ab
	local h7=0x5be0cd19

	kvals=(
		0x428a2f98 0x71374491 0xb5c0fbcf 0xe9b5dba5 0x3956c25b 0x59f111f1 0x923f82a4 0xab1c5ed5
		0xd807aa98 0x12835b01 0x243185be 0x550c7dc3 0x72be5d74 0x80deb1fe 0x9bdc06a7 0xc19bf174
		0xe49b69c1 0xefbe4786 0x0fc19dc6 0x240ca1cc 0x2de92c6f 0x4a7484aa 0x5cb0a9dc 0x76f988da
		0x983e5152 0xa831c66d 0xb00327c8 0xbf597fc7 0xc6e00bf3 0xd5a79147 0x06ca6351 0x14292967
		0x27b70a85 0x2e1b2138 0x4d2c6dfc 0x53380d13 0x650a7354 0x766a0abb 0x81c2c92e 0x92722c85
		0xa2bfe8a1 0xa81a664b 0xc24b8b70 0xc76c51a3 0xd192e819 0xd6990624 0xf40e3585 0x106aa070
		0x19a4c116 0x1e376c08 0x2748774c 0x34b0bcb5 0x391c0cb3 0x4ed8aa4a 0x5b9cca4f 0x682e6ff3
		0x748f82ee 0x78a5636f 0x84c87814 0x8cc70208 0x90befffa 0xa4506ceb 0xbef9a3f7 0xc67178f2
	)

	local msglen=$((${#1}>>1))
	#echo ${1:((msglen-1))}
	local nz=$((512-((msglen*8+65)%512)))
	msg="${1}8`repeat_char 0 $(((nz-3)/4))``printf '%016x' "$(( (-1)&(msglen<<3)))"`"
	#msg="${1}$(bin2hex "1`repeat_char 0 $numzeroes`")`printf '%016x' "$(( ((1<<64)-1)&(msglen<<3)))"`"
	for ((ichunk=0;ichunk<${#msg};ichunk+=128)); do
		local chunk=${msg:$ichunk:128}
		local w=()
		for ((wp=0;wp<128;wp+=8)); do
			w+=( "0x"${chunk:$wp:8} )
			#echo "0x"${chunk:$wp:8} $(("0x"${chunk:$wp:8}))
		done
		for ((i=16;i!=64;i++)); do
			local i_minus_15=${w[$((i-15))]}
			local i_minus_2=${w[$((i-2))]}
			local s0=$(( 	( (i_minus_15>>7)|((i_minus_15&((1<<7)-1))<<(32-7)) ) ^
					( (i_minus_15>>18)|((i_minus_15&((1<<18)-1))<<(32-18)) )^
					(i_minus_15>>3) ))
			local s1=$(( 	( (i_minus_2>>17)|((i_minus_2&((1<<17)-1))<<(32-17)) ) ^
					( (i_minus_2>>19)|((i_minus_2&((1<<19)-1))<<(32-19)) )^
					(i_minus_2>>10) ))
			w+=( $((0xffffffff& (${w[$((i-16))]}+s0+${w[$((i-7))]}+s1))) )
		done
		local a=$h0
		local b=$h1
		local c=$h2
		local d=$h3
		local e=$h4
		local f=$h5
		local g=$h6
		local h=$h7
		for ((i=0;i<64;i++)); do
			local S1=$(( 	( (e>>6)|((e&((1<<6)-1))<<(32-6)) )^
					( (e>>11)|((e&((1<<11)-1))<<(32-11)) )^
					( (e>>25)|((e&((1<<25)-1))<<(32-25)) ) ))
			local ch=$(( (e&f)^((0xffffffff^e)&g) ))
			local temp1=$((h + S1 + ch + ${kvals[$i]} + ${w[$i]}))
			local S0=$((	( (a>>2)|((a&((1<<2)-1))<<(32-2)) )^
					( (a>>13)|((a&((1<<13)-1))<<(32-13)) )^
					( (a>>22)|((a&((1<<22)-1))<<(32-22)) ) ))
			local maj=$(((a&b) ^ (a & c) ^ (b & c)))
			local temp2=$((S0 + maj))

			h=$g
			g=$f
			f=$e
			e=$((0xffffffff&(d + temp1)))
			d=$c
			c=$b
			b=$a
			a=$((0xffffffff&(temp1 + temp2) ))
			#printf "i=%d,a=%08x,b=%08x,c=%08x,d=%08x,e=%08x,f=%08x,g=%08x,h=%08x\n" $i $a $b $c $d $e $f $g $h
		done
		h0=$((0xffffffff&(h0 + a)))
		h1=$((0xffffffff&(h1 + b)))
		h2=$((0xffffffff&(h2 + c)))
		h3=$((0xffffffff&(h3 + d)))
		h4=$((0xffffffff&(h4 + e)))
		h5=$((0xffffffff&(h5 + f)))
		h6=$((0xffffffff&(h6 + g)))
		h7=$((0xffffffff&(h7 + h)))
	done
	printf "%08x%08x%08x%08x%08x%08x%08x%08x" "$h0" "$h1" "$h2" "$h3" "$h4" "$h5" "$h6" "$h7"
}


