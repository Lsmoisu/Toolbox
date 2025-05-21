#!/bin/bash

# 菜单函数，显示选项
show_menu() {
    echo "====================================="
    echo "      Google Cloud 管理脚本          "
    echo "====================================="
    echo "1. 添加账号"
    echo "2. 删除账号"
    echo "3. 查看所有账号"
    echo "4. 切换默认账号"
    echo "5. 添加项目"
    echo "6. 删除项目"
    echo "7. 查看所有项目"
    echo "8. 切换默认项目"
    echo "9. 查看虚拟机列表"
    echo "10. 创建虚拟机"
    echo "11. 删除虚拟机"
    echo "12. 查看该项目下 socks5 配置"
    echo "13. 配置防火墙"
    echo "14. 查看防火墙规则"
    echo "15. 删除防火墙规则"
    echo "16. 查看所有可用的结算账号"

    echo "0. 退出脚本"
    echo "====================================="
    echo "请输入选项（0-16）："
}

# 获取当前日期，格式为 YYYYMMDD
get_current_date() {
    date +%Y%m%d
}

# 生成四个随机字符
generate_random_suffix() {
    cat /dev/urandom | tr -dc 'a-z0-9' | head -c 4
}

# 获取当前项目的实例配额和已使用数量
get_instance_quota() {
    local project=$1
    local zone=$2
    local region=$(echo "$zone" | sed 's/-[a-z]$//')
    if [ -z "$region" ]; then
        echo "无法从区域 $zone 提取大区域信息。"
        return 1
    fi
    echo "正在获取区域 $region 的配额信息..."
    quota_info=$(gcloud compute regions describe "$region" --project="$project" --format="json(quotas)" 2>/dev/null)
    if [ -z "$quota_info" ]; then
        echo "无法获取配额信息，请检查 gcloud 配置、网络连接或区域是否正确。"
        return 1
    fi
    quota_limit=$(echo "$quota_info" | grep -A 2 '"metric": "CPUS"' | grep '"limit"' | awk '{print $2}' | tr -d ',' | grep -o '[0-9]*')
    quota_usage=$(echo "$quota_info" | grep -A 2 '"metric": "CPUS"' | grep '"usage"' | awk '{print $2}' | tr -d ',' | grep -o '[0-9]*')
    if [ -z "$quota_limit" ] || [ -z "$quota_usage" ]; then
        echo "无法解析配额数据，可能是输出格式问题。"
        return 1
    fi
    local available_cpus=$((quota_limit - quota_usage))
    local max_instances=$((available_cpus / 2))
    if [ "$max_instances" -lt 0 ]; then
        max_instances=0
    fi
    echo "$max_instances"
    return 0
}

