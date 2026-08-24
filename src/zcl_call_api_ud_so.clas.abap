*&---------------------------------------------------------------------*
CLASS zcl_call_api_ud_so DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      tt_mch_so_upl TYPE STANDARD TABLE OF ztb_d_mch_so_upl WITH EMPTY KEY.
    CLASS-METHODS update
      CHANGING
        !ct_data TYPE tt_mch_so_upl.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS:
      c_service_root        TYPE string VALUE `/sap/opu/odata/sap/API_SALES_ORDER_SRV/`,
      c_api_name            TYPE string VALUE `API_SALES_ORDER_V2`,
      c_endpoint_item       TYPE string VALUE `/sap/opu/odata4/sap/api_salesorder/srvd_a2x/sap/salesorder/0001/SalesOrderItem`,
      c_endpoint_pr_element TYPE string VALUE `/sap/opu/odata4/sap/api_salesorder/srvd_a2x/sap/salesorder/0001/SalesOrderItemPricingElement`,
      c_message_max_length  TYPE i VALUE 255,
      c_error_sep           TYPE string VALUE `; `.

    " ID text - đã confirm / cần confirm lại SSCUI với khách hàng
    CONSTANTS:
      BEGIN OF c_text_id,
        gia_duyet  TYPE string VALUE `Y001`,  "TODO(dev): confirm SSCUI
        dung_sai   TYPE string VALUE `Y002`,  " đã confirm
        sales_note TYPE string VALUE `TX02`,  "TODO(dev): confirm SSCUI
      END OF c_text_id.

    TYPES:
      " Pricing element (GET A_SalesOrderItemPrElement)
      BEGIN OF ty_pr_element,
        pricing_procedure_step      TYPE string,
        pricing_procedure_counter   TYPE string,
        condition_type              TYPE string,
        transaction_currency        TYPE waers,
        condition_quantity_iso_unit TYPE string,
      END OF ty_pr_element,
      tt_pr_element TYPE STANDARD TABLE OF ty_pr_element WITH DEFAULT KEY,

      BEGIN OF ty_pr_element_results,
        results TYPE tt_pr_element,
      END OF ty_pr_element_results,

      BEGIN OF ty_pr_element_response,
        d TYPE ty_pr_element_results,
      END OF ty_pr_element_response,

      " Cấu hình update 3 field long text của item
      BEGIN OF ty_text_update,
        text_id    TYPE string,
        text_value TYPE string,
        label      TYPE string,
      END OF ty_text_update,
      tt_text_update TYPE STANDARD TABLE OF ty_text_update WITH EMPTY KEY,

      tt_string      TYPE STANDARD TABLE OF string WITH EMPTY KEY,

      " Message lỗi chuẩn OData: {"error":{"code":"..","message":{"lang":"en","value":".."},
      " "target":"..","@SAP__common.additionalTargets":[".."]}}
      BEGIN OF ty_odata_error_message,
        lang  TYPE string,
        value TYPE string,
      END OF ty_odata_error_message,
      BEGIN OF ty_odata_error_detail_nested,
        code               TYPE string,
        message            TYPE ty_odata_error_message,
        target             TYPE string,
        additional_targets TYPE tt_string,
      END OF ty_odata_error_detail_nested,
      BEGIN OF ty_odata_error_nested,
        error TYPE ty_odata_error_detail_nested,
      END OF ty_odata_error_nested,

      " Một số service (vd API_SALESORDER OData V4) trả "message" dạng chuỗi phẳng
      BEGIN OF ty_odata_error_detail_flat,
        code               TYPE string,
        message            TYPE string,
        target             TYPE string,
        additional_targets TYPE tt_string,
      END OF ty_odata_error_detail_flat,
      BEGIN OF ty_odata_error_flat,
        error TYPE ty_odata_error_detail_flat,
      END OF ty_odata_error_flat.

    " ── Validate ──────────────────────────────────────────────────
    CLASS-METHODS validate_so_item
      IMPORTING
        !iv_sales_order      TYPE vbeln_va
        !iv_sales_order_item TYPE posnr_va
      RETURNING
        VALUE(rv_valid)      TYPE abap_bool.

    " ── Update từng nhóm field ───────────────────────────────────
    CLASS-METHODS update_item_header
      IMPORTING
        !is_data          TYPE ztb_d_mch_so_upl
      EXPORTING
        !ev_message       TYPE string
      RETURNING
        VALUE(rv_success) TYPE abap_bool.

    " Map tên field kỹ thuật (OData) -> nhãn hiển thị cho user dễ hiểu
    CLASS-METHODS get_field_label
      IMPORTING
        !iv_field       TYPE string
      RETURNING
        VALUE(rv_label) TYPE string.

    " Update cả 3 long text (số duyệt giá / dung sai / sales note), gộp lỗi (nếu có)
    CLASS-METHODS update_item_texts
      IMPORTING
        !is_data  TYPE ztb_d_mch_so_upl
      EXPORTING
        !et_error TYPE string_table.

    CLASS-METHODS upsert_item_text
      IMPORTING
        !iv_sales_order      TYPE vbeln_va
        !iv_sales_order_item TYPE posnr_va
        !iv_long_text_id     TYPE string
        !iv_long_text        TYPE string
      EXPORTING
        !ev_message          TYPE string
      RETURNING
        VALUE(rv_success)    TYPE abap_bool.

    CLASS-METHODS update_pricing_element
      IMPORTING
        !is_data          TYPE ztb_d_mch_so_upl
      EXPORTING
        !ev_message       TYPE string
      RETURNING
        VALUE(rv_success) TYPE abap_bool.

    " Tìm PricingProcedureStep/Counter khớp ConditionType (GET + match)
    CLASS-METHODS find_pricing_element
      IMPORTING
        !iv_sales_order                 TYPE vbeln_va
        !iv_sales_order_item            TYPE posnr_va
        !iv_condition_type              TYPE kschl
      EXPORTING
        !ev_proc_step                   TYPE string
        !ev_proc_counter                TYPE string
        !ev_condition_quantity_iso_unit TYPE string
        !ev_transaction_currency        TYPE waers
        !ev_message                     TYPE string
      RETURNING
        VALUE(rv_found)                 TYPE abap_bool.

    " Gộp danh sách lỗi thành message cuối cùng + set messagetype cho 1 dòng
    CLASS-METHODS set_result
      IMPORTING
        !it_error TYPE string_table
      CHANGING
        !cs_data  TYPE ztb_d_mch_so_upl.

    " ── Helpers ──────────────────────────────────────────────────
    CLASS-METHODS escape_json
      IMPORTING iv_text          TYPE string
      RETURNING VALUE(rv_result) TYPE string.

    " Bóc tách message lỗi chuẩn OData từ response body (hỗ trợ cả dạng
    " message-là-object lẫn message-là-string). Fallback: trả nguyên response.
    " it_sent_fields: danh sách field thực sự đẩy lên API - dùng để lọc bớt
    " target/additionalTargets do hệ thống trả về nhưng không liên quan tới field mình gửi.
    CLASS-METHODS get_error_message
      IMPORTING
        !iv_response      TYPE string
        !it_sent_fields   TYPE string_table OPTIONAL
      RETURNING
        VALUE(rv_message) TYPE string.

    " Ghép message gốc với tên field (target/additionalTargets) đã lọc theo
    " it_sent_fields, vd: "Product, RequestedQuantity: Read-only fields must not be changed."
    CLASS-METHODS build_friendly_message
      IMPORTING
        !iv_message            TYPE string
        !iv_target             TYPE string OPTIONAL
        !it_additional_targets TYPE tt_string OPTIONAL
        !it_sent_fields        TYPE string_table OPTIONAL
      RETURNING
        VALUE(rv_message)      TYPE string.

    CLASS-METHODS do_call
      IMPORTING
        !iv_endpoint      TYPE string
        !iv_method        TYPE string
        !iv_body          TYPE string OPTIONAL
        !iv_filter        TYPE string OPTIONAL
        !iv_sent_fields   TYPE string_table OPTIONAL
      EXPORTING
        !ev_code          TYPE i
        !ev_response      TYPE string
        !ev_message       TYPE string
      RETURNING
        VALUE(rv_success) TYPE abap_bool.

