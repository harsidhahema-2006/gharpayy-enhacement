-- Ensure pg_cron is available (Supabase standard)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1. Function to clear stale reservations (soft locks > 24h or expired)
CREATE OR REPLACE FUNCTION public.cleanup_stale_reservations()
RETURNS void AS $$
BEGIN
    UPDATE public.reservations
    SET reservation_status = 'cancelled'
    WHERE reservation_status = 'pending'
    AND (expires_at < now() OR created_at < now() - interval '24 hours');
    
    -- Also deactivate stale soft locks
    UPDATE public.soft_locks
    SET is_active = false
    WHERE is_active = true
    AND (expires_at < now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function to generate daily analytics snapshots
CREATE OR REPLACE FUNCTION public.generate_daily_analytics()
RETURNS void AS $$
BEGIN
    -- This would typically insert into a summary table. 
    -- For now, we log the aggregation event.
    INSERT INTO public.analytics_events (event_name, metadata)
    VALUES ('daily_summary_generated', jsonb_build_object(
        'date', current_date,
        'total_leads', (SELECT count(*) FROM leads WHERE created_at >= current_date),
        'total_bookings', (SELECT count(*) FROM bookings WHERE created_at >= current_date)
    ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule Jobs
-- Note: '0 * * * *' = Every Hour
-- Note: '0 0 * * *' = Every Midnight

SELECT cron.schedule('cleanup-reservations-hourly', '0 * * * *', 'SELECT public.cleanup_stale_reservations()');
SELECT cron.schedule('daily-analytics-midnight', '0 0 * * *', 'SELECT public.generate_daily_analytics()');
SELECT cron.schedule('recalculate-lead-scores-daily', '0 1 * * *', 'SELECT public.recalculate_all_lead_scores()');
