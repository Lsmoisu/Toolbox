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
    echo "0. 退出脚本"
    echo "====================================="
    echo "请输入选项（0-11）："
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

# 动态获取支持 e2-micro 的区域和可用区，并分组
get_regions_and_zones() {
    echo "正在获取支持 e2-micro 机器类型的区域和可用区..."
    zones=$(gcloud compute machine-types list --filter="name=e2-micro" --format="value(ZONE)" --limit=1000 2>/dev/null | sort | uniq)
    if [ -z "$zones" ]; then
        echo "无法获取可用区列表，请检查 gcloud 配置或网络连接。"
        return 1
    fi
    declare -g -A region_map
    declare -g -a regions
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
        echo "$i. $region"
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
    for zone in "${zones_list[@]}"; do
        echo "$i. $zone"
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
        echo "1. 使用默认地区：$default_zone"
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
            echo "$i. $instance_name (区域: $instance_zone)"
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

# 主循环
while true; do
    show_menu
    read -e -r choice  # 使用 -e 参数启用 readline 支持删除键等功能

    case $choice in
        1)
            echo "正在添加账号..."
            echo "请按照提示完成账号登录流程（浏览器将打开进行身份验证）："
            gcloud auth login
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
            echo "正在添加项目..."
            echo "请输入项目 ID（小写字母、数字或短划线组成，例如 my-project-123）："
            read -e -r project_id
            if [ -z "$project_id" ]; then
                echo "未输入项目 ID，操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "请输入项目名称（可包含空格，例如 My Project）："
            read -e -r project_name
            if [ -z "$project_name" ]; then
                echo "未输入项目名称，操作取消。"
                echo "按任意键返回菜单..."
                read -e -r -n 1
                continue
            fi
            echo "正在创建项目 $project_id ($project_name)..."
            gcloud projects create "$project_id" --name="$project_name"
            if [ $? -eq 0 ]; then
                echo "项目 $project_id 创建成功！"
            else
                echo "项目创建失败，请检查项目 ID 是否唯一或是否有权限。"
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
                        echo "使用默认地区：$default_zone"
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
                            echo "默认地区已设置为 $input_zone"
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
                    get_regions_and_zones
                    if [ $? -ne 0 ]; then
                        echo "按任意键返回菜单..."
                        read -e -r -n 1
                        continue 2
                    fi
                    while true; do
                        show_region_menu
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
                            break
                        else
                            echo "无效选项，请选择 0-${#zones_list[@]} 之间的数字。"
                        fi
                    done
                    echo "选择的可用区：$zone"
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
                        echo "默认地区已更新为 $new_zone"
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

            # 直接提示用户输入创建数量
            while true; do
                echo "请输入要创建的虚拟机数量（大于 0 的整数）："
                read -e -r instance_count
                if [[ ! "$instance_count" =~ ^[0-9]+$ ]] || [ "$instance_count" -le 0 ]; then
                    echo "无效输入，请输入大于 0 的整数。"
                    continue
                fi
                break
            done

            # 批量创建虚拟机
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
                    --metadata=ssh-keys=root:ssh-rsa\ AAAAB3NzaC1yc2EAAAADAQABAAABgQDVw/Lamb8wHXeLgCKGbumrocMvq+a6goVFBAuhYk/TVUoislrO1SrrH5YMFc7aQMZNP/mbubirIck8h0wT8hiU070OHO7HuaAyIGgFh4icIX/m7znhvWteG/evxJUN95ZWm4bk+UmGUbbAO4BkSEGub/ENJ3RGR9eJuDabgMha5fyzl9J9sm6jDeXVyGtLOy9NkYYHo/J0kUAwK1YOQ88rAXIhsJ04qsH7256VAdo6enO39Y0RG4NhK3hlRYP46f8NWyCaJFbcz4tpbHNdG9Xbqg7j/RSn7tO5bpB283m/wsZR7kM28x9dzyojJJYycEn9CTUzBjxcBBuKNa57Y+eoBo7q2KXx13ziMvO5k7Bl8GXknl0uguf49hjbPS95CThns+sqz7G3Px8a79BJ1rHEewlmMMJUa/kRY+NAcum0nVkWzZIpR6I2KWMP+8OaJLj97vIHgGydRP8y4I6IiiZBlOlshNJ3iI/XxsSWjWjdWxSHUZtHj4L1IaxclrX+QtU=\ root@gc-hk.asia-east2-c.c.annular-bucksaw-448504-h3.internal \
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
                echo "- $instance_name (区域: $instance_zone)"
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
        0)
            echo "退出脚本..."
            exit 0
            ;;
        *)
            echo "无效选项，请选择 0-11 之间的数字。"
            echo "按任意键返回菜单..."
            read -e -r -n 1
            ;;
    esac
done
