-- Table: public.device_inclinations

-- DROP TABLE IF EXISTS public.device_inclinations;

CREATE TABLE IF NOT EXISTS public.device_inclinations
(
    device_id text COLLATE pg_catalog."default",
    inclination numeric,
    "time" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.device_inclinations
    OWNER to postgres;
-- Index: device_deviations_device_id_time_deviation_idx

-- DROP INDEX IF EXISTS public.device_deviations_device_id_time_deviation_idx;

CREATE UNIQUE INDEX IF NOT EXISTS device_deviations_device_id_time_deviation_idx
    ON public.device_inclinations USING btree
    (device_id COLLATE pg_catalog."default" ASC NULLS LAST, "time" ASC NULLS LAST, inclination ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: device_deviations_time_idx

-- DROP INDEX IF EXISTS public.device_deviations_time_idx;

CREATE INDEX IF NOT EXISTS device_deviations_time_idx
    ON public.device_inclinations USING btree
    ("time" DESC NULLS FIRST)
    TABLESPACE pg_default;





-- View: public.device_position_view

-- DROP MATERIALIZED VIEW IF EXISTS public.device_position_view;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.device_position_view
TABLESPACE pg_default
AS
 SELECT count(*) FILTER (WHERE dd.inclination > (- 30::numeric)) AS active_count,
    count(*) FILTER (WHERE dd.inclination < (- 45::numeric)) AS inactive_count,
    dd.device_id,
    max(dd."time") AS max_time
   FROM device_inclinations dd
  WHERE (dd."time" IN ( SELECT dd2."time"
           FROM device_inclinations dd2
          WHERE dd2.device_id = dd.device_id
          ORDER BY dd2."time" DESC
         LIMIT 5))
  GROUP BY dd.device_id
WITH DATA;

ALTER TABLE IF EXISTS public.device_position_view
    OWNER TO postgres;

CREATE UNIQUE INDEX device_position_view_device_id_idx
    ON public.device_position_view USING btree
    (device_id COLLATE pg_catalog."default")
    TABLESPACE pg_default;




-- FUNCTION: public.tg_refresh_lti_view()

-- DROP FUNCTION IF EXISTS public.tg_refresh_lti_view();

CREATE OR REPLACE FUNCTION public.tg_refresh_lti_view()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY device_position_view;
    RETURN NULL;
END;
$BODY$;

ALTER FUNCTION public.tg_refresh_lti_view()
    OWNER TO postgres;



-- FUNCTION: public.update_modified_column()

-- DROP FUNCTION IF EXISTS public.update_modified_column();

CREATE OR REPLACE FUNCTION public.update_modified_column()
    RETURNS trigger
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
BEGIN
   IF row(NEW.upper) IS DISTINCT FROM row(OLD.upper) THEN
      NEW.updated_at = now();
      RETURN NEW;
   ELSE
      RETURN OLD;
   END IF;
END;
$BODY$;

ALTER FUNCTION public.update_modified_column()
    OWNER TO postgres;





-- Trigger: tg_refresh_lti_view

-- DROP TRIGGER IF EXISTS tg_refresh_lti_view ON public.device_inclinations;

CREATE TRIGGER tg_refresh_lti_view
    AFTER INSERT OR DELETE OR UPDATE
    ON public.device_inclinations
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.tg_refresh_lti_view();

-- Trigger: ts_insert_blocker

-- DROP TRIGGER IF EXISTS ts_insert_blocker ON public.device_inclinations;

CREATE TRIGGER ts_insert_blocker
    BEFORE INSERT
    ON public.device_inclinations
    FOR EACH ROW
    EXECUTE FUNCTION _timescaledb_internal.insert_blocker();

    
-- INSERT INTO public.device_inclinations(device_id, inclination) VALUES ('123', 123);