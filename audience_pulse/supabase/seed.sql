-- ============================================================
-- AudiencePulse — Seed Data
-- Realistic mock data for a 48-hour window ending now.
-- Run AFTER 0001_init.sql
-- ============================================================

-- ============================================================
-- PLATFORMS
-- ============================================================
INSERT INTO platforms (id, name, status, last_synced_at) VALUES
  ('11111111-0000-0000-0000-000000000001', 'X (Twitter)',  'live',         NOW() - INTERVAL '3 minutes'),
  ('11111111-0000-0000-0000-000000000002', 'Telegram',     'live',         NOW() - INTERVAL '7 minutes'),
  ('11111111-0000-0000-0000-000000000003', 'Instagram',    'coming_soon',  NULL),
  ('11111111-0000-0000-0000-000000000004', 'Facebook',     'coming_soon',  NULL),
  ('11111111-0000-0000-0000-000000000005', 'Reddit',       'coming_soon',  NULL),
  ('11111111-0000-0000-0000-000000000006', 'YouTube',      'coming_soon',  NULL);

-- ============================================================
-- AUTHORS (10 on X, 5 on Telegram)
-- ============================================================
INSERT INTO authors (id, platform_id, handle, display_name, bio_text, inferred_language, inferred_region, inferred_age_bracket, follower_count) VALUES
  -- X Authors
  ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '@techpulse_in',  'TechPulse India',       'Covering India tech scene 🇮🇳 | AI & Startups',      'en', 'India',        '25-34', 128400),
  ('22222222-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', '@aiwatch_global','AI Watch Global',       'Tracking AI breakthroughs worldwide.',                'en', 'USA',          '35-44', 95200),
  ('22222222-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000001', '@priya_tweets',  'Priya Sharma',          'Data scientist | NLP enthusiast | Bengaluru',         'en', 'India',        '25-34', 42100),
  ('22222222-0000-0000-0000-000000000004', '11111111-0000-0000-0000-000000000001', '@rohan_dev',     'Rohan Verma',           'Full-stack dev | Open source advocate',               'en', 'India',        '18-24', 18700),
  ('22222222-0000-0000-0000-000000000005', '11111111-0000-0000-0000-000000000001', '@globalvoices_', 'Global Voices',         'Citizen journalism from around the world.',           'en', 'Global',       '35-44', 210000),
  ('22222222-0000-0000-0000-000000000006', '11111111-0000-0000-0000-000000000001', '@startupwala',   'StartupWala',           'India startup ecosystem news & analysis.',            'hi', 'India',        '25-34', 67800),
  ('22222222-0000-0000-0000-000000000007', '11111111-0000-0000-0000-000000000001', '@skeptic_tech',  'Tech Skeptic',          'Questioning every AI hype claim.',                    'en', 'UK',           '35-44', 33400),
  ('22222222-0000-0000-0000-000000000008', '11111111-0000-0000-0000-000000000001', '@meena_policy',  'Meena Krishnan',        'Tech policy researcher | IIT Madras',                 'en', 'India',        '25-34', 56200),
  ('22222222-0000-0000-0000-000000000009', '11111111-0000-0000-0000-000000000001', '@ngo_digitalink','Digital Ink NGO',       'Digital literacy for underserved communities.',       'en', 'India',        '45+',   24300),
  ('22222222-0000-0000-0000-000000000010', '11111111-0000-0000-0000-000000000001', '@dev_ananya',    'Ananya Das',            'ML engineer | Kaggle Grandmaster | Delhi',            'en', 'India',        '18-24', 31600),
  -- Telegram Authors
  ('22222222-0000-0000-0000-000000000011', '11111111-0000-0000-0000-000000000002', '@tg_indiatech',  'Indiatech Channel',     'Indian tech news on Telegram',                        'en', 'India',        '25-34', 88500),
  ('22222222-0000-0000-0000-000000000012', '11111111-0000-0000-0000-000000000002', '@tg_cryptohive', 'CryptoHive',            'Crypto & Web3 signals',                               'en', 'UAE',          '25-34', 145000),
  ('22222222-0000-0000-0000-000000000013', '11111111-0000-0000-0000-000000000002', '@tg_aiforum',    'AI Discussion Forum',   'Daily AI papers & discussion',                        'en', 'Global',       '35-44', 62000),
  ('22222222-0000-0000-0000-000000000014', '11111111-0000-0000-0000-000000000002', '@tg_startupind', 'Startup India TG',      'Startup deals, funding, jobs',                        'hi', 'India',        '25-34', 41200),
  ('22222222-0000-0000-0000-000000000015', '11111111-0000-0000-0000-000000000002', '@tg_policywatch','Policy Watch India',    'Regulatory updates affecting tech sector',            'en', 'India',        '45+',   29800);

