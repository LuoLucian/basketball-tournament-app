# 超管数据管理功能 - SQL 执行说明

## 功能说明
已开发完成两个超管功能：
1. **编辑比赛数据** - 在赛事详情页，超管可以编辑任意球员的比赛数据
2. **重置球员数据** - 在球员详情页，超管可以重置该球员的所有历史比赛数据

## 需要执行的 SQL 文件

请在 Supabase Dashboard 的 SQL Editor 中按顺序执行以下两个文件：

### 1. admin_set_game_stat.sql
**路径**: `F:\项目\basketball-app\supabase\admin_set_game_stat.sql`

**功能**: 允许超管精确设置比赛中某球员的任意单项数据（pts/reb/ast/stl/blk/tov/pf/fgm/fga/fg3m/fg3a/ftm/fta/min_played）

**特性**:
- 自动同步更新比分（若修改 pts）
- 自动维护 fgm/fga、fg3m/fg3a、ftm/fta 的一致性
- 写入审计日志（action_logs）

### 2. admin_reset_player_stats.sql
**路径**: `F:\项目\basketball-app\supabase\admin_reset_player_stats.sql`

**功能**: 重置指定球员的所有比赛数据

**特性**:
- 删除该球员的全部 game_stats 记录
- 删除相关的 action_logs 记录
- 自动重新计算受影响比赛的比分
- 仅超管可调用

## 执行步骤
1. 登录 Supabase Dashboard: https://supabase.com/dashboard/project/zzuwpanihewhqtyywhny
2. 进入 **SQL Editor**
3. 打开 `admin_set_game_stat.sql` 文件，复制全部内容，粘贴到 SQL Editor，点击 **RUN**
4. 打开 `admin_reset_player_stats.sql` 文件，复制全部内容，粘贴到 SQL Editor，点击 **RUN**
5. 确认两个函数都创建成功（无报错）

## 验证
执行成功后，可以以超管身份登录应用：
- 进入任意赛事详情页，应该能看到 **"编辑数据"** 按钮
- 点击后进入编辑模式，可以修改各项数据
- 进入球员详情页，应该能看到 **"重置数据"** 按钮
- 点击后会弹出确认框，确认后重置该球员所有数据

## 注意事项
- 所有操作都会写入审计日志（action_logs 表）
- 重置操作不可恢复，请谨慎使用
- 修改 pts 时会自动更新比赛比分
- 修改 fgm/fga 等投篮数据时，系统会自动维护一致性（例如 fgm 不能大于 fga）