# 动态获取支持 e2-micro 的区域和可用区，并分组（优化版）
get_regions_and_zones() {
    echo "正在获取支持 e2-micro 机器类型的区域和可用区..."
    
    # 硬编码的支持 e2-micro 的区域和可用区列表，加速获取
    declare -g -A region_map
    declare -g -a regions
    regions=("us-central1" "us-east1" "us-east4" "us-east5" "us-east7" "us-west1" "us-west2" "us-west3" "us-west4" "us-west8" "us-south1" "europe-central2" "europe-north1" "europe-north2" "europe-southwest1" "europe-west1" "europe-west2" "europe-west3" "europe-west4" "europe-west6" "europe-west8" "europe-west9" "europe-west10" "europe-west12" "asia-east1" "asia-east2" "asia-northeast1" "asia-northeast2" "asia-northeast3" "asia-south1" "asia-south2" "asia-southeast1" "asia-southeast2" "australia-southeast1" "australia-southeast2" "southamerica-east1" "southamerica-west1" "northamerica-northeast1" "northamerica-northeast2" "northamerica-south1" "me-central1" "me-central2" "me-west1" "africa-south1")
    
    # 初始化 region_map
    region_map["us-central1"]="us-central1-a us-central1-b us-central1-c us-central1-d us-central1-f"
    region_map["us-east1"]="us-east1-a us-east1-b us-east1-c us-east1-d"
    region_map["us-east4"]="us-east4-a us-east4-b us-east4-c"
    region_map["us-east5"]="us-east5-a us-east5-b us-east5-c"
    region_map["us-east7"]="us-east7-a us-east7-b us-east7-c"
    region_map["us-west1"]="us-west1-a us-west1-b us-west1-c"
    region_map["us-west2"]="us-west2-a us-west2-b us-west2-c"
    region_map["us-west3"]="us-west3-a us-west3-b us-west3-c"
    region_map["us-west4"]="us-west4-a us-west4-b us-west4-c"
    region_map["us-west8"]="us-west8-a us-west8-b us-west8-c"
    region_map["us-south1"]="us-south1-a us-south1-b us-south1-c"
    region_map["europe-central2"]="europe-central2-a europe-central2-b europe-central2-c"
    region_map["europe-north1"]="europe-north1-a europe-north1-b europe-north1-c"
    region_map["europe-north2"]="europe-north2-a europe-north2-b europe-north2-c"
    region_map["europe-southwest1"]="europe-southwest1-a europe-southwest1-b europe-southwest1-c"
    region_map["europe-west1"]="europe-west1-b europe-west1-c europe-west1-d"
    region_map["europe-west2"]="europe-west2-a europe-west2-b europe-west2-c"
    region_map["europe-west3"]="europe-west3-a europe-west3-b europe-west3-c"
    region_map["europe-west4"]="europe-west4-a europe-west4-b europe-west4-c"
    region_map["europe-west6"]="europe-west6-a europe-west6-b europe-west6-c"
    region_map["europe-west8"]="europe-west8-a europe-west8-b europe-west8-c"
    region_map["europe-west9"]="europe-west9-a europe-west9-b europe-west9-c"
    region_map["europe-west10"]="europe-west10-a europe-west10-b europe-west10-c"
    region_map["europe-west12"]="europe-west12-a europe-west12-b europe-west12-c"
    region_map["asia-east1"]="asia-east1-a asia-east1-b asia-east1-c"
    region_map["asia-east2"]="asia-east2-a asia-east2-b asia-east2-c"
    region_map["asia-northeast1"]="asia-northeast1-a asia-northeast1-b asia-northeast1-c"
    region_map["asia-northeast2"]="asia-northeast2-a asia-northeast2-b asia-northeast2-c"
    region_map["asia-northeast3"]="asia-northeast3-a asia-northeast3-b asia-northeast3-c"
    region_map["asia-south1"]="asia-south1-a asia-south1-b asia-south1-c"
    region_map["asia-south2"]="asia-south2-a asia-south2-b asia-south2-c"
    region_map["asia-southeast1"]="asia-southeast1-a asia-southeast1-b asia-southeast1-c"
    region_map["asia-southeast2"]="asia-southeast2-a asia-southeast2-b asia-southeast2-c"
    region_map["australia-southeast1"]="australia-southeast1-a australia-southeast1-b australia-southeast1-c"
    region_map["australia-southeast2"]="australia-southeast2-a australia-southeast2-b australia-southeast2-c"
    region_map["southamerica-east1"]="southamerica-east1-a southamerica-east1-b southamerica-east1-c"
    region_map["southamerica-west1"]="southamerica-west1-a southamerica-west1-b southamerica-west1-c"
    region_map["northamerica-northeast1"]="northamerica-northeast1-a northamerica-northeast1-b northamerica-northeast1-c"
    region_map["northamerica-northeast2"]="northamerica-northeast2-a northamerica-northeast2-b northamerica-northeast2-c"
    region_map["northamerica-south1"]="northamerica-south1-a northamerica-south1-b northamerica-south1-c"
    region_map["me-central1"]="me-central1-a me-central1-b me-central1-c"
    region_map["me-central2"]="me-central2-a me-central2-b me-central2-c"
    region_map["me-west1"]="me-west1-a me-west1-b me-west1-c"
    region_map["africa-south1"]="africa-south1-a africa-south1-b africa-south1-c"
    
    # 检查硬编码列表是否有效（例如，至少有一个区域）
    if [ ${#regions[@]} -eq 0 ]; then
        echo "硬编码区域列表为空，尝试动态获取支持 e2-micro 的区域和可用区..."
        zones=$(gcloud compute machine-types list --filter="name=e2-micro" --format="value(ZONE)" --limit=1000 2>/dev/null | sort | uniq)
        if [ -z "$zones" ]; then
            echo "无法获取可用区列表，请检查 gcloud 配置或网络连接。"
            return 1
        fi
        regions=()
        IFS=$'\n'
        for zone in $zones; do
            region=$(echo "$zone" | cut -d'-' -f1)
            if [[ ! " ${regions[@]} " =~ " ${region} " ]]; then
                regions+=("$region")
            fi
            region_map["$region"]="${region_map[$region]} $zone"
        done
        unset IFS
    fi
    
    if [ ${#regions[@]} -eq 0 ]; then
        echo "未找到支持 e2-micro 的大区域。"
        return 1
    fi
    return 0
}

# 显示大区域选择菜单
show_region_menu() {
    echo "请选择大区域："
    local i=1
    for region in "${regions[@]}"; do
        location=${region_location_map["$region"]}
        if [ -n "$location" ]; then
            echo "$i. $region（$location）"
        else
            echo "$i. $region"
        fi
        ((i++))
    done
    echo "0. 取消选择"
    echo "请输入选项（0-$((i-1))）："
}

# 显示具体可用区选择菜单
show_zone_menu() {
    local region=$1
    echo "请选择具体可用区（$region）："
    local zones_list=(${region_map["$region"]})
    if [ ${#zones_list[@]} -eq 0 ]; then
        echo "未找到 $region 区域下支持 e2-micro 的可用区。"
        echo "0. 取消选择"
        echo "请输入选项（0-0）："
        return 1
    fi
    local i=1
    location=${region_location_map["$region"]}
    for zone in "${zones_list[@]}"; do
        if [ -n "$location" ]; then
            echo "$i. $zone（$location）"
        else
            echo "$i. $zone"
        fi
        ((i++))
    done
    echo "0. 取消选择"
    echo "请输入选项（0-$((i-1))）："
    return 0
}

# 显示地区选择方式菜单
show_zone_selection_method() {
    echo "请选择地区选择方式："
    local default_zone=$(gcloud config get-value compute/zone 2>/dev/null)
    if [ -n "$default_zone" ]; then
        region=$(echo "$default_zone" | sed 's/-[a-z]$//')
        location=${region_location_map["$region"]}
        if [ -n "$location" ]; then
            echo "1. 使用默认地区：$default_zone（$location）"
        else
            echo "1. 使用默认地区：$default_zone"
        fi
    else
        echo "1. 使用默认地区（未设置，需手动指定）"
    fi
    echo "2. 自动获取并选择支持 e2-micro 的区域"
    echo "3. 修改默认地区"
    echo "0. 取消选择"
    echo "请输入选项（0-3）："
}

# 获取当前项目下的虚拟机列表
get_instance_list() {
    local project=$1
    instance_list=$(gcloud compute instances list --project="$project" --format="value(NAME,ZONE)" 2>/dev/null)
    if [ -z "$instance_list" ]; then
        echo "无法获取虚拟机列表，请检查 gcloud 配置或网络连接。"
        return 1
    fi
    echo "$instance_list"
    return 0
}

# 显示虚拟机列表并返回数组
show_instance_menu() {
    local instance_data="$1"
    declare -g -a instance_array
    instance_array=()
    echo "当前项目下的虚拟机列表："
    if [ -z "$instance_data" ]; then
        echo "没有找到虚拟机。"
        return 1
    fi
    local i=1
    IFS=$'\n'
    for line in $instance_data; do
        if [ -z "$line" ]; then
            continue
        fi
        instance_name=$(echo "$line" | awk '{print $1}')
        instance_zone=$(echo "$line" | awk '{print $2}')
        if [ -n "$instance_name" ] && [ -n "$instance_zone" ]; then
            region=$(echo "$instance_zone" | sed 's/-[a-z]$//')
            location=${region_location_map["$region"]}
             if [ -n "$location" ]; then
                echo "$i. $instance_name (区域: $instance_zone - $location)"
            else
                echo "$i. $instance_name (区域: $instance_zone)"
            fi
            instance_array+=("$instance_name|$instance_zone")
            ((i++))
        fi
    done
    unset IFS
    if [ ${#instance_array[@]} -eq 0 ]; then
        echo "没有找到虚拟机。"
        return 1
    fi
    return 0
}

# 获取所有账号列表
get_account_list() {
    account_list=$(gcloud auth list --format="value(ACCOUNT)" 2>/dev/null)
    if [ -z "$account_list" ]; then
        echo "无法获取账号列表，请检查 gcloud 配置或网络连接。"
        return 1
    fi
    echo "$account_list"
    return 0
}

# 显示账号列表并返回数组
show_account_menu() {
    local account_data="$1"
    declare -g -a account_array
    account_array=()
    echo "当前已配置的账号列表："
    if [ -z "$account_data" ]; then
        echo "没有找到已配置的账号。"
        return 1
    fi
    local i=1
    IFS=$'\n'
    for account in $account_data; do
        if [ -n "$account" ]; then
            active_mark=""
            if [[ "$account" == *"(active)"* ]]; then
                active_mark=" (当前默认)"
                account=$(echo "$account" | sed 's/ (active)//')
            fi
            echo "$i. $account$active_mark"
            account_array+=("$account")
            ((i++))
        fi
    done
    unset IFS
    if [ ${#account_array[@]} -eq 0 ]; then
        echo "没有找到已配置的账号。"
        return 1
    fi
    return 0
}

# 获取所有项目列表
get_project_list() {
    project_list=$(gcloud projects list --format="value(PROJECT_ID,NAME)" 2>/dev/null)
    if [ -z "$project_list" ]; then
        echo "无法获取项目列表，请检查 gcloud 配置或网络连接。"
        return 1
    fi
    echo "$project_list"
    return 0
}

# 显示项目列表并返回数组
show_project_menu() {
    local project_data="$1"
    declare -g -a project_array
    project_array=()
    echo "当前可用的项目列表："
    if [ -z "$project_data" ]; then
        echo "没有找到项目。"
        return 1
    fi
    local i=1
    IFS=$'\n'
    for line in $project_data; do
        if [ -z "$line" ]; then
            continue
        fi
        project_id=$(echo "$line" | awk '{print $1}')
        project_name=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ //')
        if [ -n "$project_id" ]; then
            current_mark=""
            current_project=$(gcloud config get-value project 2>/dev/null)
            if [ "$project_id" == "$current_project" ]; then
                current_mark=" (当前默认)"
            fi
            echo "$i. $project_id - $project_name$current_mark"
            project_array+=("$project_id")
            ((i++))
        fi
    done
    unset IFS
    if [ ${#project_array[@]} -eq 0 ]; then
        echo "没有找到项目。"
        return 1
    fi
    return 0
}
# 获取可用结算账号列表
get_billing_accounts() {
    echo "正在获取可用的结算账号列表..."
    # 尝试列出状态为 OPEN 且当前用户有权关联的结算账号
    billing_accounts_list=$(gcloud billing accounts list --filter='open=true' --format="value(ACCOUNT_ID, NAME)" 2>/dev/null)

    if [ -z "$billing_accounts_list" ]; then
        echo "未能获取到结算账号列表。可能是因为："
        echo "1. 当前授权账号没有查看结算账号的权限。"
        echo "2. 没有可用的（状态为 OPEN）结算账号。"
        echo "3. gcloud 配置或网络连接问题。"
        return 1 # 指示失败或未找到账户
    fi

    declare -g -a billing_account_array_ids # 仅存储账户 ID
    declare -g -a billing_account_array_display # 存储用于菜单显示的信息

    billing_account_array_ids=()
    billing_account_array_display=()

    local i=1
    IFS=$'\n'
    for line in $billing_accounts_list; do
        if [ -z "$line" ]; then
            continue
        fi
        account_id=$(echo "$line" | cut -d$'\t' -f1)
        # 获取账户 ID 之后的所有内容作为显示名称, 如果存在的话
        display_name=$(echo "$line" | cut -d$'\t' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ -n "$account_id" ]; then
            billing_account_array_ids+=("$account_id")
            # 检查显示名称是否为空，如果为空则只显示账号ID，否则显示ID和名称
            if [ -z "$display_name" ]; then
                billing_account_array_display+=("$i. $account_id")
            else
                billing_account_array_display+=("$i. $account_id - $display_name")
            fi
            ((i++))
        fi
    done
    unset IFS

    if [ ${#billing_account_array_ids[@]} -eq 0 ]; then
        echo "未找到可用的结算账号。"
        return 1 # 指示未找到账户
    fi
    return 0 # 成功
}

# 显示结算账号选择菜单
show_billing_account_menu() {
    echo "请选择要关联的结算账号："
    if [ ${#billing_account_array_display[@]} -eq 0 ]; then
        # 此情况理论上如果 get_billing_accounts 返回 0 则不会发生，但作为健壮性检查
        echo "错误：billing_account_array_display 为空，但 get_billing_accounts 返回成功。"
        echo "0. 取消并返回主菜单"
        echo "m. 手动输入结算账号 ID"
        return 1 # 表示菜单显示有问题
    fi

    for item in "${billing_account_array_display[@]}"; do
        echo "$item"
    done
    echo "-------------------------------------"
    echo "m. 手动输入结算账号 ID"
    echo "0. 取消并返回主菜单"
    echo "请输入选项 (1-${#billing_account_array_ids[@]}, m, 或 0):"
    return 0
}
# 定义区域到地理位置的映射
declare -A region_location_map
region_location_map["africa-south1"]="南非约翰内斯堡"
region_location_map["us-central1"]="美国爱荷华州"
region_location_map["us-east1"]="美国南卡罗来纳州"
region_location_map["us-east4"]="美国弗吉尼亚州北部"
region_location_map["us-east5"]="美国俄亥俄州"
region_location_map["us-east7"]="美国弗吉尼亚州"
region_location_map["us-west1"]="美国俄勒冈州"
region_location_map["us-west2"]="美国洛杉矶"
region_location_map["us-west3"]="美国盐湖城"
region_location_map["us-west4"]="美国拉斯维加斯"
region_location_map["us-west8"]="美国萨克拉门托"
region_location_map["us-south1"]="美国达拉斯"
region_location_map["europe-central2"]="波兰华沙"
region_location_map["europe-north1"]="芬兰哈米纳"
region_location_map["europe-north2"]="挪威奥斯陆"
region_location_map["europe-southwest1"]="西班牙马德里"
region_location_map["europe-west1"]="比利时圣吉斯兰"
region_location_map["europe-west2"]="英国伦敦"
region_location_map["europe-west3"]="德国法兰克福"
region_location_map["europe-west4"]="荷兰埃姆斯哈文"
region_location_map["europe-west6"]="瑞士苏黎世"
region_location_map["europe-west8"]="意大利米兰"
region_location_map["europe-west9"]="法国巴黎"
region_location_map["europe-west10"]="德国柏林"
region_location_map["europe-west12"]="意大利都灵"
region_location_map["asia-east1"]="中国台湾彰化县"
region_location_map["asia-east2"]="中国香港"
region_location_map["asia-northeast1"]="日本东京"
region_location_map["asia-northeast2"]="日本大阪"
region_location_map["asia-northeast3"]="韩国首尔"
region_location_map["asia-south1"]="印度孟买"
region_location_map["asia-south2"]="印度德里"
region_location_map["asia-southeast1"]="新加坡"
region_location_map["asia-southeast2"]="印度尼西亚雅加达"
region_location_map["australia-southeast1"]="澳大利亚悉尼"
region_location_map["australia-southeast2"]="澳大利亚墨尔本"
region_location_map["southamerica-east1"]="巴西圣保罗"
region_location_map["southamerica-west1"]="智利圣地亚哥"
region_location_map["northamerica-northeast1"]="加拿大蒙特利尔"
region_location_map["northamerica-northeast2"]="加拿大多伦多"
region_location_map["northamerica-south1"]="墨西哥城"
region_location_map["me-central1"]="卡塔尔多哈"
region_location_map["me-central2"]="沙特阿拉伯达曼"
region_location_map["me-west1"]="以色列特拉维夫"

# 主循环
while true; do
    show_menu
    read -e -r choice  # 使用 -e 参数启用 readline 支持删除键等功能

    case $choice in
        1)
            echo "正在添加账号..."
            echo "请按照提示完成账号登录流程（浏览器将打开进行身份验证）："
            gcloud auth login --no-launch-browser
            if [ $? -eq 0 ]; then
                echo "账号添加成功！"
            else
                echo "账号添加失败，请检查网络连接或权限。"
            fi
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        2)
            echo "正在删除账号..."
            account_data=$(get_account_list)
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            show_account_menu "$account_data"
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "0. 取消选择"
            echo "请输入要删除的账号编号（多个编号用空格分隔，例如 '1 2'，输入 'all' 删除全部非默认账号）："
            read -e -r input_selection
            if [ -z "$input_selection" ] || [ "$input_selection" == "0" ]; then
                echo "操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 处理用户选择
            declare -a selected_accounts
            current_account=$(gcloud auth list --format="value(ACCOUNT)" | grep "(active)" | sed 's/ (active)//')
            if [ "$input_selection" == "all" ] || [ "$input_selection" == "ALL" ]; then
                for account in "${account_array[@]}"; do
                    if [ "$account" != "$current_account" ]; then
                        selected_accounts+=("$account")
                    fi
                done
            else
                IFS=' ' read -ra selections <<< "$input_selection"
                for sel in "${selections[@]}"; do
                    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#account_array[@]}" ]; then
                        account="${account_array[$((sel-1))]}"
                        if [ "$account" != "$current_account" ]; then
                            selected_accounts+=("$account")
                        else
                            echo "无法删除当前默认账号：$account，已忽略。"
                        fi
                    else
                        echo "无效选项：$sel，已忽略。"
                    fi
                done
                unset IFS
            fi

            # 如果没有有效选择
            if [ ${#selected_accounts[@]} -eq 0 ]; then
                echo "没有有效的账号被选中，操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 确认删除
            echo "您选择了以下账号进行删除："
            for account in "${selected_accounts[@]}"; do
                echo "- $account"
            done
            echo "确认删除这些账号吗？（输入 'yes' 确认，任意其他输入取消）："
            read -e -r confirm
            if [ "$confirm" != "yes" ] && [ "$confirm" != "YES" ]; then
                echo "删除操作已取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 执行删除操作
            echo "正在删除选中的账号..."
            for account in "${selected_accounts[@]}"; do
                echo "删除 $account..."
                gcloud auth revoke "$account" --quiet 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "账号 $account 删除成功！"
                else
                    echo "账号 $account 删除失败，请检查错误信息。"
                fi
            done
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        3)
            echo "正在查看所有账号..."
            account_data=$(get_account_list)
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            show_account_menu "$account_data"
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        4)
            echo "正在切换默认账号..."
            account_data=$(get_account_list)
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            show_account_menu "$account_data"
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "0. 取消选择"
            echo "请输入要设置为默认账号的编号："
            read -e -r selection
            if [ -z "$selection" ] || [ "$selection" == "0" ]; then
                echo "操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#account_array[@]}" ]; then
                selected_account="${account_array[$((selection-1))]}"
                echo "正在将默认账号切换为 $selected_account..."
                gcloud config set account "$selected_account"
                if [ $? -eq 0 ]; then
                    echo "默认账号已切换为 $selected_account！"
                else
                    echo "切换默认账号失败，请检查错误信息。"
                fi
            else
                echo "无效选项，操作取消。"
            fi
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        5)
            echo "正在添加项目 (并关联结算账号)..."
            echo "请输入项目 ID（6-30 个字符，小写字母开头，可包含小写字母、数字或连字符，例如 my-project-123）："
            read -e -r project_id
            if [ -z "$project_id" ]; then
                echo "未输入项目 ID，操作取消。"
            elif ! [[ "$project_id" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
                echo "项目 ID 格式无效。要求：以小写字母开头，可包含小写字母、数字或连字符，总长度为 6 到 30 个字符。"
                project_id="" # 清空以便后续判断
            fi
            if [ -z "$project_id" ]; then # 如果 project_id 无效或为空
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            echo "请输入项目名称（可选，可包含空格，例如 My Project，留空则默认使用项目 ID）："
            read -e -r project_name
            # 项目名称可以为空，GCP 会默认使用项目 ID

            selected_billing_account_id=""
            echo # 空行以改善可读性
            get_billing_accounts
            billing_fetch_status=$? # 0 表示成功获取并有账户，1 表示获取失败或无账户

            while true; do
                if [ "$billing_fetch_status" -eq 0 ]; then # 成功获取到账户列表
                    show_billing_account_menu
                else # 未能自动获取到账户
                    echo "未能自动获取结算账户列表。"
                    echo "您可以选择："
                    echo "m. 手动输入结算账号 ID"
                    echo "0. 取消并返回主菜单"
                    echo "请输入选项 (m 或 0):"
                fi

                read -e -r billing_choice

                if [ "$billing_choice" == "0" ]; then
                    echo "操作取消。"
                    echo "按任意键返回菜单..."
                    read -e -r -n 1
                    continue 2 # 继续外层主循环
                elif [ "$billing_choice" == "m" ] || [ "$billing_choice" == "M" ]; then
                    echo "请输入要关联的结算账号 ID (格式: XXXXXX-XXXXXX-XXXXXX):"
                    read -e -r manual_billing_id
                    if [ -z "$manual_billing_id" ]; then
                        echo "未输入结算账号 ID。请重新选择或输入。"
                        # 如果之前获取失败，再次提示手动或取消
                        if [ "$billing_fetch_status" -ne 0 ]; then continue; fi
                    elif ! [[ "$manual_billing_id" =~ ^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$ ]]; then
                        echo "结算账号 ID 格式无效 (期望格式: XXXXXX-XXXXXX-XXXXXX)。请检查并重新输入。"
                        if [ "$billing_fetch_status" -ne 0 ]; then continue; fi
                    else
                        selected_billing_account_id="$manual_billing_id"
                        echo "将使用手动输入的结算账号：$selected_billing_account_id"
                        break # 跳出结算账号选择循环
                    fi
                # 仅当 billing_fetch_status 为 0 (即列表成功显示) 时，才处理数字选项
                elif [ "$billing_fetch_status" -eq 0 ] && [[ "$billing_choice" =~ ^[0-9]+$ ]] && [ "$billing_choice" -ge 1 ] && [ "$billing_choice" -le "${#billing_account_array_ids[@]}" ]; then
                    selected_billing_account_id="${billing_account_array_ids[$((billing_choice-1))]}"
                    echo "已选择结算账号：$selected_billing_account_id"
                    break # 跳出结算账号选择循环
                else
                    echo "无效选项 '$billing_choice'。"
                    if [ "$billing_fetch_status" -ne 0 ]; then
                         echo "由于未能自动获取结算账户列表，您需要手动输入 (m) 或取消 (0)。"
                    else
                         echo "请输入列表中的数字、'm' 或 '0'。"
                    fi
                fi
            done

            if [ -z "$selected_billing_account_id" ]; then # 如果循环结束还没有选定结算账号
                echo "未指定有效的结算账号，项目创建取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            echo # 空行
            echo "即将执行以下操作："
            echo "  创建项目 ID: $project_id"
            if [ -n "$project_name" ]; then
                echo "  项目名称: $project_name"
            else
                echo "  项目名称: (将使用项目 ID)"
            fi
            echo "  关联结算账号: $selected_billing_account_id"
            echo "确认创建项目并关联结算账号吗？ (输入 'yes' 确认):"
            read -e -r confirm_create
            if [[ "$confirm_create" != "yes" ]]; then
                echo "项目创建已取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 创建项目和关联结算账号分两步执行
            echo "正在创建项目..."
            if [ -z "$project_name" ]; then
                gcloud projects create "$project_id" --quiet
            else
                gcloud projects create "$project_id" --name="$project_name" --quiet
            fi

            create_status=$?
            if [ $create_status -eq 0 ]; then
                echo "项目 '$project_id' 创建请求已提交。"
                echo "正在关联结算账号..."
                # 关联结算账号
                gcloud billing projects link "$project_id" --billing-account="$selected_billing_account_id" --quiet
                billing_status=$?
                
                if [ $billing_status -eq 0 ]; then
                    echo "项目 '$project_id' 已成功关联到结算账号 '$selected_billing_account_id'。"
                    echo "注意：项目创建和结算账号关联可能是异步操作，可能需要一些时间才能完全生效并在控制台中正确显示。"
                    echo "您可以稍后使用 'gcloud billing projects describe $project_id' 来验证结算信息。"
                else
                    echo "结算账号关联失败 (退出码: $billing_status)。请检查以下可能的原因："
                    echo "1. 结算账号 ID '$selected_billing_account_id' 无效、您没有权限使用它，或者它不处于活动状态。"
                    echo "2. 当前授权账号可能没有足够的权限（如 roles/billing.user）。"
                    echo "3. Google Cloud API 可能遇到临时问题。"
                    echo "您可以稍后手动关联结算账号：gcloud billing projects link $project_id --billing-account=$selected_billing_account_id"
                fi
            else
                echo "项目创建或结算账号关联失败 (退出码: $create_status)。请检查以下可能的原因："
                echo "1. 项目 ID '$project_id' 可能已被占用或格式仍不符合最新 GCP 要求。"
                echo "2. 结算账号 ID '$selected_billing_account_id' 无效、您没有权限使用它，或者它不处于活动状态。"
                echo "3. 当前授权账号可能没有足够的权限（如 roles/billing.user, roles/resourcemanager.projectCreator）。"
                echo "4. Google Cloud API 可能遇到临时问题。"
                echo "请检查 gcloud 的详细错误输出（如果上述命令未加 --quiet，则会有输出）。"
            fi
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        6)
            echo "正在删除项目..."
            project_data=$(get_project_list)
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            show_project_menu "$project_data"
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "0. 取消选择"
            echo "请输入要删除的项目编号（多个编号用空格分隔，例如 '1 2'，输入 'all' 删除全部非默认项目）："
            read -e -r input_selection
            if [ -z "$input_selection" ] || [ "$input_selection" == "0" ]; then
                echo "操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 处理用户选择
            declare -a selected_projects
            current_project=$(gcloud config get-value project 2>/dev/null)
            if [ "$input_selection" == "all" ] || [ "$input_selection" == "ALL" ]; then
                for project in "${project_array[@]}"; do
                    if [ "$project" != "$current_project" ]; then
                        selected_projects+=("$project")
                    fi
                done
            else
                IFS=' ' read -ra selections <<< "$input_selection"
                for sel in "${selections[@]}"; do
                    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#project_array[@]}" ]; then
                        project="${project_array[$((sel-1))]}"
                        if [ "$project" != "$current_project" ]; then
                            selected_projects+=("$project")
                        else
                            echo "无法删除当前默认项目：$project，已忽略。"
                        fi
                    else
                        echo "无效选项：$sel，已忽略。"
                    fi
                done
                unset IFS
            fi

            # 如果没有有效选择
            if [ ${#selected_projects[@]} -eq 0 ]; then
                echo "没有有效的项目被选中，操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 确认删除
            echo "您选择了以下项目进行删除："
            for project in "${selected_projects[@]}"; do
                echo "- $project"
            done
            echo "确认删除这些项目吗？（输入 'yes' 确认，任意其他输入取消）："
            read -e -r confirm
            if [ "$confirm" != "yes" ] && [ "$confirm" != "YES" ]; then
                echo "删除操作已取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 执行删除操作
            echo "正在删除选中的项目..."
            for project in "${selected_projects[@]}"; do
                echo "删除 $project..."
                gcloud projects delete "$project" --quiet 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "项目 $project 删除成功！"
                else
                    echo "项目 $project 删除失败，请检查错误信息或是否有权限。"
                fi
            done
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        7)
            echo "正在查看所有项目..."
            project_data=$(get_project_list)
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            show_project_menu "$project_data"
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        8)
            echo "正在切换默认项目..."
            project_data=$(get_project_list)
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            show_project_menu "$project_data"
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "0. 取消选择"
            echo "请输入要设置为默认项目的编号："
            read -e -r selection
            if [ -z "$selection" ] || [ "$selection" == "0" ]; then
                echo "操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#project_array[@]}" ]; then
                selected_project="${project_array[$((selection-1))]}"
                echo "正在将默认项目切换为 $selected_project..."
                gcloud config set project "$selected_project"
                if [ $? -eq 0 ]; then
                    echo "默认项目已切换为 $selected_project！"
                else
                    echo "切换默认项目失败，请检查错误信息或是否有权限。"
                fi
            else
                echo "无效选项，操作取消。"
            fi
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        9)
            echo "正在查看虚拟机列表..."
            current_project=$(gcloud config get-value project)
            if [ -z "$current_project" ]; then
                echo "未找到默认项目，请先切换默认项目（选项 8）。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "当前默认项目：$current_project"
            instance_data=$(get_instance_list "$current_project")
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            show_instance_menu "$instance_data"
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        10)
            echo "正在创建虚拟机..."
            current_project=$(gcloud config get-value project)
            if [ -z "$current_project" ]; then
                echo "未找到默认项目，请先切换默认项目（选项 8）。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "当前默认项目：$current_project"
            current_date=$(get_current_date)
            echo "当前日期：$current_date"
            echo "请输入机器标识符（如 us01, sg002）："
            read -e -r machine_id
            if [ -z "$machine_id" ]; then
                echo "未输入机器标识符，操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            # 下载启动脚本
#            echo "正在从远程地址下载启动脚本..."
#            script_url="https://github.com/Lsmoisu/Toolbox/raw/refs/heads/main/#enablesshandcreatesocks5.sh"
#            if ! command -v curl &> /dev/null; then
#                echo "curl 未安装，尝试安装..."
#                if command -v apt-get &> /dev/null; then
#                    sudo apt-get update && sudo apt-get install -y curl
#                elif command -v yum &> /dev/null; then
#                    sudo yum install -y curl
#                else
#                    echo "无法安装 curl，请手动安装后重试。"
#                    echo "按任意键返回菜单..."
#                    read -e -r -n 1
#                    continue
#                fi
#            fi
#            
#            # 使用 -L 参数跟随重定向，-sS 减少输出，-f 失败时返回错误码
#            if curl -L -sS -f -o startup-script.sh "$script_url"; then
#                echo "启动脚本下载成功！"
#                # 检查文件是否为空
#                if [ -s startup-script.sh ]; then
#                    echo "脚本内容非空，下载验证通过。"
#                    chmod +x startup-script.sh
#                else
#                    echo "错误：下载的脚本文件为空，请检查URL内容或网络连接。"
#                    rm -f startup-script.sh
#                    echo "按任意键返回菜单..."
#                    read -e -r -n 1
#                    continue
#                fi
#            else
#                echo "启动脚本下载失败，请检查网络连接或URL是否正确。"
#                echo "错误信息："
#                curl -L -sS "$script_url" -o /dev/null -w "%{http_code}\n"
#                rm -f startup-script.sh
#                echo "按任意键返回菜单..."
#                read -e -r -n 1
#                continue
#            fi

                #检测初始化脚本
                if [ ! -f "/opt/gcloud/startup-script.sh" ]; then
                    echo "未找到初始化脚本 startup-script.sh，请确保脚本位于当前目录。"
                    echo "按任意键返回菜单..."
                    read -e -r -n 1
                fi
                if [ -s /opt/gcloud/startup-script.sh ]; then
                    echo "脚本内容非空，验证通过。"
                    chmod +x /opt/gcloud/startup-script.sh
                else
                    echo "错误：初始化脚本检查失败，请检查/opt/gcloud/startup-script.sh"
                    echo "按任意键返回菜单..."
                    read -e -r -n 1
                    continue
                fi
            region_location_map["us-east7"]="美国弗吉尼亚州"
            region_location_map["us-west1"]="美国俄勒冈州"
            region_location_map["us-west2"]="美国加利福尼亚州洛杉矶"
            region_location_map["us-west3"]="美国犹他州盐湖城"
            region_location_map["us-west4"]="美国内华达州拉斯维加斯"
            region_location_map["us-west8"]="美国德克萨斯州达拉斯"
            region_location_map["us-south1"]="美国得克萨斯州"
            region_location_map["europe-central2"]="波兰华沙"
            region_location_map["europe-north1"]="芬兰哈米纳"
            region_location_map["europe-north2"]="挪威斯塔万格"
            region_location_map["europe-southwest1"]="西班牙马德里"
            region_location_map["europe-west1"]="比利时圣吉斯兰"
            region_location_map["europe-west2"]="英国伦敦"
            region_location_map["europe-west3"]="德国法兰克福"
            region_location_map["europe-west4"]="荷兰埃姆斯哈文"
            region_location_map["europe-west6"]="瑞士苏黎世"
            region_location_map["europe-west8"]="意大利米兰"
            region_location_map["europe-west9"]="法国巴黎"
            region_location_map["europe-west10"]="德国柏林"
            region_location_map["europe-west12"]="意大利都灵"
            region_location_map["asia-east1"]="台湾彰化县"
            region_location_map["asia-east2"]="中国香港"
            region_location_map["asia-northeast1"]="日本东京"
            region_location_map["asia-northeast2"]="日本大阪"
            region_location_map["asia-northeast3"]="韩国首尔"
            region_location_map["asia-south1"]="印度孟买"
            region_location_map["asia-south2"]="印度德里"
            region_location_map["asia-southeast1"]="新加坡"
            region_location_map["asia-southeast2"]="亚太地区印度尼西亚雅加达"
            region_location_map["australia-southeast1"]="澳大利亚悉尼"
            region_location_map["australia-southeast2"]="澳大利亚墨尔本"
            region_location_map["southamerica-east1"]="巴西圣保罗"
            region_location_map["southamerica-west1"]="智利圣地亚哥"
            region_location_map["northamerica-northeast1"]="加拿大蒙特利尔"
            region_location_map["northamerica-northeast2"]="加拿大多伦多"
            region_location_map["northamerica-south1"]="美国南卡罗来纳州"
            region_location_map["me-central1"]="卡塔尔多哈"
            region_location_map["me-central2"]="沙特阿拉伯达曼"
            region_location_map["me-west1"]="以色列特拉维夫"
            # 选择地区选择方式
            while true; do
                show_zone_selection_method
                read -e -r method_choice
                if [ "$method_choice" -eq 0 ]; then
                    echo "操作取消。"
                    echo "按任意键返回菜单..."
                    read -e -r -n 1
                    continue 2
                elif [ "$method_choice" -eq 1 ]; then
                    default_zone=$(gcloud config get-value compute/zone 2>/dev/null)
                    if [ -n "$default_zone" ]; then
                        region=$(echo "$default_zone" | cut -d'-' -f1-2)
                        location=${region_location_map["$region"]}
                        if [ -n "$location" ]; then
                            echo "使用默认地区：$default_zone（$location）"
                        else
                            echo "使用默认地区：$default_zone"
                        fi
                        zone="$default_zone"
                        break
                    else
                        echo "未设置默认地区，请手动输入一个区域作为默认地区（如 us-central1-a）："
                        read -e -r input_zone
                        if [ -z "$input_zone" ]; then
                            echo "未输入区域，操作取消。"
                            echo "按任意键返回菜单..."
                            read -e -r -n 1
                            continue 2
                        fi
                        echo "正在设置默认地区为 $input_zone..."
                        gcloud config set compute/zone "$input_zone"
                        if [ $? -eq 0 ]; then
                            region=$(echo "$input_zone" | cut -d'-' -f1-2)
                            location=${region_location_map["$region"]}
                            if [ -n "$location" ]; then
                                echo "默认地区已设置为 $input_zone（$location）"
                            else
                                echo "默认地区已设置为 $input_zone"
                            fi
                            zone="$input_zone"
                            break
                        else
                            echo "设置默认地区失败，请检查区域格式或权限。"
                            echo "按任意键返回菜单..."
                            read -e -r -n 1
                            continue 2
                        fi
                    fi
                elif [ "$method_choice" -eq 2 ]; then
                    echo "正在获取支持 e2-micro 机器类型的区域和可用区..."
                    get_regions_and_zones
                    if [ $? -ne 0 ]; then
                        echo "按任意键返回菜单..."
                        read -e -r -n 1
                        continue 2
                    fi
                    while true; do
                        echo "请选择大区域："
                        for i in "${!regions[@]}"; do
                            region="${regions[$i]}"
                            location=${region_location_map["$region"]}
                            if [ -n "$location" ]; then
                                printf "%2d. %s (%s)\n" "$((i+1))" "$region" "$location"
                            else
                                printf "%2d. %s\n" "$((i+1))" "$region"
                            fi
                        done
                        echo "0. 取消选择"
                        echo "请输入选项（0-${#regions[@]}）："
                        read -e -r region_choice
                        if [ "$region_choice" -eq 0 ]; then
                            echo "操作取消。"
                            echo "按任意键返回菜单..."
                            read -e -r -n 1
                            continue 3
                        fi
                        if [ "$region_choice" -ge 1 ] && [ "$region_choice" -le "${#regions[@]}" ]; then
                            region="${regions[$((region_choice-1))]}"
                            break
                        else
                            echo "无效选项，请选择 0-${#regions[@]} 之间的数字。"
                        fi
                    done
                    echo "选择的大区域：$region"
                    while true; do
                        show_zone_menu "$region"
                        if [ $? -ne 0 ]; then
                            echo "操作取消。"
                            echo "按任意键返回菜单..."
                            read -e -r -n 1
                            continue 3
                        fi
                        read -e -r zone_choice
                        zones_list=(${region_map["$region"]})
                        if [ "$zone_choice" -eq 0 ]; then
                            echo "操作取消。"
                            echo "按任意键返回菜单..."
                            read -e -r -n 1
                            continue 3
                        fi
                        if [ "$zone_choice" -ge 1 ] && [ "$zone_choice" -le "${#zones_list[@]}" ]; then
                            zone="${zones_list[$((zone_choice-1))]}"
                            # 自动设置选择的区域为默认区域
                            echo "正在设置默认地区为 $zone..."
                            gcloud config set compute/zone "$zone"
                            region=$(echo "$zone" | cut -d'-' -f1-2)
                            location=${region_location_map["$region"]}
                            if [ $? -eq 0 ]; then
                                if [ -n "$location" ]; then
                                    echo "默认地区已设置为 $zone（$location）"
                                else
                                    echo "默认地区已设置为 $zone"
                                fi
                            else
                                if [ -n "$location" ]; then
                                    echo "设置默认地区失败，请检查区域格式或权限，但将继续使用 $zone（$location） 创建虚拟机。"
                                else
                                    echo "设置默认地区失败，请检查区域格式或权限，但将继续使用 $zone 创建虚拟机。"
                                fi
                            fi
                            break
                        else
                            echo "无效选项，请选择 0-${#zones_list[@]} 之间的数字。"
                        fi
                    done
                    region=$(echo "$zone" | cut -d'-' -f1-2)
                    location=${region_location_map["$region"]}
                    if [ -n "$location" ]; then
                        echo "选择的可用区：$zone（$location）"
                    else
                        echo "选择的可用区：$zone"
                    fi
                    break
                elif [ "$method_choice" -eq 3 ]; then
                    echo "请输入新的默认地区（如 us-central1-a）："
                    read -e -r new_zone
                    if [ -z "$new_zone" ]; then
                        echo "未输入区域，操作取消。"
                        echo "按任意键返回菜单..."
                        read -e -r -n 1
                        continue 2
                    fi
                    echo "正在设置默认地区为 $new_zone..."
                    gcloud config set compute/zone "$new_zone"
                    if [ $? -eq 0 ]; then
                        region=$(echo "$new_zone" | cut -d'-' -f1-2)
                        location=${region_location_map["$region"]}
                        if [ -n "$location" ]; then
                            echo "默认地区已更新为 $new_zone（$location）"
                        else
                            echo "默认地区已更新为 $new_zone"
                        fi
                    else
                        echo "设置默认地区失败，请检查区域格式或权限。"
                        echo "按任意键返回菜单..."
                        read -e -r -n 1
                        continue 2
                    fi
                else
                    echo "无效选项，请选择 0-3 之间的数字。"
                fi
            done

            # 直接提示用户输入创建数量（保持不变）
            while true; do
                echo "请输入要创建的虚拟机数量（大于 0 的整数）："
                read -e -r instance_count
                if [[ ! "$instance_count" =~ ^[0-9]+$ ]] || [ "$instance_count" -le 0 ]; then
                    echo "无效输入，请输入大于 0 的整数。"
                    continue
                fi
                break
            done

            # 批量创建虚拟机（保持不变）
            echo "将创建 $instance_count 台虚拟机..."
            for ((i=1; i<=instance_count; i++)); do
                random_suffix=$(generate_random_suffix)
                instance_name="instance-${current_date}-${machine_id}-${random_suffix}"
                device_name="$instance_name"
                echo "正在创建第 $i 台虚拟机：$instance_name..."
                gcloud compute instances create "$instance_name" \
                    --project="$current_project" \
                    --zone="$zone" \
                    --machine-type=e2-micro \
                    --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
                    --metadata-from-file startup-script=/opt/gcloud/startup-script.sh \
                    --maintenance-policy=MIGRATE \
                    --provisioning-model=STANDARD \
                    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append \
                    --create-disk=auto-delete=yes,boot=yes,device-name="$device_name",image=projects/debian-cloud/global/images/debian-12-bookworm-v20250513,mode=rw,size=10,type=pd-standard \
                    --no-shielded-secure-boot \
                    --shielded-vtpm \
                    --shielded-integrity-monitoring \
                    --labels=goog-ec-src=vm_add-gcloud \
                    --reservation-affinity=any

                if [ $? -eq 0 ]; then
                    echo "第 $i 台虚拟机 $instance_name 创建成功！"
                else
                    echo "第 $i 台虚拟机 $instance_name 创建失败，请检查错误信息。"
                fi
            done
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        11)
            echo "正在删除虚拟机..."
            current_project=$(gcloud config get-value project)
            if [ -z "$current_project" ]; then
                echo "未找到默认项目，请先切换默认项目（选项 8）。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "当前默认项目：$current_project"

            # 获取虚拟机列表
            instance_data=$(get_instance_list "$current_project")
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 显示虚拟机列表
            show_instance_menu "$instance_data"
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 提示用户选择要删除的虚拟机
            echo "0. 取消选择"
            echo "请输入要删除的虚拟机编号（多个编号用空格分隔，例如 '1 2 3'，输入 'all' 删除全部）："
            read -e -r input_selection
            if [ -z "$input_selection" ] || [ "$input_selection" == "0" ]; then
                echo "操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 处理用户选择
            declare -a selected_instances
            if [ "$input_selection" == "all" ] || [ "$input_selection" == "ALL" ]; then
                for instance in "${instance_array[@]}"; do
                    selected_instances+=("$instance")
                done
            else
                IFS=' ' read -ra selections <<< "$input_selection"
                for sel in "${selections[@]}"; do
                    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#instance_array[@]}" ]; then
                        selected_instances+=("${instance_array[$((sel-1))]}")
                    else
                        echo "无效选项：$sel，已忽略。"
                    fi
                done
                unset IFS
            fi

            # 如果没有有效选择
            if [ ${#selected_instances[@]} -eq 0 ]; then
                echo "没有有效的虚拟机被选中，操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 确认删除
            echo "您选择了以下虚拟机进行删除："
            for inst in "${selected_instances[@]}"; do
                instance_name=$(echo "$inst" | cut -d'|' -f1)
                instance_zone=$(echo "$inst" | cut -d'|' -f2)
                region=$(echo "$instance_zone" | sed 's/-[a-z]$//')
                location=${region_location_map["$region"]}
                if [ -n "$location" ]; then
                    echo "- $instance_name (区域: $instance_zone（$location）)"
                else
                    echo "- $instance_name (区域: $instance_zone)"
                fi
            done
            echo "确认删除这些虚拟机吗？（输入 'yes' 确认，任意其他输入取消）："
            read -e -r confirm
            if [ "$confirm" != "yes" ] && [ "$confirm" != "YES" ]; then
                echo "删除操作已取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 执行删除操作
            echo "正在删除选中的虚拟机..."
            for inst in "${selected_instances[@]}"; do
                instance_name=$(echo "$inst" | cut -d'|' -f1)
                instance_zone=$(echo "$inst" | cut -d'|' -f2)
                echo "删除 $instance_name (区域: $instance_zone)..."
                gcloud compute instances delete "$instance_name" \
                    --project="$current_project" \
                    --zone="$instance_zone" \
                    --quiet 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "虚拟机 $instance_name 删除成功！"
                else
                    echo "虚拟机 $instance_name 删除失败，请检查错误信息。"
                fi
            done
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
         12)
            echo "正在查看当前项目下所有实例的 socks5 配置..."
            current_project=$(gcloud config get-value project)
            if [ -z "$current_project" ]; then
                echo "未找到默认项目，请先切换默认项目（选项 8）。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "当前默认项目：$current_project"
            instance_data=$(get_instance_list "$current_project")
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi


            region_location_map["us-east7"]="美国弗吉尼亚州"
            region_location_map["us-west1"]="美国俄勒冈州"
            region_location_map["us-west2"]="美国加利福尼亚州洛杉矶"
            region_location_map["us-west3"]="美国犹他州盐湖城"
            region_location_map["us-west4"]="美国内华达州拉斯维加斯"
            region_location_map["us-west8"]="美国德克萨斯州达拉斯"
            region_location_map["us-south1"]="美国得克萨斯州"
            region_location_map["europe-central2"]="波兰华沙"
            region_location_map["europe-north1"]="芬兰哈米纳"
            region_location_map["europe-north2"]="挪威斯塔万格"
            region_location_map["europe-southwest1"]="西班牙马德里"
            region_location_map["europe-west1"]="比利时圣吉斯兰"
            region_location_map["europe-west2"]="英国伦敦"
            region_location_map["europe-west3"]="德国法兰克福"
            region_location_map["europe-west4"]="荷兰埃姆斯哈文"
            region_location_map["europe-west6"]="瑞士苏黎世"
            region_location_map["europe-west8"]="意大利米兰"
            region_location_map["europe-west9"]="法国巴黎"
            region_location_map["europe-west10"]="德国柏林"
            region_location_map["europe-west12"]="意大利都灵"
            region_location_map["asia-east1"]="台湾彰化县"
            region_location_map["asia-east2"]="中国香港"
            region_location_map["asia-northeast1"]="日本东京"
            region_location_map["asia-northeast2"]="日本大阪"
            region_location_map["asia-northeast3"]="韩国首尔"
            region_location_map["asia-south1"]="印度孟买"
            region_location_map["asia-south2"]="印度德里"
            region_location_map["asia-southeast1"]="新加坡"
            region_location_map["asia-southeast2"]="亚太地区印度尼西亚雅加达"
            region_location_map["australia-southeast1"]="澳大利亚悉尼"
            region_location_map["australia-southeast2"]="澳大利亚墨尔本"
            region_location_map["southamerica-east1"]="巴西圣保罗"
            region_location_map["southamerica-west1"]="智利圣地亚哥"
            region_location_map["northamerica-northeast1"]="加拿大蒙特利尔"
            region_location_map["northamerica-northeast2"]="加拿大多伦多"
            region_location_map["northamerica-south1"]="美国南卡罗来纳州"
            region_location_map["me-central1"]="卡塔尔多哈"
            region_location_map["me-central2"]="沙特阿拉伯达曼"
            region_location_map["me-west1"]="以色列特拉维夫"

            # 显示虚拟机列表并获取数组
            show_instance_menu "$instance_data"
            if [ $? -ne 0 ]; then
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 遍历每个实例，读取 /opt/socks.txt 文件内容
            echo "正在读取每个实例的 /opt/socks.txt 文件内容..."
            for inst in "${instance_array[@]}"; do
                instance_name=$(echo "$inst" | cut -d'|' -f1)
                instance_zone=$(echo "$inst" | cut -d'|' -f2)
                echo "----------------------------------------"
                region=$(echo "$instance_zone" | sed 's/-[a-z]$//')
                location=${region_location_map["$region"]}
                if [ -n "$location" ]; then
                    echo "实例：$instance_name (区域: $instance_zone（$location）)"
                else
                    echo "实例：$instance_name (区域: $instance_zone)"
                fi
                # 使用 gcloud compute ssh 远程读取文件内容
                socks_content=$(gcloud compute ssh "$instance_name" \
                    --project="$current_project" \
                    --zone="$instance_zone" \
                    --command="cat /opt/socks.txt" \
                    --quiet 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$socks_content" ]; then
                    echo "$socks_content"
                else
                    echo "无法读取文件内容，可能是文件不存在、权限不足或 SSH 连接失败。"
                fi
                echo "----------------------------------------"
            done
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
    13)
    echo "正在配置防火墙规则..."
    current_project=$(gcloud config get-value project)
    if [ -z "$current_project" ]; then
        echo "未找到默认项目，请先切换默认项目（选项 8）。"
        echo "按任意键返回菜单..."
        read -e -r -n 1
        continue
    fi
    echo "当前默认项目：$current_project"

    # 提示用户输入防火墙规则名称
    echo "请输入防火墙规则名称（小写字母、数字或短划线组成，留空取消操作）："
    read -e -r rule_name
    if [ -z "$rule_name" ]; then
        echo "未输入规则名称，操作取消。"
        echo "按任意键返回菜单..."
        read -e -r -n 1
        continue
    fi

    # 验证规则名称格式（仅允许小写字母、数字和短划线）
    if [[ ! "$rule_name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]] || [[ "$rule_name" =~ ^- ]] || [[ "$rule_name" =~ -$ ]]; then
        echo "规则名称格式无效，仅允许小写字母、数字和短划线，且不能以短划线开头或结尾。"
        echo "按任意键返回菜单..."
        read -e -r -n 1
        continue
    fi

    # 检查规则名称是否已存在
    echo "正在检查规则名称是否已存在..."
    if gcloud compute firewall-rules list --project="$current_project" | grep -q "^$rule_name "; then
        echo "规则名称 '$rule_name' 已存在，请使用其他名称。"
        echo "按任意键返回菜单..."
        read -e -r -n 1
        continue
    fi

    # 提示用户选择协议类型
    echo "请选择协议类型："
    echo "1. TCP"
    echo "2. UDP"
    echo "3. TCP 和 UDP"
    echo "0. 取消操作"
    read -e -r protocol_choice
    case $protocol_choice in
        1)
            protocol="tcp"
            ;;
        2)
            protocol="udp"
            ;;
        3)
            protocol="tcp,udp"
            ;;
        0)
            echo "操作取消。"
            echo "按任意键返回菜单..."
            read -e -r -n 1
            continue
            ;;
        *)
            echo "无效选项，操作取消。"
            echo "按任意键返回菜单..."
            read -e -r -n 1
            continue
            ;;
    esac

    # 提示用户输入端口号或范围
    echo "请输入端口号（支持单个端口如 '8080'，非连续端口如 '8080,8081'，连续端口范围如 '8000-9000'）："
    read -e -r port_input
    if [ -z "$port_input" ]; then
        echo "未输入端口号，操作取消。"
        echo "按任意键返回菜单..."
        read -e -r -n 1
        continue
    fi

    # 验证端口输入格式
    if [[ ! "$port_input" =~ ^[0-9]+(-[0-9]+)?([,][0-9]+(-[0-9]+)?)*$ ]]; then
        echo "端口格式无效，仅支持数字、逗号和短划线（用于范围）。示例：8080 或 8000-9000 或 8080,8081,9000-9100"
        echo "按任意键返回菜单..."
        read -e -r -n 1
        continue
    fi

    # 拆分端口输入，检查每个端口或范围是否合法
    IFS=',' read -ra port_entries <<< "$port_input"
    for entry in "${port_entries[@]}"; do
        if [[ "$entry" =~ ^[0-9]+-[0-9]+$ ]]; then
            # 范围端口
            IFS='-' read -ra range <<< "$entry"
            start_port=${range[0]}
            end_port=${range[1]}
            if [ "$start_port" -lt 1 ] || [ "$start_port" -gt 65535 ] || [ "$end_port" -lt 1 ] || [ "$end_port" -gt 65535 ] || [ "$start_port" -gt "$end_port" ]; then
                echo "端口范围 $entry 无效，端口必须在 1-65535 之间，且起始端口不能大于结束端口。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue 2
            fi
        elif [[ "$entry" =~ ^[0-9]+$ ]]; then
            # 单个端口
            if [ "$entry" -lt 1 ] || [ "$entry" -gt 65535 ]; then
                echo "端口 $entry 无效，端口必须在 1-65535 之间。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue 2
            fi
        else
            echo "端口格式 $entry 无效。"
            echo "按任意键返回菜单..."
            read -e -r -n 1
            continue 2
        fi
    done
    unset IFS

    # 提示用户输入来源 IP 范围（默认为 0.0.0.0/0，即所有来源）
    echo "请输入允许的来源 IP 范围（CIDR 格式，如 0.0.0.0/0 表示所有 IP，留空使用默认值 0.0.0.0/0）："
    read -e -r source_ranges
    if [ -z "$source_ranges" ]; then
        source_ranges="0.0.0.0/0"
    fi

    # 验证 CIDR 格式（简单检查）
    if [[ ! "$source_ranges" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "来源 IP 范围格式无效，应为 CIDR 格式（如 0.0.0.0/0 或 192.168.1.0/24）。"
        echo "按任意键返回菜单..."
        read -e -r -n 1
        continue
    fi

    # 确认创建防火墙规则
    echo "即将创建以下防火墙规则："
    echo "规则名称：$rule_name"
    echo "协议：$protocol"
    echo "端口：$port_input"
    echo "来源 IP 范围：$source_ranges"
    echo "确认创建吗？（输入 'y' 确认，其他取消）："
    read -e -r -n 1 confirm
    echo ""
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "创建操作已取消。"
        echo "按任意键返回菜单..."
        read -e -r -n 1
        continue
    fi

    # 格式化 --rules 参数
    rules=""
    IFS=',' read -ra protocols <<< "$protocol"
    IFS=',' read -ra ports <<< "$port_input"
    for proto in "${protocols[@]}"; do
        for port in "${ports[@]}"; do
            if [ -n "$rules" ]; then
                rules="$rules,"
            fi
            rules="$rules$proto:$port"
        done
    done
    unset IFS

    # 创建防火墙规则
    echo "正在创建防火墙规则 '$rule_name'..."
    gcloud compute firewall-rules create "$rule_name" \
        --project="$current_project" \
        --direction=INGRESS \
        --priority=1000 \
        --network=default \
        --action=ALLOW \
        --rules="$rules" \
        --source-ranges="$source_ranges"
    if [ $? -eq 0 ]; then
        echo "防火墙规则 '$rule_name' 创建成功！"
    else
        echo "创建防火墙规则失败，可能是规则名称已存在或没有权限。"
        echo "错误信息如上，请检查。"
    fi
    echo "按任意键返回菜单..."
    read -e -r -n 1
    ;;

        14)
            echo "正在查看当前防火墙规则..."
            current_project=$(gcloud config get-value project)
            if [ -z "$current_project" ]; then
                echo "未找到默认项目，请先切换默认项目（选项 8）。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "当前默认项目：$current_project"
            echo "列出所有防火墙规则："
            # 使用 gcloud 命令列出防火墙规则
            gcloud compute firewall-rules list --project="$current_project" --format="table(name,network,direction,priority,allow,disabled)" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "防火墙规则列表显示完毕。"
            else
                echo "无法获取防火墙规则列表，请检查是否有权限或项目是否正确。"
            fi
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        15)
            echo "正在准备删除防火墙规则..."
            current_project=$(gcloud config get-value project)
            if [ -z "$current_project" ]; then
                echo "未找到默认项目，请先切换默认项目（选项 8）。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "当前默认项目：$current_project"
            echo "当前防火墙规则列表："
            # 列出所有防火墙规则供用户参考
            gcloud compute firewall-rules list --project="$current_project" --format="table(name,network,direction,priority,allow,disabled)" 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "无法获取防火墙规则列表，请检查是否有权限或项目是否正确。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 提示用户输入要删除的规则名称
            echo "请输入要删除的防火墙规则名称（留空取消操作）："
            read -e -r rule_name
            if [ -z "$rule_name" ]; then
                echo "未输入规则名称，操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 确认删除操作
            echo "确认要删除防火墙规则 '$rule_name' 吗？（输入 'y' 确认，其他取消）："
            read -e -r -n 1 confirm
            echo ""
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "删除操作已取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi

            # 执行删除操作
            echo "正在删除防火墙规则 '$rule_name'..."
            gcloud compute firewall-rules delete "$rule_name" --project="$current_project" --quiet 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "防火墙规则 '$rule_name' 删除成功。"
            else
                echo "删除防火墙规则失败，可能是规则不存在或没有权限。"
            fi
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
        16)
            if get_billing_accounts; then
                echo "可用的结算账号列表："
                for item in "${billing_account_array_display[@]}"; do
                    echo "$item"
                done
            else
                echo "无法获取结算账号列表。"
            fi
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;

        0)
            echo "退出脚本..."
            exit 0
            ;;
        *)
            echo "无效选项，请选择 0-12 之间的数字。"
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
    esac
done
