-- Function to generate internal notifications
CREATE OR REPLACE FUNCTION public.create_notification_fn()
RETURNS TRIGGER AS $$
DECLARE
    target_user_id UUID;
    notify_title TEXT;
    notify_body TEXT;
BEGIN
    -- Handle Lead Assignment
    IF (TG_TABLE_NAME = 'leads' AND TG_OP = 'UPDATE') THEN
        IF (NEW.assigned_agent_id IS DISTINCT FROM OLD.assigned_agent_id AND NEW.assigned_agent_id IS NOT NULL) THEN
            SELECT user_id INTO target_user_id FROM public.agents WHERE id = NEW.assigned_agent_id;
            notify_title := 'New Lead Assigned';
            notify_body := 'You have been assigned a new lead: ' || NEW.name;
        END IF;
    END IF;

    -- Handle Visit Scheduling
    IF (TG_TABLE_NAME = 'visits' AND TG_OP = 'INSERT') THEN
        -- Notify the assigned agent of the lead
        SELECT a.user_id INTO target_user_id 
        FROM public.leads l 
        JOIN public.agents a ON l.assigned_agent_id = a.id 
        WHERE l.id = NEW.lead_id;
        
        notify_title := 'Visit Scheduled';
        notify_body := 'A visitor scheduled a site visit for lead ID: ' || NEW.lead_id;
    END IF;

    -- Handle Booking Confirmation
    IF (TG_TABLE_NAME = 'bookings' AND TG_OP = 'UPDATE') THEN
        IF (NEW.booking_status = 'confirmed' AND OLD.booking_status != 'confirmed') THEN
            -- Notify the Property Owner
            SELECT owner_id INTO target_user_id FROM public.properties WHERE id = NEW.property_id;
            
            notify_title := 'New Booking Confirmed';
            notify_body := 'A new booking has been confirmed for your property.';
        END IF;
    END IF;

    -- Insert into notifications table if target found
    IF (target_user_id IS NOT NULL) THEN
        INSERT INTO public.notifications (user_id, title, body, type)
        VALUES (target_user_id, notify_title, notify_body, TG_TABLE_NAME);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Triggers for Notifications
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_notify_leads') THEN
        CREATE TRIGGER tr_notify_leads AFTER UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.create_notification_fn();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_notify_visits') THEN
        CREATE TRIGGER tr_notify_visits AFTER INSERT ON public.visits FOR EACH ROW EXECUTE FUNCTION public.create_notification_fn();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_notify_bookings') THEN
        CREATE TRIGGER tr_notify_bookings AFTER UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.create_notification_fn();
    END IF;
END $$;