-- ============================================================
-- POSTS (25 posts across the 48-hour window)
-- ============================================================
INSERT INTO posts (id, platform_id, author_id, content_text, posted_at, raw_engagement_count, url) VALUES
  -- X Posts
  ('33333333-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000001',
   'Just tried the new Gemini 2.0 API — it''s genuinely impressive. Multi-modal reasoning has reached a new level. Indian startups have a huge opportunity here. 🚀 #AI #IndiaAI',
   NOW()-INTERVAL '47 hours', 4820, 'https://x.com/techpulse_in/status/1'),

  ('33333333-0000-0000-0000-000000000002','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000002',
   'Thread: Why LLM benchmarks are becoming increasingly meaningless. 1/8 The problem is Goodhart''s Law applied to AI evaluation...',
   NOW()-INTERVAL '45 hours', 12300, 'https://x.com/aiwatch_global/status/2'),

  ('33333333-0000-0000-0000-000000000003','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000003',
   'Fine-tuned a small BERT model on Hindi-English code-switched tweets and the results are actually better than GPT-4 for this niche task. Open-sourcing soon!',
   NOW()-INTERVAL '43 hours', 3240, 'https://x.com/priya_tweets/status/3'),

  ('33333333-0000-0000-0000-000000000004','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000004',
   'Government''s new digital public infrastructure policy could be a game changer for fintech. Or not. We''ve heard this before. 🤔 #DPI #IndiaFintech',
   NOW()-INTERVAL '41 hours', 1890, 'https://x.com/rohan_dev/status/4'),

  ('33333333-0000-0000-0000-000000000005','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000007',
   'Hot take: 90% of "AI-powered" startups are just GPT wrappers with a fancy UI. The moat is zero. Investors are going to feel this in 18 months. 🔥',
   NOW()-INTERVAL '39 hours', 8740, 'https://x.com/skeptic_tech/status/5'),

  ('33333333-0000-0000-0000-000000000006','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000005',
   'BREAKING: Major AI lab announces new safety framework amid growing regulatory pressure. Details emerging... #AISafety #Regulation',
   NOW()-INTERVAL '37 hours', 21400, 'https://x.com/globalvoices_/status/6'),

  ('33333333-0000-0000-0000-000000000007','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000008',
   'Our paper on algorithmic bias in social media recommendation systems got accepted at FAccT 2026! Very excited about this. The findings are stark. Link in bio.',
   NOW()-INTERVAL '35 hours', 5630, 'https://x.com/meena_policy/status/7'),

  ('33333333-0000-0000-0000-000000000008','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000006',
   'Series B funding roundup: 3 Indian AI startups raised $40M+ this week. The ecosystem is maturing fast. Full breakdown in the thread 🧵',
   NOW()-INTERVAL '33 hours', 6780, 'https://x.com/startupwala/status/8'),

  ('33333333-0000-0000-0000-000000000009','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000001',
   'Update on the AI literacy program: 500 rural students trained this month alone across 3 states. Technology is only meaningful if it''s accessible. 🙏 #DigitalIndia',
   NOW()-INTERVAL '30 hours', 9200, 'https://x.com/techpulse_in/status/9'),

  ('33333333-0000-0000-0000-000000000010','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000010',
   'Just ranked in the top 50 globally on the new multimodal Kaggle competition. The key insight: ensemble of a small vision-language model with traditional CV pipeline. Sharing notebook!',
   NOW()-INTERVAL '28 hours', 4100, 'https://x.com/dev_ananya/status/10'),

  ('33333333-0000-0000-0000-000000000011','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000002',
   'AI regulation in the EU is starting to bite. Three major deployments paused this week pending compliance review. This is just the beginning. #EUAI #Regulation',
   NOW()-INTERVAL '26 hours', 7890, 'https://x.com/aiwatch_global/status/11'),

  ('33333333-0000-0000-0000-000000000012','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000003',
   'Stop telling juniors that "prompt engineering" is a long-term career. It''s a skill, not a job title. Invest in fundamentals: math, stat, CS. Controversial but true.',
   NOW()-INTERVAL '24 hours', 15200, 'https://x.com/priya_tweets/status/12'),

  ('33333333-0000-0000-0000-000000000013','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000009',
   'We just launched free AI tools for 200 village panchayats. Healthcare, agriculture, local governance — all in local languages. This is what inclusive tech looks like. 🌱',
   NOW()-INTERVAL '21 hours', 3400, 'https://x.com/ngo_digitalink/status/13'),

  ('33333333-0000-0000-0000-000000000014','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000005',
   'Major deepfake incident detected in an ongoing election. Social platforms are scrambling. This is the AI threat we should have prepared for earlier. #Deepfake #Elections',
   NOW()-INTERVAL '18 hours', 34500, 'https://x.com/globalvoices_/status/14'),

  ('33333333-0000-0000-0000-000000000015','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000007',
   'The deepfake panic is overblown. Media detection tools exist. What''s lacking is media literacy. Blame the education system, not the technology.',
   NOW()-INTERVAL '16 hours', 11200, 'https://x.com/skeptic_tech/status/15'),

  ('33333333-0000-0000-0000-000000000016','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000008',
   'New MEITY guidelines on AI transparency are a step in the right direction, but enforcement mechanisms are still vague. Detailed analysis on my blog.',
   NOW()-INTERVAL '14 hours', 4300, 'https://x.com/meena_policy/status/16'),

  ('33333333-0000-0000-0000-000000000017','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000001',
   'AI in healthcare is saving lives in tier-2 cities. Radiologist AI at a Jaipur hospital caught 3 cancers missed in manual review this month alone. Incredible.',
   NOW()-INTERVAL '10 hours', 18700, 'https://x.com/techpulse_in/status/17'),

  ('33333333-0000-0000-0000-000000000018','11111111-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000004',
   'Just open-sourced a Flutter + Dart toolkit for building accessible mobile apps for low-literacy users. Please share! Link in bio 👇 #OpenSource #Flutter',
   NOW()-INTERVAL '7 hours', 2900, 'https://x.com/rohan_dev/status/18'),

  -- Telegram Posts
  ('33333333-0000-0000-0000-000000000019','11111111-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000011',
   '🔥 Big update: India''s first sovereign AI compute cluster goes live next month. 10,000 GPUs for domestic researchers. Details: [link] #IndiaAI #GovTech',
   NOW()-INTERVAL '46 hours', 3200, NULL),

  ('33333333-0000-0000-0000-000000000020','11111111-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000012',
   'BTC holding 61k strong. Next resistance at 67k. AI-driven trading bots now account for 43% of crypto volume according to new Chainalysis data. DYR.',
   NOW()-INTERVAL '40 hours', 8900, NULL),

  ('33333333-0000-0000-0000-000000000021','11111111-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000013',
   'Paper of the day: "Constitutional AI with Multi-Agent Debate" — agents argue against each other to surface flaws. Brilliant approach to alignment. PDF: [link]',
   NOW()-INTERVAL '34 hours', 4700, NULL),

  ('33333333-0000-0000-0000-000000000022','11111111-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000014',
   'ALERT 🚨 SEBI new circular on AI-driven robo-advisors. Mandatory explainability requirements from April 2027. All BFSI folks need to read this.',
   NOW()-INTERVAL '22 hours', 6100, NULL),

  ('33333333-0000-0000-0000-000000000023','11111111-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000015',
   'Draft Digital India Act 2026 analysis — Section 47 on AI intermediary liability is concerning. We''ve prepared a response brief. Sharing with stakeholders.',
   NOW()-INTERVAL '15 hours', 2800, NULL),

  ('33333333-0000-0000-0000-000000000024','11111111-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000011',
   '⚡ LIVE: Smart India Hackathon results just announced! 3 AI projects won top prizes. Incredible talent from tier-2 colleges. The future is bright 🇮🇳',
   NOW()-INTERVAL '5 hours', 12400, NULL),

  ('33333333-0000-0000-0000-000000000025','11111111-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000013',
   'Reminder: Weekly AI paper reading group TODAY at 8pm IST. Topic: Mechanistic interpretability of transformers. Zoom link in pinned message. All welcome!',
   NOW()-INTERVAL '2 hours', 1900, NULL);

