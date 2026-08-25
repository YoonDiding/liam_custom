CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS serving;

CREATE TABLE core.indicator_sub (id integer PRIMARY KEY);
COMMENT ON TABLE core.indicator_sub IS '[영역:사전] DEPRECATED · Q. 예전 서브컬럼 정의는 어디로 갔나 — 항목 정의는 indicator_component로, 출처 정보는 indicator_source_map으로 나눠 옮김. 이관 기간 동안 참조를 풀기 위해서만 남겨둔 빈 껍데기';

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
COMMENT ON TABLE raw.etl_job IS '[영역:파이프라인] [신규] L0 · Q. 어떤 작업이 언제 실행됐나? — 실행 1번이 행 1개. 백필처럼 행 단위 이력을 끄고 작업할 때는 이 테이블의 기록이 유일한 흔적이 된다 (MySQL 802행+리허설 작업 기록)';
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
COMMENT ON TABLE raw.etl_job_log IS '[영역:파이프라인] [신규] L0 · Q. 그 작업이 남긴 로그는? — 로그 한 줄이 행 1개. etl_job에 딸린 상세 기록이고 실행 이력 자체는 아니다 (MySQL 198,184행)';
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
  "dedup_key" text,
  "srdoc_id" bigint,
  "doc_page" integer,
  "component_code" varchar(60),
  "basis" varchar(20)
);
COMMENT ON TABLE raw.etl_crawl_raw IS '[영역:파이프라인] [신규] L0 · Q. 크롤러가 원래 가져온 내용은? — 크롤 원문 보관 + 처리 대기열. 단순 보관용이 아니라 파싱 상태를 관리하는 테이블이다 (682,556행 — 스테이징 15432 기준)';
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
COMMENT ON COLUMN raw.etl_crawl_raw."srdoc_id" IS '[신설] · SR→PG 직행 경로 — 이 관측이 어느 문서에서 나왔는지(source_document 판본사슬 참조)';
COMMENT ON COLUMN raw.etl_crawl_raw."doc_page" IS '[신설] · 문서 안 페이지 위치 — Vision 추출 근거';
COMMENT ON COLUMN raw.etl_crawl_raw."component_code" IS '[신설] · 문서 주도 추출이 판정한 component 후보 — 조립 단계 재료. 지표미정 관측은 indicator_code와 함께 NULL일 수 있다';
COMMENT ON COLUMN raw.etl_crawl_raw."basis" IS '[신설] · 원문이 밝힌 경계(연결/별도 등) — basis 채움 사다리의 1순위 재료';

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
COMMENT ON TABLE raw.etl_review_queue IS '[영역:파이프라인] [신규] L0 · Q. 사람이 검토해야 할 건은? — 검토 대기열. 다만 2,784행 전부 pending이라 사실상 쓰이지 않았고, 다른 테이블로 흡수할지 폐기할지 미정';
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
COMMENT ON TABLE raw.etl_indicator_mapping IS '[영역:파이프라인] [신규] L0 · Q. 크롤 결과를 어느 지표로 연결하나? — 매핑 규칙 테이블. 7행뿐이고 규칙 컬럼이 전부 NULL이라(rule_param의 전신 격) 흡수 여부 미정';
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
COMMENT ON TABLE core.indicator_master IS '[영역:사전] [확장] L1 · Q. 이 지표는 무엇인가? — 지표 정의. 기존 테이블에 fy_definition(연도를 어떻게 해석할지: S43은 공시연도-1 등)만 추가. classification_rules·extraction_script는 안 쓰기로 함(0행)';
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
COMMENT ON TABLE core.indicator_component IS '[영역:사전] [신규] L1 · Q. 이 항목은 무엇을 재는가? — 항목의 정의만 담고 출처 정보는 담지 않는다. role 6종(aggregate/component/derived/asreported/flag/attribute), parent_code(어느 합계의 부분인지), 정의가 바뀌면 기존 행을 수정하지 않고 valid_to를 닫고 새 행을 만든다(SCD Type 2). 구 sub 494행이 460개로 정리됨. S48 항목들은 이 표의 정의 없이 raw의 KISA 원본 테이블(c_kisa_disclosure, ERD 밖 c_* 출처원본 부류)에 행이 있는지로 판단';
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
COMMENT ON TABLE core.indicator_source_map IS '[영역:사전] [신규] L2 · Q. 이 항목을 어느 출처가 주고, 거기서는 뭐라고 부르나? — source_label(출처마다 다른 이름을 기록해 이름 차이를 흡수), source_unit(단위 변환의 입력값). 여기에 행이 있으면 그 출처가 이 항목을 제공한다는 뜻';
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
COMMENT ON TABLE core.company_master IS '[영역:사전] [확장] L2 · Q. 이 회사는 누구인가? — 회사 명부. has_consolidation(연결 대상 자회사가 있는지)을 추가했고, NULL은 ''아직 모름''이라는 뜻이라 false로 채우지 않는다';
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
COMMENT ON TABLE core.corporate_action IS '[영역:사전] [신규] L2 · Q. 이 회사가 예전의 그 회사와 같은 법인인가? — 분할·합병·사명변경·지주사 전환 이력. 동국 3사·한화비전·스팩합병을 수기로 넣는 것부터 시작';
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
COMMENT ON TABLE core.indicator_derivation IS '[영역:규칙 및 히스토리] [신규] L3 · Q. 파생 지표는 무엇으로 계산하나? — 분자·분모 지표를 지정. same_basis로 설정하면 분자와 분모의 연결/별도 기준이 다를 때 계산을 거부한다(포스코 0.978 같은 잘못된 비율 재발 방지)';
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
  "valid_from" date NOT NULL,
  "valid_to" date,
  UNIQUE ("indicator_code", "source_code", "rule_key")
);
COMMENT ON TABLE core.rule_param IS '[영역:규칙 및 히스토리] [신규] L3 · Q. 파싱·검증에 쓰는 판정 기준값은? — 알고리즘은 코드에 두고 여기엔 숫자·목록 같은 재료만 담는다. 지표별·출처별로 세분화 가능(4단계 우선순위). 기준이 바뀌면 행을 수정하지 않고 새 행을 만들며, 기간이 겹치면 DB가 등록을 거부한다. 값 쪽에서 rule_applied=''{id}:{rule_key}''로 어떤 규칙을 썼는지 기록';
COMMENT ON COLUMN core.rule_param."indicator_code" IS 'NULL=전역 기본값';
COMMENT ON COLUMN core.rule_param."source_code" IS 'NULL=출처 무관';
COMMENT ON COLUMN core.rule_param."rule_key" IS '현재 4값: total_row·unit_scale·missing_policy·row_filter. CHECK 없음(의도) · 동일 스코프 유효기간 겹침 금지(EXCLUDE gist)';
COMMENT ON COLUMN core.rule_param."valid_from" IS '[신설] · 260819 신설 — 용도는 현행 규칙 선택. 검증 재현은 id 참조가 담당';
COMMENT ON COLUMN core.rule_param."valid_to" IS '[신설]';

