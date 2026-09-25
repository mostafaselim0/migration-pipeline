prompt --application/shared_components/user_interface/lovs/customer_name_a
begin
--   Manifest
--     CUSTOMER.NAME_A
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
 p_id=>wwv_flow_imp.id(2501136809320128)
,p_lov_name=>'CUSTOMER.NAME_A'
,p_source_type=>'TABLE'
,p_location=>'LOCAL'
,p_query_table=>'CUSTOMER'
,p_return_column_name=>'CODE'
,p_display_column_name=>'NAME_A'
,p_default_sort_column_name=>'NAME_A'
,p_default_sort_direction=>'ASC'
,p_version_scn=>2507923
);
wwv_flow_imp.component_end;
end;
/