-- ============================================================
-- SENTIMENT SCORES (one per post)
-- ============================================================
INSERT INTO sentiment_scores (id, post_id, sentiment_label, confidence, scored_at) VALUES
  ('44444444-0000-0000-0000-000000000001','33333333-0000-0000-0000-000000000001','positive',   0.91, NOW()-INTERVAL '47 hours'),
  ('44444444-0000-0000-0000-000000000002','33333333-0000-0000-0000-000000000002','neutral',    0.78, NOW()-INTERVAL '45 hours'),
  ('44444444-0000-0000-0000-000000000003','33333333-0000-0000-0000-000000000003','positive',   0.87, NOW()-INTERVAL '43 hours'),
  ('44444444-0000-0000-0000-000000000004','33333333-0000-0000-0000-000000000004','anxious',    0.72, NOW()-INTERVAL '41 hours'),
  ('44444444-0000-0000-0000-000000000005','33333333-0000-0000-0000-000000000005','against',    0.83, NOW()-INTERVAL '39 hours'),
  ('44444444-0000-0000-0000-000000000006','33333333-0000-0000-0000-000000000006','anxious',    0.88, NOW()-INTERVAL '37 hours'),
  ('44444444-0000-0000-0000-000000000007','33333333-0000-0000-0000-000000000007','positive',   0.82, NOW()-INTERVAL '35 hours'),
  ('44444444-0000-0000-0000-000000000008','33333333-0000-0000-0000-000000000008','positive',   0.79, NOW()-INTERVAL '33 hours'),
  ('44444444-0000-0000-0000-000000000009','33333333-0000-0000-0000-000000000009','supportive', 0.91, NOW()-INTERVAL '30 hours'),
  ('44444444-0000-0000-0000-000000000010','33333333-0000-0000-0000-000000000010','positive',   0.85, NOW()-INTERVAL '28 hours'),
  ('44444444-0000-0000-0000-000000000011','33333333-0000-0000-0000-000000000011','anxious',    0.76, NOW()-INTERVAL '26 hours'),
  ('44444444-0000-0000-0000-000000000012','33333333-0000-0000-0000-000000000012','against',    0.69, NOW()-INTERVAL '24 hours'),
  ('44444444-0000-0000-0000-000000000013','33333333-0000-0000-0000-000000000013','supportive', 0.94, NOW()-INTERVAL '21 hours'),
  ('44444444-0000-0000-0000-000000000014','33333333-0000-0000-0000-000000000014','anxious',    0.92, NOW()-INTERVAL '18 hours'),
  ('44444444-0000-0000-0000-000000000015','33333333-0000-0000-0000-000000000015','sarcastic',  0.71, NOW()-INTERVAL '16 hours'),
  ('44444444-0000-0000-0000-000000000016','33333333-0000-0000-0000-000000000016','neutral',    0.80, NOW()-INTERVAL '14 hours'),
  ('44444444-0000-0000-0000-000000000017','33333333-0000-0000-0000-000000000017','positive',   0.93, NOW()-INTERVAL '10 hours'),
  ('44444444-0000-0000-0000-000000000018','33333333-0000-0000-0000-000000000018','supportive', 0.88, NOW()-INTERVAL '7 hours'),
  ('44444444-0000-0000-0000-000000000019','33333333-0000-0000-0000-000000000019','positive',   0.86, NOW()-INTERVAL '46 hours'),
  ('44444444-0000-0000-0000-000000000020','33333333-0000-0000-0000-000000000020','neutral',    0.74, NOW()-INTERVAL '40 hours'),
  ('44444444-0000-0000-0000-000000000021','33333333-0000-0000-0000-000000000021','positive',   0.90, NOW()-INTERVAL '34 hours'),
  ('44444444-0000-0000-0000-000000000022','33333333-0000-0000-0000-000000000022','anxious',    0.85, NOW()-INTERVAL '22 hours'),
  ('44444444-0000-0000-0000-000000000023','33333333-0000-0000-0000-000000000023','against',    0.78, NOW()-INTERVAL '15 hours'),
  ('44444444-0000-0000-0000-000000000024','33333333-0000-0000-0000-000000000024','positive',   0.95, NOW()-INTERVAL '5 hours'),
  ('44444444-0000-0000-0000-000000000025','33333333-0000-0000-0000-000000000025','supportive', 0.82, NOW()-INTERVAL '2 hours');