CREATE TABLE core.canonical_rule (
  "id" bigint PRIMARY KEY,
  "indicator_code" varchar(20) UNIQUE,
  "basis_preference" varchar(20)[],
  "source_order" varchar(40)[],
  "ingest_order" varchar(20)[],
  "tie_breaker" varchar(30),
  "note" text
);
COMMENT ON TABLE core.canonical_rule IS '[영역:규칙 및 히스토리] [신규] L3 · Q. 같은 항목에 값이 여러 개면 무엇을 대표로 보여주나? — 대표값 선택 규칙(260820 확정 골격). 접을 때는 출처 우선순위(source_order)→적재경로 우선순위(ingest_order)→tie_breaker→id 순서로 하나를 고른다. basis(연결/별도)는 여기서 접지 않고 파티션에 남긴다 — 지표마다 경계를 따로 고르면 분자·분모가 어긋나는 사고가 나기 때문. 구 indicator_source_config에서는 표시 우선순위만 가져오고 수집 계획(work_period)은 그 표에 그대로 둔다';
COMMENT ON COLUMN core.canonical_rule."id" IS 'PK를 id로 풀어 indicator_code NULL(전역행)을 허용';
COMMENT ON COLUMN core.canonical_rule."indicator_code" IS 'NULL이면 전역 기본 순서 행. UNIQUE NULLS NOT DISTINCT(ux_canonical_scope)라 전역행도 1행만';
COMMENT ON COLUMN core.canonical_rule."basis_preference" IS '접기에는 쓰지 않는다 — 파생 계산과 순위표가 경계(연결/별도)를 고를 때만 사용';
COMMENT ON COLUMN core.canonical_rule."source_order" IS '접기 1순위 — 출처(source_code) 우선순위. 지표행에 일부만 적으면 나머지는 전역 순서를 이어붙인다(array_cat)';
COMMENT ON COLUMN core.canonical_rule."ingest_order" IS '[신설] · 접기 2순위 — 적재경로(data_source) 우선순위. 코드 2곳에 복제돼 있던 SRC_RANK 하드코딩 7값을 흡수';
COMMENT ON COLUMN core.canonical_rule."tie_breaker" IS 'enum: latest_collected|highest_status|manual · 접기 3순위. 그래도 남으면 id가 최종 결정';

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
COMMENT ON TABLE ops.indicator_data IS '[영역:파이프라인] [확장] L3 · Q. 확정된 값은 얼마인가? — 값의 정본 테이블. 행 하나를 회사·지표·component·연도·출처·basis 6가지로 식별하고, 보고된 원래 값(value_raw)과 정규화된 숫자(value_num)를 같은 행에 둔다. UNIQUE 제약은 Phase C에서 걸 예정';
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
COMMENT ON TABLE ops.evidence IS '[영역:파이프라인] [개명+확장] L2 · Q. 그 값을 어디에서 봤나? — 근거 전용 테이블(구 indicator_source를 개명). doc_ref 표기법: DART 문서는 rcept_no, 지속가능경영보고서는 SRDOC:{id}, KISA 공시는 KISA:{id}. 현재 값의 56.1%는 근거 행이 없는데, 이 비율 자체를 관리 지표로 삼는다';
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
COMMENT ON TABLE ops.indicator_data_history IS '[영역:규칙 및 히스토리] [신규] L3 · Q. 값이 언제, 왜 바뀌었나? — 트리거가 7개 컬럼의 변경을 자동 기록. 백필 때는 세션 스위치로 끄고 대신 etl_job에 남긴다. absorb 작업은 reason(사람이 읽는 설명)과 new_value.absorbed_into(기계가 따라가는 링크)를 함께 기록. 과거로 소급해서 만들 수 없으므로 이관보다 먼저 걸어야 이관 자체가 기록에 남는다. data_id에 FK를 안 건 것은 의도 — 원본 행이 삭제돼도 이력은 남긴다';
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
COMMENT ON TABLE ops.data_quality_flag IS '[영역:규칙 및 히스토리] [신규] L3 · Q. 의심스럽지만 원문대로 적은 값은? — 값 자체는 원문대로 두고, 의심된다는 표시를 옆 테이블에 따로 기록. 해소 안 된 플래그 목록이 곧 검수 대기 목록이고, 재수집해도 플래그는 자동으로 지워지지 않는다';
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
COMMENT ON TABLE serving.v_fact IS '[영역:서빙] [VIEW] [신규] L4 · Q. 지금 서빙 가능한 사실 목록은? — 값·항목·지표·근거를 조인해 6가지 식별자와 메타 정보를 한 줄로 제공하는 뷰. 단위는 값 행 → component → master 순서로 채운다';

