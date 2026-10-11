-- schema.sql —— 错题本数据库（全新建库，启动时自动执行）
-- 全部业务表含 user_id 外键 NOT NULL + 索引 + ON DELETE CASCADE
-- 未在真机执行验证，需你实测

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(200) NOT NULL,
  nickname VARCHAR(50),
  avatar_url TEXT,
  role VARCHAR(20) NOT NULL DEFAULT 'user',
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(200) NOT NULL,
  device_info TEXT,
  ip VARCHAR(64),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);

CREATE TABLE IF NOT EXISTS login_logs (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id) ON DELETE CASCADE,
  action VARCHAR(30) NOT NULL,
  ip VARCHAR(64),
  device_info TEXT,
  success BOOLEAN NOT NULL DEFAULT true,
  message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_login_logs_user ON login_logs(user_id);

CREATE TABLE IF NOT EXISTS audit_logs (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(50) NOT NULL,
  target TEXT,
  ip VARCHAR(64),
  detail JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_settings (
  user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  theme VARCHAR(20) DEFAULT 'system',
  locale VARCHAR(10) DEFAULT 'zh-CN',
  ai_mode VARCHAR(20) DEFAULT 'local',
  api_cost_limit NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subjects (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL,
  sort_order INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS chapters (
  id SERIAL PRIMARY KEY,
  subject_id INT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  sort_order INT DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_chapters_subject ON chapters(subject_id);

CREATE TABLE IF NOT EXISTS knowledge_points (
  id SERIAL PRIMARY KEY,
  chapter_id INT NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  parent_id INT REFERENCES knowledge_points(id) ON DELETE SET NULL,
  level INT DEFAULT 1,
  standard_requirement TEXT,
  exam_type VARCHAR(30),
  difficulty VARCHAR(20),
  common_question_types TEXT,
  common_errors TEXT,
  related_concepts TEXT,
  formulas TEXT,
  tags TEXT,
  source_basis TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_kps_chapter ON knowledge_points(chapter_id);

CREATE TABLE IF NOT EXISTS questions (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id INT REFERENCES subjects(id) ON DELETE SET NULL,
  chapter_id INT REFERENCES chapters(id) ON DELETE SET NULL,
  source VARCHAR(30) DEFAULT 'manual',
  difficulty VARCHAR(20),
  original_question TEXT NOT NULL,
  my_answer TEXT,
  correct_answer TEXT,
  analysis TEXT,
  answer_source_url TEXT,
  answer_source_name TEXT,
  answer_source_author TEXT,
  answer_source_authority VARCHAR(20),
  answer_source_accessed_at TIMESTAMPTZ,
  answer_source_snippet TEXT,
  alternative_sources JSONB DEFAULT '[]',
  verification_status VARCHAR(20) DEFAULT 'unverified',
  similarity_score NUMERIC,
  ai_generated_answer TEXT,
  ai_generated_analysis TEXT,
  copyright_note TEXT,
  search_keywords TEXT[],
  search_plan TEXT,
  search_status VARCHAR(20) DEFAULT 'none',
  last_verified_at TIMESTAMPTZ,
  adopted_source_id INT,
  error_type VARCHAR(50),
  error_reason TEXT,
  mastery VARCHAR(20) DEFAULT 'red',
  key_breakthrough TEXT,
  warning TEXT,
  same_type_signal TEXT,
  review_today BOOLEAN DEFAULT false,
  review_d1 TIMESTAMPTZ,
  review_d3 TIMESTAMPTZ,
  review_d7 TIMESTAMPTZ,
  review_d15 TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_questions_user ON questions(user_id);
CREATE INDEX IF NOT EXISTS idx_questions_user_subject ON questions(user_id, subject_id);
CREATE INDEX IF NOT EXISTS idx_questions_review_today ON questions(user_id, review_today);

CREATE TABLE IF NOT EXISTS question_kps (
  question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  kp_id INT NOT NULL REFERENCES knowledge_points(id) ON DELETE CASCADE,
  PRIMARY KEY (question_id, kp_id)
);

CREATE TABLE IF NOT EXISTS review_logs (
  id SERIAL PRIMARY KEY,
  question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  reviewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  result VARCHAR(20),
  note TEXT
);
CREATE INDEX IF NOT EXISTS idx_review_logs_question ON review_logs(question_id);

CREATE TABLE IF NOT EXISTS tags (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS question_tags (
  question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  tag_id INT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (question_id, tag_id)
);

CREATE TABLE IF NOT EXISTS prompt_templates (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  subject VARCHAR(50),
  course_type VARCHAR(50),
  question_type VARCHAR(50),
  template_content TEXT NOT NULL,
  variables JSONB DEFAULT '{}',
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_prompt_templates_user ON prompt_templates(user_id);

CREATE TABLE IF NOT EXISTS question_analysis_logs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_id INT REFERENCES questions(id) ON DELETE CASCADE,
  template_id INT REFERENCES prompt_templates(id) ON DELETE SET NULL,
  rendered_prompt TEXT,
  ai_response TEXT,
  model VARCHAR(100),
  mode VARCHAR(30),
  platform VARCHAR(30),
  strength VARCHAR(20),
  estimated_cost NUMERIC DEFAULT 0,
  actual_cost NUMERIC DEFAULT 0,
  duration_ms INT,
  provider VARCHAR(50),
  device_info TEXT,
  load_time_ms INT,
  first_token_ms INT,
  total_tokens INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_analysis_logs_user ON question_analysis_logs(user_id);

CREATE TABLE IF NOT EXISTS analysis_strength_configs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject VARCHAR(50),
  question_type VARCHAR(50),
  default_strength VARCHAR(20) NOT NULL DEFAULT 'standard',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_strength_configs_user ON analysis_strength_configs(user_id);

CREATE TABLE IF NOT EXISTS user_ai_memory (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  memory_type VARCHAR(30) NOT NULL,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  confidence NUMERIC DEFAULT 0.5,
  source VARCHAR(30) DEFAULT 'explicit',
  hit_count INT DEFAULT 0,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_memory_user ON user_ai_memory(user_id);

CREATE TABLE IF NOT EXISTS user_ai_profile (
  user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  preferred_strength VARCHAR(20) DEFAULT 'standard',
  preferred_explanation_style VARCHAR(30) DEFAULT 'step_by_step',
  weak_subjects JSONB DEFAULT '[]',
  weak_knowledge_points JSONB DEFAULT '[]',
  common_error_types JSONB DEFAULT '[]',
  learning_goal TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_feedback (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_id INT REFERENCES questions(id) ON DELETE CASCADE,
  analysis_log_id INT REFERENCES question_analysis_logs(id) ON DELETE SET NULL,
  feedback_type VARCHAR(30) NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_feedback_user ON user_feedback(user_id);

-- 本地离线队列（App 上传的待处理任务）
CREATE TABLE IF NOT EXISTS local_records (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_record_id VARCHAR(100),
  action VARCHAR(50) NOT NULL,
  payload JSONB,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  retry_count INT DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_local_records_user ON local_records(user_id);
CREATE INDEX IF NOT EXISTS idx_local_records_status ON local_records(status);

CREATE TABLE IF NOT EXISTS api_providers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL,
  base_url TEXT,
  enabled BOOLEAN DEFAULT false,
  config JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS search_cache (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  cache_key TEXT NOT NULL,
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, cache_key)
);

CREATE TABLE IF NOT EXISTS question_sources (
  id SERIAL PRIMARY KEY,
  question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  provider VARCHAR(50),
  url TEXT,
  title TEXT,
  author TEXT,
  authority VARCHAR(20) DEFAULT 'C',
  snippet TEXT,
  similarity_score NUMERIC,
  adopted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_question_sources_q ON question_sources(question_id);

CREATE TABLE IF NOT EXISTS verification_logs (
  id SERIAL PRIMARY KEY,
  question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  status VARCHAR(30),
  detail JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
