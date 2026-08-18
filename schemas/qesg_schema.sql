CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS serving;

CREATE TABLE core.indicator_sub (id integer PRIMARY KEY);
COMMENT ON TABLE core.indicator_sub IS 'DEPRECATED — indicator_component로 대체, 이관 기간만 보존';

CREATE TABLE raw.etl_job (
  "id" varchar(36) PRIMARY KEY,
  "job_type" varchar(20) NOT NULL,
  "status" varchar(20) NOT NULL,
  "params" jsonb NOT NULL,
  "total_count" integer NOT NULL,
  "processed_count" integer NOT NULL,
  "success_count" integer NOT NULL,
  "inserted_count" integer NOT NULL,
  "updated_count" integer NOT NULL,
  "skipped_count" integer NOT NULL,
  "error_count" integer NOT NULL,
  "result" jsonb,
  "error_message" text,
  "created_by" varchar(100),
  "created_at" timestamptz NOT NULL,
  "started_at" timestamptz,
  "completed_at" timestamptz,
  "updated_at" timestamptz NOT NULL
);
COMMENT ON TABLE raw.etl_job IS '[신규] L0 · 실행 이력 (MySQL 802행)';
COMMENT ON COLUMN raw.etl_job."id" IS 'UUID v4';
COMMENT ON COLUMN raw.etl_job."job_type" IS 'enum: download|crawl|map|commit|import|sync|csv|verify';
COMMENT ON COLUMN raw.etl_job."status" IS 'enum: pending|running|completed|failed|cancelled';

CREATE TABLE raw.etl_job_log (
  "id" bigint PRIMARY KEY,
  "job_id" varchar(36) NOT NULL,
  "level" varchar(10) NOT NULL,
  "message" text NOT NULL,
  "indicator_code" varchar(20),
  "corp_name" varchar(200),
  "sub_code" varchar(100),
  "fiscal_year" varchar(4),
  "detail" text,
  "created_at" timestamptz NOT NULL
);
COMMENT ON TABLE raw.etl_job_log IS '[신규] L0 · 로그 라인 (실행 이력 아님, MySQL 198,184행)';
COMMENT ON COLUMN raw.etl_job_log."job_id" IS '논리 관계 (FK 미선언)';

CREATE TABLE raw.etl_crawl_raw (
  "id" bigint PRIMARY KEY,
  "crawl_job_id" varchar(36),
  "source_type" varchar(30) NOT NULL,
  "rcept_no" varchar(20),
  "corp_code" varchar(20),
  "stock_code" varchar(10),
  "bizr_no" varchar(20),
  "corp_name" varchar(200),
  "company_raw" varchar(200) NOT NULL,
  "enriched_from" varchar(20),
  "indicator_code" varchar(20) NOT NULL,
  "raw_label" varchar(200),
  "fiscal_year" varchar(4) NOT NULL,
  "raw_data" jsonb NOT NULL,
  "parsed_value" text,
  "parsed_unit" varchar(50),
  "confidence" numeric(3,2),
  "status" varchar(20) NOT NULL,
  "error_message" text,
  "committed_data_id" bigint,
  "committed_at" timestamptz,
  "crawled_at" timestamptz NOT NULL,
  "mapped_at" timestamptz,
  "verified" boolean,
  "verify_reason" text,
  "created_at" timestamptz NOT NULL,
  "updated_at" timestamptz NOT NULL,
  "dedup_key" text
);
COMMENT ON TABLE raw.etl_crawl_raw IS '[신규] L0 · 크롤 원본 + 스테이징 파이프라인 (MySQL 682,276행). 단순 원본 저장이 아니라 파이프라인 테이블';
COMMENT ON COLUMN raw.etl_crawl_raw."source_type" IS 'L0는 잘게 유지(DART_BR≠DART_CG). 17종';
COMMENT ON COLUMN raw.etl_crawl_raw."rcept_no" IS 'evidence.doc_ref 소스 (33.9% 보유)';
COMMENT ON COLUMN raw.etl_crawl_raw."corp_code" IS '보강값 보존, dedup_key 제외';
COMMENT ON COLUMN raw.etl_crawl_raw."company_raw" IS '축 18-b: 명부 보강 전 원문 회사값 — dedup_key는 이것만 사용';
COMMENT ON COLUMN raw.etl_crawl_raw."enriched_from" IS '보강 근거 (진단용)';
COMMENT ON COLUMN raw.etl_crawl_raw."raw_label" IS '구 parent_sub_code+sub_code 통합. 원문 라벨 그대로 — component 매핑은 L1의 일';
COMMENT ON COLUMN raw.etl_crawl_raw."status" IS 'enum: pending|mapped|committed|error|review|stale|source · ''source''=분리 시 보존된 원본(260813 mapper L0 보존) — Committer/Verifier 대상 제외, pending 리셋으로 재파싱';
COMMENT ON COLUMN raw.etl_crawl_raw."committed_data_id" IS '값↔원문 링크 (96.0% 보유). FK는 Phase C';
COMMENT ON COLUMN raw.etl_crawl_raw."verified" IS '축 10 재료. 현재 75% 미검증';
COMMENT ON COLUMN raw.etl_crawl_raw."dedup_key" IS 'GENERATED: company_raw || ''|'' || indicator_code || ''|'' || regexp_replace(coalesce(raw_label · 신 5원소 (구 9원소에서 회사 4칸→company_raw 1칸). concat_ws는 STABLE이라 || 동치 구현. UNIQUE는 Phase C — 지금 걸면 기존 31,807행 충돌';

