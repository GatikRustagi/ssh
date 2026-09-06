require('dotenv').config();
const { Scraper } = require('agent-twitter-client');
const { createClient } = require('@supabase/supabase-js');

// ==============================================================================
// Configuration — set these in your .env file:
//
//   TWITTER_USERNAME   — your Twitter / X username
//   TWITTER_PASSWORD   — your Twitter / X password
//   TWITTER_EMAIL      — your Twitter / X email (often required by login flow)
//   SUPABASE_URL       — https://<project-ref>.supabase.co
//   SUPABASE_KEY       — service_role or anon key from Project Settings → API
//   SCRAPE_HASHTAG     — default hashtag, e.g. #SIH2026
//   SCRAPE_MAX_ITEMS   — max tweets to fetch per run (default 50)
// ==============================================================================

const TWITTER_USERNAME = process.env.TWITTER_USERNAME;
const TWITTER_PASSWORD = process.env.TWITTER_PASSWORD;
const TWITTER_EMAIL    = process.env.TWITTER_EMAIL;
const SUPABASE_URL     = process.env.SUPABASE_URL;
const SUPABASE_KEY     = process.env.SUPABASE_KEY;
const DEFAULT_HASHTAG  = process.env.SCRAPE_HASHTAG  || '#SIH2026';
const DEFAULT_MAX      = parseInt(process.env.SCRAPE_MAX_ITEMS || '50', 10);

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Extract all hashtags from a tweet text string. */
function extractHashtags(text) {
    if (!text) return [];
    const matches = text.match(/#[\w\u0080-\uFFFF]+/g) || [];
    return matches.map((h) => h.toLowerCase());
}

/** Simple Twitter URL builder from handle + tweet id. */
function tweetUrl(handle, id) {
    return `https://twitter.com/${handle}/status/${id}`;
}

// ── Client Init ───────────────────────────────────────────────────────────────

async function initClients() {
    if (!TWITTER_USERNAME || !TWITTER_PASSWORD || !SUPABASE_URL || !SUPABASE_KEY) {
        console.error(
            '[!] Missing required environment variables.\n' +
            '    Please set TWITTER_USERNAME, TWITTER_PASSWORD, SUPABASE_URL, SUPABASE_KEY in your .env'
        );
        process.exit(1);
    }

    console.log('[*] Initialising Twitter scraper...');
    const scraper = new Scraper();

    try {
        await scraper.login(TWITTER_USERNAME, TWITTER_PASSWORD, TWITTER_EMAIL);
        console.log('[+] Logged into Twitter successfully');
    } catch (err) {
        console.error('[!] Twitter login failed:', err.message || err);
        process.exit(1);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
    return { scraper, supabase };
}

// ── Platform helper ───────────────────────────────────────────────────────────

/**
 * Returns the UUID of the "Twitter" platform row, creating it if absent.
 */
async function getOrCreatePlatform(supabase) {
    const { data, error } = await supabase
        .from('platforms')
        .select('id')
        .eq('name', 'Twitter');

    if (error) throw error;
    if (data && data.length > 0) return data[0].id;

    const { data: inserted, error: insertErr } = await supabase
        .from('platforms')
        .insert({ name: 'Twitter', status: 'live', last_synced_at: new Date().toISOString() })
        .select();

    if (insertErr) throw insertErr;
    return inserted[0].id;
}

// ── Author upsert ─────────────────────────────────────────────────────────────

/**
 * Returns the author row ID for a given handle, creating a row if absent.
 * @param {object} supabase
 * @param {string} platformId
 * @param {object} tweet  — agent-twitter-client tweet object
 * @returns {Promise<string|null>} author UUID or null on failure
 */
async function upsertAuthor(supabase, platformId, tweet) {
    const handle = tweet.username;
    if (!handle) return null;

    const { data } = await supabase
        .from('authors')
        .select('id')
        .eq('platform_id', platformId)
        .eq('handle', handle);

    if (data && data.length > 0) return data[0].id;

    const { data: inserted, error } = await supabase
        .from('authors')
        .insert({
            platform_id:  platformId,
            handle:       handle,
            display_name: tweet.name || handle,
            bio_text:     tweet.userBio || '',
            follower_count: tweet.followersCount || 0,
        })
        .select();

    if (error || !inserted || inserted.length === 0) {
        console.warn(`  [!] Could not insert author @${handle}:`, error?.message);
        return null;
    }

    console.log(`  [+] New author: @${handle}`);
    return inserted[0].id;
}

// ── Post insert ───────────────────────────────────────────────────────────────

/**
 * Inserts a tweet into the posts table (skips if URL already exists).
 */
async function insertPost(supabase, platformId, authorId, tweet) {
    const url = tweetUrl(tweet.username, tweet.id);

    const { data: existing } = await supabase
        .from('posts')
        .select('id')
        .eq('url', url);

    if (existing && existing.length > 0) {
        console.log(`    -> Already exists: ${url}`);
        return;
    }

    const engagement =
        (tweet.likes    || 0) +
        (tweet.retweets || 0) +
        (tweet.replies  || 0);

    const { error } = await supabase.from('posts').insert({
        platform_id:        platformId,
        author_id:          authorId,
        content_text:       tweet.text || '',
        posted_at:          tweet.timeParsed ? tweet.timeParsed.toISOString() : new Date().toISOString(),
        raw_engagement_count: engagement,
        url,
    });

    if (error) {
        console.warn(`  [!] Post insert failed (${url}):`, error.message);
    } else {
        console.log(`    -> Inserted: ${url}`);
    }
}

// ── Trends upsert ─────────────────────────────────────────────────────────────

/**
 * Given a map of { hashtag: [tweetObjects] }, compute mention counts and
 * growth_rate (mentions per hour since oldest tweet), then upsert into the
 * trends table.
 *
 * Growth rate formula: mentionCount / hoursSpanned (capped at 1 hour min)
 * This gives a "mentions per hour" velocity which maps to growth_rate in the DB.
 */
async function upsertTrends(supabase, platformId, hashtagMap) {
    const now = new Date();
    const rows = [];

    for (const [hashtag, tweets] of Object.entries(hashtagMap)) {
        if (tweets.length === 0) continue;

        const times = tweets
            .map((t) => t.timeParsed || now)
            .map((d) => (d instanceof Date ? d : new Date(d)));

        const oldest = new Date(Math.min(...times.map((d) => d.getTime())));
        const newest = new Date(Math.max(...times.map((d) => d.getTime())));
        const hoursSpanned = Math.max(
            (now.getTime() - oldest.getTime()) / 3_600_000,
            1
        );

        const mentionCount = tweets.length;
        const growthRate   = parseFloat((mentionCount / hoursSpanned).toFixed(2));

        rows.push({
            platform_id:     platformId,
            keyword_or_topic: hashtag,
            mention_count:   mentionCount,
            growth_rate:     growthRate,
            window_start:    oldest.toISOString(),
            window_end:      newest.toISOString(),
        });
    }

    if (rows.length === 0) {
        console.log('[!] No hashtags found in tweets — trends table not updated.');
        return;
    }

    // Sort by mention count desc for nice console output
    rows.sort((a, b) => b.mention_count - a.mention_count);

    console.log(`\n[*] Top extracted hashtags:`);
    rows.slice(0, 10).forEach((r, i) =>
        console.log(`  ${i + 1}. ${r.keyword_or_topic} — ${r.mention_count} mentions (${r.growth_rate}/hr)`)
    );

    // Upsert (conflict on platform_id + keyword_or_topic if your DB has that unique constraint)
    // Otherwise insert fresh rows each run so the timeline grows.
    const { error } = await supabase.from('trends').insert(rows);
    if (error) {
        console.error('[!] Failed to insert trends:', error.message);
    } else {
        console.log(`[+] Inserted ${rows.length} trend rows into Supabase.`);
    }
}

// ── Core scrape loop ──────────────────────────────────────────────────────────

/**
 * Scrapes tweets for a hashtag, stores authors + posts,
 * and optionally returns per-tweet data for trend analysis.
 *
 * @param {object} supabase
 * @param {object} scraper
 * @param {string} platformId
 * @param {string} hashtag
 * @param {number} maxItems
 * @returns {Promise<object[]>} array of raw tweet objects successfully processed
 */
async function scrapeHashtag(supabase, scraper, platformId, hashtag, maxItems) {
    console.log(`\n[*] Searching for "${hashtag}" (max ${maxItems} tweets)…`);
    const processed = [];

    try {
        const tweets = scraper.searchTweets(hashtag, maxItems, 1 /* SearchMode.Latest */);
        let count = 0;

        for await (const tweet of tweets) {
            if (count >= maxItems) break;

            const authorId = await upsertAuthor(supabase, platformId, tweet);
            if (!authorId) { count++; continue; }

            await insertPost(supabase, platformId, authorId, tweet);
            processed.push(tweet);
            count++;
        }
    } catch (err) {
        console.error('[!] Error during tweet search:', err.message || err);
    }

    console.log(`[*] Processed ${processed.length} tweets.`);
    return processed;
}

// ── Public commands ───────────────────────────────────────────────────────────

/**
 * Scrape tweets for a hashtag and store authors + posts.
 * Usage: node twitter_scraper.js hashtag [#tag] [maxItems]
 */
async function scrapeAndStore(hashtag = DEFAULT_HASHTAG, maxItems = DEFAULT_MAX) {
    const { scraper, supabase } = await initClients();
    const platformId = await getOrCreatePlatform(supabase);
    console.log(`[*] Platform ID: ${platformId}`);

    await scrapeHashtag(supabase, scraper, platformId, hashtag, maxItems);
    console.log('\n[+] Done — posts table updated.');
}

/**
 * Scrape tweets for a hashtag AND extract trending hashtags into the trends table.
 * Usage: node twitter_scraper.js analyze [#tag] [maxItems]
 */
async function scrapeAndAnalyzeTrends(hashtag = DEFAULT_HASHTAG, maxItems = DEFAULT_MAX) {
    const { scraper, supabase } = await initClients();
    const platformId = await getOrCreatePlatform(supabase);
    console.log(`[*] Platform ID: ${platformId}`);

    const tweets = await scrapeHashtag(supabase, scraper, platformId, hashtag, maxItems);

    // Build a map of hashtag → [tweets that mentioned it]
    const hashtagMap = {};
    for (const tweet of tweets) {
        const tags = extractHashtags(tweet.text);
        for (const tag of tags) {
            if (!hashtagMap[tag]) hashtagMap[tag] = [];
            hashtagMap[tag].push(tweet);
        }
    }

    await upsertTrends(supabase, platformId, hashtagMap);
    console.log('\n[+] Done — posts and trends tables updated.');
}

/**
 * Fetch a user's timeline and store tweets.
 * Usage: node twitter_scraper.js timeline <handle> [maxItems]
 */
async function scrapeUserTimeline(handle, maxItems = DEFAULT_MAX) {
    const { scraper, supabase } = await initClients();
    const platformId = await getOrCreatePlatform(supabase);
    console.log(`[+] Fetching timeline for @${handle}`);

    const timeline = scraper.getUserTimeline(handle, maxItems);
    let count = 0;

    for await (const tweet of timeline) {
        if (count >= maxItems) break;
        const authorId = await upsertAuthor(supabase, platformId, tweet);
        if (!authorId) { count++; continue; }
        await insertPost(supabase, platformId, authorId, tweet);
        count++;
    }

    console.log('[+] Done — timeline tweets stored.');
}

/**
 * Fetch current Twitter trends via twitterapi.io and store them.
 * Requires TWITTER_TRENDS_ENDPOINT and TWITTER_TRENDS_KEY env vars.
 * Usage: node twitter_scraper.js trends
 */
async function storeTrends() {
    const { supabase } = await initClients();
    const platformId  = await getOrCreatePlatform(supabase);
    const endpoint    = process.env.TWITTER_TRENDS_ENDPOINT;
    const apiKey      = process.env.TWITTER_TRENDS_KEY;

    if (!endpoint || !apiKey || apiKey === 'your-twitterapi-io-key') {
        console.error(
            '[!] Please set TWITTER_TRENDS_ENDPOINT and TWITTER_TRENDS_KEY in your .env\n' +
            '    (Get an API key from https://twitterapi.io)'
        );
        process.exit(1);
    }

    try {
        const resp = await fetch(`${endpoint}?key=${apiKey}`);
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        const trends = data.trends || [];

        const rows = trends.map((t) => ({
            platform_id:     platformId,
            keyword_or_topic: typeof t === 'string' ? t : t.name,
            mention_count:   typeof t === 'object' ? (t.tweet_volume || 0) : 0,
            growth_rate:     0,
            window_start:    new Date().toISOString(),
            window_end:      new Date().toISOString(),
        }));

        if (rows.length === 0) { console.log('[!] No trends returned from API.'); return; }

        const { error } = await supabase.from('trends').insert(rows);
        if (error) console.error('[!] Error inserting trends:', error.message);
        else console.log(`[+] Inserted ${rows.length} trends.`);
    } catch (err) {
        console.error('[!] Failed to fetch/store trends:', err.message || err);
    }
}

// ── CLI dispatcher ────────────────────────────────────────────────────────────

if (require.main === module) {
    const [, , cmd, arg, maxArg] = process.argv;
    const maxItems = maxArg ? parseInt(maxArg, 10) : DEFAULT_MAX;

    switch (cmd) {
        case 'hashtag':
            scrapeAndStore(arg || DEFAULT_HASHTAG, maxItems).catch(console.error);
            break;

        case 'analyze':
            // Scrape + extract trending hashtags → writes posts AND trends table
            scrapeAndAnalyzeTrends(arg || DEFAULT_HASHTAG, maxItems).catch(console.error);
            break;

        case 'timeline':
            if (!arg) {
                console.error('[!] Usage: node twitter_scraper.js timeline <handle>');
                process.exit(1);
            }
            scrapeUserTimeline(arg, maxItems).catch(console.error);
            break;

        case 'trends':
            storeTrends().catch(console.error);
            break;

        default:
            console.log(
                '\nUsage:\n' +
                '  node twitter_scraper.js hashtag  [#tag] [maxItems]  — scrape tweets by hashtag\n' +
                '  node twitter_scraper.js analyze  [#tag] [maxItems]  — scrape + extract trends\n' +
                '  node twitter_scraper.js timeline <handle> [maxItems] — scrape user timeline\n' +
                '  node twitter_scraper.js trends                       — fetch from twitterapi.io\n'
            );
    }
}
