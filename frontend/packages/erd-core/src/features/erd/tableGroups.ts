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
      '공시·웹에서 수집한 원문이 파싱을 거쳐 확정된 값과 근거로 쌓이는 길.',
  },
  '사전': {
    color: '#2E8B8B',
    description:
      '데이터 값의 뜻을 정해두는 영역 — 지표·항목·출처·회사.',
  },
  '규칙 및 히스토리': {
    color: '#C25E82',
    description:
      '판단의 근거 — 산출 규칙·파생·대표값, 그리고 변경 이력·품질 flag.',
  },
  '서빙': {
    color: '#5FA05A',
    description:
      '사용자에게 보여지는 층 — 모든 데이터를 하나의 표로 펼치고, 규칙 영역에서 정한 대푯값을 제공.',
  },
  '출처 원본': {
    color: '#8A7DBE',
    description:
      '출처 사이트에서 긁어온 그대로를 보관하는 테이블들 — 출처가 늘면 여기에 테이블이 하나씩 늘어난다.',
  },
  '포털 운영': {
    color: '#4E9BAA',
    description:
      '데이터가 아니라 서비스를 움직이는 테이블들 — 계정·로그인·AI 사용량과 비용.',
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