ENDCLASS.



CLASS ZCL_CALL_API_UD_SO IMPLEMENTATION.


  METHOD update.
    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<row>).

      " ── 1. Validate SO + SO Item tồn tại (CDS view - local SELECT) ──
      IF validate_so_item( iv_sales_order      = <row>-sales_order
                           iv_sales_order_item = <row>-sales_order_item ) = abap_false.
        <row>-messagetype = 'E'.
        <row>-message      = |SO { <row>-sales_order } Item { <row>-sales_order_item } không tồn tại|.
        CONTINUE.
      ENDIF.

      DATA(lt_error) = VALUE string_table( ).

      " ── 2. Update Material / Plant / Qty / Customer Reference ──────
      update_item_header( EXPORTING is_data    = <row>
                           IMPORTING ev_message = DATA(lv_header_message)
                           RECEIVING rv_success = DATA(lv_header_ok) ).
      IF lv_header_ok = abap_false AND lv_header_message IS NOT INITIAL.
        APPEND lv_header_message TO lt_error.
      ENDIF.

      " ── 3. Update 3 Text (Số duyệt giá / Dung sai / Sales Note) ────
      update_item_texts( EXPORTING is_data  = <row>
                          IMPORTING et_error = DATA(lt_text_errors) ).
      APPEND LINES OF lt_text_errors TO lt_error.

      " ── 4. Update Pricing Element (Condition Type/Amount/Crcy/Per) ─
      IF <row>-condition_type IS NOT INITIAL.
        update_pricing_element( EXPORTING is_data    = <row>
                                 IMPORTING ev_message = DATA(lv_pricing_message)
                                 RECEIVING rv_success = DATA(lv_pricing_ok) ).
        IF lv_pricing_ok = abap_false AND lv_pricing_message IS NOT INITIAL.
          APPEND lv_pricing_message TO lt_error.
        ENDIF.
      ELSEIF <row>-condition_amount IS NOT INITIAL
      OR    <row>-currency IS NOT INITIAL
      OR    <row>-condition_pricing_unit IS NOT INITIAL.
        " Nếu user gửi 1 trong 3 field liên quan đến pricing element mà không có condition_type
        		  APPEND |Cannot update Amount/Crcy/Per. Please fill in ConditionType.| TO lt_error.

      ENDIF.

      " ── 5. Set message kết quả ──────────────────────────────────
      set_result( EXPORTING it_error = lt_error
                  CHANGING  cs_data  = <row> ).

    ENDLOOP.
  ENDMETHOD.


  METHOD validate_so_item.
    " Dùng view released I_SalesOrderItem để tránh gọi HTTP API,
    " chỉ SELECT trong DB nội bộ cho nhanh (đỡ tốn performance).
    DATA(lv_sales_order)      = |{ iv_sales_order ALPHA = IN }|.
    DATA(lv_sales_order_item) = |{ iv_sales_order_item ALPHA = IN }|.

    SELECT SINGLE @abap_true
      FROM I_SalesOrderItem
      WHERE SalesOrder     = @lv_sales_order
        AND SalesOrderItem = @lv_sales_order_item
      INTO @rv_valid.
    " sy-subrc <> 0 -> rv_valid giữ giá trị initial (abap_false)
  ENDMETHOD.


  METHOD escape_json.
    rv_result = iv_text.
    REPLACE ALL OCCURRENCES OF '\' IN rv_result WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_result WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_result WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN rv_result WITH '\n'.
  ENDMETHOD.


  METHOD get_error_message.
    IF iv_response IS INITIAL.
      RETURN.
    ENDIF.

    " "@SAP__common.additionalTargets" có ký tự đặc biệt -> cần mapping tường minh
    DATA(lt_mapping) = VALUE /ui2/cl_json=>name_mappings(
      ( abap = 'additional_targets' json = '@SAP__common.additionalTargets' ) ).

    " Dạng chuẩn OData: message là object { "lang": "..", "value": ".." }
    TRY.
        DATA(ls_nested) = VALUE ty_odata_error_nested( ).
        /ui2/cl_json=>deserialize( EXPORTING json          = iv_response
                                              name_mappings = lt_mapping
                                    CHANGING  data          = ls_nested ).
        IF ls_nested-error-message-value IS NOT INITIAL.
          rv_message = build_friendly_message( iv_message            = ls_nested-error-message-value
                                                iv_target             = ls_nested-error-target
                                                it_additional_targets = ls_nested-error-additional_targets
                                                it_sent_fields        = it_sent_fields ).
          RETURN.
        ENDIF.
      CATCH cx_root.
    ENDTRY.

    " Một số service (vd API_SALESORDER OData V4) trả message dạng chuỗi phẳng
    TRY.
        DATA(ls_flat) = VALUE ty_odata_error_flat( ).
        /ui2/cl_json=>deserialize( EXPORTING json          = iv_response
                                              name_mappings = lt_mapping
                                    CHANGING  data          = ls_flat ).
        IF ls_flat-error-message IS NOT INITIAL.
          rv_message = build_friendly_message( iv_message            = ls_flat-error-message
                                                iv_target             = ls_flat-error-target
                                                it_additional_targets = ls_flat-error-additional_targets
                                                it_sent_fields        = it_sent_fields ).
          RETURN.
        ENDIF.
      CATCH cx_root.
    ENDTRY.

    " Không parse được theo format lỗi chuẩn -> trả nguyên response thô
    rv_message = iv_response.
  ENDMETHOD.


  METHOD build_friendly_message.
    rv_message = iv_message.

    DATA(lt_fields) = VALUE string_table( ).
    IF iv_target IS NOT INITIAL.
      APPEND iv_target TO lt_fields.
    ENDIF.
    APPEND LINES OF it_additional_targets TO lt_fields.

    " Chỉ giữ lại field nào thực sự có trong body đã gửi lên API -
    " tránh liệt kê các field hệ thống (vd RequestedQuantitySAPUnit) khiến user rối.
    IF it_sent_fields IS NOT INITIAL.
      DATA(lt_matched) = VALUE string_table( ).
      LOOP AT lt_fields INTO DATA(lv_field).
        IF line_exists( it_sent_fields[ table_line = lv_field ] ).

          DATA(lv_label) = get_field_label( lv_field ) .
          APPEND lv_label TO lt_matched.

        ENDIF.
      ENDLOOP.
      lt_fields = lt_matched.
    ENDIF.

    IF lt_fields IS NOT INITIAL.
      rv_message = |{ concat_lines_of( table = lt_fields sep = `, ` ) }: { rv_message }|.
    ENDIF.
  ENDMETHOD.


  METHOD do_call.
    DATA(lv_response) = zcl_call_api=>call_api(
      iv_body     = iv_body
      iv_endpoint = iv_endpoint
      iv_apiName  = c_api_name
      iv_filter   = iv_filter
      iv_method   = iv_method ).

    ev_code     = zcl_call_api=>code.
    ev_response = lv_response.

    rv_success = xsdbool( ev_code = 200 OR ev_code = 201 OR ev_code = 204 ).

    IF rv_success = abap_false.
      ev_message = get_error_message( iv_response    = lv_response
                                       it_sent_fields = iv_sent_fields ).
    ENDIF.
  ENDMETHOD.


  METHOD update_item_header.
    SELECT SINGLE OrderQuantityUnit
      FROM I_SalesOrderItem
      WHERE SalesOrder     = @is_data-sales_order
        AND SalesOrderItem = @is_data-sales_order_item
      INTO @DATA(lv_item_quantity_unit).

    DATA(lt_fields)      = VALUE string_table( ).
    DATA(lt_sent_fields) = VALUE string_table( ).

    IF is_data-material IS NOT INITIAL.
      DATA(lv_matnr) = |{ is_data-material ALPHA = OUT }|.
      CONDENSE lv_matnr NO-GAPS.
      APPEND |"Product":"{ lv_matnr }"| TO lt_fields.
      APPEND `Product` TO lt_sent_fields.
    ENDIF.

    IF is_data-plant IS NOT INITIAL.
      APPEND |"Plant":"{ is_data-plant }"| TO lt_fields.
      APPEND `Plant` TO lt_sent_fields.
    ENDIF.

    IF is_data-order_quantity IS NOT INITIAL.
      APPEND |"RequestedQuantity":{ is_data-order_quantity }| TO lt_fields.
      APPEND `RequestedQuantity` TO lt_sent_fields.

      " sales_unit từ file upload là mã ngoài (external); nếu không có thì
      " dùng lại đơn vị hiện tại của item (mã nội bộ) để suy ra ISO code.
      IF is_data-sales_unit IS NOT INITIAL.
        SELECT SINGLE UnitOfMeasureISOCode
          FROM I_UnitOfMeasure
          WHERE UnitOfMeasure_E = @is_data-sales_unit
          INTO @DATA(lv_quantity_iso_unit).
      ELSE.
        SELECT SINGLE UnitOfMeasureISOCode
          FROM I_UnitOfMeasure
          WHERE UnitOfMeasure = @lv_item_quantity_unit
          INTO @lv_quantity_iso_unit.
      ENDIF.

      APPEND |"RequestedQuantityISOUnit":"{ lv_quantity_iso_unit }"| TO lt_fields.
      APPEND `RequestedQuantityISOUnit` TO lt_sent_fields.
    ENDIF.

    IF is_data-customer_reference IS NOT INITIAL.
      APPEND |"PurchaseOrderByCustomer":"{ is_data-customer_reference }"| TO lt_fields.
      APPEND `PurchaseOrderByCustomer` TO lt_sent_fields.
    ENDIF.

    IF lt_fields IS INITIAL.
      rv_success = abap_true. " không có gì để update
      RETURN.
    ENDIF.

    DATA(lv_endpoint) = |{ c_endpoint_item }| &&
      |(SalesOrder='{ is_data-sales_order }',SalesOrderItem='{ is_data-sales_order_item }')|.

    do_call( EXPORTING iv_endpoint    = lv_endpoint
                        iv_body        = |\{ { concat_lines_of( table = lt_fields sep = `,` ) } \}|
                        iv_method      = 'PATCH'
                        iv_sent_fields = lt_sent_fields
             IMPORTING ev_message     = ev_message
             RECEIVING rv_success     = rv_success ).
  ENDMETHOD.


  METHOD update_item_texts.
    CLEAR et_error.

    DATA(lt_texts) = VALUE tt_text_update(
      ( text_id = c_text_id-gia_duyet  text_value = is_data-text_price_approval      label = `Số duyệt giá` )
      ( text_id = c_text_id-dung_sai   text_value = is_data-text_order_tolerance     label = `Dung sai đơn hàng` )
      ( text_id = c_text_id-sales_note text_value = is_data-text_sales_note_customer label = `Sales Note for Customer` ) ).

    LOOP AT lt_texts INTO DATA(ls_text) WHERE text_value IS NOT INITIAL.
      upsert_item_text( EXPORTING iv_sales_order      = is_data-sales_order
                                   iv_sales_order_item = is_data-sales_order_item
                                   iv_long_text_id     = ls_text-text_id
                                   iv_long_text        = ls_text-text_value
                         IMPORTING ev_message          = DATA(lv_message)
                         RECEIVING rv_success           = DATA(lv_success) ).
      IF lv_success = abap_false.
        APPEND |Update "{ ls_text-label }" failed{ COND #( WHEN lv_message IS NOT INITIAL THEN |: { lv_message }| ) }|
          TO et_error.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD upsert_item_text.
    DATA(lv_endpoint_patch) =
      |{ c_service_root }A_SalesOrderItemText| &&
      |(SalesOrder='{ iv_sales_order }',SalesOrderItem='{ iv_sales_order_item }',| &&
      |Language='EN',LongTextID='{ iv_long_text_id }')|.

    do_call( EXPORTING iv_endpoint    = lv_endpoint_patch
                        iv_body        = |\{ "LongText":"{ escape_json( iv_long_text ) }" \}|
                        iv_method      = 'PATCH'
                        iv_sent_fields = VALUE string_table( ( `LongText` ) )
             IMPORTING ev_code        = DATA(lv_code)
                       ev_message     = ev_message
             RECEIVING rv_success     = rv_success ).
    IF rv_success = abap_true.
      RETURN.
    ENDIF.

    " Text với LongTextID này chưa tồn tại trên item -> tạo mới (POST)
    IF lv_code = 404.
      DATA(lv_body_post) =
        |\{ "SalesOrder":"{ iv_sales_order }",| &&
        |"SalesOrderItem":"{ iv_sales_order_item }",| &&
        |"Language":"EN",| &&
        |"LongTextID":"{ iv_long_text_id }",| &&
        |"LongText":"{ escape_json( iv_long_text ) }" \}|.

      do_call( EXPORTING iv_endpoint    = |{ c_service_root }A_SalesOrderItemText|
                          iv_body        = lv_body_post
                          iv_method      = 'POST'
                          iv_sent_fields = VALUE string_table( ( `LongText` ) )
               IMPORTING ev_message     = ev_message
               RECEIVING rv_success     = rv_success ).
    ENDIF.
  ENDMETHOD.


  METHOD find_pricing_element.
    DATA(lv_filter) = |SalesOrder eq '{ iv_sales_order }' and SalesOrderItem eq '{ iv_sales_order_item }'|.

    do_call( EXPORTING iv_endpoint = |{ c_service_root }A_SalesOrderItemPrElement|
                        iv_method   = 'GET'
                        iv_filter   = lv_filter
             IMPORTING ev_response = DATA(lv_response)
                       ev_message  = ev_message
             RECEIVING rv_success  = DATA(lv_ok) ).

    IF lv_ok = abap_false OR lv_response IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_mapping) = VALUE /ui2/cl_json=>name_mappings(
      ( abap = 'pricing_procedure_step'      json = 'PricingProcedureStep' )
      ( abap = 'pricing_procedure_counter'   json = 'PricingProcedureCounter' )
      ( abap = 'condition_type'              json = 'ConditionType' )
      ( abap = 'transaction_currency'        json = 'TransactionCurrency' )
      ( abap = 'condition_quantity_iso_unit' json = 'ConditionQuantityISOUnit' ) ).

    DATA(ls_response) = VALUE ty_pr_element_response( ).
    /ui2/cl_json=>deserialize( EXPORTING json          = lv_response
                                          name_mappings = lt_mapping
                                CHANGING  data          = ls_response ).

    ASSIGN ls_response-d-results[ condition_type = iv_condition_type ] TO FIELD-SYMBOL(<element>).
    IF sy-subrc <> 0.
      ev_message = |Pricing Element not found for ConditionType { iv_condition_type } | &&
                   |in SO { iv_sales_order } Item { iv_sales_order_item }|.
      RETURN.
    ENDIF.

    ev_proc_step                   = <element>-pricing_procedure_step.
    ev_proc_counter                = <element>-pricing_procedure_counter.
    ev_transaction_currency        = <element>-transaction_currency.
    ev_condition_quantity_iso_unit = <element>-condition_quantity_iso_unit.
    rv_found                       = abap_true.
  ENDMETHOD.


  METHOD update_pricing_element.
    find_pricing_element(
      EXPORTING iv_sales_order                  = is_data-sales_order
                iv_sales_order_item             = is_data-sales_order_item
                iv_condition_type               = is_data-condition_type
      IMPORTING ev_proc_step                    = DATA(lv_proc_step)
                ev_proc_counter                 = DATA(lv_proc_counter)
                ev_condition_quantity_iso_unit  = DATA(lv_condition_quantity_iso_unit)
                ev_transaction_currency         = DATA(lv_transaction_currency)
                ev_message                      = ev_message
      RECEIVING rv_found                        = DATA(lv_found) ).

    IF lv_found = abap_false.
      RETURN. " rv_success = abap_false (initial), ev_message đã được set
    ENDIF.

    DATA(lt_fields)      = VALUE string_table( ).
    DATA(lt_sent_fields) = VALUE string_table( ).

    IF is_data-condition_amount IS NOT INITIAL.
      APPEND |"ConditionRateAmount":{ is_data-condition_amount }| TO lt_fields.
      APPEND `ConditionRateAmount` TO lt_sent_fields.
    ENDIF.
    IF is_data-currency IS NOT INITIAL.
      APPEND |"ConditionCurrency":"{ is_data-currency }"| TO lt_fields.
      APPEND `ConditionCurrency` TO lt_sent_fields.
    ENDIF.
    IF is_data-condition_pricing_unit IS NOT INITIAL.
      APPEND |"ConditionQuantity":{ is_data-condition_pricing_unit }| TO lt_fields.
      APPEND `ConditionQuantity` TO lt_sent_fields.
      APPEND |"ConditionQuantityISOUnit":"{ lv_condition_quantity_iso_unit }"| TO lt_fields.
      APPEND `ConditionQuantityISOUnit` TO lt_sent_fields.
    ENDIF.

    IF lt_fields IS INITIAL.
      rv_success = abap_true.
      RETURN.
    ENDIF.

    DATA(lv_endpoint) = |{ c_endpoint_pr_element }| &&
      |(SalesOrder='{ is_data-sales_order }',SalesOrderItem='{ is_data-sales_order_item }',| &&
      |PricingProcedureStep='{ lv_proc_step }',PricingProcedureCounter='{ lv_proc_counter }')|.

    do_call( EXPORTING iv_endpoint    = lv_endpoint
                        iv_body        = |\{ { concat_lines_of( table = lt_fields sep = `,` ) } \}|
                        iv_method      = 'PATCH'
                        iv_sent_fields = lt_sent_fields
             IMPORTING ev_message     = ev_message
             RECEIVING rv_success     = rv_success ).
  ENDMETHOD.


  METHOD set_result.
    IF it_error IS INITIAL.
      cs_data-messagetype = 'S'.
      cs_data-message      = 'Success'.
      RETURN.
    ENDIF.

    DATA(lv_message) = concat_lines_of( table = it_error sep = c_error_sep ).

    cs_data-messagetype = 'E'.
    cs_data-message      = substring( val = lv_message
                                       len = nmin( val1 = c_message_max_length
                                                   val2 = strlen( lv_message ) ) ).
  ENDMETHOD.


  METHOD get_field_label.
    CASE iv_field.
      WHEN 'ConditionQuantity'.
        rv_label = 'Per'.
      WHEN 'Product'.
        rv_label = 'Material'.
      WHEN 'ConditionRateAmount'.
        rv_label = 'Amount'.
      WHEN 'ConditionCurrency'.
        rv_label = 'Crcy'.
      WHEN OTHERS.
        rv_label = iv_field.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
