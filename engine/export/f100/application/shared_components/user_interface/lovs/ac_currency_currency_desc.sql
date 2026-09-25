prompt --application/shared_components/user_interface/lovs/ac_currency_currency_desc
begin
--   Manifest
--     AC_CURRENCY.CURRENCY_DESC
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2024.11.30'
,p_release=>'24.2.0'
,p_default_workspace_id=>1600195100832328
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'SMART'
);
wwv_flow_imp_shared.create_list_of_values(
 p_id=>wwv_flow_imp.id(2417239801282456)
,p_lov_name=>'AC_CURRENCY.CURRENCY_DESC'
,p_source_type=>'TABLE'
,p_location=>'LOCAL'
,p_query_table=>'AC_CURRENCY'
,p_return_column_name=>'CURRENCY_CODE'
,p_display_column_name=>'CURRENCY_DESC'
,p_default_sort_column_name=>'CURRENCY_DESC'
,p_default_sort_direction=>'ASC'
,p_version_scn=>2504587
);
wwv_flow_imp.component_end;
end;
/