CREATE TABLE serving.v_fact_canonical (
  "cols" text
);
COMMENT ON TABLE serving.v_fact_canonical IS '[영역:서빙] [VIEW] [예정] L4 · Q. 회사·지표당 대표값 하나만 필요하면? — canonical_rule에 따라 여러 출처 중 하나를 골라 대표값으로 만든다. 연결/별도는 합치지 않고 각각 따로 제공. 일반 뷰로는 조회량을 감당 못해 구체화 뷰로 만들고 적재 후 리프레시하며, 응답에 갱신 시점(as_of)을 반드시 붙인다. 아직 골격만 있음';

CREATE TABLE raw.source_document (
  "id" bigint PRIMARY KEY,
  "source_type" varchar(30) NOT NULL,
  "doc_type" varchar(30) NOT NULL,
  "doc_subtype" varchar(50),
  "company_id" integer,
  "company_raw" varchar(200),
  "fiscal_year" varchar(4) NOT NULL,
  "lang" varchar(5),
  "title" text,
  "published_date" date,
  "period_start" date,
  "period_end" date,
  "report_scope_raw" text,
  "basis_default" varchar(20),
  "basis_geo_default" varchar(20),
  "pages" integer,
  "file_path" text,
  "file_hash" varchar(64) UNIQUE,
  "note" text,
  "created_at" timestamptz NOT NULL,
  "updated_at" timestamptz NOT NULL,
  "s3_key" text UNIQUE,
  "supersedes_id" bigint
);
COMMENT ON TABLE raw.source_document IS '[영역:파이프라인] [신규] L0 · Q. 이 문서는 어떤 판본인가? — 보고서 한 부가 행 하나. 행은 수정하지 않고 새 판본이 나오면 새 행을 만든다. evidence.doc_ref가 SRDOC:{id} 형식으로 가리키는 대상. 같은 파일을 두 번 등록하는 실수만 file_hash로 잡는다. V8: 원본은 S3 단일 정본(s3_key)으로 관리, 판본 교체는 supersedes_id 사슬';
COMMENT ON COLUMN raw.source_document."source_type" IS 'SR·FACTBOOK… L0는 잘게(축 18)';
COMMENT ON COLUMN raw.source_document."doc_type" IS 'enum: SR|FACTBOOK|DATABOOK|CLIMATE_REPORT|VALUE_UP|OTHER · 3어휘 SR·DATABOOK·OTHER(V15) — 처리 경로가 갈리는 만큼만 잘게. 상세 유형은 doc_subtype. 컬럼화 근거=밸류업 10부 SR 위장 실측(260818)';
COMMENT ON COLUMN raw.source_document."doc_subtype" IS '[신설] · 상세 유형 자유 라벨(V15 — 기후보고서·TCFD 등, CHECK 없음). 특징 서술은 note에, 이 칸은 짧은 라벨만. 처리 경로가 갈라지면 doc_type으로 승격';
COMMENT ON COLUMN raw.source_document."company_raw" IS '원문 회사 표기(보강 전) — L0 원칙';
COMMENT ON COLUMN raw.source_document."fiscal_year" IS '대상 회계연도 — 발간연도 아님(''2025 Report'' 25부가 FY2024)';
COMMENT ON COLUMN raw.source_document."report_scope_raw" IS '보고범위 원문. 값의 범위 정본은 값 행(basis_*) — 이건 폴백. 사다리: 셀 주석>문서 기본>출처 기본표>unknown';
COMMENT ON COLUMN raw.source_document."basis_default" IS 'enum: separate|consolidated|group_sum|site|unknown';
COMMENT ON COLUMN raw.source_document."basis_geo_default" IS 'enum: domestic|domestic_overseas|unknown';
COMMENT ON COLUMN raw.source_document."file_hash" IS '판본·중복 검출(260818 md5 실측)';
COMMENT ON COLUMN raw.source_document."s3_key" IS '[신설] · S3 정본 위치(V8) — sr-reports/{연도}/{코드}_{doc_type}_{언어}_{md5앞8}.{확장자}. V15부터 유형 포함·PDF/XLSX 허용, 구 등록분 키는 유지';
COMMENT ON COLUMN raw.source_document."supersedes_id" IS '[신설] · 이 행이 대체한 구 판본(V8) — 파일 교체는 덮어쓰기가 아니라 새 행+이 링크';

