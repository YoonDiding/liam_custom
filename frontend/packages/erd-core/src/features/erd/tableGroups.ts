/* eslint-disable no-non-english/no-non-english-characters --
 * QESG fork intentionally displays Korean group names and descriptions. */
/**
 * QESG custom - domain groups.
 *
 * Tables are assigned to a group via a `[DOMAIN:name]`-style tag in the table
 * comment (the schema stays the single source). This file only defines display
 * metadata (description, color); unknown group names fall back to a hashed
 * color, so new domains render without code changes.
 */

export const TABLE_GROUP_NODE_TYPE = 'tableGroup'

export const DOMAIN_TAG_PATTERN = /\[영역:([^\]]+)\]/

export const tableGroupNodeId = (name: string): string =>
  `table-group-${name}`

type TableGroupMeta = {
  description: string
  color: string
}

const META: Record<string, TableGroupMeta> = {
  '파이프라인': {
    color: '#C08A2E',
    description:
      '값이 지나가는 길 — 크롤 원문(L0)이 파싱을 거쳐 값 정본(indicator_data)과 근거(evidence)로 흘러간다. 매일 돈다.',
  },
  '사전': {
    color: '#2E8B8B',
    description:
      '값의 의미 정의 — 지표·항목·출처·회사. 느리게 바뀌고 모든 층이 이것을 참조한다.',
  },
  '규칙·기록': {
    color: '#C25E82',
    description:
      '판단의 재료와 흔적 — 산출 규칙(rule_param)·파생·대표 선택, 그리고 변경 이력·품질 플래그.',
  },
  '서빙': {
    color: '#5FA05A',
    description:
      '표현 층 — 의미축 6원소를 전부 펴는 v_fact, 출처를 접은 대표값 v_fact_canonical.',
  },
}

const FALLBACK_COLORS = ['#6B7FD7', '#8A7DBE', '#4E9BAA', '#B0743C']

export type TableGroupNodeData = {
  label: string
  description: string
  color: string
}

export const tableGroupData = (name: string): TableGroupNodeData => {
  const meta = META[name]
  if (meta) {
    return { label: name, description: meta.description, color: meta.color }
  }
  let hash = 0
  for (const ch of name) {
    hash = (hash * 31 + ch.charCodeAt(0)) | 0
  }
  const fallback =
    FALLBACK_COLORS[Math.abs(hash) % FALLBACK_COLORS.length] ?? '#6B7FD7'
  return { label: name, description: '', color: fallback }
}
