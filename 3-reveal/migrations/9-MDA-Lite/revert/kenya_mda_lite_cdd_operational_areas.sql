-- Revert 9-MDA-Lite:kenya_mda_lite_cdd_operational_areas from pg

BEGIN;

SET search_path TO :"schema",public;

DROP MATERIALIZED VIEW kenya_mda_lite_cdd_operational_areas CASCADE;

COMMIT;