CREATE TABLE ops.users (
  "id" bigint PRIMARY KEY,
  "email" text NOT NULL,
  "display_name" text,
  "portal_role" varchar NOT NULL,
  "plan" varchar,
  "plan_expires_at" timestamptz,
  "is_active" boolean NOT NULL,
  "last_login_at" timestamptz,
  "note" text,
  "created_at" timestamptz NOT NULL
);
COMMENT ON TABLE ops.users IS '[영역:포털 운영] [기존] OPS · Q. 포털에 누가 들어올 수 있나? — 계정 명부. portal_role(권한)과 plan(요금제)·plan_expires_at으로 접근을 통제한다 (스테이징 11명)';

CREATE TABLE ops.portal_login_code (
  "id" bigint PRIMARY KEY,
  "email" text NOT NULL,
  "code" varchar NOT NULL,
  "expires_at" timestamptz NOT NULL,
  "used_at" timestamptz,
  "created_at" timestamptz NOT NULL
);
COMMENT ON TABLE ops.portal_login_code IS '[영역:포털 운영] [기존] OPS · Q. 로그인 시도는 어떻게 확인하나? — 이메일로 보낸 1회용 코드와 만료·사용 시각. 비밀번호 없이 코드 로그인';

CREATE TABLE ops.portal_credit_grant (
  "id" bigint PRIMARY KEY,
  "account_id" bigint NOT NULL,
  "amount_usd" numeric NOT NULL,
  "reason" text NOT NULL,
  "granted_at" timestamptz NOT NULL,
  "note" text
);
COMMENT ON TABLE ops.portal_credit_grant IS '[영역:포털 운영] [기존] OPS · Q. 이 계정에 크레딧을 언제 왜 줬나? — 지급 1건이 행 1개(사유 필수). 잔액은 지급 합계에서 사용량을 빼서 계산';

