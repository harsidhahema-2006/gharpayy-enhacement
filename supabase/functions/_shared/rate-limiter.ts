import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/**
 * Basic Rate Limiter using Supabase Database
 * In a high-traffic production scenario, a Redis-based limiter is preferred.
 * This implementation prevents brute-force abuse of public endpoints.
 */
export async function checkRateLimit(
  supabase: ReturnType<typeof createClient>,
  identifier: string, // e.g. IP address or User ID
  limit: number = 5,
  windowSeconds: number = 60
): Promise<{ allowed: boolean; remaining: number }> {
  const windowStart = new Date(Date.now() - windowSeconds * 1000).toISOString()

  // We use the analytics_events table or a dedicated rate_limits table
  // Here we've already created analytics_events in the migration
  const { data, count, error } = await supabase
    .from('analytics_events')
    .select('id', { count: 'exact' })
    .eq('event_name', 'api_request')
    .eq('metadata->>identifier', identifier)
    .gt('created_at', windowStart)

  if (error) {
    console.error('Rate limit check error:', error)
    return { allowed: true, remaining: 0 } // Fail open to avoid blocking users
  }

  const currentCount = count || 0
  
  if (currentCount >= limit) {
    return { allowed: false, remaining: 0 }
  }

  // Log the attempt
  await supabase.from('analytics_events').insert({
    event_name: 'api_request',
    metadata: { identifier, timestamp: new Date().toISOString() }
  })

  return { allowed: true, remaining: limit - currentCount - 1 }
}
