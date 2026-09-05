// ================================================================
// Supabase Edge Function: X (Twitter) Ingestion
// Path: supabase/functions/ingest_x/index.ts
// Runtime: Deno (TypeScript)
// ================================================================
//
// TODO: Implement real X API v2 ingestion.
//
// This edge function should:
// 1. Authenticate with X API v2 using Bearer Token (OAuth 2.0)
//    - Store the token in Supabase Vault: select vault.create_secret('X_BEARER_TOKEN', '...')
//    - Retrieve it here: const token = Deno.env.get('X_BEARER_TOKEN')
//
// 2. Fetch recent tweets from target handles/keywords:
//    GET https://api.twitter.com/2/tweets/search/recent
//      ?query=<keyword> OR from:<handle>
//      &tweet.fields=created_at,public_metrics,author_id
//      &user.fields=public_metrics,description,location
//      &expansions=author_id
//      &max_results=100
//
// 3. For each tweet:
//    a. Upsert the author into `authors` table
//    b. Insert the tweet into `posts` table
//    c. Call the ML sentiment classification Edge Function
//       (or queue it for async processing)
//    d. Update `trends` table by counting hashtag mentions
//    e. Build network_edges from reply_to / mention relationships
//
// 4. Schedule this function to run every 15 minutes via pg_cron:
//    select cron.schedule('ingest-x', '*/15 * * * *',
//      $$ select net.http_post('https://<ref>.supabase.co/functions/v1/ingest_x') $$);
//
// ================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// TODO: Store this in Supabase Vault, not as a plain env var in production
const X_BEARER_TOKEN = Deno.env.get("X_BEARER_TOKEN") ?? "";

serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // TODO: Replace this stub with real X API calls
  console.log("[ingest_x] Edge function triggered — ingestion not yet implemented.");
  console.log("[ingest_x] TODO steps:");
  console.log("  1. Fetch recent tweets from X API v2");
  console.log("  2. Upsert authors into `authors` table");
  console.log("  3. Insert posts into `posts` table");
  console.log("  4. Trigger ML sentiment classification");
  console.log("  5. Update `trends` with hashtag counts");
  console.log("  6. Build `network_edges` from reply/mention graph");

  // Update platform last_synced_at to indicate the function ran
  await supabase
    .from("platforms")
    .update({ last_synced_at: new Date().toISOString() })
    .eq("name", "X (Twitter)");

  return new Response(
    JSON.stringify({ status: "stub", message: "X ingestion not yet implemented" }),
    { headers: { "Content-Type": "application/json" } },
  );
});