CREATE TABLE raw.etl_review_queue (
  "id" bigint PRIMARY KEY,
  "crawl_raw_id" bigint NOT NULL,
  "review_reason" varchar(100) NOT NULL,
  "review_priority" smallint,
  "review_status" varchar(20) NOT NULL,
  "reviewed_by" varchar(100),
  "reviewed_at" timestamptz,
  "review_note" text,
  "modified_value" text,
  "modified_unit" varchar(50),
  "created_at" timestamptz NOT NULL,
  "updated_at" timestamptz NOT NULL
);
COMMENT ON TABLE raw.etl_review_queue IS '[신규] L0 · 검토 대기열 (2,784행 전부 pending — 미사용). 흡수/폐기 미결';
COMMENT ON COLUMN raw.etl_review_queue."review_status" IS 'enum: pending|approved|rejected|modified';

CREATE TABLE raw.etl_indicator_mapping (
  "id" bigint PRIMARY KEY,
  "source_type" varchar(30) NOT NULL,
  "source_table_name" varchar(200),
  "source_keyword" varchar(500),
  "indicator_code" varchar(20) NOT NULL,
  "parent_sub_code" varchar(50),
  "sub_code" varchar(50),
  "value_transform" varchar(100),
  "unit_mapping" varchar(100),
  "default_confidence" numeric(3,2),
  "is_active" char(1),
  "note" varchar(500),
  "created_by" varchar(100),
  "created_at" timestamptz NOT NULL,
  "updated_at" timestamptz NOT NULL
);
COMMENT ON TABLE raw.etl_indicator_mapping IS '[신규] L0 · 지표 매핑 규칙 (7행, 규칙 컬럼 전부 NULL — rule_param 원형). 흡수 여부 미결';
COMMENT ON COLUMN raw.etl_indicator_mapping."value_transform" IS '실사용 0건';
COMMENT ON COLUMN raw.etl_indicator_mapping."unit_mapping" IS '실사용 0건';

