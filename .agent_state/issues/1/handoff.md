# Handoff

Review status: **complete**

## Summary

独立复核通过。工作树实际 diff 仅触及 check-updates.sh、update-sources.sh、AGENTS.md、README.md 共 4 个文件（+22/-6），改动最小且与 bootstrap.sh 已有的 track 分支校验（第 160-170 行）风格一致。check_git_repo 新增第 5 参 ref 并在 branch 模式下、网络探测前校验（不符即 error、退出码 2、不入缓存），probe 调用点正确传入 $SRC_REF；update_git_repo 新增第 4 参 ref 并在 pull 模式的 fetch 重试循环前拦截（不 fetch 不合并，-n/-f 不旁路，游离 HEAD 显示为「游离 HEAD」）；pinned/latest 等非 pull/branch 模式不受影响。本人在验证者保留的 /tmp/issue1-fix-test 环境（脚本与工作树逐字节一致）独立重跑核心场景：fixture 停在 feature 时 check 退出码 2 并输出「配置要求分支 main，当前在 feature，请先切回 main」、update 无 fetch 且 HEAD 不变并报「分支不符（feature ≠ main）」；切回 main 后 check 退出码 0 报最新、远端推进后 check 退出码 10、update ff-only 合并成功。bash -n 与 shellcheck 无新告警类别。验证者报告 pass，验收条件逐点满足。

## Findings

- low: 缓存回放缺口（既有语义，非本次回归）——check-updates.sh 的 cache_get/cache_put（约第 83-111 行）按目标名缓存探测结果，若先在某目标正确分支上跑过检查（ok 入缓存），TTL（默认 6h）内切到错误分支再以默认参数运行，probe 直接命中缓存、分支守卫不执行，仍回放「UPTODATE … 最新（main@…）」退出码 0。issue 复现步骤明确使用 --no-cache，故不阻塞验收；但 AGENTS.md 约定退出码 0 即「直接读源码」，建议后续将当前分支纳入缓存键或在回放前快速比对分支。
- info: check-updates.sh 聚合头对分支不符场景措辞略偏——分支不符复用 error 状态后，BODY 头仍为「ERROR 检查失败，按『未能更新、基于本地版本』处理」（约第 282 行），网络故障色彩较浓；单行明细与 AGENTS.md 新增例外已说明真因，属计划中预先声明的取舍。
- info: check-updates.sh 的 -v 页脚「（N 项走网络…）」把被分支守卫拦截的目标计入走网络计数（实际未发生任何网络请求），纯展示层小瑕疵。
- info: update-sources.sh 对分支不符目标沿用既有「跳过目标退出码恒为 0」约定，调用方仅凭退出码无法察觉，需读输出/摘要；与既有「非 git 仓库跳过」路径一致，且 README.md 已补充说明，属可接受取舍。

## Next step

可合并该修复；后续低优先级跟进：把当前分支纳入 check-updates.sh 的缓存键（或在缓存回放前做分支比对），堵住 TTL 内先 main 缓存、后切 feature 时默认带缓存运行仍回放 UPTODATE 的既有缺口。