-- ============================================================
-- TRENDS (top trending topics)
-- ============================================================
INSERT INTO trends (id, keyword_or_topic, platform_id, mention_count, growth_rate, window_start, window_end) VALUES
  ('55555555-0000-0000-0000-000000000001','#IndiaAI',          '11111111-0000-0000-0000-000000000001', 4820, 127.4, NOW()-INTERVAL '24 hours', NOW()),
  ('55555555-0000-0000-0000-000000000002','#Deepfake',         '11111111-0000-0000-0000-000000000001', 8230, 312.8, NOW()-INTERVAL '24 hours', NOW()),
  ('55555555-0000-0000-0000-000000000003','#AISafety',         '11111111-0000-0000-0000-000000000001', 3140, 89.2,  NOW()-INTERVAL '24 hours', NOW()),
  ('55555555-0000-0000-0000-000000000004','LLM Regulation',    '11111111-0000-0000-0000-000000000001', 2780, 67.5,  NOW()-INTERVAL '24 hours', NOW()),
  ('55555555-0000-0000-0000-000000000005','#SIH2026',          '11111111-0000-0000-0000-000000000001', 6400, 445.1, NOW()-INTERVAL '12 hours', NOW()),
  ('55555555-0000-0000-0000-000000000006','AI Healthcare India','11111111-0000-0000-0000-000000000001', 1890, 54.3,  NOW()-INTERVAL '24 hours', NOW()),
  ('55555555-0000-0000-0000-000000000007','#OpenSource',       '11111111-0000-0000-0000-000000000001', 1240, 23.8,  NOW()-INTERVAL '24 hours', NOW()),
  ('55555555-0000-0000-0000-000000000008','Constitutional AI', '11111111-0000-0000-0000-000000000002', 2100, 78.9,  NOW()-INTERVAL '24 hours', NOW()),
  ('55555555-0000-0000-0000-000000000009','SEBI AI Circular',  '11111111-0000-0000-0000-000000000002', 3400, 201.3, NOW()-INTERVAL '12 hours', NOW()),
  ('55555555-0000-0000-0000-000000000010','Digital India Act', '11111111-0000-0000-0000-000000000002', 1600, 45.2,  NOW()-INTERVAL '24 hours', NOW());