CREATE TABLE core.indicator_master (
  "id" integer PRIMARY KEY,
  "indicator_code" varchar(20) UNIQUE,
  "indicator_name" varchar(200),
  "category" varchar(1),
  "sort_order" integer,
  "measure_type" varchar(20),
  "value_type" varchar(20),
  "unit" varchar(50),
  "collection_period" varchar(10),
  "source_status" varchar(20),
  "note" varchar(500),
  "extraction_rules" jsonb,
  "validation_rules" jsonb,
  "classification_rules" jsonb,
  "extraction_script" text,
  "script_updated_at" timestamptz,
  "is_active" boolean,
  "display_format" varchar(20),
  "export_note" text,
  "alias" text[],
  "is_representative" boolean,
  "portal_group_code" varchar(10),
  "portal_group_name" varchar(50),
  "portal_visible" boolean,
  "gri_standard" varchar(30),
  "description" text,
  "search_aliases" text,
  "portal_alias" varchar(200),
  "portal_display" text NOT NULL,
  "fy_definition" varchar(30),
  "fy_note" text
);
COMMENT ON TABLE core.indicator_master IS '[확장] L1 · 지표 정의 (기존 + fy_definition 축 9)';
COMMENT ON COLUMN core.indicator_master."classification_rules" IS '[DEPRECATED] 0행. core.rule_param으로 대체 (축 15)';
COMMENT ON COLUMN core.indicator_master."extraction_script" IS '[DEPRECATED] 0행. 코드를 문자열로 넣으려던 시도';
COMMENT ON COLUMN core.indicator_master."portal_display" IS 'enum: collapsed|expanded';
COMMENT ON COLUMN core.indicator_master."fy_definition" IS '[신설] · enum: fiscal_year|publish_year_minus_1|incident_year|report_base_year · 축 9. S43=publish_year_minus_1, S18_1=incident_year';
COMMENT ON COLUMN core.indicator_master."fy_note" IS '[신설]';

