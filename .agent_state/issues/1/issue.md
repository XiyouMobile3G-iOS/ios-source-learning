# Issue #1: [Bug] track 策略未校验 sources.sh 指定的 ref，其他分支会被判定为最新

- URL: https://github.com/XiyouMobile3G-iOS/ios-source-learning/issues/1
- Author association: NONE
- Labels: bug, solve-it

## Body

## 问题描述

当 `sources.sh` 中的源码使用 `track` 策略并指定分支（例如 `track|main`）时，`check-updates.sh` 和 `update-sources.sh` 实际使用的是源码目录当前所在分支，而不是配置中指定的 `ref`。

因此，如果本地源码误切到了其他分支，检查脚本仍可能报告“最新”，更新脚本也会继续更新错误的分支。仓库中的笔记包含固定源码行号，这会造成笔记所对应的源码版本与实际源码不一致。

## 复现方式

在隔离的本地 Git 仓库中验证，配置一个源码：

```text
Fixture|fixture|track|main
```

然后：

1. 让 `fixture` 当前位于另一个已设置 upstream 的分支，例如 `feature`。
2. 运行 `./bootstrap.sh --check`，脚本会正确提示当前分支与 `main` 不一致。
3. 运行 `./check-updates.sh --no-cache`。
4. 运行 `./update-sources.sh`。

## 实际结果

`check-updates.sh` 按当前分支检查，并报告：

```text
UPTODATE Fixture: 最新（feature@4b65423）
```

`update-sources.sh` 也会沿当前分支的 upstream 更新 `origin/feature`。

## 预期结果

配置要求 `main` 时，如果当前处于 `feature`，检查和更新不应把它判定为有效的最新版本。例如：

```text
配置要求：main
当前分支：feature
检查结果：ERROR，请先切回 main
```

更新逻辑也应以 `sources.sh` 中的 `SRC_REF` 为准，或者在分支不匹配时停止并给出明确提示。

## 相关代码

- `check-updates.sh` 第 155-165 行：使用当前分支构造远端分支，没有校验 `SRC_REF`。
- `update-sources.sh` 第 152-160 行：使用当前分支的 `@{u}`，没有校验 `SRC_REF`。

## 验证版本

仓库 `main`：`4159adde`。
