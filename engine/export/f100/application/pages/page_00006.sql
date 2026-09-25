prompt --application/pages/page_00006
begin
--   Manifest
--     PAGE: 00006
--   Manifest End
wwv_flow_imp.component_begin (
 p_version_yyyy_mm_dd=>'2024.11.30'
,p_release=>'24.2.0'
,p_default_workspace_id=>1600195100832328
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'SMART'
);
wwv_flow_imp_page.create_page(
 p_id=>6
,p_name=>'Sales Order'
,p_alias=>'SALES-ORDER'
,p_step_title=>'Sales Order'
,p_autocomplete_on_off=>'OFF'
,p_page_template_options=>'#DEFAULT#'
,p_dialog_chained=>'N'
,p_protection_level=>'C'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(2495464954320114)
,p_plug_name=>'Form on ST_SALES_ORDER'
,p_region_template_options=>'#DEFAULT#:t-Region--scrollBody'
,p_plug_template=>4072358936313175081
,p_plug_display_sequence=>10
,p_query_type=>'TABLE'
,p_query_table=>'ST_SALES_ORDER'
,p_query_order_by=>'TRNS_SERIAL'
,p_include_rowid_column=>false
,p_is_editable=>true
,p_edit_operations=>'i:u:d'
,p_lost_update_check_type=>'VALUES'
,p_plug_source_type=>'NATIVE_FORM'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(2604865605320195)
,p_plug_name=>'Breadcrumb'
,p_region_template_options=>'#DEFAULT#:t-BreadcrumbRegion--useBreadcrumbTitle'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>2531463326621247859
,p_plug_display_sequence=>10
,p_plug_display_point=>'REGION_POSITION_01'
,p_menu_id=>wwv_flow_imp.id(1807472898231448)
,p_plug_source_type=>'NATIVE_BREADCRUMB'
,p_menu_template_id=>4072363345357175094
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(2605573138320231)
,p_plug_name=>'Sales Order'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>30
,p_query_type=>'TABLE'
,p_query_table=>'ST_SALES_ORDER_DET'
,p_query_where=>wwv_flow_string.join(wwv_flow_t_varchar2(
'TRNS_TYPE_CODE = :P6_TRNS_TYPE_CODE',
' and TRNS_SERIAL = :P6_TRNS_SERIAL'))
,p_include_rowid_column=>false
,p_plug_source_type=>'NATIVE_IG'
,p_ajax_items_to_submit=>'P6_TRNS_TYPE_CODE, P6_TRNS_SERIAL'
,p_plug_display_condition_type=>'ITEM_IS_NOT_NULL'
,p_plug_display_when_condition=>'P6_TRNS_TYPE_CODE'
,p_prn_page_header=>'Sales Order'
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2606884368320235)
,p_name=>'APEX$ROW_SELECTOR'
,p_item_type=>'NATIVE_ROW_SELECTOR'
,p_display_sequence=>10
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'enable_multi_select', 'Y',
  'hide_control', 'N',
  'show_select_all', 'Y')).to_clob