CREATE TABLE core.indicator_component (
  "id" integer PRIMARY KEY,
  "indicator_code" varchar(20) NOT NULL,
  "component_code" varchar(60) NOT NULL,
  "component_name" varchar(200) NOT NULL,
  "unit" varchar(40),
  "role" varchar(20) NOT NULL,
  "parent_code" varchar(60),
  "sort_order" integer,
  "valid_from" date NOT NULL,
  "valid_to" date,
  "supersedes_id" integer,
  "composition_changed" jsonb,
  "is_active" boolean NOT NULL,
  "created_at" timestamptz,
  UNIQUE ("indicator_code", "component_code", "valid_from")
);
COMMENT ON TABLE core.indicator_component IS '[신규] L1 · 항목의 정체(출처 무관). 구 indicator_sub 494행 → 약 446개. SCD Type 2 (축 16)';
COMMENT ON COLUMN core.indicator_component."role" IS 'enum: aggregate|component|derived|asreported|flag|attribute · attribute=측정값 아닌 레코드 필드(date·cause 등)';
COMMENT ON COLUMN core.indicator_component."parent_code" IS '어느 합계에 속하나 (E7 airtotal←nox·sox·pm). NULL 통일, '''' 금지';
COMMENT ON COLUMN core.indicator_component."valid_from" IS '축 16. 개념이 유효한 시점 (수집 시점 아님)';
COMMENT ON COLUMN core.indicator_component."valid_to" IS 'NULL=현행';
COMMENT ON COLUMN core.indicator_component."supersedes_id" IS '정의 변경 계보 (self-FK)';
COMMENT ON COLUMN core.indicator_component."composition_changed" IS '{"2025":"+e"} aggregate 구성 변경';

CREATE TABLE core.indicator_source_map (
  "id" integer PRIMARY KEY,
  "component_id" integer NOT NULL,
  "source_code" varchar(40) NOT NULL,
  "source_label" varchar(200),
  "source_unit" varchar(40),
  "is_available" boolean NOT NULL,
  "note" text,
  UNIQUE ("component_id", "source_code")
);
COMMENT ON TABLE core.indicator_source_map IS '[신규] L2 · 어느 출처가 이 항목을 어떻게 부르나. 구 indicator_sub의 ''출처'' 부분 (축 1)';
COMMENT ON COLUMN core.indicator_source_map."source_label" IS '그 출처에서의 이름 (라벨오류 흡수)';
COMMENT ON COLUMN core.indicator_source_map."source_unit" IS '축 5 정규화 입력';

CREATE TABLE core.company_master (
  "id" integer PRIMARY KEY,
  "qesg_code" varchar(20),
  "priority" integer,
  "corp_code" varchar(8),
  "stock_code" varchar(20),
  "bizr_no" varchar(20),
  "corp_name" varchar(200),
  "corp_name_eng" varchar(200),
  "stock_name" varchar(100),
  "company_name_prev" varchar(200),
  "corp_cls" varchar(1),
  "company_size" varchar(30),
  "listed" varchar(1),
  "merged" boolean,
  "name_changed" boolean,
  "is_active" boolean,
  "version" integer,
  "last_updated" varchar(10),
  "sector_code" varchar(30),
  "sector_name" varchar(60),
  "sector_div" varchar(1),
  "sector_div_name" varchar(100),
  "sector_source" varchar(10),
  "sector_mid_name" varchar(200),
  "sector_small_name" varchar(200),
  "portal_visible" boolean,
  "has_consolidation" boolean
);
COMMENT ON TABLE core.company_master IS '[확장] L2 · 회사 명부 (기존 + has_consolidation 축 2)';
COMMENT ON COLUMN core.company_master."has_consolidation" IS '[신설] · 축 2. 연결 대상 법인 보유 여부. NULL=미확인 — false로 채우지 않는다';

CREATE TABLE core.corporate_action (
  "id" integer PRIMARY KEY,
  "from_company_id" integer,
  "to_company_id" integer,
  "action_type" varchar(20) NOT NULL,
  "effective_date" date NOT NULL,
  "note" text,
  "created_at" timestamptz
);
COMMENT ON TABLE core.corporate_action IS '[신규] L2 · 법인 계보 (축 7). 동국 3사·한화비전·스팩합병 수기 시딩';
COMMENT ON COLUMN core.corporate_action."action_type" IS 'enum: split|merge|rename|holding_conversion';

CREATE TABLE core.indicator_derivation (
  "indicator_code" varchar(20) PRIMARY KEY,
  "numerator_code" varchar(20) NOT NULL,
  "numerator_component" varchar(60),
  "denominator_code" varchar(20) NOT NULL,
  "denominator_component" varchar(60),
  "basis_constraint" varchar(20) NOT NULL,
  "formula" varchar(20) NOT NULL,
  "unit_rule" varchar(60),
  "note" text
);
COMMENT ON TABLE core.indicator_derivation IS '[신규] L3 · 파생 규칙 (축 8) — 포스코 0.978 재발 차단';
COMMENT ON COLUMN core.indicator_derivation."basis_constraint" IS 'enum: same_basis|any · same_basis면 분자·분모 basis 불일치 시 계산 거부';
COMMENT ON COLUMN core.indicator_derivation."formula" IS 'enum: divide|ratio|weighted_avg';

CREATE TABLE core.rule_param (
  "id" integer PRIMARY KEY,
  "indicator_code" varchar(20),
  "source_code" varchar(40),
  "rule_key" varchar(40) NOT NULL,
  "params" jsonb NOT NULL,
  "note" text,
  "updated_at" timestamptz,
  UNIQUE ("indicator_code", "source_code", "rule_key")
);
COMMENT ON TABLE core.rule_param IS '[신규] L3 · 산출 규칙 파라미터 (축 15). params에 조건문·수식 금지 — 알고리즘은 코드, 여기엔 재료만';
COMMENT ON COLUMN core.rule_param."indicator_code" IS 'NULL=전역 기본값';
COMMENT ON COLUMN core.rule_param."source_code" IS 'NULL=출처 무관';
COMMENT ON COLUMN core.rule_param."rule_key" IS '현재 4값: total_row·unit_scale·missing_policy·row_filter. CHECK 없음(의도)';

CREATE TABLE core.canonical_rule (
  "indicator_code" varchar(20) PRIMARY KEY,
  "basis_preference" varchar(20)[],
  "source_order" varchar(40)[],
  "tie_breaker" varchar(30),
  "note" text
);
COMMENT ON TABLE core.canonical_rule IS '[신규] L3 · 대표 선택 규칙 (축 14). 코드 3벌→표 1벌. basis_preference가 source_order보다 앞. 기존 indicator_source_config(161행) 흡수 → 포털 7곳 동반 수정';
COMMENT ON COLUMN core.canonical_rule."basis_preference" IS '1순위 축';
COMMENT ON COLUMN core.canonical_rule."source_order" IS '2순위 타이브레이크';
COMMENT ON COLUMN core.canonical_rule."tie_breaker" IS 'enum: latest_collected|highest_status|manual';

CREATE TABLE ops.indicator_data (
  "id" bigint PRIMARY KEY,
  "company_id" integer NOT NULL,
  "indicator_id" integer NOT NULL,
  "sub_id" integer,
  "fiscal_year" varchar(4),
  "value_raw" text,
  "value_num" numeric,
  "value_bool" boolean,
  "value_date" date,
  "unit" varchar(50),
  "is_industry_avg" boolean,
  "data_source" varchar(20),
  "last_etl_job_id" varchar(36),
  "created_at" timestamptz,
  "updated_at" timestamptz,
  "component_id" integer,
  "source_code" varchar(40),
  "basis" varchar(20),
  "basis_geo" varchar(20),
  "basis_raw" text,
  "method" varchar(20),
  "match_method" varchar(20),
  "match_confidence" numeric(3,2),
  "status" varchar(20),
  "status_at" timestamptz,
  "confirmed_by" varchar(60),
  "rule_applied" varchar(60)[]
);
COMMENT ON TABLE ops.indicator_data IS '[확장] L3 · 값 정본. 신규 12컬럼 추가, 업무키 6원소 UNIQUE는 Phase C';
COMMENT ON COLUMN ops.indicator_data."sub_id" IS '[DEPRECATED] component_id로 대체. 이관 기간 보존(롤백 경로) 후 DROP';
COMMENT ON COLUMN ops.indicator_data."value_raw" IS '🔒 원공시값 — 수정 API가 인자로 받지 않는다';
COMMENT ON COLUMN ops.indicator_data."value_num" IS '✏️ 사람이 고칠 때 바뀌는 유일한 값 컬럼';
COMMENT ON COLUMN ops.indicator_data."data_source" IS '적재 경로(ETL_CRAWL·ETL_CSV·LEGACY·MANUAL). 의미축 아님 — 의미축은 source_code';
COMMENT ON COLUMN ops.indicator_data."component_id" IS '[신설] · Phase C에서 NOT NULL';
COMMENT ON COLUMN ops.indicator_data."source_code" IS '[신설] · 🔴 조인이 아니라 값 컬럼 — 조인으로 얻으면 64.1% 탈락. Phase C: NOT NULL DEFAULT ''UNKNOWN''';
COMMENT ON COLUMN ops.indicator_data."basis" IS '[신설] · enum: separate|consolidated|group_sum|site|unknown · 축 2. Phase C: NOT NULL DEFAULT ''unknown''';
COMMENT ON COLUMN ops.indicator_data."basis_geo" IS '[신설] · enum: domestic|domestic_overseas|unknown';
COMMENT ON COLUMN ops.indicator_data."basis_raw" IS '[신설] · 원문 기준 표기 (SR 혼재 대응)';
COMMENT ON COLUMN ops.indicator_data."method" IS '[신설] · enum: location_based|market_based|unknown';
COMMENT ON COLUMN ops.indicator_data."match_method" IS '[신설] · enum: bizr_no|exact_name|alias|fuzzy_name';
COMMENT ON COLUMN ops.indicator_data."match_confidence" IS '[신설]';
COMMENT ON COLUMN ops.indicator_data."status" IS '[신설] · enum: collected|parsed|rule_checked|corrected|confirmed|legacy · 축 10. 이관 전 데이터는 ''legacy'' — confirmed로 위장하지 않는다';
COMMENT ON COLUMN ops.indicator_data."status_at" IS '[신설]';
COMMENT ON COLUMN ops.indicator_data."confirmed_by" IS '[신설]';
COMMENT ON COLUMN ops.indicator_data."rule_applied" IS '[신설]';

