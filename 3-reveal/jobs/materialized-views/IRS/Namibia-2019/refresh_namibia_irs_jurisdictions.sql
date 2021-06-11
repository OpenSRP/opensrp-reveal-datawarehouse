-- Suggestion is to refresh this every 10min
SELECT NOW();
SELECT refresh_mat_view('namibia_irs_structures', FALSE);
SELECT NOW();
SELECT refresh_mat_view('namibia_focus_area_irs', TRUE);
SELECT NOW();
SELECT refresh_mat_view('namibia_irs_jurisdictions', TRUE);
SELECT NOW();
