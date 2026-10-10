<template>
  <div class="page-container max-w-3xl mx-auto">
    <!-- 头部 -->
    <div class="flex items-center gap-3 mb-5">
      <router-link to="/tournaments" class="text-dark-500 hover:text-white transition-colors p-1 flex-shrink-0">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
      </router-link>
      <div class="min-w-0 flex-1">
        <h1 class="text-xl font-bold text-white">📜 德泰园区篮球赛规程</h1>
        <p class="text-xs text-dark-500 mt-0.5">了解参赛说明、比赛办法与规则</p>
      </div>
      <template v-if="auth.isSuperAdmin">
        <button v-if="!editing" @click="startEdit" class="btn-primary btn-sm">✏️ 编辑规程</button>
        <template v-else>
          <button @click="saveRegulation" class="btn-primary btn-sm" :disabled="saving">
            {{ saving ? '保存中…' : '💾 保存' }}
          </button>
          <button @click="cancelEdit" class="btn-secondary btn-sm" :disabled="saving">取消</button>
        </template>
      </template>
    </div>

    <!-- 本届未定提示 -->
    <div class="card card-body mb-5 border-accent-500/30 bg-gradient-to-r from-accent-950/40 to-dark-900">
      <p class="text-sm text-white leading-relaxed">
        <span class="font-bold">📣 本届（第六届）具体比赛时间与赛制尚未确定</span>，确定后将在本页面及锦标赛公告栏公布。
      </p>
      <p class="text-xs text-dark-400 mt-2 leading-relaxed">
        以下内容为第四届赛事规程，供各参赛队了解比赛组织方式与规则参考。报名、抽签、赛程等信息请以公告栏最新通知为准。
      </p>
    </div>

    <div v-if="!editing" class="card card-body space-y-6 text-sm leading-relaxed text-dark-200">
      <p class="text-center font-bold text-white text-base">{{ reg.title }}</p>
      <p class="text-dark-400">{{ reg.intro }}</p>

      <section v-for="(sec, i) in reg.sections" :key="i">
        <h2 class="reg-h">{{ sec.heading }}</h2>
        <template v-if="sec.paras?.length">
          <p v-for="(p, j) in sec.paras" :key="j" :class="j > 0 ? 'mt-2' : ''">{{ p }}</p>
        </template>
        <template v-if="sec.list?.length">
          <ol class="reg-list">
            <li v-for="(item, j) in sec.list" :key="j">{{ item }}</li>
          </ol>
        </template>
        <template v-if="sec.table?.length">
          <div class="reg-table">
            <div v-for="(row, j) in sec.table" :key="j" class="reg-row">
              <span>{{ row[0] }}</span><span>{{ row[1] }}</span>
            </div>
          </div>
        </template>
      </section>
    </div>

    <!-- ── 超管编辑模式 ── -->
    <div v-else class="card card-body space-y-5 text-sm">
      <div>
        <label class="edit-label">标题</label>
        <input v-model="editForm.title" class="edit-input" />
      </div>
      <div>
        <label class="edit-label">导语</label>
        <textarea v-model="editForm.intro" rows="2" class="edit-input"></textarea>
      </div>
      <div v-for="(sec, i) in editForm.sections" :key="i" class="border border-dark-700 rounded-xl p-3 space-y-2">
        <div class="flex items-center gap-2">
          <input v-model="sec.heading" class="edit-input font-bold" placeholder="章节标题" />
          <button @click="removeSection(i)" class="text-danger hover:text-danger-light text-xs px-1" title="删除章节">✕</button>
        </div>
        <template v-if="sec.paras">
          <label class="edit-label">段落（每行一段）</label>
          <textarea v-model="sec.parasText" rows="3" class="edit-input"></textarea>
        </template>
        <template v-if="sec.list">
          <label class="edit-label">条目（每行一条）</label>
          <textarea v-model="sec.listText" rows="6" class="edit-input"></textarea>
        </template>
        <template v-if="sec.table">
          <label class="edit-label">表格（每行两列，用 | 分隔，如：冠军|奖杯、奖品）</label>
          <div v-for="(row, j) in sec.table" :key="j" class="flex gap-2">
            <input v-model="row[0]" class="edit-input flex-1" />
            <input v-model="row[1]" class="edit-input flex-1" />
            <button @click="sec.table.splice(j, 1)" class="text-danger hover:text-danger-light text-xs px-1">✕</button>
          </div>
          <button @click="sec.table.push(['', ''])" class="btn-secondary btn-sm">+ 添加行</button>
        </template>
      </div>
      <button @click="addSection" class="btn-secondary btn-sm self-start">+ 添加章节</button>

      <div class="flex justify-end gap-2 pt-2 border-t border-dark-800">
        <button @click="cancelEdit" class="btn-secondary btn-sm" :disabled="saving">取消</button>
        <button @click="saveRegulation" class="btn-primary btn-sm" :disabled="saving">
          {{ saving ? '保存中…' : '💾 保存修改' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/utils/supabase'

const auth = useAuthStore()
const reg = ref({ title: '', intro: '', sections: [] })
const editing = ref(false)
const saving = ref(false)
const editForm = ref(null)

// 默认内容（第四届规程，本届为第六届、时间赛制待定）
const DEFAULT_REG = {
  title: '园区男子篮球赛规程',
  intro: '为了营造一个积极、健康、热烈、活泼、和谐的园区环境，丰富园区职员的业余文化生活，德泰科技园将策划组织园区篮球赛。',
  sections: [
    {
      heading: '一、活动目的',
      paras: ['为园区打造一个互相交流、互相学习的平台，树立在职人员内练素质、外树形象的风貌，展现大家的运动风采。']
    },
    {
      heading: '二、活动宗旨',
      paras: ['增进各企业之间的感情。']
    },
    {
      heading: '三、活动举办单位',
      paras: ['德泰科技（深圳）有限公司']
    },
    {
      heading: '四、比赛时间及地点',
      paras: ['以下为第四届时间安排，本届时间待定，确定后另行公布：'],
      table: [
        ['第一阶段（小组赛）', '10月22日 – 10月24日'],
        ['第二阶段（半决赛）', '10月28日 – 11月1日'],
        ['决赛', '11月5日']
      ],
      paras2: ['比赛地点：德泰科技园篮球场']
    },
    {
      heading: '五、参赛说明',
      list: [
        '每队可报领队1人，教练员1人，运动员12人。如报名运动员大于12人，每场比赛上场队员均不能大于12人。',
        '参赛单位：德泰科技园区企业（企业单独组团，原则上不足10人队伍的企业可根据实际与园区内其他企业组团）。',
        '参赛资格：德泰科技园区企业员工，以社保核验为准。运动员以赛前各队报来的名单为准，中途不能更换、增补运动员，不能弄虚作假、冒名顶替，一经查实，取消该队参赛资格与成绩。',
        '凡属身体健康、适合参加篮球运动者均可报名参赛。有心脑血管系统、呼吸系统等疾病以及近期不宜参加体育活动者，不能参赛。参加比赛的行为视为本队（本人）已对参赛存在风险和意外做了审慎的评估，并愿意自行承担由此产生的一切后果。'
      ]
    },
    {
      heading: '六、比赛办法',
      list: [
        '比赛分阶段进行：第一阶段为小组赛，通过抽签分组分别进行单循环比赛；第二阶段为半决赛；最后进行决赛，决出1至3名的名次。（本届分组数、出线名额与淘汰赛形式待定，以抽签前公布为准）',
        '决定名次办法：每胜一场得2分，负一场得1分，比赛因弃权告负得0分（对方以20:0获胜），以积分多少确定名次，积分多者名次列前。',
        '如两队或多于两队之间的比赛有相同的胜负记录，将按照下列原则依顺序排列名次：① 按它们之间比赛的净胜分，高者列前；② 按它们之间比赛的（总）得分数，高者列前；③ 按它们在该小组中所有比赛的净胜分，高者列前；④ 按它们在该小组中所有比赛的（总）得分数，高者列前；⑤ 如仍无法决定名次，将用抽签的办法进行名次排列。',
        '各参赛队应按照主办方制定的比赛时间提前20分钟到达比赛场地签到。无正当理由而未准时到场比赛的参赛队，迟到15分钟应判为弃权。',
        '比赛服装：每队必须准备比赛服，号码按规则规定印制，上场队员服装颜色必须统一，号码醒目。比赛服装由各队伍自行负责。',
        '凡对某场比赛有异议或对他队运动员资格有争议，请务必在该场比赛结束后1小时内以书面形式向举办方提出申诉，否则不予受理。',
        '如在比赛过程中出现打架、弃权、消极比赛、罢赛等违反赛风纪律的现象，将取消参赛资格，处罚视具体情况由主办方制定。'
      ]
    },
    {
      heading: '七、比赛规则',
      list: [
        '4×12分钟的比赛模式，半场的休息时间为5分钟。上半场2次暂停，下半场3次暂停。如有加时赛，只有一次暂停机会，加时赛时长为五分钟。',
        '计时：小组赛中间罚球、换人、场外不停表。在离比赛结束还有2分钟时暂停时间停表，其他均不停表（裁判要求停表的情况除外）。淘汰赛、半决赛和决赛采取净时停表。',
        '球权：本次比赛仅第一节跳球，比赛过程中采取球权轮替制。',
        '加时赛：正常时间比赛结束后若仍未分胜负，进入一次或多次的五分钟延长赛，接续第四节进攻的篮框，中间有两分钟休息时间。如5分钟延长赛中仍然平分，休息2分钟后开始比赛，以哪一方先获胜为获胜方。',
        '暂停及换人：如果要登记的暂停时间未到，而请求暂停的队已做好了比赛的准备，主裁判员要尽快重新开始比赛；只有球成为死球后才能申请暂停和换人，记录员要立即通知裁判员某队的暂停及换人请求。',
        '犯规：球员犯规满5次必须离场，该队换上一名替补球员上场。如果没有替补球员或替补球员不在比赛现场，视为该队对本场比赛弃权。',
        '比赛中不得有非正规动作出现，比赛遵循友谊第一、比赛第二的原则。',
        '运动员必须在比赛开始前15分钟签到。如有一方队伍在比赛时间到后迟到15分钟无法上场，将以弃权论处。',
        '在比赛中严格遵守比赛规程，尊重裁判，服从裁判判决，尊重对手。'
      ]
    },
    {
      heading: '八、奖项设置',
      table: [
        ['🏆 冠军', '奖杯、奖品'],
        ['🥈 亚军', '奖杯、奖品'],
        ['🥉 季军', '奖杯、奖品']
      ]
    },
    {
      heading: '九、免责声明及其他',
      list: [
        '本次比赛活动为德泰科技园主办的非营利性健身活动，遵循平等、民主、自助、互助的原则。参加者必须对自己的安全负责。活动中发生意外，发起者和同行者有义务组织救援，但不承担任何法律和经济责任，特此声明。为进一步强化队员的自我保护意识，参加活动后本声明自动生效并表明你接受本声明，否则请在活动开始前退出。该免责声明目的是为活动发起人、组织者和同行者再次明确活动的风险，提高自律能力和抗风险能力，免除一些不必要的后果，让活动更安全更快乐。',
        '本规程未尽事宜另行通知。',
        '本竞赛规程解释权属举办方所有。'
      ]
    }
  ]
}

// 序列化 / 反序列化辅助
function flattenSection(sec) {
  const out = { ...sec }
  if (sec.paras) out.parasText = sec.paras.join('\n')
  if (sec.list) out.listText = sec.list.join('\n')
  if (sec.paras2) out.paras2Text = sec.paras2.join('\n')
  return out
}

async function load() {
  const { data, error } = await supabase.from('site_regulation').select('content').eq('id', 1).maybeSingle()
  if (error) {
    console.warn('[Regulation] 读取失败，使用默认内容:', error.message)
    reg.value = JSON.parse(JSON.stringify(DEFAULT_REG))
    return
  }
  reg.value = data?.content || JSON.parse(JSON.stringify(DEFAULT_REG))
}

function startEdit() {
  editForm.value = {
    title: reg.value.title,
    intro: reg.value.intro,
    sections: reg.value.sections.map(s => {
      const flat = flattenSection(s)
      // 段落分隔的表格后续说明行（比赛地点）合并进 paras
      if (s.paras2?.length) flat.parasText += (flat.parasText ? '\n' : '') + s.paras2.join('\n')
      return flat
    })
  }
  editing.value = true
}

function cancelEdit() {
  editing.value = false
  editForm.value = null
}

function addSection() {
  editForm.value.sections.push({ heading: '新章节', paras: [''], parasText: '' })
}

function removeSection(i) {
  editForm.value.sections.splice(i, 1)
}

function unflattenSection(sec) {
  const out = { heading: sec.heading }
  if ('paras' in sec) {
    out.paras = (sec.parasText || '').split('\n').map(x => x.trim()).filter(Boolean)
  }
  if ('list' in sec) {
    out.list = (sec.listText || '').split('\n').map(x => x.trim()).filter(Boolean)
  }
  if ('table' in sec) {
    out.table = sec.table.map(row => [row[0] || '', row[1] || '']).filter(row => row[0] || row[1])
  }
  return out
}

async function saveRegulation() {
  saving.value = true
  try {
    const content = {
      title: editForm.value.title.trim() || '园区男子篮球赛规程',
      intro: editForm.value.intro.trim(),
      sections: editForm.value.sections.map(unflattenSection).filter(s => s.heading.trim())
    }
    const { error } = await supabase.rpc('save_regulation', {
      p_content: content,
      p_user_id: auth.user?.id || null
    })
    if (error) throw error
    reg.value = content
    editing.value = false
    editForm.value = null
  } catch (e) {
    alert('保存失败：' + (e.message || '未知错误'))
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.reg-h {
  font-weight: 700;
  color: #fff;
  font-size: 0.95rem;
  margin-bottom: 0.5rem;
  padding-left: 0.5rem;
  border-left: 3px solid var(--color-accent-500, #f59e0b);
}
.reg-list {
  list-style: none;
  counter-reset: reg-item;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.reg-list > li {
  counter-increment: reg-item;
  padding-left: 1.4rem;
  position: relative;
  color: #cbd5e1;
}
.reg-list > li::before {
  content: counter(reg-item);
  position: absolute;
  left: 0;
  top: 0.1rem;
  width: 1.05rem;
  height: 1.05rem;
  border-radius: 9999px;
  background: rgba(245, 158, 11, 0.12);
  color: #fbbf24;
  font-size: 0.65rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}
.reg-table {
  border: 1px solid rgba(55, 65, 81, 0.8);
  border-radius: 0.75rem;
  overflow: hidden;
  font-size: 0.85rem;
}
.reg-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.55rem 0.9rem;
}
.reg-row + .reg-row {
  border-top: 1px solid rgba(55, 65, 81, 0.6);
}
.reg-row span:first-child {
  color: #94a3b8;
}
.reg-row span:last-child {
  color: #fff;
  font-weight: 500;
}
.edit-label {
  display: block;
  font-size: 0.65rem;
  color: #64748b;
  margin-bottom: 0.25rem;
}
.edit-input {
  width: 100%;
  background: #1e293b;
  border: 1px solid #334155;
  border-radius: 0.5rem;
  padding: 0.4rem 0.6rem;
  font-size: 0.8rem;
  color: #fff;
  outline: none;
}
.edit-input:focus {
  border-color: #3b82f6;
}
</style>