CREATE TABLE ops.evidence (
  "id" bigint PRIMARY KEY,
  "data_id" bigint NOT NULL,
  "source_code" varchar(20),
  "source_detail" varchar(500),
  "note" varchar(500),
  "collected_at" timestamptz,
  "doc_ref" varchar(100),
  "doc_page" integer,
  "etl_log" text
);
COMMENT ON TABLE ops.evidence IS '[개명+확장] L2 · 근거 전용 (구 indicator_source 개명 + doc_ref 축 4·12·18). 현재 값의 56.1%에 대응 행 없음 — 커버리지를 지표로 관리';
COMMENT ON COLUMN ops.evidence."data_id" IS 'ON DELETE CASCADE (축 12 — 고아 행 금지). ⚠️260813 적용 후 구 fk_src_data(무CASCADE)와 2중 — 구 FK DROP 권고';
COMMENT ON COLUMN ops.evidence."source_code" IS '[DEPRECATED] ops.indicator_data.source_code로 승격';
COMMENT ON COLUMN ops.evidence."note" IS '축 4. 사람이 남긴 메모만 — 로그는 etl_log, 출처는 doc_ref';
COMMENT ON COLUMN ops.evidence."doc_ref" IS '[신설] · 🔑 L0를 가리킨다. DART=rcept_no·SR=보고서 ID';
COMMENT ON COLUMN ops.evidence."doc_page" IS '[신설] · source_detail의 ''_NNNp'' 구조화';
COMMENT ON COLUMN ops.evidence."etl_log" IS '[신설]';