-- ============================================================
-- NETWORK EDGES (interactions between authors)
-- ============================================================
INSERT INTO network_edges (id, source_author_id, target_author_id, interaction_type, weight, occurred_at) VALUES
  -- Replies and retweets forming clusters
  ('66666666-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000004','22222222-0000-0000-0000-000000000001','reply',   2, NOW()-INTERVAL '46 hours'),
  ('66666666-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000003','22222222-0000-0000-0000-000000000002','retweet', 1, NOW()-INTERVAL '44 hours'),
  ('66666666-0000-0000-0000-000000000003','22222222-0000-0000-0000-000000000007','22222222-0000-0000-0000-000000000005','reply',   3, NOW()-INTERVAL '36 hours'),
  ('66666666-0000-0000-0000-000000000004','22222222-0000-0000-0000-000000000001','22222222-0000-0000-0000-000000000005','retweet', 4, NOW()-INTERVAL '35 hours'),
  ('66666666-0000-0000-0000-000000000005','22222222-0000-0000-0000-000000000008','22222222-0000-0000-0000-000000000002','mention', 2, NOW()-INTERVAL '33 hours'),
  ('66666666-0000-0000-0000-000000000006','22222222-0000-0000-0000-000000000010','22222222-0000-0000-0000-000000000003','reply',   1, NOW()-INTERVAL '27 hours'),
  ('66666666-0000-0000-0000-000000000007','22222222-0000-0000-0000-000000000006','22222222-0000-0000-0000-000000000001','retweet', 5, NOW()-INTERVAL '32 hours'),
  ('66666666-0000-0000-0000-000000000008','22222222-0000-0000-0000-000000000004','22222222-0000-0000-0000-000000000003','mention', 1, NOW()-INTERVAL '42 hours'),
  ('66666666-0000-0000-0000-000000000009','22222222-0000-0000-0000-000000000009','22222222-0000-0000-0000-000000000001','retweet', 3, NOW()-INTERVAL '29 hours'),
  ('66666666-0000-0000-0000-000000000010','22222222-0000-0000-0000-000000000005','22222222-0000-0000-0000-000000000007','reply',   2, NOW()-INTERVAL '15 hours'),
  ('66666666-0000-0000-0000-000000000011','22222222-0000-0000-0000-000000000002','22222222-0000-0000-0000-000000000008','mention', 1, NOW()-INTERVAL '25 hours'),
  ('66666666-0000-0000-0000-000000000012','22222222-0000-0000-0000-000000000011','22222222-0000-0000-0000-000000000013','forward', 6, NOW()-INTERVAL '45 hours'),
  ('66666666-0000-0000-0000-000000000013','22222222-0000-0000-0000-000000000012','22222222-0000-0000-0000-000000000014','forward', 4, NOW()-INTERVAL '39 hours'),
  ('66666666-0000-0000-0000-000000000014','22222222-0000-0000-0000-000000000015','22222222-0000-0000-0000-000000000013','reply',   2, NOW()-INTERVAL '14 hours'),
  ('66666666-0000-0000-0000-000000000015','22222222-0000-0000-0000-000000000014','22222222-0000-0000-0000-000000000011','forward', 3, NOW()-INTERVAL '21 hours');

