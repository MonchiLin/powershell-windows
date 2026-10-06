# powershell-windows

面向 Windows 自动化与排障的 PowerShell 7 技能。当前版本：**2.1.0**。

为支持 `SKILL.md` 的 AI 编程助手提供执行指导：确认真实运行环境、正确传递原生命令参数、处理中文与编码、保留配置结构，并核实操作结果。

## 能力

- 验证实际使用 PowerShell 7 / Core，避免意外回退到 Windows PowerShell 5.1。
- 处理包含中文、空格和方括号的路径，以及 PowerShell 与 Python 的文本编码边界。
- 编辑 JSON、CSV 等配置，保留空数组和单元素数组的结构。
- 正确解释每个原生命令的退出码，管理后台任务和子进程生命周期。
- 排查命令解析、端口、进程、服务和应用配置加载问题，并输出结构化证据。

## 安装与使用

将整个仓库目录放入你的助手支持的 skills 目录，保持目录名 `powershell-windows`。例如，使用用户级 `.agents/skills` 目录时，在 PowerShell 7 中运行：

```powershell
$skillsRoot = Join-Path $HOME '.agents/skills'
New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
git clone https://github.com/MonchiLin/powershell-windows.git (Join-Path $skillsRoot 'powershell-windows')
```

如果同名技能已经存在，先检查现有内容再决定如何合并。不同助手的技能目录和刷新方式可能不同，请使用其实际配置。

在支持技能调用的助手中，例如：

```text
使用 $powershell-windows 检查 8080 端口由哪个进程占用。
使用 $powershell-windows 修复这个 PowerShell 脚本的中文编码问题。
```

## 文件结构

```text
powershell-windows/
├── SKILL.md
├── agents/openai.yaml
├── references/
│   ├── execution.md
│   ├── files-and-config.md
│   └── windows-diagnostics.md
└── scripts/
    ├── Get-WindowsContext.ps1
    └── Test-PowerShellScript.ps1
```

`SKILL.md` 是技能入口，详细规则按需从参考文件读取。

## 辅助脚本

在 PowerShell 7 中从仓库根目录运行：

```powershell
# 查看运行时、编码、命令路径等环境信息。
./scripts/Get-WindowsContext.ps1 -AsJson

# 只解析语法，不执行待检查脚本。
./scripts/Test-PowerShellScript.ps1 -LiteralPath './example.ps1' -AsJson
```

两个脚本要求 PowerShell 7 / Core。语法检查返回退出码 0 表示解析通过，1 表示文件或语法错误；语法通过并不代表运行结果正确。

## 2.1.0 更新

- 补充 Python 标准流、文件读写与调用方解码的区别。
- 增加 JSON 顶层数组在解析和序列化两端的结构保留规则。
- 要求多条原生命令逐项判断成功与失败。
- 将混合诊断结果组织为具名 JSON，避免表格隐藏字段与深度截断。

本版本的技能格式、内部引用、9 个 PowerShell 文档示例语法，以及空数组、单元素数组、多元素数组和对象内数组的往返转换，已在 Windows / PowerShell 7.6.5 上检查。

技能提供执行知识，需要助手本身具有可用的 Windows 执行工具。它不会安装 PowerShell、增加系统权限或授予远程访问能力。
