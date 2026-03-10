-- ENUMs for RBAC
CREATE TYPE public.user_role AS ENUM ('admin', 'manager', 'agent', 'owner', 'customer');

-- User Roles Table
CREATE TABLE IF NOT EXISTS public.user_roles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role public.user_role NOT NULL DEFAULT 'customer',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Audit Log Table
CREATE TABLE IF NOT EXISTS public.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Analytics Events Table
CREATE TABLE IF NOT EXISTS public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Payment Transactions Table
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_id UUID REFERENCES public.reservations(id),
    customer_id UUID REFERENCES auth.users(id),
    amount DECIMAL(12,2) NOT NULL,
    currency TEXT DEFAULT 'INR',
    status TEXT NOT NULL, -- pending, successful, failed
    provider TEXT DEFAULT 'razorpay',
    provider_txn_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Notifications Table (Ensuring it exists or updating)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT,
    is_read BOOLEAN DEFAULT false,
    link TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RBAC helper function
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS public.user_role
LANGUAGE sql SECURITY DEFINER
AS $$
    SELECT role FROM public.user_roles WHERE user_id = auth.uid();
$$;

-- Audit Logging function
CREATE OR REPLACE FUNCTION public.logger_trigger_fn()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.audit_log (user_id, action, entity_type, entity_id, metadata)
    VALUES (
        auth.uid(),
        TG_OP,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id 
            ELSE NEW.id 
        END,
        jsonb_build_object(
            'old', CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
            'new', CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply Audit Log to critical tables
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'audit_leads_trigger') THEN
        CREATE TRIGGER audit_leads_trigger AFTER INSERT OR UPDATE OR DELETE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.logger_trigger_fn();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'audit_bookings_trigger') THEN
        CREATE TRIGGER audit_bookings_trigger AFTER INSERT OR UPDATE OR DELETE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.logger_trigger_fn();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'audit_properties_trigger') THEN
        CREATE TRIGGER audit_properties_trigger AFTER INSERT OR UPDATE OR DELETE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.logger_trigger_fn();
    END IF;
END $$;

-- Full-Text Search for Discovery
-- Check if fts_doc column exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='properties' AND column_name='fts_doc') THEN
        ALTER TABLE public.properties ADD COLUMN fts_doc tsvector;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.properties_fts_update() RETURNS trigger AS $$
BEGIN
  new.fts_doc :=
    setweight(to_tsvector('english', coalesce(new.name,'')), 'A') ||
    setweight(to_tsvector('english', coalesce(new.area,'')), 'B') ||
    setweight(to_tsvector('english', coalesce(new.city,'')), 'B');
  return new;
END
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_properties_fts') THEN
        CREATE TRIGGER tr_properties_fts BEFORE INSERT OR UPDATE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.properties_fts_update();
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_properties_fts ON public.properties USING GIN(fts_doc);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_assigned_agent ON public.leads(assigned_agent_id);
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON public.leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_visits_lead_id ON public.visits(lead_id);
CREATE INDEX IF NOT EXISTS idx_visits_scheduled_at ON public.visits(scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_property_id ON public.bookings(property_id);
CREATE INDEX IF NOT EXISTS idx_bookings_booking_status ON public.bookings(booking_status);
CREATE INDEX IF NOT EXISTS idx_properties_zone_id ON public.properties(zone_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_res_id ON public.payment_transactions(reservation_id);

-- RLS Hardening (Example for Leads)
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Auth users read leads" ON public.leads;
CREATE POLICY "RLS_Leads_Isolation" ON public.leads
    FOR ALL
    TO authenticated
    USING (
        CASE 
            WHEN public.get_user_role() = 'admin' THEN true -- Admis see all
            WHEN public.get_user_role() = 'agent' THEN (assigned_agent_id IN (SELECT id FROM agents WHERE user_id = auth.uid())) -- Agents see assigned
            ELSE false
        END
    );

-- Enable RLS for new tables
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins full access" ON public.user_roles FOR ALL USING (public.get_user_role() = 'admin');
CREATE POLICY "Admins read audit" ON public.audit_log FOR SELECT USING (public.get_user_role() = 'admin');
