prompt --application/pages/page_00003
begin
--   Manifest
--     PAGE: 00003
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
 p_id=>3
,p_name=>'Chart of Accounts'
,p_alias=>'CHART-OF-ACCOUNTS'
,p_step_title=>'Chart of Accounts'
,p_autocomplete_on_off=>'OFF'
,p_page_template_options=>'#DEFAULT#'
,p_protection_level=>'C'
,p_page_component_map=>'18'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(2435685138282468)
,p_plug_name=>'Chart of Accounts'
,p_region_template_options=>'#DEFAULT#:t-IRR-region--hideHeader js-addHiddenHeadingRoleDesc'
,p_plug_template=>2100526641005906379
,p_plug_display_sequence=>10
,p_query_type=>'TABLE'
,p_query_table=>'AC_MASTER'
,p_include_rowid_column=>false
,p_plug_source_type=>'NATIVE_IR'
,p_prn_page_header=>'Chart of Accounts'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(2435765945282468)
,p_name=>'Chart of Accounts'
,p_max_row_count_message=>'The maximum row count for this report is #MAX_ROW_COUNT# rows.  Please apply a filter to reduce the number of records in your query.'
,p_no_data_found_message=>'No data found.'
,p_base_pk1=>'ACCOUNT_NUMBER'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'C'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_detail_link=>'f?p=&APP_ID.:4:&APP_SESSION.::&DEBUG.:RP:P4_ACCOUNT_NUMBER:\#ACCOUNT_NUMBER#\'
,p_detail_link_text=>'<span role="img" aria-label="Edit" class="fa fa-edit" title="Edit"></span>'
,p_owner=>'CLAUDE'
,p_internal_uid=>2435765945282468
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2436440832282473)
,p_db_column_name=>'ACCOUNT_NUMBER'
,p_display_order=>0
,p_is_primary_key=>'Y'
,p_column_identifier=>'A'
,p_column_label=>'Account Number'
,p_column_type=>'NUMBER'
,p_display_text_as=>'HIDDEN_ESCAPE_SC'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2436828865282473)
,p_db_column_name=>'ACCOUNT_NAME'
,p_display_order=>2
,p_column_identifier=>'B'
,p_column_label=>'Account Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2437270189282473)
,p_db_column_name=>'ACCOUNT_NAME_E'
,p_display_order=>3
,p_column_identifier=>'C'
,p_column_label=>'Account Name E'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2437651210282473)
,p_db_column_name=>'CURRENCY_CODE'
,p_display_order=>4
,p_column_identifier=>'D'
,p_column_label=>'Currency Code'
,p_column_type=>'STRING'
,p_display_text_as=>'LOV_ESCAPE_SC'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_rpt_named_lov=>wwv_flow_imp.id(2417239801282456)
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2438014597282475)
,p_db_column_name=>'CURRENT_LOC'
,p_display_order=>5
,p_column_identifier=>'E'
,p_column_label=>'Current Loc'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2438447684282475)
,p_db_column_name=>'CURRENT_FOR'
,p_display_order=>6
,p_column_identifier=>'F'
,p_column_label=>'Current For'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2438845547282475)
,p_db_column_name=>'BEGIN_PERIOD_LOC'
,p_display_order=>7
,p_column_identifier=>'G'
,p_column_label=>'Begin Period Loc'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2439296349282475)
,p_db_column_name=>'BEGIN_PERIOD_FOR'
,p_display_order=>8
,p_column_identifier=>'H'
,p_column_label=>'Begin Period For'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2439606057282475)
,p_db_column_name=>'BEGIN_YEAR_LOC'
,p_display_order=>9
,p_column_identifier=>'I'
,p_column_label=>'Begin Year Loc'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2440044899282475)
,p_db_column_name=>'BEGIN_YEAR_FOR'
,p_display_order=>10
,p_column_identifier=>'J'
,p_column_label=>'Begin Year For'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2440400694282475)
,p_db_column_name=>'ACCOUNT_LEVEL'
,p_display_order=>11
,p_column_identifier=>'K'
,p_column_label=>'Account Level'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_format_mask=>'999G999G999G999G999G999G999G999G999G990'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2440878536282475)
,p_db_column_name=>'ACCOUNT_STATUS'
,p_display_order=>12
,p_column_identifier=>'L'
,p_column_label=>'Account Status'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_format_mask=>'999G999G999G999G999G999G999G999G999G990D0'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2441289260282475)
,p_db_column_name=>'CASH_MANAG'
,p_display_order=>13
,p_column_identifier=>'M'
,p_column_label=>'Cash Manag'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_format_mask=>'999G999G999G999G999G999G999G999G999G990'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2441635869282475)
,p_db_column_name=>'STOP_FLAG'
,p_display_order=>14
,p_column_identifier=>'N'
,p_column_label=>'Stop Flag'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2442059799282475)
,p_db_column_name=>'BANK_FLAG'
,p_display_order=>15
,p_column_identifier=>'O'
,p_column_label=>'Bank Flag'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_format_mask=>'999G999G999G999G999G999G999G999G999G990'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2442430892282475)
,p_db_column_name=>'BANK_NAME'
,p_display_order=>16
,p_column_identifier=>'P'
,p_column_label=>'Bank Name'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2442822422282475)
,p_db_column_name=>'BANK_NAME_E'
,p_display_order=>17
,p_column_identifier=>'Q'
,p_column_label=>'Bank Name E'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2443251996282476)
,p_db_column_name=>'RAP_FLAG'
,p_display_order=>18
,p_column_identifier=>'R'
,p_column_label=>'Rap Flag'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2443649922282476)
,p_db_column_name=>'AC_FLAG'
,p_display_order=>19
,p_column_identifier=>'S'
,p_column_label=>'Ac Flag'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_format_mask=>'999G999G999G999G999G999G999G999G999G990D0'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2444022318282476)
,p_db_column_name=>'ACC_COST1_FLAG'
,p_display_order=>20
,p_column_identifier=>'T'
,p_column_label=>'Acc Cost1 Flag'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_format_mask=>'999G999G999G999G999G999G999G999G999G990D0'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(2444493150282476)
,p_db_column_name=>'ACC_COST2_FLAG'
,p_display_order=>21
,p_column_identifier=>'U'
,p_column_label=>'Acc Cost2 Flag'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_format_mask=>'999G999G999G999G999G999G999G999G999G990D0'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(2446598626282478)
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
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(2444988821282476)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(2435685138282468)
,p_button_name=>'CREATE'
,p_button_action=>'REDIRECT_PAGE'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>4072362960822175091
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Create'
,p_button_position=>'RIGHT_OF_IR_SEARCH_BAR'
,p_button_redirect_url=>'f?p=&APP_ID.:4:&APP_SESSION.::&DEBUG.:4::'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(2445263574282476)
,p_name=>'Edit Report - Dialog Closed'
,p_event_sequence=>10
,p_triggering_element_type=>'REGION'
,p_triggering_region_id=>wwv_flow_imp.id(2435685138282468)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'apexafterclosedialog'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(2445765604282478)
,p_event_id=>wwv_flow_imp.id(2445263574282476)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(2435685138282468)
);
wwv_flow_imp.component_end;
end;
/