,p_enable_hide=>true
,p_is_primary_key=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2607394577320235)
,p_name=>'APEX$ROW_ACTION'
,p_item_type=>'NATIVE_ROW_ACTION'
,p_label=>'Actions'
,p_heading_alignment=>'CENTER'
,p_display_sequence=>20
,p_value_alignment=>'CENTER'
,p_enable_hide=>true
,p_is_primary_key=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2608312598320237)
,p_name=>'TRNS_TYPE_CODE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TRNS_TYPE_CODE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>30
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_enable_filter=>false
,p_enable_hide=>true
,p_is_primary_key=>true
,p_default_type=>'ITEM'
,p_default_expression=>'P6_TRNS_TYPE_CODE'
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2609313748320237)
,p_name=>'TRNS_SERIAL'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TRNS_SERIAL'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>40
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_enable_filter=>false
,p_enable_hide=>true
,p_is_primary_key=>true
,p_default_type=>'ITEM'
,p_default_expression=>'P6_TRNS_SERIAL'
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2610332188320239)
,p_name=>'SERIAL'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'SERIAL'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_HIDDEN'
,p_display_sequence=>50
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
,p_enable_filter=>false
,p_enable_hide=>true
,p_is_primary_key=>true
,p_duplicate_value=>true
,p_include_in_export=>false
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2611359328320239)
,p_name=>'ITEM_GROUP_CODE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ITEM_GROUP_CODE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Item Group Code'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>60
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>true
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2612375036320240)
,p_name=>'ITEM_CODE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ITEM_CODE'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Item Code'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>70
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'send_on_page_submit', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>true
,p_max_length=>18
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_is_required=>false
,p_filter_text_case=>'MIXED'
,p_filter_exact_match=>true
,p_filter_lov_type=>'DISTINCT'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2613351079320240)
,p_name=>'UNIT_CODE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'UNIT_CODE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Unit Code'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>80
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>true
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2614322824320240)
,p_name=>'QUANTITY'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'QUANTITY'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Quantity'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>90
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>true
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2615336478320242)
,p_name=>'BONUS'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'BONUS'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Bonus'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>100
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2616331372320242)
,p_name=>'UNIT_PRICE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'UNIT_PRICE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Unit Price'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>110
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2617330671320242)
,p_name=>'UNIT_PRICE_CURR'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'UNIT_PRICE_CURR'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Unit Price Curr'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>120
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2618329572320242)
,p_name=>'RESERVED_QTY'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'RESERVED_QTY'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Reserved Qty'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>130
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2619313660320243)
,p_name=>'ITEM_CONFG_ID'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ITEM_CONFG_ID'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Item Confg Id'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>140
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2620392934320243)
,p_name=>'BASIC_QTY'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'BASIC_QTY'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Basic Qty'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>150
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>true
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2621370432320243)
,p_name=>'DET_DISC'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DET_DISC'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Det Disc'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>160
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2622379087320245)
,p_name=>'DISC'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DISC'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Disc'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>170
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2623316061320245)
,p_name=>'DET_DISC_CURR'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DET_DISC_CURR'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Det Disc Curr'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>180
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2624394502320246)
,p_name=>'R_ITEM_SERIAL'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'R_ITEM_SERIAL'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'R Item Serial'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>190
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2625390809320246)
,p_name=>'STORE_CODE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'STORE_CODE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Store Code'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>200
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2626317261320246)
,p_name=>'DSRV_BONUS'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DSRV_BONUS'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Dsrv Bonus'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>210
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2627350043320246)
,p_name=>'ALT_KEY'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ALT_KEY'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXT_FIELD'
,p_heading=>'Alt Key'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>220
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'send_on_page_submit', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
,p_max_length=>50
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_is_required=>false
,p_filter_text_case=>'MIXED'
,p_filter_exact_match=>true
,p_filter_lov_type=>'DISTINCT'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2628337257320248)
,p_name=>'TAX_CODE1'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TAX_CODE1'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Tax Code1'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>230
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2629355068320248)
,p_name=>'TAX_VALUE1'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TAX_VALUE1'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Tax Value1'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>240
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2630378172320248)
,p_name=>'TAX_CODE2'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TAX_CODE2'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Tax Code2'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>250
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2631320976320248)
,p_name=>'TAX_VALUE2'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TAX_VALUE2'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Tax Value2'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>260
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2632350621320250)
,p_name=>'OFFER_DISC_VAL1'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_VAL1'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Val1'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>270
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2633322697320250)
,p_name=>'OFFER_DISC_VAL2'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_VAL2'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Val2'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>280
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2634315164320250)
,p_name=>'OFFER_DISC_VAL3'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_VAL3'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Val3'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>290
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2635300433320250)
,p_name=>'OFFER_DISC_DSRV_VAL1'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_DSRV_VAL1'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Dsrv Val1'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>300
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2636350428320251)
,p_name=>'OFFER_DISC_DSRV_VAL2'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_DSRV_VAL2'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Dsrv Val2'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>310
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2637329005320251)
,p_name=>'OFFER_DISC_DSRV_VAL3'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_DSRV_VAL3'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Dsrv Val3'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>320
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2638345960320251)
,p_name=>'OFFER_DISC_PER1'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_PER1'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Per1'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>330
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2639308949320251)
,p_name=>'OFFER_DISC_PER2'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_PER2'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Per2'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>340
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2640362596320253)
,p_name=>'OFFER_DISC_PER3'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_PER3'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Per3'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>350
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2641304017320253)
,p_name=>'OFFER_DISC_INDX1'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_INDX1'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Indx1'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>360
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2642395597320253)
,p_name=>'OFFER_DISC_INDX2'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_INDX2'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Indx2'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>370
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2643346924320253)
,p_name=>'OFFER_DISC_INDX3'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_INDX3'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Indx3'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>380
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2644353405320254)
,p_name=>'OFFER_DISC_RSRV'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OFFER_DISC_RSRV'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Offer Disc Rsrv'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>390
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2645332300320254)
,p_name=>'USER_DET_DISC'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'USER_DET_DISC'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'User Det Disc'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>400
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2646332823320254)
,p_name=>'USER_DET_DISC_CURR'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'USER_DET_DISC_CURR'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'User Det Disc Curr'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>410
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2647345392320254)
,p_name=>'DISC1_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DISC1_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Disc1 Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>420
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2648383664320256)
,p_name=>'DISC2_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DISC2_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Disc2 Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>430
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2649354457320256)
,p_name=>'DISC1_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DISC1_VALUE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Disc1 Value'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>440
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2650304862320257)
,p_name=>'DISC2_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DISC2_VALUE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Disc2 Value'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>450
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2651360198320257)
,p_name=>'PROFIT_PRCN'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'PROFIT_PRCN'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Profit Prcn'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>460
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2652379004320259)
,p_name=>'PROFIT_VAL'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'PROFIT_VAL'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Profit Val'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>470
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2653317053320259)
,p_name=>'REMARK'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'REMARK'
,p_data_type=>'VARCHAR2'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_TEXTAREA'
,p_heading=>'Remark'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>480
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
,p_is_required=>false
,p_max_length=>2000
,p_enable_filter=>true
,p_filter_operators=>'C:S:CASE_INSENSITIVE:REGEXP'
,p_filter_is_required=>false
,p_filter_text_case=>'MIXED'
,p_filter_exact_match=>true
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>false
,p_enable_control_break=>false
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2654330659320259)
,p_name=>'ITM_CNT'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ITM_CNT'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Itm Cnt'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>490
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2655316633320260)
,p_name=>'DISC3_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DISC3_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Disc3 Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>500
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2656351477320260)
,p_name=>'DISC3_VALUE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'DISC3_VALUE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Disc3 Value'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>510
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2657374295320260)
,p_name=>'BONUS_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'BONUS_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Bonus Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>520
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2658318484320260)
,p_name=>'EXTRA_BONUS_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'EXTRA_BONUS_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Extra Bonus Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>530
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2659376798320260)
,p_name=>'EXTRA_BONUS'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'EXTRA_BONUS'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Extra Bonus'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>540
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2660346400320262)
,p_name=>'AUTO_DISC'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'AUTO_DISC'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Auto Disc'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>550
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2661327329320262)
,p_name=>'ORG_DISC1_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ORG_DISC1_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Org Disc1 Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>560
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2662335565320264)
,p_name=>'ORG_DISC2_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ORG_DISC2_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Org Disc2 Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>570
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2663389233320264)
,p_name=>'ORG_DISC3_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ORG_DISC3_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Org Disc3 Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>580
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2664318390320264)
,p_name=>'ORG_BONUS_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ORG_BONUS_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Org Bonus Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>590
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2665306441320265)
,p_name=>'ORG_EXTRA_BONUS_RATIO'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ORG_EXTRA_BONUS_RATIO'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Org Extra Bonus Ratio'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>600
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2666320243320265)
,p_name=>'ORG_UNIT_PRICE_CURR'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ORG_UNIT_PRICE_CURR'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Org Unit Price Curr'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>610
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2667349053320265)
,p_name=>'LAST_EXPIRE_DATE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'LAST_EXPIRE_DATE'
,p_data_type=>'DATE'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_DATE_PICKER_APEX'
,p_heading=>'Last Expire Date'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>620
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_date_ranges=>'ALL'
,p_filter_lov_type=>'DISTINCT'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2668352215320265)
,p_name=>'TEMP_QUANTITY'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'TEMP_QUANTITY'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Temp Quantity'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>630
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2669358834320267)
,p_name=>'OR_DATE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'OR_DATE'
,p_data_type=>'DATE'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_DATE_PICKER_APEX'
,p_heading=>'Or Date'
,p_heading_alignment=>'LEFT'
,p_display_sequence=>640
,p_value_alignment=>'LEFT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_date_ranges=>'ALL'
,p_filter_lov_type=>'DISTINCT'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_region_column(
 p_id=>wwv_flow_imp.id(2670332531320267)
,p_name=>'ORG_CLASS_CODE'
,p_source_type=>'DB_COLUMN'
,p_source_expression=>'ORG_CLASS_CODE'
,p_data_type=>'NUMBER'
,p_session_state_data_type=>'VARCHAR2'
,p_is_query_only=>false
,p_item_type=>'NATIVE_NUMBER_FIELD'
,p_heading=>'Org Class Code'
,p_heading_alignment=>'RIGHT'
,p_display_sequence=>650
,p_value_alignment=>'RIGHT'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
,p_is_required=>false
,p_enable_filter=>true
,p_filter_is_required=>false
,p_filter_lov_type=>'NONE'
,p_use_as_row_header=>false
,p_enable_sort_group=>true
,p_enable_control_break=>true
,p_enable_hide=>true
,p_enable_pivot=>false
,p_is_primary_key=>false
,p_duplicate_value=>true
,p_include_in_export=>true
);
wwv_flow_imp_page.create_interactive_grid(
 p_id=>wwv_flow_imp.id(2606026923320232)
,p_internal_uid=>2606026923320232
,p_is_editable=>true
,p_edit_operations=>'i:u:d'
,p_lost_update_check_type=>'VALUES'
,p_add_row_if_empty=>true
,p_submit_checked_rows=>false
,p_lazy_loading=>false
,p_requires_filter=>false
,p_select_first_row=>true
,p_fixed_row_height=>true
,p_pagination_type=>'SCROLL'
,p_show_total_row_count=>true
,p_show_toolbar=>true
,p_toolbar_buttons=>'SEARCH_COLUMN:SEARCH_FIELD:ACTIONS_MENU:RESET'
,p_enable_save_public_report=>false
,p_enable_subscriptions=>true
,p_enable_flashback=>true
,p_define_chart_view=>true
,p_enable_download=>true
,p_enable_mail_download=>true
,p_fixed_header=>'PAGE'
,p_show_icon_view=>false
,p_show_detail_view=>false
);
wwv_flow_imp_page.create_ig_report(
 p_id=>wwv_flow_imp.id(2606445818320234)
,p_interactive_grid_id=>wwv_flow_imp.id(2606026923320232)
,p_static_id=>'26065'
,p_type=>'PRIMARY'
,p_default_view=>'GRID'
,p_show_row_number=>false
,p_settings_area_expanded=>true
);
wwv_flow_imp_page.create_ig_report_view(
 p_id=>wwv_flow_imp.id(2606698288320234)
,p_report_id=>wwv_flow_imp.id(2606445818320234)
,p_view_type=>'GRID'
,p_srv_exclude_null_values=>false
,p_srv_only_display_columns=>true
,p_edit_mode=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2607732173320237)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>0
,p_column_id=>wwv_flow_imp.id(2607394577320235)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2608724137320237)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>1
,p_column_id=>wwv_flow_imp.id(2608312598320237)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2609799673320239)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>2
,p_column_id=>wwv_flow_imp.id(2609313748320237)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2610784290320239)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>3
,p_column_id=>wwv_flow_imp.id(2610332188320239)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2611738494320240)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>4
,p_column_id=>wwv_flow_imp.id(2611359328320239)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2612731801320240)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>5
,p_column_id=>wwv_flow_imp.id(2612375036320240)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2613767932320240)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>6
,p_column_id=>wwv_flow_imp.id(2613351079320240)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2614731146320240)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>7
,p_column_id=>wwv_flow_imp.id(2614322824320240)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2615771405320242)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>8
,p_column_id=>wwv_flow_imp.id(2615336478320242)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2616770408320242)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>9
,p_column_id=>wwv_flow_imp.id(2616331372320242)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2617756772320242)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>10
,p_column_id=>wwv_flow_imp.id(2617330671320242)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2618714127320242)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>11
,p_column_id=>wwv_flow_imp.id(2618329572320242)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2619733442320243)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>12
,p_column_id=>wwv_flow_imp.id(2619313660320243)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2620746166320243)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>13
,p_column_id=>wwv_flow_imp.id(2620392934320243)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2621786432320243)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>14
,p_column_id=>wwv_flow_imp.id(2621370432320243)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2622737722320245)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>15
,p_column_id=>wwv_flow_imp.id(2622379087320245)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2623792666320245)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>16
,p_column_id=>wwv_flow_imp.id(2623316061320245)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2624780339320246)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>17
,p_column_id=>wwv_flow_imp.id(2624394502320246)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2625795779320246)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>18
,p_column_id=>wwv_flow_imp.id(2625390809320246)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2626705396320246)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>19
,p_column_id=>wwv_flow_imp.id(2626317261320246)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2627713872320246)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>20
,p_column_id=>wwv_flow_imp.id(2627350043320246)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2628714008320248)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>21
,p_column_id=>wwv_flow_imp.id(2628337257320248)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2629798104320248)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>22
,p_column_id=>wwv_flow_imp.id(2629355068320248)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2630723659320248)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>23
,p_column_id=>wwv_flow_imp.id(2630378172320248)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2631769466320250)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>24
,p_column_id=>wwv_flow_imp.id(2631320976320248)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2632774615320250)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>25
,p_column_id=>wwv_flow_imp.id(2632350621320250)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2633702095320250)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>26
,p_column_id=>wwv_flow_imp.id(2633322697320250)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2634783594320250)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>27
,p_column_id=>wwv_flow_imp.id(2634315164320250)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2635784834320251)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>28
,p_column_id=>wwv_flow_imp.id(2635300433320250)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2636726336320251)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>29
,p_column_id=>wwv_flow_imp.id(2636350428320251)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2637753727320251)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>30
,p_column_id=>wwv_flow_imp.id(2637329005320251)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2638761191320251)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>31
,p_column_id=>wwv_flow_imp.id(2638345960320251)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2639774623320253)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>32
,p_column_id=>wwv_flow_imp.id(2639308949320251)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2640785502320253)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>33
,p_column_id=>wwv_flow_imp.id(2640362596320253)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2641771594320253)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>34
,p_column_id=>wwv_flow_imp.id(2641304017320253)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2642741092320253)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>35
,p_column_id=>wwv_flow_imp.id(2642395597320253)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2643702506320254)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>36
,p_column_id=>wwv_flow_imp.id(2643346924320253)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2644747666320254)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>37
,p_column_id=>wwv_flow_imp.id(2644353405320254)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2645744426320254)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>38
,p_column_id=>wwv_flow_imp.id(2645332300320254)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2646736305320254)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>39
,p_column_id=>wwv_flow_imp.id(2646332823320254)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2647707174320256)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>40
,p_column_id=>wwv_flow_imp.id(2647345392320254)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2648789994320256)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>41
,p_column_id=>wwv_flow_imp.id(2648383664320256)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2649752236320257)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>42
,p_column_id=>wwv_flow_imp.id(2649354457320256)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2650768155320257)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>43
,p_column_id=>wwv_flow_imp.id(2650304862320257)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2651725569320259)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>44
,p_column_id=>wwv_flow_imp.id(2651360198320257)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2652732939320259)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>45
,p_column_id=>wwv_flow_imp.id(2652379004320259)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2653771078320259)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>46
,p_column_id=>wwv_flow_imp.id(2653317053320259)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2654796581320259)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>47
,p_column_id=>wwv_flow_imp.id(2654330659320259)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2655758038320260)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>48
,p_column_id=>wwv_flow_imp.id(2655316633320260)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2656726828320260)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>49
,p_column_id=>wwv_flow_imp.id(2656351477320260)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2657724123320260)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>50
,p_column_id=>wwv_flow_imp.id(2657374295320260)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2658774607320260)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>51
,p_column_id=>wwv_flow_imp.id(2658318484320260)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2659772752320262)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>52
,p_column_id=>wwv_flow_imp.id(2659376798320260)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2660764554320262)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>53
,p_column_id=>wwv_flow_imp.id(2660346400320262)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2661757636320264)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>54
,p_column_id=>wwv_flow_imp.id(2661327329320262)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2662721040320264)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>55
,p_column_id=>wwv_flow_imp.id(2662335565320264)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2663799745320264)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>56
,p_column_id=>wwv_flow_imp.id(2663389233320264)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2664724796320265)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>57
,p_column_id=>wwv_flow_imp.id(2664318390320264)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2665786646320265)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>58
,p_column_id=>wwv_flow_imp.id(2665306441320265)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2666732406320265)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>59
,p_column_id=>wwv_flow_imp.id(2666320243320265)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2667735911320265)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>60
,p_column_id=>wwv_flow_imp.id(2667349053320265)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2668730992320267)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>61
,p_column_id=>wwv_flow_imp.id(2668352215320265)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2669788997320267)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>62
,p_column_id=>wwv_flow_imp.id(2669358834320267)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_ig_report_column(
 p_id=>wwv_flow_imp.id(2670734370320267)
,p_view_id=>wwv_flow_imp.id(2606698288320234)
,p_display_seq=>63
,p_column_id=>wwv_flow_imp.id(2670332531320267)
,p_is_visible=>true
,p_is_frozen=>false
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(2562822371320165)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_button_name=>'SAVE'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Apply Changes'
,p_button_position=>'CHANGE'
,p_button_alignment=>'RIGHT'
,p_button_condition=>':P6_TRNS_TYPE_CODE is not null and :P6_TRNS_SERIAL is not null'
,p_button_condition2=>'SQL'
,p_button_condition_type=>'EXPRESSION'
,p_database_action=>'UPDATE'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(2561894887320164)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_button_name=>'CANCEL'
,p_button_action=>'REDIRECT_PAGE'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Cancel'
,p_button_position=>'CLOSE'
,p_button_alignment=>'RIGHT'
,p_button_redirect_url=>'f?p=&APP_ID.:5:&APP_SESSION.::&DEBUG.:::'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(2563268960320165)
,p_button_sequence=>40
,p_button_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_button_name=>'CREATE'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Create'
,p_button_position=>'CREATE'
,p_button_alignment=>'RIGHT'
,p_button_condition=>':P6_TRNS_TYPE_CODE is null or :P6_TRNS_SERIAL is null'
,p_button_condition2=>'SQL'
,p_button_condition_type=>'EXPRESSION'
,p_database_action=>'INSERT'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(2562457153320164)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_button_name=>'DELETE'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_image_alt=>'Delete'
,p_button_position=>'DELETE'
,p_button_alignment=>'RIGHT'
,p_button_execute_validations=>'N'
,p_confirm_message=>'&APP_TEXT$DELETE_MSG!RAW.'
,p_confirm_style=>'danger'
,p_button_condition=>':P6_TRNS_TYPE_CODE is not null and :P6_TRNS_SERIAL is not null'
,p_button_condition2=>'SQL'
,p_button_condition_type=>'EXPRESSION'
,p_database_action=>'DELETE'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(2563638334320165)
,p_button_sequence=>60
,p_button_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_button_name=>'GET_NEXT_TRNS_TYPE_CODE'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>2349107722467437027
,p_button_image_alt=>'Next'
,p_button_position=>'NEXT'
,p_button_condition=>'P6_TRNS_TYPE_CODE_NEXT'
,p_button_condition_type=>'ITEM_IS_NOT_NULL'
,p_icon_css_classes=>'fa-chevron-right'
,p_button_comment=>'This button is needed for Get Next or Previous Primary Key Value process.'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(2563515514320165)
,p_button_sequence=>50
,p_button_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_button_name=>'GET_PREVIOUS_TRNS_TYPE_CODE'
,p_button_action=>'SUBMIT'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>2349107722467437027
,p_button_image_alt=>'Previous'
,p_button_position=>'PREVIOUS'
,p_button_condition=>'P6_TRNS_TYPE_CODE_PREV'
,p_button_condition_type=>'ITEM_IS_NOT_NULL'
,p_icon_css_classes=>'fa-chevron-left'
,p_button_comment=>'This button is needed for Get Next or Previous Primary Key Value process.'
);
wwv_flow_imp_page.create_page_branch(
 p_id=>wwv_flow_imp.id(2564446355320167)
,p_branch_action=>'f?p=&APP_ID.:6:&APP_SESSION.::&DEBUG.::P6_TRNS_TYPE_CODE,P6_TRNS_SERIAL:&P6_TRNS_TYPE_CODE_NEXT.,&P6_TRNS_SERIAL_NEXT.'
,p_branch_point=>'AFTER_PROCESSING'
,p_branch_type=>'REDIRECT_URL'
,p_branch_when_button_id=>wwv_flow_imp.id(2563638334320165)
,p_branch_sequence=>1
,p_branch_comment=>'This button is needed for Get Next or Previous Primary Key Value process.'
);
wwv_flow_imp_page.create_page_branch(
 p_id=>wwv_flow_imp.id(2564845748320168)
,p_branch_action=>'f?p=&APP_ID.:6:&APP_SESSION.::&DEBUG.::P6_TRNS_TYPE_CODE,P6_TRNS_SERIAL:&P6_TRNS_TYPE_CODE_PREV.,&P6_TRNS_SERIAL_PREV.'
,p_branch_point=>'AFTER_PROCESSING'
,p_branch_type=>'REDIRECT_URL'
,p_branch_when_button_id=>wwv_flow_imp.id(2563515514320165)
,p_branch_sequence=>1
,p_branch_comment=>'This button is needed for Get Next or Previous Primary Key Value process.'
);
wwv_flow_imp_page.create_page_branch(
 p_id=>wwv_flow_imp.id(2565101955320168)
,p_branch_action=>'f?p=&APP_ID.:5:&APP_SESSION.::&DEBUG.:::&success_msg=#SUCCESS_MSG#'
,p_branch_point=>'AFTER_PROCESSING'
,p_branch_type=>'REDIRECT_URL'
,p_branch_sequence=>1
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2495827290320117)
,p_name=>'P6_TRNS_TYPE_CODE'
,p_source_data_type=>'NUMBER'
,p_is_primary_key=>true
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Trns Type Code'
,p_source=>'TRNS_TYPE_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_HIDDEN'
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2496213979320120)
,p_name=>'P6_TRNS_TYPE_CODE_PREV'
,p_is_query_only=>true
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_display_as=>'NATIVE_HIDDEN'
,p_is_persistent=>'N'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2496677605320120)
,p_name=>'P6_TRNS_TYPE_CODE_NEXT'
,p_is_query_only=>true
,p_item_sequence=>30
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_display_as=>'NATIVE_HIDDEN'
,p_is_persistent=>'N'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2497037658320120)
,p_name=>'P6_TRNS_SERIAL'
,p_source_data_type=>'NUMBER'
,p_is_primary_key=>true
,p_item_sequence=>40
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Trns Serial'
,p_source=>'TRNS_SERIAL'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_HIDDEN'
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2497431653320120)
,p_name=>'P6_TRNS_SERIAL_PREV'
,p_is_query_only=>true
,p_item_sequence=>50
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_display_as=>'NATIVE_HIDDEN'
,p_is_persistent=>'N'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2497862262320121)
,p_name=>'P6_TRNS_SERIAL_NEXT'
,p_is_query_only=>true
,p_item_sequence=>60
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_display_as=>'NATIVE_HIDDEN'
,p_is_persistent=>'N'
,p_protection_level=>'S'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'value_protected', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2498291261320121)
,p_name=>'P6_ORDER_SERIAL'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>70
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Order Serial'
,p_source=>'ORDER_SERIAL'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2498691965320126)
,p_name=>'P6_ORDER_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>80
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Order Date'
,p_source=>'ORDER_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2499028309320126)
,p_name=>'P6_LOADING_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>90
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Loading Date'
,p_source=>'LOADING_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2499492657320126)
,p_name=>'P6_INVOICE_NUMBER'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>100
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Invoice Number'
,p_source=>'INVOICE_NUMBER'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>32
,p_cMaxlength=>50
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2499829918320126)
,p_name=>'P6_DOC_NO'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>110
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Doc No'
,p_source=>'DOC_NO'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2500238581320126)
,p_name=>'P6_DELIVERY_TERMS'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>120
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Delivery Terms'
,p_source=>'DELIVERY_TERMS'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>32
,p_cMaxlength=>200
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2500629648320126)
,p_name=>'P6_PAY_TERM'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>130
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Pay Term'
,p_source=>'PAY_TERM'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>32
,p_cMaxlength=>200
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2501099205320128)
,p_name=>'P6_CUSTOMER_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>140
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Customer Code'
,p_source=>'CUSTOMER_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_named_lov=>'CUSTOMER.NAME_A'
,p_lov_display_null=>'YES'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'execute_validations', 'Y',
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2501739107320131)
,p_name=>'P6_SALESMAN_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>150
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Salesman Code'
,p_source=>'SALESMAN_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2502133341320131)
,p_name=>'P6_APPROVED'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>160
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Approved'
,p_source=>'APPROVED'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2502596861320131)
,p_name=>'P6_CLOSED'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>170
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Closed'
,p_source=>'CLOSED'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2502929703320131)
,p_name=>'P6_NOTE'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>180
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Note'
,p_source=>'NOTE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXTAREA'
,p_cSize=>60
,p_cMaxlength=>500
,p_cHeight=>4
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2503373929320131)
,p_name=>'P6_DESC_A'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>190
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Desc A'
,p_source=>'DESC_A'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>32
,p_cMaxlength=>200
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2503758869320131)
,p_name=>'P6_DESC_E'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>200
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Desc E'
,p_source=>'DESC_E'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>32
,p_cMaxlength=>200
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2504186275320132)
,p_name=>'P6_SO_TYPE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>210
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'So Type'
,p_source=>'SO_TYPE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2504547992320132)
,p_name=>'P6_CURRENCY_CODE'
,p_source_data_type=>'NUMBER'
,p_is_required=>true
,p_item_sequence=>220
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Currency Code'
,p_source=>'CURRENCY_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609122147107268652
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2504914352320132)
,p_name=>'P6_CURRENCY_RATE'
,p_source_data_type=>'NUMBER'
,p_is_required=>true
,p_item_sequence=>230
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Currency Rate'
,p_source=>'CURRENCY_RATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609122147107268652
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2505351891320132)
,p_name=>'P6_WEIGHT'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>240
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Weight'
,p_source=>'WEIGHT'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2505799464320132)
,p_name=>'P6_DEMO_TRNS_TYPE_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>250
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Demo Trns Type Code'
,p_source=>'DEMO_TRNS_TYPE_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2506171478320132)
,p_name=>'P6_DEMO_TRNS_SERIAL'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>260
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Demo Trns Serial'
,p_source=>'DEMO_TRNS_SERIAL'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2506567638320132)
,p_name=>'P6_INSERT_USER'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>270
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Insert User'
,p_source=>'INSERT_USER'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2506921013320134)
,p_name=>'P6_INSERT_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>280
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Insert Date'
,p_source=>'INSERT_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2507363219320134)
,p_name=>'P6_UPDATE_USER'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>290
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Update User'
,p_source=>'UPDATE_USER'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2507789992320134)
,p_name=>'P6_UPDATE_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>300
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Update Date'
,p_source=>'UPDATE_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2508192440320134)
,p_name=>'P6_DELETE_USER'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>310
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Delete User'
,p_source=>'DELETE_USER'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2508565003320134)
,p_name=>'P6_DELETE_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>320
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Delete Date'
,p_source=>'DELETE_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2508979750320134)
,p_name=>'P6_DISC_VAL'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>330
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Disc Val'
,p_source=>'DISC_VAL'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2509330497320135)
,p_name=>'P6_TRNSPORT_VAL'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>340
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Trnsport Val'
,p_source=>'TRNSPORT_VAL'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2509705830320135)
,p_name=>'P6_SUPPLIER_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>350
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Supplier Code'
,p_source=>'SUPPLIER_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2510142564320135)
,p_name=>'P6_OFFER_EXPIRY'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>360
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Expiry'
,p_source=>'OFFER_EXPIRY'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>32
,p_cMaxlength=>200
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2510536646320135)
,p_name=>'P6_STORE_CODE'
,p_source_data_type=>'NUMBER'
,p_is_required=>true
,p_item_sequence=>370
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Store Code'
,p_source=>'STORE_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609122147107268652
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2510927265320135)
,p_name=>'P6_PAY_TERM_SERIAL'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>380
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Pay Term Serial'
,p_source=>'PAY_TERM_SERIAL'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_named_lov=>'ST_PAYMENT_TERMS.TYPE_NAME'
,p_lov_display_null=>'YES'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'execute_validations', 'Y',
  'page_action_on_selection', 'NONE')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2511613381320135)