CREATE TABLE ops.ai_quota (
  "account_id" bigint PRIMARY KEY,
  "token_limit" bigint,
  "token_bonus" bigint NOT NULL,
  "reset_period" varchar NOT NULL,
  "reset_at" timestamptz,
  "enforce" boolean NOT NULL,
  "updated_by" text,
  "updated_at" timestamptz NOT NULL,
  "note" text
);
COMMENT ON TABLE ops.ai_quota IS '[영역:포털 운영] [기존] OPS · Q. 이 계정이 AI를 얼마나 쓸 수 있나? — 토큰 한도·보너스·리셋 주기. enforce가 꺼져 있으면 기록만 하고 막지는 않는다';

CREATE TABLE ops.ai_usage_log (
  "id" bigint PRIMARY KEY,
  "ts" timestamptz NOT NULL,
  "account_id" bigint,
  "env" text,
  "query" text,
  "model" text,
  "type" text,
  "steps" integer,
  "tokens" bigint,
  "input_tokens" bigint,
  "output_tokens" bigint,
  "billed_input_tokens" bigint,
  "cache_read_tokens" bigint,
  "cache_write_tokens" bigint,
  "cost_usd" numeric,
  "extra" jsonb
);
COMMENT ON TABLE ops.ai_usage_log IS '[영역:포털 운영] [기존] OPS · Q. AI 호출 한 번에 무엇을 얼마나 썼나? — 질의·모델·토큰(캐시 읽기/쓰기 구분)·비용(cost_usd)을 호출 단위로 기록. 계정별 사용량 집계의 원천';

CREATE TABLE core.code_master (
  "id" integer PRIMARY KEY,
  "code_type" varchar,
  "code" varchar,
  "code_name" varchar,
  "sort_order" integer,
  "is_active" boolean
);
COMMENT ON TABLE core.code_master IS '[영역:사전] [기존] L1 · Q. 시스템 곳곳의 코드값은 무슨 뜻인가? — 코드 유형·코드·이름을 담는 공용 코드표';

CREATE TABLE core.company_synonym (
  "id" integer PRIMARY KEY,
  "company_id" integer,
  "synonym" varchar,
  "source" varchar
);
COMMENT ON TABLE core.company_synonym IS '[영역:사전] [기존] L2 · Q. 이 표기가 어느 회사를 말하나? — 회사명 이표기(옛 사명·약칭·영문 등)를 company_master로 연결. 회사 매칭의 보조 재료';

CREATE TABLE ops.sync_state (
  "table_name" text PRIMARY KEY,
  "last_id" bigint,
  "last_ts" timestamptz,
  "last_run_at" timestamptz
);
COMMENT ON TABLE ops.sync_state IS '[영역:파이프라인] [기존] L0 · Q. MySQL→PG 동기화가 어디까지 왔나? — 테이블별 마지막 동기화 지점(id·시각). 컷오버 전 이중 운영기의 이정표';

CREATE TABLE raw.c_dart_company_info (
  "cols" text
);
COMMENT ON TABLE raw.c_dart_company_info IS '[영역:출처 원본] [기존] L0 · DART 기업개황 원본 (3,957행)';

CREATE TABLE raw.c_env_info_company (
  "cols" text
);
COMMENT ON TABLE raw.c_env_info_company IS '[영역:출처 원본] [기존] L0 · 환경정보공개시스템 기업 단위 원본 (12,331행)';

CREATE TABLE raw.c_env_info_section (
  "cols" text
);
COMMENT ON TABLE raw.c_env_info_section IS '[영역:출처 원본] [기존] L0 · 환경정보공개시스템 섹션 단위 원본 (279,617행)';

CREATE TABLE raw.c_ecosq_product (
  "cols" text
);
COMMENT ON TABLE raw.c_ecosq_product IS '[영역:출처 원본] [기존] L0 · 에코스퀘어 친환경 제품 인증 원본 (11,152행)';

CREATE TABLE raw.c_sanction_detail (
  "cols" text
);
COMMENT ON TABLE raw.c_sanction_detail IS '[영역:출처 원본] [기존] L0 · 제재 처분 상세 원본 (10,627행)';

