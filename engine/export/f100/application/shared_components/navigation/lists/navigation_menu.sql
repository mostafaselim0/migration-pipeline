prompt --application/shared_components/navigation/lists/navigation_menu
begin
--   Manifest
--     LIST: Navigation Menu
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2024.11.30'
,p_release=>'24.2.0'
,p_default_workspace_id=>1600195100832328
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'SMART'
);
wwv_flow_imp_shared.create_list(
 p_id=>wwv_flow_imp.id(1807960701231450)
,p_name=>'Navigation Menu'
,p_list_status=>'PUBLIC'
,p_version_scn=>2508032
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(1819669560231501)
,p_list_item_display_sequence=>10
,p_list_item_link_text=>'Home'
,p_list_item_link_target=>'f?p=&APP_ID.:1:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-home'
,p_list_item_current_type=>'TARGET_PAGE'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(2402350173259853)
,p_list_item_display_sequence=>20
,p_list_item_link_text=>'Currencies'
,p_list_item_link_target=>'f?p=&APP_ID.:2:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-table-pointer'
,p_list_item_current_type=>'COLON_DELIMITED_PAGE_LIST'
,p_list_item_current_for_pages=>'2'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(2435288709282467)
,p_list_item_display_sequence=>30
,p_list_item_link_text=>'Chart of Accounts'
,p_list_item_link_target=>'f?p=&APP_ID.:3:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-table'
,p_list_item_current_type=>'COLON_DELIMITED_PAGE_LIST'
,p_list_item_current_for_pages=>'3,4'
);
wwv_flow_imp_shared.create_list_item(
 p_id=>wwv_flow_imp.id(2566639505320170)
,p_list_item_display_sequence=>40
,p_list_item_link_text=>'Sales Orders'
,p_list_item_link_target=>'f?p=&APP_ID.:5:&APP_SESSION.::&DEBUG.:::'
,p_list_item_icon=>'fa-layout-header-sidebar-left'
,p_list_item_current_type=>'COLON_DELIMITED_PAGE_LIST'
,p_list_item_current_for_pages=>'5,6'
);
wwv_flow_imp.component_end;
end;
/