,p_name=>'P6_PAYMENT_TERMS_DAYS'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>390
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Payment Terms Days'
,p_source=>'PAYMENT_TERMS_DAYS'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2512033621320135)
,p_name=>'P6_DISC_PER'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>400
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Disc Per'
,p_source=>'DISC_PER'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2512418506320137)
,p_name=>'P6_OVER_DUES_FLAG'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>410
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Over Dues Flag'
,p_source=>'OVER_DUES_FLAG'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2512863832320137)
,p_name=>'P6_OVER_DUES_VALUE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>420
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Over Dues Value'
,p_source=>'OVER_DUES_VALUE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2513216803320137)
,p_name=>'P6_OVER_DUES_DAYS'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>430
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Over Dues Days'
,p_source=>'OVER_DUES_DAYS'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2513603838320137)
,p_name=>'P6_OVER_DUES_USER'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>440
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Over Dues User'
,p_source=>'OVER_DUES_USER'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2514036757320137)
,p_name=>'P6_CTGRY_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>450
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Ctgry Code'
,p_source=>'CTGRY_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2514436183320139)
,p_name=>'P6_USER_DISC_PER'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>460
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'User Disc Per'
,p_source=>'USER_DISC_PER'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2514826581320139)
,p_name=>'P6_ORDER_STATUS'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>470
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Order Status'
,p_source=>'ORDER_STATUS'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2515275341320139)
,p_name=>'P6_SUPERVISOR_SLSMAN'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>480
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Supervisor Slsman'
,p_source=>'SUPERVISOR_SLSMAN'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2515612136320139)
,p_name=>'P6_OVER_DUES_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>490
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Over Dues Date'
,p_source=>'OVER_DUES_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2516072827320139)
,p_name=>'P6_VALID_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>500
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Valid Date'
,p_source=>'VALID_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2516483292320139)
,p_name=>'P6_CLOSE_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>510
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Close Code'
,p_source=>'CLOSE_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2516814400320140)
,p_name=>'P6_ALT_KEY'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>520
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Alt Key'
,p_source=>'ALT_KEY'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>32
,p_cMaxlength=>50
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2517294124320140)
,p_name=>'P6_TAX_CODE1'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>530
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tax Code1'
,p_source=>'TAX_CODE1'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2517636827320140)
,p_name=>'P6_TAX_VALUE1'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>540
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tax Value1'
,p_source=>'TAX_VALUE1'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2518014792320140)
,p_name=>'P6_TAX_CODE2'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>550
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tax Code2'
,p_source=>'TAX_CODE2'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2518427777320140)
,p_name=>'P6_TAX_VALUE2'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>560
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tax Value2'
,p_source=>'TAX_VALUE2'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2518834315320140)
,p_name=>'P6_USER_DISC_DISC_VAL'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>570
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'User Disc Disc Val'
,p_source=>'USER_DISC_DISC_VAL'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2519246409320142)
,p_name=>'P6_OFFER_DISC_VAL1'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>580
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Val1'
,p_source=>'OFFER_DISC_VAL1'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2519601358320142)
,p_name=>'P6_OFFER_DISC_VAL2'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>590
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Val2'
,p_source=>'OFFER_DISC_VAL2'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2520036852320142)
,p_name=>'P6_OFFER_DISC_VAL3'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>600
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Val3'
,p_source=>'OFFER_DISC_VAL3'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2520467977320142)
,p_name=>'P6_OFFER_DISC_DSRV_VAL1'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>610
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Dsrv Val1'
,p_source=>'OFFER_DISC_DSRV_VAL1'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2520843094320142)
,p_name=>'P6_OFFER_DISC_DSRV_VAL2'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>620
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Dsrv Val2'
,p_source=>'OFFER_DISC_DSRV_VAL2'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2521252463320143)
,p_name=>'P6_OFFER_DISC_DSRV_VAL3'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>630
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Dsrv Val3'
,p_source=>'OFFER_DISC_DSRV_VAL3'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2521660543320143)
,p_name=>'P6_OFFER_DISC_PER1'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>640
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Per1'
,p_source=>'OFFER_DISC_PER1'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2522076875320143)
,p_name=>'P6_OFFER_DISC_PER2'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>650
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Per2'
,p_source=>'OFFER_DISC_PER2'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2522453750320143)
,p_name=>'P6_OFFER_DISC_PER3'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>660
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Disc Per3'
,p_source=>'OFFER_DISC_PER3'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2522802822320143)
,p_name=>'P6_INV_CAT_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>670
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Inv Cat Code'
,p_source=>'INV_CAT_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2523293760320143)
,p_name=>'P6_MOB_TRNS_SEQ'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>680
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Mob Trns Seq'
,p_source=>'MOB_TRNS_SEQ'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2523687746320143)
,p_name=>'P6_RFQ'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>690
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Rfq'
,p_source=>'RFQ'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXTAREA'
,p_cSize=>60
,p_cMaxlength=>2000
,p_cHeight=>4
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2524008577320145)
,p_name=>'P6_OFFER_EXPIRE_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>700
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Offer Expire Date'
,p_source=>'OFFER_EXPIRE_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2524489815320145)
,p_name=>'P6_PO_CUST_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>710
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Po Cust Date'
,p_source=>'PO_CUST_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2524827930320145)
,p_name=>'P6_TOT_DISC1_RATIO'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>720
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tot Disc1 Ratio'
,p_source=>'TOT_DISC1_RATIO'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2525283694320145)
,p_name=>'P6_TOT_DISC2_RATIO'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>730
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tot Disc2 Ratio'
,p_source=>'TOT_DISC2_RATIO'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2525659638320145)
,p_name=>'P6_TOT_DISC3_RATIO'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>740
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tot Disc3 Ratio'
,p_source=>'TOT_DISC3_RATIO'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2526025332320145)
,p_name=>'P6_TOT_DISC1_VALUE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>750
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tot Disc1 Value'
,p_source=>'TOT_DISC1_VALUE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2526471220320145)
,p_name=>'P6_TOT_DISC2_VALUE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>760
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tot Disc2 Value'
,p_source=>'TOT_DISC2_VALUE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2526888077320146)
,p_name=>'P6_TOT_DISC3_VALUE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>770
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Tot Disc3 Value'
,p_source=>'TOT_DISC3_VALUE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2527256896320146)
,p_name=>'P6_SALESMAN_BRANCH_MGR'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>780
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Salesman Branch Mgr'
,p_source=>'SALESMAN_BRANCH_MGR'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2527655173320146)
,p_name=>'P6_SALESMAN_SALES_MGR'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>790
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Salesman Sales Mgr'
,p_source=>'SALESMAN_SALES_MGR'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2528071711320146)
,p_name=>'P6_SL_TRNS_TYPE_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>800
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Sl Trns Type Code'
,p_source=>'SL_TRNS_TYPE_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2528406265320146)
,p_name=>'P6_SL_TRNS_SERIAL'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>810
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Sl Trns Serial'
,p_source=>'SL_TRNS_SERIAL'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2528831044320146)
,p_name=>'P6_APPROVED2'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>820
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Approved2'
,p_source=>'APPROVED2'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2529228540320146)
,p_name=>'P6_APPROVED_USERS_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>830
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Approved Users Code'
,p_source=>'APPROVED_USERS_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2529647446320148)
,p_name=>'P6_APPROVED_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>840
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Approved Date'
,p_source=>'APPROVED_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2530083459320148)
,p_name=>'P6_APPROVED2_USERS_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>850
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Approved2 Users Code'
,p_source=>'APPROVED2_USERS_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2530443682320148)
,p_name=>'P6_APPROVED2_DATE'
,p_source_data_type=>'DATE'
,p_item_sequence=>860
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Approved2 Date'
,p_source=>'APPROVED2_DATE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_DATE_PICKER_APEX'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'appearance_and_behavior', 'MONTH-PICKER:YEAR-PICKER:TODAY-BUTTON',
  'days_outside_month', 'VISIBLE',
  'display_as', 'POPUP',
  'max_date', 'NONE',
  'min_date', 'NONE',
  'multiple_months', 'N',
  'show_on', 'FOCUS',
  'show_time', 'N',
  'use_defaults', 'Y')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2530884975320148)