CREATE TABLE raw.c_consum_recall (
  "cols" text
);
COMMENT ON TABLE raw.c_consum_recall IS '[영역:출처 원본] [기존] L0 · 소비자원 리콜 원본 (8,517행)';

CREATE TABLE raw.c_climate_initiative_membership (
  "cols" text
);
COMMENT ON TABLE raw.c_climate_initiative_membership IS '[영역:출처 원본] [기존] L0 · 기후 이니셔티브 가입 현황 원본 (2,672행)';

CREATE TABLE raw.c_company_report_status (
  "cols" text
);
COMMENT ON TABLE raw.c_company_report_status IS '[영역:출처 원본] [기존] L0 · 보고서 발간 현황 원본 (6,922행)';

CREATE TABLE raw.c_sr_report (
  "cols" text
);
COMMENT ON TABLE raw.c_sr_report IS '[영역:출처 원본] [기존] L0 · SR 적재 경로 테이블 (436행). ⚠️ 로컬 절대경로가 값에 들어 있어 컷오버 때 경로 체계째 재정비 — source_document로 승격 예정';

CREATE TABLE raw.c_sr_e3_climate_risk (
  "cols" text
);
COMMENT ON TABLE raw.c_sr_e3_climate_risk IS '[영역:출처 원본] [기존] L0 · SR에서 추출한 기후리스크(E3) 원본 (370행)';

CREATE TABLE raw.c_exchange_rate (
  "cols" text
);
COMMENT ON TABLE raw.c_exchange_rate IS '[영역:출처 원본] [기존] L0 · 환율 참조표 (48행)';

CREATE TABLE raw.c_ksic_code (
  "cols" text
);
COMMENT ON TABLE raw.c_ksic_code IS '[영역:출처 원본] [기존] L0 · 표준산업분류(KSIC) 코드표 (1,205행)';

CREATE TABLE raw.c_nts_biz_code (
  "cols" text
);
COMMENT ON TABLE raw.c_nts_biz_code IS '[영역:출처 원본] [기존] L0 · 국세청 업종 코드표 (1,782행)';

CREATE TABLE raw.br_board_meeting (
  "cols" text
);
COMMENT ON TABLE raw.br_board_meeting IS '[영역:출처 원본] [기존] L0 · 사업보고서 이사회 개최 내역 원본 (1,780행)';

CREATE TABLE raw.i_ghg_target (
  "cols" text
);
COMMENT ON TABLE raw.i_ghg_target IS '[영역:출처 원본] [기존] L0 · NGMS 온실가스 감축목표 원본 (1,977행)';

CREATE TABLE raw.i_indicator_source (
  "cols" text
);
COMMENT ON TABLE raw.i_indicator_source IS '[영역:출처 원본] [기존] L0 · 구 근거 테이블 스냅샷 (389,885행). evidence의 원형 — 신 구조 정착 후 대체';

CREATE TABLE raw.c_kisa_disclosure (
  "cols" text
);
COMMENT ON TABLE raw.c_kisa_disclosure IS '[영역:출처 원본] [기존] L0 · KISA 정보보호공시 원본. 공시 1건=행 1개, S48 값들의 파생원(행이 있는지로 판단)·doc_ref KISA:{id} 대상';

CREATE TABLE serving.company_profile (
  "cols" text
);
COMMENT ON TABLE serving.company_profile IS '[영역:서빙] [기존] L4 · 회사 프로필 카드 재료 (3,956행) — 대표자·업종 등 표시용 요약';

CREATE TABLE serving.indicator_embedding (
  "cols" text
);
COMMENT ON TABLE serving.indicator_embedding IS '[영역:서빙] [기존] L4 · 지표 설명 임베딩 (124행) — 구어체 질의를 지표로 매칭';

CREATE TABLE serving.news_embedding (
  "cols" text
);
COMMENT ON TABLE serving.news_embedding IS '[영역:서빙] [기존] L4 · 뉴스 임베딩 — 유사 기사 중복 제거·연관도 정렬 재료';

CREATE TABLE serving.sr_chunk_embedding (
  "cols" text
);
COMMENT ON TABLE serving.sr_chunk_embedding IS '[영역:서빙] [기존] L4 · SR 본문 청크 임베딩 (920,162행) — 벡터 탐색으로 근거 후보를 찾는 재료';