CREATE TABLE ops.indicator_data_history (
  "id" bigint PRIMARY KEY,
  "data_id" bigint NOT NULL,
  "changed_at" timestamptz NOT NULL,
  "changed_by" varchar(60),
  "change_type" varchar(20),
  "reason" text,
  "old_value" jsonb,
  "new_value" jsonb
);
COMMENT ON TABLE ops.indicator_data_history IS '[신규] L3 · 이력 (축 11). 🔴 소급 불가 — 이관보다 먼저 걸어야 이관 자체가 기록에 남는다. data_id에 FK 없음(의도 — 원본 삭제돼도 이력 존속)';
COMMENT ON COLUMN ops.indicator_data_history."data_id" IS '논리 관계 (FK 미선언 — 의도)';
COMMENT ON COLUMN ops.indicator_data_history."change_type" IS 'enum: insert|update|correct|delete|reassign · reassign=회사 귀속 변경 — 삭제+삽입을 한 이력 행에 묶는다';
COMMENT ON COLUMN ops.indicator_data_history."reason" IS '일회성 수정인지 규칙 문제인지 구별하는 유일한 단서. N번 반복되면 rule_param으로 승격';

CREATE TABLE ops.data_quality_flag (
  "id" bigint PRIMARY KEY,
  "data_id" bigint NOT NULL,
  "rule" varchar(40) NOT NULL,
  "severity" varchar(10) NOT NULL,
  "detail" text,
  "raised_by" varchar(60),
  "raised_at" timestamptz NOT NULL,
  "resolved_at" timestamptz,
  "resolved_by" varchar(60),
  "resolution" varchar(30)
);
COMMENT ON TABLE ops.data_quality_flag IS '[신규] L3 · 품질 플래그 (축 13). ''의심스럽지만 원문대로 적었다''를 담는 자리. 미해소 플래그 조회=검수 큐. 재수집이 지우지 않는다';
COMMENT ON COLUMN ops.data_quality_flag."data_id" IS 'ON DELETE CASCADE';
COMMENT ON COLUMN ops.data_quality_flag."rule" IS 'enum: unit_suspect|multi_source_divergence|carry_forward|similar_name_match|outlier|manual_override_stale';
COMMENT ON COLUMN ops.data_quality_flag."severity" IS 'enum: info|warn|block';
COMMENT ON COLUMN ops.data_quality_flag."resolution" IS 'enum: corrected|confirmed_as_is|source_fixed';