,p_name=>'P6_PAYMENT_TYPE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>870
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Payment Type'
,p_source=>'PAYMENT_TYPE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2531248531320150)
,p_name=>'P6_AUTO_DISC_INIT'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>880
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Auto Disc Init'
,p_source=>'AUTO_DISC_INIT'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2531662510320150)
,p_name=>'P6_OLD_CUSTOMER_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>890
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Old Customer Code'
,p_source=>'OLD_CUSTOMER_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2532098914320150)
,p_name=>'P6_OLD_SALESMAN_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>900
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Old Salesman Code'
,p_source=>'OLD_SALESMAN_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2532400282320150)
,p_name=>'P6_CLASS_CODE'
,p_source_data_type=>'NUMBER'
,p_item_sequence=>910
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Class Code'
,p_source=>'CLASS_CODE'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_NUMBER_FIELD'
,p_cSize=>32
,p_cMaxlength=>255
,p_cHeight=>1
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'number_alignment', 'left',
  'virtual_keyboard', 'decimal')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2532816978320150)
,p_name=>'P6_GLN'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>920
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Gln'
,p_source=>'GLN'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>32
,p_cMaxlength=>20
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'disabled', 'N',
  'submit_when_enter_pressed', 'N',
  'subtype', 'TEXT',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2533292589320150)
