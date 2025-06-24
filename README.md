# Termux 下的 OpenList

这是一个在 Android Termux 环境中方便安装、更新和管理 [OpenList](https://github.com/OpenListTeam/OpenList) 的脚本。

## 功能
- 在 Termux 中一键安装和更新 OpenList。
- 集成 aria2 ，高效下载。
- 支持快捷命令 `oplist` 快速调出管理菜单。
- 支持openlist新版本检测 （非实时）。
- 支持脚本自更新

## 前置要求
1. **安装 curl 和 wget 工具**：
   - 在 Termux 中运行以下命令安装：
     ```bash
     pkg in -y wget curl
     ```

2. **GitHub 个人访问令牌（Token）**：
   - 用于突破未登录账户频繁调用 GitHub API 导致的速率限制。
   - **如何获取 GitHub token**：
     1. 访问 [GitHub 设置 > 开发者设置 > 个人访问令牌 > 经典令牌](https://github.com/settings/tokens)。
     2. 点击 **生成新令牌（经典）**。
     3. 选择权限：如需访问私有仓库请选择 `repo`，公开仓库可不选。
     4. 生成并复制令牌。
     - **注意**：token只显示一次，请及时保存。首次输入后，token 会安全存储在 Termux 本地，无需重复输入。

3. **aria2 RPC 密钥**：
   - 自行设置一个由字母、数字和符号组成的易记密钥，用于 aria2 的 RPC 认证。
   - 与 GitHub token 使用了相同的安全策略，密钥会存储在 Termux 本地。

## 安装与使用
1. 打开 Termux，在根目录运行以下命令：
   ```bash
   curl -O https://raw.githubusercontent.com/giturass/openlist_termux/refs/heads/main/oplist.sh && chmod +x oplist.sh && ./oplist.sh
   ```

2. 根据交互提示操作：
   - 按提示输入 **GitHub token**（首次安装更新输入后本地保存）。
   - 按提示输入 **aria2 RPC 密钥**（首次启动aria2交互输入同样本地安全保存）。

3. 脚本将自动：
   - 安装或更新 OpenList。
   - 配置并安装 aria2 以支持下载。
   - 安全存储凭据以便后续使用。
   - 设置 `oplist` 快捷命令（首次安装后自动配置）。

## 快捷使用
- 首次安装完成后，您可以在任何时候通过输入以下命令快速打开管理菜单：
  ```bash
  oplist
  ```
- 无需记住复杂的路径和参数，一个命令即可管理所有功能。

## 注意事项
- 安装或更新时请确保网络连接稳定。
- 脚本在 Termux 本地安全存储敏感数据，无需担心安全问题。
- 如有问题或想贡献代码，请访问 [GitHub 仓库](https://github.com/giturass/openlist_termux)。
