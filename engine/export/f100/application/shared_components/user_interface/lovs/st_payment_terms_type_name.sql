prompt --application/shared_components/user_interface/lovs/st_payment_terms_type_name
begin
--   Manifest
--     ST_PAYMENT_TERMS.TYPE_NAME
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
 p_id=>wwv_flow_imp.id(2511045292320135)
,p_lov_name=>'ST_PAYMENT_TERMS.TYPE_NAME'
,p_source_type=>'TABLE'
,p_location=>'LOCAL'
,p_query_table=>'ST_PAYMENT_TERMS'
,p_return_column_name=>'SERIAL'
,p_display_column_name=>'TYPE_NAME'
,p_default_sort_column_name=>'TYPE_NAME'
,p_default_sort_direction=>'ASC'
,p_version_scn=>2507924
);
wwv_flow_imp.component_end;
end;
/
