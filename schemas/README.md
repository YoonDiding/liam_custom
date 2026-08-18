# QESG 신 스키마 ERD 소스

- `qesg_schema.sql` — ERD 전용 순수 CREATE DDL.
  정본은 `esg-data-system-backend/test/out/target_schema_erd.json`이며
  `test/gen_liam_erd.py`가 이 파일을 생성한다. **여기서 직접 고치지 말고
  생성기를 다시 돌려 덮어쓸 것** (직접 수정은 다음 생성 때 사라진다).
- 이 파일을 갱신해 main에 push하면 GitHub Actions가 ERD를 빌드해
  GitHub Pages로 자동 배포한다.