-- ============================================================
-- DEMOGRAPHIC SUMMARIES
-- ============================================================
INSERT INTO demographic_summaries (id, platform_id, age_bracket, region, language, professional_interest, aggregate_count, computed_at) VALUES
  -- X Demographics
  ('77777777-0000-0000-0000-000000000001','11111111-0000-0000-0000-000000000001','18-24','India',  'en','Software Engineering', 34200, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000002','11111111-0000-0000-0000-000000000001','25-34','India',  'en','AI & Machine Learning', 67800, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000003','11111111-0000-0000-0000-000000000001','35-44','India',  'en','Tech Policy',           28400, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000004','11111111-0000-0000-0000-000000000001','45+',  'India',  'en','Entrepreneurship',      12600, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000005','11111111-0000-0000-0000-000000000001','18-24','USA',    'en','AI Research',            8900, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000006','11111111-0000-0000-0000-000000000001','25-34','USA',    'en','Startups',               14200, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000007','11111111-0000-0000-0000-000000000001','25-34','UK',     'en','Tech Journalism',         6800, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000008','11111111-0000-0000-0000-000000000001','25-34','India',  'hi','Startup Ecosystem',      19400, NOW()-INTERVAL '1 hour'),
  -- Telegram Demographics
  ('77777777-0000-0000-0000-000000000009','11111111-0000-0000-0000-000000000002','18-24','India',  'en','Crypto & Web3',         22100, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000010','11111111-0000-0000-0000-000000000002','25-34','India',  'en','AI Research',           41500, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000011','11111111-0000-0000-0000-000000000002','25-34','UAE',    'en','Finance & Trading',     31800, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000012','11111111-0000-0000-0000-000000000002','35-44','Global', 'en','Policy & Regulation',   18700, NOW()-INTERVAL '1 hour'),
  ('77777777-0000-0000-0000-000000000013','11111111-0000-0000-0000-000000000002','45+',  'India',  'hi','Government & Civic',    9200,  NOW()-INTERVAL '1 hour');
