#!/usr/bin/env python3
"""CI 辅助：确保 release 构建关闭 R8 混淆。

用法：python3 ci/disable_minify.py <build.gradle 路径>
逻辑：
1. 若已有 minifyEnabled 行，把 true 改为 false（兼容带等号/不带等号写法）；
2. 若完全没有 minifyEnabled 行，在第一个 `release {` 块内插入 minifyEnabled false 与 shrinkResources false。
个人内网应用无需混淆，换取 release 构建稳定（APK 体积略大）。
"""
import sys


def main() -> None:
    if len(sys.argv) != 2:
        print('用法: disable_minify.py <build.gradle 路径>')
        sys.exit(1)
    path = sys.argv[1]
    with open(path, 'r', encoding='utf-8') as f:
        src = f.read()

    if 'minifyEnabled true' in src or 'minifyEnabled = true' in src:
        src = src.replace('minifyEnabled true', 'minifyEnabled false')
        src = src.replace('minifyEnabled = true', 'minifyEnabled = false')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(src)
        print('minify: 已将 true 改为 false')
        return

    if 'minifyEnabled' in src:
        print('minify: 已存在且非 true，无需修改')
        return

    # 模板没有 minifyEnabled 行：插入到第一个 release { 块内
    marker = 'release {'
    idx = src.find(marker)
    if idx == -1:
        print('minify: 未找到 release { 块，跳过插入（构建将继续）')
        return
    insert_at = idx + len(marker)
    src = (
        src[:insert_at]
        + '\n            minifyEnabled false\n            shrinkResources false'
        + src[insert_at:]
    )
    with open(path, 'w', encoding='utf-8') as f:
        f.write(src)
    print('minify: 已在 release 块插入 minifyEnabled false / shrinkResources false')


if __name__ == '__main__':
    main()
