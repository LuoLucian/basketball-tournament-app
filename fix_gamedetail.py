import re

with open('src/views/game/GameDetailView.vue', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add canEdit computed after gameTypeOptions
idx = content.find('const gameTypeOptions')
if idx >= 0:
    # find end of gameTypeOptions block
    end_idx = content.find('\n\n', idx)
    if end_idx < 0:
        end_idx = content.find('\nonMounted', idx)
    if end_idx > 0:
        insert = ('\n'
                   '// 管理员编辑权限\n'
                   'const canEdit = computed(() => auth.isSuperAdmin && game.value?.status === \'finished\')\n')
        content = content[:end_idx] + insert + content[end_idx:]
        print('Added canEdit computed')
    else:
        print('Could not find insertion point for canEdit')
else:
    print('gameTypeOptions not found')

# 2. Update saveEdits to call admin_set_game_stat RPC
save_idx = content.find('async function saveEdits()')
if save_idx >= 0:
    end_save = content.find('\nasync ', save_idx + 10)
    if end_save < 0:
        end_save = content.find('\n</script>', save_idx)
    if end_save > 0:
        new_save = ("async function saveEdits() {\n"
                      "  saving.value = true\n"
                      "  try {\n"
                      "    for (const s of editStats.value) {\n"
                      "      const orig = editOriginals.value[s.player_id]\n"
                      "      const changes = {}\n"
                      "      for (const f of statFieldsForEdit) {\n"
                      "        if (s[f] !== orig[f]) {\n"
                      "          changes[f] = s[f]\n"
                      "        }\n"
                      "      }\n"
                      "      if (Object.keys(changes).length) {\n"
                      "        const { error } = await supabase.rpc('admin_set_game_stat', {\n"
                      "          p_game_id: game.value.id,\n"
                      "          p_player_id: s.player_id,\n"
                      "          p_team_id: s.team_id,\n"
                      "          p_changes: changes\n"
                      "        })\n"
                      "        if (error) throw error\n"
                      "      }\n"
                      "    }\n"
                      "    showToast('✅ 数据已更新')\n"
                      "    editMode.value = false\n"
                      "    location.reload()\n"
                      "  } catch (e) {\n"
                      "    showToast('❌ 保存失败：' + (e.message || '未知错误'))\n"
                      "  } finally {\n"
                      "    saving.value = false\n"
                      "  }\n"
                      "}\n")
        content = content[:save_idx] + new_save + content[end_save:]
        print('Updated saveEdits with admin_set_game_stat RPC')
    else:
        print('Could not find end of saveEdits')
else:
    print('saveEdits function not found')

# 3. Add '编辑数据' button to template
if '编辑数据' not in content:
    # Find the 进入录入 button area
    record_idx = content.find('进入录入')
    if record_idx >= 0:
        end_link = content.find('</router-link>', record_idx)
        if end_link > 0:
            insert_pos = end_link + len('</router-link>')
            btn = ('\n        <!-- 编辑数据 -->\n'
                    '        <button v-if="canEdit" @click="enterEditMode"\n'
                    '          class="btn-primary btn-sm flex items-center gap-1.5">\n'
                    '          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">\n'
                    '            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.586a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>\n'
                    '          </svg>\n'
                    '          编辑数据\n'
                    '        </button>\n')
            content = content[:insert_pos] + btn + content[insert_pos:]
            print('Added 编辑数据 button')
        else:
            print('Could not find end of 进入录入 link')
    else:
        print('进入录入 button not found')
else:
    print('编辑数据 button already present')

# 4. When editMode is true, show Save/Cancel buttons in the card header
if 'saveEdits' in content and 'editMode' in content:
    # Find the stats table card header area, add save/cancel when editMode
    header_idx = content.find('<!-- 统计汇总 -->')
    if header_idx > 0:
        # Insert save/cancel bar before stats table
        insert_edit_bar = ('\n    <!-- 编辑操作栏 -->\n'
                           '    <div v-if="editMode" class="flex items-center gap-3 px-4 py-2 border-b border-dark-700/50">\n'
                           '      <button @click="saveEdits" :disabled="saving"\n'
                           '        class="px-4 py-1.5 rounded-lg text-sm font-bold bg-primary-600 text-white\n'
                           '               hover:bg-primary-700 disabled:opacity-50 transition-all">\n'
                           '        {{ saving ? \'保存中...\' : \'保存\' }}\n'
                           '      </button>\n'
                           '      <button @click="cancelEdit"\n'
                           '        class="px-4 py-1.5 rounded-lg text-sm font-medium border border-dark-700\n'
                           '               text-dark-300 hover:text-white hover:border-dark-500 transition-all">\n'
                           '        取消\n'
                           '      </button>\n'
                           '    </div>\n')
        content = content[:header_idx] + insert_edit_bar + content[header_idx:]
        print('Added edit mode save/cancel bar')
    else:
        print('Stats table header not found for edit bar')

# Write back
with open('src/views/game/GameDetailView.vue', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done! GameDetailView.vue updated.')