,p_name=>'P6_CUST_SALES_DOC_NO'
,p_source_data_type=>'VARCHAR2'
,p_item_sequence=>930
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_item_source_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_use_cache_before_default=>'NO'
,p_prompt=>'Cust Sales Doc No'
,p_source=>'CUST_SALES_DOC_NO'
,p_source_type=>'REGION_SOURCE_COLUMN'
,p_display_as=>'NATIVE_TEXTAREA'
,p_cSize=>60
,p_cMaxlength=>500
,p_cHeight=>4
,p_label_alignment=>'RIGHT'
,p_field_template=>1609121967514267634
,p_item_template_options=>'#DEFAULT#'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'auto_height', 'N',
  'character_counter', 'N',
  'resizable', 'Y',
  'trim_spaces', 'BOTH')).to_clob
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(2561500148320164)
,p_name=>'P6_TRNS_TYPE_CODE_COUNT'
,p_item_sequence=>940
,p_item_plug_id=>wwv_flow_imp.id(2495464954320114)
,p_display_as=>'NATIVE_DISPLAY_ONLY'
,p_cSize=>30
,p_tag_attributes=>'class="fielddata"'
,p_is_persistent=>'N'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'based_on', 'VALUE',
  'send_on_page_submit', 'N')).to_clob
,p_item_comment=>'This item is needed for Get Next or Previous Primary Key Value process.'
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(2566052402320168)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_region_id=>wwv_flow_imp.id(2495464954320114)
,p_process_type=>'NATIVE_FORM_DML'
,p_process_name=>'Process form Form on ST_SALES_ORDER'
,p_attribute_01=>'REGION_SOURCE'
,p_attribute_05=>'Y'
,p_attribute_06=>'Y'
,p_attribute_08=>'Y'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_internal_uid=>2566052402320168
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(2671328981320268)
,p_process_sequence=>35
,p_process_point=>'AFTER_SUBMIT'
,p_region_id=>wwv_flow_imp.id(2605573138320231)
,p_process_type=>'NATIVE_IG_DML'
,p_process_name=>'Sales Order - Save Interactive Grid Data'
,p_attribute_01=>'REGION_SOURCE'
,p_attribute_05=>'Y'
,p_attribute_06=>'Y'
,p_attribute_08=>'Y'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_internal_uid=>2671328981320268
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(2565625271320168)
,p_process_sequence=>10
,p_process_point=>'BEFORE_HEADER'
,p_region_id=>wwv_flow_imp.id(2495464954320114)
,p_process_type=>'NATIVE_FORM_INIT'
,p_process_name=>'Initialize form Form on ST_SALES_ORDER'
,p_attribute_01=>'P6_TRNS_TYPE_CODE_NEXT,P6_TRNS_SERIAL_NEXT'
,p_attribute_02=>'P6_TRNS_TYPE_CODE_PREV,P6_TRNS_SERIAL_PREV'
,p_attribute_03=>'P6_TRNS_TYPE_CODE_COUNT'
,p_internal_uid=>2565625271320168
);
wwv_flow_imp.component_end;
end;
/
