#!/bin/bash

# 交互式寫作腳本
# 使用方法: ./posting.sh

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 配置變數
TEMPLATE_DIR="templates"          # 模板目錄
POSTS_DIR="./content/posts"         # 文章目錄
CONFIG_FILE=".writing-config"     # 配置文件

# 預設分類（你可以修改這個列表）
AVAILABLE_CATEGORIES=(
    "活動" "相簿"
)

# 函數：輸出彩色訊息
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_prompt() {
    echo -e "${CYAN}[PROMPT]${NC} $1"
}

# 函數：創建目錄
create_directories() {
    mkdir -p "$TEMPLATE_DIR"
}

# 函數：列出可用模板
list_templates() {
    if [ ! -d "$TEMPLATE_DIR" ]; then
        log_error "模板目錄不存在: $TEMPLATE_DIR"
        return 1
    fi
    
    local templates=($(find "$TEMPLATE_DIR" -name "*.md" -type f))
    
    if [ ${#templates[@]} -eq 0 ]; then
        log_warning "沒有找到模板文件"
        log_info "請在 $TEMPLATE_DIR 目錄中創建 .md 模板文件"
        return 1
    fi
    
    echo -e "\n${MAGENTA}=== 可用模板 ===${NC}"
    for i in "${!templates[@]}"; do
        local basename=$(basename "${templates[$i]}" .md)
        echo -e "${YELLOW}$((i+1)).${NC} $basename"
    done
    
    return 0
}

# 函數：選擇模板
select_template() {
    local templates=($(find "$TEMPLATE_DIR" -name "*.md" -type f))
    
    while true; do
        log_prompt "請選擇模板 (輸入數字):"
        read -r template_choice
        
        if [[ "$template_choice" =~ ^[0-9]+$ ]] && [ "$template_choice" -ge 1 ] && [ "$template_choice" -le ${#templates[@]} ]; then
            SELECTED_TEMPLATE="${templates[$((template_choice-1))]}"
            log_info "已選擇模板: $(basename "$SELECTED_TEMPLATE" .md)"
            break
        else
            log_error "無效選擇，請輸入 1-${#templates[@]} 之間的數字"
        fi
    done
}

# 函數：顯示分類選擇
show_category_selection() {
    echo -e "\n${MAGENTA}=== 可用分類 ===${NC}"
    for i in "${!AVAILABLE_CATEGORIES[@]}"; do
        local num=$((i+1))
        if [ $num -le 9 ]; then
            echo -e "${YELLOW} $num.${NC} ${AVAILABLE_CATEGORIES[$i]}"
        else
            echo -e "${YELLOW}$num.${NC} ${AVAILABLE_CATEGORIES[$i]}"
        fi
    done
}

# 函數：選擇分類
select_categories() {
    local selected_categories=()
    
    show_category_selection
    
    echo -e "\n${CYAN}分類選擇說明：${NC}"
    echo "- 輸入數字選擇分類 (例如: 1,3,5)"
    echo "- 輸入 'c' 自定義分類"
    echo "- 輸入 'done' 完成選擇"
    echo "- 輸入 'show' 重新顯示分類列表"
    
    while true; do
        log_prompt "請選擇分類 (當前已選: ${selected_categories[*]}):"
        read -r category_input
        
        case "$category_input" in
            "done")
                if [ ${#selected_categories[@]} -eq 0 ]; then
                    log_warning "至少選擇一個分類"
                    continue
                fi
                break
                ;;
            "show")
                show_category_selection
                ;;
            "c")
                log_prompt "請輸入自定義分類:"
                read -r custom_category
                if [ -n "$custom_category" ]; then
                    selected_categories+=("$custom_category")
                    log_success "已添加自定義分類: $custom_category"
                fi
                ;;
            *)
                # 處理數字選擇
                IFS=',' read -ra category_numbers <<< "$category_input"
                for num in "${category_numbers[@]}"; do
                    # 去除空格
                    num=$(echo "$num" | xargs)
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#AVAILABLE_CATEGORIES[@]} ]; then
                        local category="${AVAILABLE_CATEGORIES[$((num-1))]}"
                        # 檢查是否已經選擇
                        if [[ ! " ${selected_categories[*]} " =~ " $category " ]]; then
                            selected_categories+=("$category")
                            log_success "已添加分類: $category"
                        else
                            log_warning "分類 '$category' 已經選擇過了"
                        fi
                    else
                        log_error "無效的分類編號: $num"
                    fi
                done
                ;;
        esac
    done
    
    # 修復：直接生成正確的 YAML 格式字符串，不包含外層方括號
    SELECTED_CATEGORIES_YAML=""
    for category in "${selected_categories[@]}"; do
        if [ -z "$SELECTED_CATEGORIES_YAML" ]; then
            SELECTED_CATEGORIES_YAML="\"$category\""
        else
            SELECTED_CATEGORIES_YAML="$SELECTED_CATEGORIES_YAML, \"$category\""
        fi
    done
    
    log_info "最終選擇的分類: [$SELECTED_CATEGORIES_YAML]"
}

# 函數：獲取文章標題
get_article_title() {
    while true; do
        log_prompt "請輸入文章標題:"
        read -r article_title
        
        if [ -n "$article_title" ]; then
            ARTICLE_TITLE="$article_title"
            break
        else
            log_error "標題不能為空"
        fi
    done
}

# 函數：生成文件名
generate_filename() {
    #local date=$(date '+%Y-%m-%d')
    # 簡單的文件名處理：移除特殊字符，替換空格為連字符
    #local safe_title=$(echo "$ARTICLE_TITLE" | sed 's/[^a-zA-Z0-9\u4e00-\u9fff ]//g' | sed 's/ /-/g' | sed 's/--*/-/g')
    #ARTICLE_FILENAME="$ARTICLE_TITLE.md"
    while true; do
        log_prompt "請輸入文件名:"
        read -r file_name
        
        if [ -n "$file_name" ]; then
            ARTICLE_FILENAME="$file_name.md"
            break
        else
            log_error "文件名不能為空"
        fi
    done
    ARTICLE_FILEPATH="${POSTS_DIR}/${ARTICLE_FILENAME}"
}

# 函數：處理模板變數替換
process_template() {
    local current_time=$(date '+%Y-%m-%dT%H:%M:%S+08:00')
    
    # 讀取模板內容
    local template_content=$(cat "$SELECTED_TEMPLATE")
    
    # 替換變數 - 將標題用引號包起來
    template_content=$(echo "$template_content" | sed "s|{{TITLE}}|\"$ARTICLE_TITLE\"|g")
    template_content=$(echo "$template_content" | sed "s|{{DATE}}|$current_time|g")
    # 修復：在模板替換時直接加上方括號，生成正確的 YAML 數組格式
    template_content=$(echo "$template_content" | sed "s|{{CATEGORIES}}|[$SELECTED_CATEGORIES_YAML]|g")
    
    # 寫入新文件
    echo "$template_content" > "$ARTICLE_FILEPATH"
}

# 函數：創建文章資料夾並重新組織文件
organize_article_files() {
    # 獲取不含副檔名的文件名
    local filename_without_ext="${ARTICLE_FILENAME%.*}"
    local folder_path="${POSTS_DIR}/${filename_without_ext}"
    
    log_info "正在創建文章資料夾: $filename_without_ext"
    
    # 創建同名資料夾
    mkdir -p "$folder_path"

    # 創建圖片資料夾
    mkdir -p "$folder_path/images"
    
    # 移動文件到資料夾中並重命名為 index.md
    local new_filepath="${folder_path}/index.md"
    mv "$ARTICLE_FILEPATH" "$new_filepath"
    
    # 更新文件路徑變數
    ARTICLE_FILEPATH="$new_filepath"
    
    log_success "文章已組織到資料夾: $folder_path/index.md"
}

# 函數：保存配置
save_config() {
    echo "LAST_CATEGORIES=($SELECTED_CATEGORIES_YAML)" > "$CONFIG_FILE"
    log_info "配置已保存"
}

# 主函數
main() {
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════╗"
    echo "║        快速寫作助手 v1.0             ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 創建必要目錄
    create_directories
    
    # 列出並選擇模板
    log_info "步驟 1: 選擇文章模板"
    if ! list_templates; then
        log_error "無法繼續，請先創建模板文件"
        exit 1
    fi
    select_template
    
    # 獲取文章標題
    log_info "步驟 2: 設定文章標題"
    get_article_title
    
    # 選擇分類
    log_info "步驟 3: 選擇文章分類"
    select_categories
    
    # 生成文件名
    generate_filename
    
    # 檢查文件是否已存在
    if [ -f "$ARTICLE_FILEPATH" ]; then
        log_warning "文件已存在: $ARTICLE_FILEPATH"
        log_prompt "是否覆蓋? (y/N):"
        read -r overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            log_info "操作取消"
            exit 0
        fi
    fi
    
    # 處理模板並創建文章
    log_info "步驟 4: 創建文章文件"
    process_template
    
    # 組織文章文件到資料夾中
    log_info "步驟 5: 組織文章文件"
    organize_article_files
    
    # 保存配置
    save_config

    echo -e "\n${GREEN}🎉 寫作準備完成！祝你寫作愉快！${NC}"
}

# 錯誤處理
trap 'log_error "腳本執行過程中發生錯誤"; exit 1' ERR

# 執行主函數
main "$@"