CREATE TABLE serving.v_fact (
  "company_id" integer,
  "indicator_code" varchar(20),
  "component_code" varchar(60),
  "role" varchar(20),
  "fiscal_year" varchar(4),
  "fy_definition" varchar(30),
  "value_num" numeric,
  "unit" varchar(50),
  "source_code" varchar(40),
  "basis" varchar(20),
  "basis_geo" varchar(20),
  "basis_raw" text,
  "method" varchar(20),
  "status" varchar(20),
  "rule_applied" varchar(60)[],
  "match_method" varchar(20),
  "match_confidence" numeric(3,2),
  "data_source" varchar(20),
  "doc_ref" varchar(100),
  "doc_page" integer
);
COMMENT ON TABLE serving.v_fact IS '[VIEW] [신규] L4 · 의미축 6원소 + 메타 (하네스 요구 #1). indicator_data ⋈ component ⋈ master ⟕ evidence. 단위는 행 우선 COALESCE(d.unit, c.unit, m.unit)';

CREATE TABLE serving.v_fact_canonical (
  "cols" text
);
COMMENT ON TABLE serving.v_fact_canonical IS '[VIEW] [예정] L4 · 대표값 구체화 뷰 — canonical_rule(basis_preference→source_order)을 풀어 출처는 접고 기준은 편다. 뷰로는 규모를 못 버팀(순위표 2,500사×지표, mv_industry_avg 233,995행 선례) → matview + 적재 후 리프레시, 응답에 as_of 필수. DDL은 골격만 — canonical_rule 확정 시 본문 작성';

ALTER TABLE raw.etl_job_log ADD FOREIGN KEY ("job_id") REFERENCES raw.etl_job ("id");
ALTER TABLE raw.etl_crawl_raw ADD FOREIGN KEY ("crawl_job_id") REFERENCES raw.etl_job ("id");
ALTER TABLE raw.etl_crawl_raw ADD FOREIGN KEY ("committed_data_id") REFERENCES ops.indicator_data ("id");
ALTER TABLE raw.etl_review_queue ADD FOREIGN KEY ("crawl_raw_id") REFERENCES raw.etl_crawl_raw ("id");
ALTER TABLE core.indicator_component ADD FOREIGN KEY ("indicator_code") REFERENCES core.indicator_master ("indicator_code");
ALTER TABLE core.indicator_component ADD FOREIGN KEY ("supersedes_id") REFERENCES core.indicator_component ("id");
ALTER TABLE core.indicator_source_map ADD FOREIGN KEY ("component_id") REFERENCES core.indicator_component ("id");
ALTER TABLE core.corporate_action ADD FOREIGN KEY ("from_company_id") REFERENCES core.company_master ("id");
ALTER TABLE core.corporate_action ADD FOREIGN KEY ("to_company_id") REFERENCES core.company_master ("id");
ALTER TABLE core.indicator_derivation ADD FOREIGN KEY ("indicator_code") REFERENCES core.indicator_master ("indicator_code");
ALTER TABLE core.canonical_rule ADD FOREIGN KEY ("indicator_code") REFERENCES core.indicator_master ("indicator_code");
ALTER TABLE ops.indicator_data ADD FOREIGN KEY ("company_id") REFERENCES core.company_master ("id");
ALTER TABLE ops.indicator_data ADD FOREIGN KEY ("indicator_id") REFERENCES core.indicator_master ("id");
ALTER TABLE ops.indicator_data ADD FOREIGN KEY ("sub_id") REFERENCES core.indicator_sub ("id");
ALTER TABLE ops.indicator_data ADD FOREIGN KEY ("component_id") REFERENCES core.indicator_component ("id");
ALTER TABLE ops.evidence ADD FOREIGN KEY ("data_id") REFERENCES ops.indicator_data ("id");
ALTER TABLE ops.indicator_data_history ADD FOREIGN KEY ("data_id") REFERENCES ops.indicator_data ("id");
ALTER TABLE ops.data_quality_flag ADD FOREIGN KEY ("data_id") REFERENCES ops.indicator_data ("id");