CREATE TABLE serving.sr_chunk_voyage (
  "cols" text
);
COMMENT ON TABLE serving.sr_chunk_voyage IS '[영역:서빙] [기존] L4 · SR 청크 임베딩 Voyage 모델판 (920,162행) — 모델 비교·전환용';

CREATE TABLE serving.br_doc_section (
  "cols" text
);
COMMENT ON TABLE serving.br_doc_section IS '[영역:서빙] [기존] L4 · 사업보고서 원문 섹션 (275,716행) — BR 뷰어가 읽는 본문';

CREATE TABLE serving.sanction_summary (
  "cols" text
);
COMMENT ON TABLE serving.sanction_summary IS '[영역:서빙] [기존] L4 · 제재 요약 (1,050행) — 포털 제재 조회 API가 읽는 표';

CREATE TABLE serving.v_esg_news (
  "cols" text
);
COMMENT ON TABLE serving.v_esg_news IS '[영역:서빙] [기존] L4 · ESG 뉴스 서빙 표 (1,579행)';

CREATE TABLE serving.mv_industry_avg (
  "cols" text
);
COMMENT ON TABLE serving.mv_industry_avg IS '[영역:서빙] [VIEW] [기존] L4 · Q. 업계 평균은 어디서 오나? — 업종×지표×연도의 평균·중앙값·최소최대 구체화뷰 (229,065행, 스테이징 기준). 수치형 지표만 집계하며 적재 후 리프레시가 필요하다(이관 finalize 절차에 포함)';

CREATE TABLE serving.v_company_doc_coverage (
  "cols" text
);
COMMENT ON TABLE serving.v_company_doc_coverage IS '[영역:서빙] [VIEW] [기존] L4 · Q. 어느 회사가 어떤 문서를 확보했나? — 회사별 SR·BR 공시 여부와 인덱싱된 청크 수·최신 연도를 모은 커버리지 뷰(V10, SR 수집 현황 API가 읽는다)';

CREATE TABLE raw.source_document_company (
  "id" bigint PRIMARY KEY,
  "srdoc_id" bigint NOT NULL,
  "company_id" integer NOT NULL,
  "relation" varchar(20) NOT NULL,
  "source" varchar(20) NOT NULL,
  "note" text,
  "created_at" timestamptz,
  UNIQUE ("srdoc_id", "company_id")
);
COMMENT ON TABLE raw.source_document_company IS '[영역:파이프라인] [신규] L0 · Q. 이 문서가 어느 회사들을 다루나? — 지주사 연결보고서(무림그룹→무림페이퍼 등)처럼 한 문서가 여러 회사를 담는 경우의 매핑(V10). 발행 주체는 issuer 1행, 보고범위에 포함된 회사는 covered 행. AI 보고범위 추출이 채우고 사람이 정정한다(source 컬럼으로 구분). 행의 존재가 사실';
COMMENT ON COLUMN raw.source_document_company."srdoc_id" IS '문서 (삭제 시 함께 삭제)';
COMMENT ON COLUMN raw.source_document_company."relation" IS 'enum: issuer|covered · issuer=발행 주체(업로드 시 자동) / covered=보고범위 포함';
COMMENT ON COLUMN raw.source_document_company."source" IS 'enum: issuer_auto|ai|manual · 채움 주체 — AI가 메인, 사람이 보조';
COMMENT ON COLUMN raw.source_document_company."note" IS '원문 근거 (예: 연결대상 종속회사 명시 p.3)';

CREATE TABLE ops.verification_run (
  "id" bigint PRIMARY KEY,
  "data_id" bigint NOT NULL,
  "method" varchar(20) NOT NULL,
  "verdict" varchar(12) NOT NULL,
  "detail" jsonb,
  "verifier" varchar(80),
  "run_at" timestamptz NOT NULL
);
COMMENT ON TABLE ops.verification_run IS '[영역:규칙 및 히스토리] [신규] L3 · Q. 이 값을 누가 언제 어떻게 검증했나? — 검증 시행 1건이 행 1개(V13). 통과도 기록해 레거시 verified 0/1의 통과 근거 증발을 해소한다. 이 표는 사건 기록이고, 현재 상태는 indicator_data.status가, 미해소 문제는 data_quality_flag가 맡는다. method는 원문 대조 비용 사다리(text_recheck→ai_snippet→ai_embedding)+rule+human';
COMMENT ON COLUMN ops.verification_run."data_id" IS 'ops.indicator_data.id — FK 미선언(의도): 값이 폐기·교체돼도 검증 이력은 존속';
COMMENT ON COLUMN ops.verification_run."method" IS 'enum: rule|text_recheck|ai_snippet|ai_embedding|human';
COMMENT ON COLUMN ops.verification_run."verdict" IS 'enum: pass|fail|uncertain';
COMMENT ON COLUMN ops.verification_run."detail" IS '근거 통째 — 규칙={rule_applied, 편차} / AI={model, 원문 위치, 응답 요지, confidence, cost}';
COMMENT ON COLUMN ops.verification_run."verifier" IS '러너 이름 또는 사람';

