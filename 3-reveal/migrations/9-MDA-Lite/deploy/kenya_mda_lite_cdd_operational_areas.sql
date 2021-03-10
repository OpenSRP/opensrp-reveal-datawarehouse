-- Deploy 9-MDA-Lite:kenya_mda_lite_cdd_operational_areas to pg
-- requires: 9-MDA-Lite:kenya_mda_lite_structures
-- requires: irs_lite_zambia_2020:zambia_irs_lite_structures
-- requires: jurisdictions_materialized_view
-- requires: opensrp_settings

BEGIN;

SET search_path TO :"schema",public;

CREATE MATERIALIZED VIEW IF NOT EXISTS kenya_mda_lite_cdd_operational_areas AS
SELECT
    main_query.*
FROM (
    SELECT
        public.uuid_generate_v5(
            '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
            concat(operational_area_query.structure_jurisdiction_id, operational_area_query.plan_id)
        ) AS id,
        operational_area_query.plan_id as plan_id,
        kenya_lite_jurisdictions.jurisdiction_id AS jurisdiction_id,
        kenya_lite_jurisdictions.jurisdiction_parent_id AS jurisdiction_parent_id,
        kenya_lite_jurisdictions.jurisdiction_name AS jurisdiction_name,
        kenya_lite_jurisdictions.jurisdiction_depth AS jurisdiction_depth,
        kenya_lite_jurisdictions.jurisdiction_path AS jurisdiction_path,
        kenya_lite_jurisdictions.jurisdiction_name_path AS jurisdiction_name_path,
        operational_area_query.treated_male_1_4 AS treated_male_1_4,
        operational_area_query.treated_male_5_14 AS treated_male_5_14,
        operational_area_query.treated_male_above_15 AS treated_male_above_15,
        operational_area_query.treated_female_1_4 AS treated_female_1_4,
        operational_area_query.treated_female_5_14 AS treated_female_5_14,
        operational_area_query.treated_female_above_15 AS treated_female_above_15,
        operational_area_query.total_males AS total_males,
        operational_area_query.total_females AS total_females,
        operational_area_query.total_all_genders AS total_all_genders
    FROM reveal_stage.plans
    LEFT JOIN (
        SELECT
            jurisdictions.plan_id,
            jurisdictions.structure_jurisdiction_id,
            COALESCE(sum(daily_summary.treated_male_1_4), 0) AS treated_male_1_4,
            COALESCE(sum(daily_summary.treated_male_5_14), 0) AS treated_male_5_14,
            COALESCE(sum(daily_summary.treated_male_above_15), 0) AS treated_male_above_15,
            COALESCE(sum(daily_summary.treated_female_1_4), 0) AS treated_female_1_4,
            COALESCE(sum(daily_summary.treated_female_5_14), 0) AS treated_female_5_14,
            COALESCE(sum(daily_summary.treated_female_above_15), 0) AS treated_female_above_15,
            COALESCE(sum(daily_summary.total_males), 0) AS total_males,
            COALESCE(sum(daily_summary.total_females), 0) AS total_females,
            COALESCE(sum(daily_summary.total_all_genders), 0) AS total_all_genders
        FROM (
            SELECT
                structures.plan_id,
                structures.structure_jurisdiction_id
            FROM kenya_mda_lite_structures_mini AS structures
            WHERE structures.plan_id IS NOT NULL
            GROUP BY structures.plan_id, structures.structure_jurisdiction_id
        ) AS jurisdictions
        LEFT JOIN LATERAL (
            SELECT

            subq.treated_male_1_4 AS treated_male_1_4,
            subq.treated_male_5_14 AS treated_male_5_14,
            subq.treated_male_above_15 AS treated_male_above_15,
            subq.treated_female_1_4 AS treated_female_1_4,
            subq.treated_female_5_14 AS treated_female_5_14,
            subq.treated_female_above_15 AS treated_female_above_15,
            subq.total_males AS total_males,
            subq.total_females AS total_females,
            subq.total_all_genders AS total_all_genders

            FROM (
                SELECT
                    SUM(COALESCE (events.form_data->'treated_male_1-4'->>0, '0')::int) AS treated_male_1_4,
                    SUM(COALESCE (events.form_data->'treated_male_5-14'->>0, '0')::int) AS treated_male_5_14,
                    SUM(COALESCE (events.form_data->'treated_male_above_15'->>0, '0')::int) AS treated_male_above_15,

                    SUM(COALESCE (events.form_data->'treated_female_1-4'->>0, '0')::int) AS treated_female_1_4,
                    SUM(COALESCE (events.form_data->'treated_female_5-14'->>0, '0')::int) AS treated_female_5_14,
                    SUM(COALESCE (events.form_data->'treated_female_above_15'->>0, '0')::int) AS treated_female_above_15,

                    SUM(COALESCE (events.form_data->'treated_male_1-4'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_male_5-14'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_male_above_15'->>0, '0')::int) AS total_males,

                    SUM(COALESCE (events.form_data->'treated_female_1-4'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_female_5-14'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_female_above_15'->>0, '0')::int) AS total_females,

                    SUM(COALESCE (events.form_data->'treated_male_1-4'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_male_5-14'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_male_above_15'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_female_1-4'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_female_5-14'->>0, '0')::int +
                    COALESCE (events.form_data->'treated_female_above_15'->>0, '0')::int) AS total_all_genders

                FROM public.events
                WHERE jurisdictions.structure_jurisdiction_id  = events.location_id
                AND events.plan_id = jurisdictions.plan_id
                AND events.entity_type = 'Structure'
                AND events.event_type = 'cdd_supervisor_daily_summary'
                GROUP BY jurisdictions.plan_id, jurisdictions.structure_jurisdiction_id
            ) AS subq
        ) AS daily_summary ON true
        GROUP BY jurisdictions.plan_id, jurisdictions.structure_jurisdiction_id
    ) AS operational_area_query ON operational_area_query.plan_id = plans.identifier
    LEFT JOIN pending.jurisdictions_materialized_view AS kenya_lite_jurisdictions
        ON operational_area_query.structure_jurisdiction_id = kenya_lite_jurisdictions.jurisdiction_id
    LEFT JOIN LATERAL (
        SELECT
            key as jurisdiction_id,
            COALESCE(data->>'value', '0')::INTEGER as target
        FROM reveal_stage.opensrp_settings
        WHERE identifier = 'jurisdiction_metadata-target'
        AND operational_area_query.structure_jurisdiction_id = opensrp_settings.key
        ORDER BY COALESCE(data->>'serverVersion', '0')::BIGINT DESC
        LIMIT 1
    ) AS jurisdiction_target_query ON true
    LEFT JOIN LATERAL (
        SELECT
            key as jurisdiction_id,
            COALESCE(data->>'value', '0')::INTEGER as structure
        FROM reveal_stage.opensrp_settings
        WHERE identifier = 'jurisdiction_metadata-structures'
        AND operational_area_query.structure_jurisdiction_id = opensrp_settings.key
        ORDER BY COALESCE(data->>'serverVersion', '0')::BIGINT DESC
        LIMIT 1
    ) AS jurisdiction_structure_query ON true
    WHERE plans.intervention_type IN ('MDA-Lite') AND plans.status NOT IN ('draft', 'retired')
) AS main_query;



COMMIT;
