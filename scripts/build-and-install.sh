#!/bin/zsh

set -euo pipefail

readonly script_dir="$(cd "$(dirname "$0")" && pwd)"
readonly project_root="$(cd "${script_dir}/.." && pwd)"
readonly configuration="${CONFIGURATION:-Release}"
readonly derived_data_path="${DERIVED_DATA_PATH:-${project_root}/.build/DerivedData}"
readonly install_root="${INSTALL_ROOT:-${HOME}/Applications}"
readonly app_name="CoordinatePreview.app"
readonly bundle_identifier="com.codex.CoordinatePreview"
readonly installed_app="${install_root}/${app_name}"
readonly launch_services_register="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

staging_dir=""

cleanup() {
    if [[ -n "${staging_dir}" && -d "${staging_dir}" ]]; then
        /bin/rm -rf "${staging_dir}"
    fi
}

trap cleanup EXIT

echo "正在构建 ${configuration} 版本…"
/usr/bin/xcodebuild \
    -quiet \
    -project "${project_root}/CoordinatePreview.xcodeproj" \
    -scheme CoordinatePreview \
    -configuration "${configuration}" \
    -destination 'platform=macOS' \
    -derivedDataPath "${derived_data_path}" \
    CODE_SIGNING_ALLOWED=NO \
    build

readonly built_app="${derived_data_path}/Build/Products/${configuration}/${app_name}"
if [[ ! -d "${built_app}" ]]; then
    echo "错误：构建成功，但未找到产物：${built_app}" >&2
    exit 1
fi

/bin/mkdir -p "${install_root}"
staging_dir="$(/usr/bin/mktemp -d "${install_root}/.coordinate-preview-install.XXXXXX")"
readonly staged_app="${staging_dir}/${app_name}"
/usr/bin/ditto "${built_app}" "${staged_app}"

# 为本机安装添加 ad-hoc 签名，同时保留工程声明的沙盒权限。
/usr/bin/codesign \
    --force \
    --sign - \
    --entitlements "${project_root}/CoordinatePreview/CoordinatePreview.entitlements" \
    "${staged_app}"
/usr/bin/codesign --verify --deep --strict "${staged_app}"

# 已运行的进程不会因替换磁盘上的 App 而自动更新，先请求旧实例正常退出。
if /usr/bin/pgrep -x CoordinatePreview >/dev/null 2>&1; then
    /usr/bin/osascript -e "tell application id \"${bundle_identifier}\" to quit" >/dev/null 2>&1 || true
fi

previous_app=""
if [[ -e "${installed_app}" ]]; then
    previous_app="${staging_dir}/previous-${app_name}"
    /bin/mv "${installed_app}" "${previous_app}"
fi

if ! /bin/mv "${staged_app}" "${installed_app}"; then
    if [[ -n "${previous_app}" && -e "${previous_app}" ]]; then
        /bin/mv "${previous_app}" "${installed_app}"
    fi
    echo "错误：无法安装到 ${installed_app}" >&2
    exit 1
fi

# 注销同 Bundle ID 的旧构建，避免“打开方式”出现多个无法区分的同名 App。
# 这里只更新 Launch Services 记录，不会删除其他位置的 App 文件。
registered_apps="$(
    /usr/bin/osascript -l JavaScript -e \
        'ObjC.import("AppKit"); $.NSWorkspace.sharedWorkspace.URLsForApplicationsWithBundleIdentifier("com.codex.CoordinatePreview").js.map(url => ObjC.unwrap(url.path)).join("\n")' \
        2>/dev/null || true
)"
while IFS= read -r registered_app; do
    if [[ -n "${registered_app}" && "${registered_app}" != "${installed_app}" ]]; then
        "${launch_services_register}" -u "${registered_app}" >/dev/null 2>&1 || true
        echo "已注销旧构建：${registered_app}"
    fi
done <<< "${registered_apps}"

# 若系统查询没有返回 xcodebuild 的临时产物，仍按已知路径补充注销。
"${launch_services_register}" -u "${built_app}" >/dev/null 2>&1 || true

# 强制 Launch Services 刷新固定路径的注册信息，让 Finder 的“打开方式”使用本次产物。
"${launch_services_register}" -f "${installed_app}"

echo
echo "已安装最新构建：${installed_app}"
echo "现在可在 Finder 中右键图片，选择“打开方式 > Coordinate Preview”。"
