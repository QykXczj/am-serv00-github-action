#!/bin/bash

# 定义颜色代码
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
purple() { echo -e "\033[35m$1\033[0m"; }
re="\033[0m"

# 打印欢迎信息
echo ""
purple "=== serv00 | AM科技 一键保活脚本 ===\n"
echo -e "${green}脚本地址：${re}${yellow}https://github.com/amclubs/am-serv00-github-action${re}\n"
echo -e "${green}YouTube频道：${re}${yellow}https://youtube.com/@AM_CLUBS${re}\n"
echo -e "${green}个人博客：${re}${yellow}https://am.809098.xyz${re}\n"
echo -e "${green}TG反馈群组：${re}${yellow}https://t.me/AM_CLUBS${re}\n"
purple "=== 转载请著名出处 AM科技，请勿滥用 ===\n"

# 发送 Telegram 消息的函数
send_telegram_message() {
# 如果传入了 TG_TOKEN 和 CHAT_ID，发送 Telegram 通知
if [ -n "$TG_TOKEN" ] && [ -n "$CHAT_ID" ]; then
local message="$1"
# 替换空格为URL编码
local encoded_message=$(echo "$message" | sed 's/ /%20/g' | sed 's/+/%2B/g')
response=$(curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$encoded_message")

# 检查响应
if [[ $(echo "$response" | jq -r '.ok') == "true" ]]; then
echo "::info::Telegram消息发送成功: $message"
else
echo "::error::Telegram消息发送失败: $response"
fi
fi
}

# 检查是否传入了参数
if [ "$#" -lt 1 ]; then
echo "用法: $0 <accounts.json> [<TG_TOKEN> <CHAT_ID>]"
echo "请确保将账户信息以 JSON 格式保存在指定的文件中。"
exit 1
fi

accounts_file="$1"
TG_TOKEN="$2"
CHAT_ID="$3"

echo "Loading accounts from $accounts_file..."
accounts_count=$(jq '. | length' "$accounts_file")
echo "::info::总共有 $accounts_count 个用户"
echo "----------------------------"

if [ "$accounts_count" -eq 0 ]; then
echo "::error::没有找到用户账户，请检查 SSH_ACCOUNTS 变量的格式"
send_telegram_message "🔴serv00激活失败: 没有找到用户账户，请检查账户文件"
exit 1
fi

# 初始化计数器
batch_success=0
batch_fail=0
current_count=0

jq -c '.[]' "$accounts_file" | while read -r account; do
    ip=$(echo "$account" | jq -r '.ip')
    username=$(echo "$account" | jq -r '.username')
    password=$(echo "$account" | jq -r '.password')

    echo "正在连接 $username@$ip ..."
    if sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 -o ServerAliveInterval=30 -o ServerAliveCountMax=2 -tt "$username@$ip" "sleep 3; exit"; then
        echo "成功激活 $username@$ip"
        ((batch_success++))
    else
        echo "连接激活 $username@$ip 失败"
        ((batch_fail++))
    fi
    ((current_count++))

    # 每处理10个账户发送一次汇总
    if (( current_count % 10 == 0 )); then
        message="🟢激活批次汇总（${current_count}次）\n成功：${batch_success}次\n失败：${batch_fail}次"
        send_telegram_message "$message"
        # 重置计数器
        batch_success=0
        batch_fail=0
    fi
done

# 发送最后未满10次的汇总
if (( current_count % 10 != 0 )); then
    message="🟢最后批次汇总（${current_count}次）\n成功：${batch_success}次\n失败：${batch_fail}次"
    send_telegram_message "$message"
fi

echo "所有账户处理完成，最终汇总已发送"