CREATE TABLE serving.srdoc_chunk (
  "id" bigint PRIMARY KEY,
  "srdoc_id" bigint NOT NULL,
  "page" integer NOT NULL,
  "chunk_idx" integer NOT NULL,
  "text" text NOT NULL,
  "vec" vector(384),
  "model" varchar(80) NOT NULL,
  "created_at" timestamptz NOT NULL,
  UNIQUE ("srdoc_id", "page", "chunk_idx", "model")
);
COMMENT ON TABLE serving.srdoc_chunk IS '[영역:서빙] [신규] L4 · Q. 문서의 어느 페이지에 무슨 내용이 있나? — SR 청크·임베딩(V14). srdoc_id 키라서 임베딩의 수명주기가 문서 행을 따라간다(ON DELETE CASCADE). 페이지 벡터·키워드 탐색의 재료이고, 텍스트 모드 추출은 이 텍스트를 그대로 읽는다. 파일명 키였던 구 sr_chunk_embedding의 후속';
COMMENT ON COLUMN serving.srdoc_chunk."srdoc_id" IS 'ON DELETE CASCADE — 문서 행이 지워지면 청크도 함께';
COMMENT ON COLUMN serving.srdoc_chunk."chunk_idx" IS '페이지 내 순번';
COMMENT ON COLUMN serving.srdoc_chunk."vec" IS 'pgvector — MiniLM 384차원';
COMMENT ON COLUMN serving.srdoc_chunk."model" IS '임베딩 모델 — 교체 실험 구분';

CREATE TABLE serving.v_fact_core (
  "cols" text
);
COMMENT ON TABLE serving.v_fact_core IS '[영역:서빙] [VIEW] [신규] L4 · Q. 신 체계의 서빙 계약은? — 업무키 6원소+값 4종+내력을 한 줄로 주는 뷰(V12). status 게이트 내장(parsed는 노출되지 않음), evidence의 doc_ref·doc_page 탑재, component는 LEFT 조인(이월 3,230행 보존). 회사 메타는 싣지 않는다 — 소비자가 company_master를 직접 조인. 구 v_fact 교체(D-3) 전까지 병행 운영';

ALTER TABLE raw.etl_job_log ADD FOREIGN KEY ("job_id") REFERENCES raw.etl_job ("id");
ALTER TABLE raw.etl_crawl_raw ADD FOREIGN KEY ("crawl_job_id") REFERENCES raw.etl_job ("id");
ALTER TABLE raw.etl_crawl_raw ADD FOREIGN KEY ("committed_data_id") REFERENCES ops.indicator_data ("id");
ALTER TABLE raw.etl_crawl_raw ADD FOREIGN KEY ("srdoc_id") REFERENCES raw.source_document ("id");
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
ALTER TABLE raw.source_document ADD FOREIGN KEY ("company_id") REFERENCES core.company_master ("id");
ALTER TABLE raw.source_document ADD FOREIGN KEY ("supersedes_id") REFERENCES raw.source_document ("id");
ALTER TABLE ops.portal_credit_grant ADD FOREIGN KEY ("account_id") REFERENCES ops.users ("id");
ALTER TABLE ops.ai_quota ADD FOREIGN KEY ("account_id") REFERENCES ops.users ("id");
ALTER TABLE ops.ai_usage_log ADD FOREIGN KEY ("account_id") REFERENCES ops.users ("id");
ALTER TABLE core.company_synonym ADD FOREIGN KEY ("company_id") REFERENCES core.company_master ("id");
ALTER TABLE raw.source_document_company ADD FOREIGN KEY ("srdoc_id") REFERENCES raw.source_document ("id");
ALTER TABLE raw.source_document_company ADD FOREIGN KEY ("company_id") REFERENCES core.company_master ("id");
ALTER TABLE serving.srdoc_chunk ADD FOREIGN KEY ("srdoc_id") REFERENCES raw.source_document ("id");