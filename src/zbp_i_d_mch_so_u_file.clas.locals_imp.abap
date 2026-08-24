






CLASS lhc_ManageFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        accepted  TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected  TYPE c LENGTH 1 VALUE 'X', "Rejected
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In process
        error     TYPE c LENGTH 1 VALUE 'E', "Error
        success   TYPE c LENGTH 1 VALUE 'S', "Success
      END OF file_status.

    " Số dòng header trong template Excel (3 dòng: 2 dòng title gộp +
    " 1 dòng field name) - CẦN xác nhận lại đúng theo template thực tế,
    " template hiện tại (Template_Mass_Change_Sale_Order.xlsx) có 3 dòng
    " header trước khi tới dữ liệu.
    CONSTANTS c_header_rows TYPE i VALUE 3.

    " Thứ tự field ở đây PHẢI khớp đúng thứ tự cột A->M trong file Excel,
    " vì XCO xlsx map theo VỊ TRÍ CỘT, không phải theo tên header.
    TYPES: BEGIN OF ty_file_upload,
             SalesOrder            TYPE string, "A - SO
             SalesOrderItem        TYPE string, "B - SO item
             Material              TYPE string, "C - Material
             Plant                 TYPE string, "D - Plant
             OrderQuantity         TYPE string, "E - Order Quantity
             ConditionType         TYPE string, "F - Conditon Type
             ConditionAmount       TYPE string, "G - Amount
             Currency              TYPE string, "H - Crcy
             ConditionPricingUnit  TYPE string, "I - Per
             TextPriceApproval     TYPE string, "J - Số duyệt giá
             TextOrderTolerance    TYPE string, "K - Dung sai đơn hàng
             TextSalesNoteCustomer TYPE string, "L - Sales Note for Customer
             CustomerReference     TYPE string, "M - Customer Reference
           END OF ty_file_upload.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ManageFile RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE ManageFile.

    METHODS downloadFile FOR MODIFY
      IMPORTING keys FOR ACTION ManageFile~downloadFile RESULT result.

    METHODS downloadTemplate FOR MODIFY
      IMPORTING keys FOR ACTION ManageFile~downloadTemplate.

    METHODS uploadExcel FOR MODIFY
      IMPORTING keys FOR ACTION ManageFile~uploadExcel.

    METHODS setStatusToOpen FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ManageFile~setStatusToOpen.

    METHODS getExcelData FOR DETERMINE ON SAVE
      IMPORTING keys FOR ManageFile~getExcelData.

    METHODS getInstanceFeatures FOR INSTANCE FEATURES
	  IMPORTING keys REQUEST requested_features FOR ManageFile RESULT result.

ENDCLASS.

CLASS lhc_ManageFile IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.
    LOOP AT entities
               ASSIGNING FIELD-SYMBOL(<f_entities>)
               WHERE uuid IS NOT INITIAL.

      APPEND CORRESPONDING #( <f_entities> ) TO mapped-managefile.

    ENDLOOP.

    DATA(lt_file) = entities.

    DELETE lt_file WHERE uuid IS NOT INITIAL.

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_file ASSIGNING <f_entities>.

      TRY.
          <f_entities>-uuid = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
        CATCH cx_uuid_error.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft
          )
                 TO reported-managefile.

          APPEND VALUE #( %cid      = <f_entities>-%cid
                          %key      = <f_entities>-%key
                          %is_draft = <f_entities>-%is_draft )
                 TO failed-managefile.

          EXIT.
      ENDTRY.

      APPEND VALUE #( %cid      = <f_entities>-%cid
                      %key      = <f_entities>-%key
                      %is_draft = <f_entities>-%is_draft )
       TO mapped-managefile.
    ENDLOOP.
  ENDMETHOD.

  METHOD downloadFile.
    " TODO: build lại file (excel/attachment) từ dữ liệu hiện có để trả về result
  ENDMETHOD.

  METHOD downloadTemplate.
    " TODO: trả về file template mẫu (đọc từ MIME repository hoặc build động)
  ENDMETHOD.

  METHOD uploadExcel.
    DATA lt_file TYPE STANDARD TABLE OF ty_file_upload.

    DATA: lt_mn_file TYPE TABLE FOR CREATE zi_d_mch_so_u_file,
          ls_mn_file LIKE LINE OF lt_mn_file.

    READ TABLE keys ASSIGNING FIELD-SYMBOL(<k>) INDEX 1.

    CHECK sy-subrc = 0.

    IF <k>-%param-filecontent IS INITIAL.
      RETURN.
    ENDIF.

    ls_mn_file-attachment = <k>-%param-filecontent.
    ls_mn_file-filename   = <k>-%param-filename.
    ls_mn_file-mimetype   = <k>-%param-mimetype.

    FINAL(lv_filecontent) = <k>-%param-filecontent.

    FINAL(lo_xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = lv_filecontent )->read_access( ).
    FINAL(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).

    FINAL(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

    FINAL(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( lt_file ) ).

    lo_execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
               )->if_xco_xlsx_ra_operation~execute( ).

    " Bỏ các dòng header (xem c_header_rows - hiện = 3 theo template)
    IF lt_file IS NOT INITIAL.
      DO c_header_rows TIMES.
        DELETE lt_file INDEX 1.
      ENDDO.
    ENDIF.

    DELETE lt_file WHERE salesorder IS INITIAL AND salesorderitem IS INITIAL.

    IF lines( lt_file ) > 100.
*      APPEND VALUE #( %cid = <k>-%cid ) TO failed-managefile.

      APPEND VALUE #( %cid      = <k>-%cid
                       %msg      = new_message( id       = 'Z_FILE_MSG'          " TODO: đổi thành message class thực tế
                                                 number   = '001'                   " TODO: đổi thành số message thực tế
                                                 severity = if_abap_behv_message=>severity-error ) )                       " TODO: đổi tên field tương ứng nếu cần highlight field lỗi
        TO reported-managefile.

      RETURN.
    ENDIF.
    	

    DATA lv_error TYPE abap_boolean VALUE IS INITIAL.

    "TODO: Validate dữ liệu file (nếu cần) trước khi cho lưu

    IF lv_error = abap_false.
      ls_mn_file-Countline = lines( lt_file ).
      APPEND ls_mn_file TO lt_mn_file.
    ENDIF.



    IF lt_mn_file IS NOT INITIAL.
      MODIFY ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
        ENTITY managefile
        CREATE AUTO FILL CID FIELDS (
                          status
                          attachment
                          mimetype
                          filename
                          countline
                          createdbyuser
                          createddate
                          changedbyuser
                          changeddate
                        ) WITH lt_mn_file
        MAPPED DATA(lt_mapped_create)
        REPORTED DATA(lt_reported_create)
        FAILED DATA(lt_failed_create).

      APPEND VALUE #( %cid      = <k>-%cid
               %msg      = new_message( id       = 'Z_FILE_MSG'          " TODO: đổi thành message class thực tế
                                         number   = '002'                   " TODO: đổi thành số message thực tế
                                         severity = if_abap_behv_message=>severity-success ) )                       " TODO: đổi tên field tương ứng nếu cần highlight field lỗi
TO reported-managefile.

      RETURN.
    ENDIF.


  ENDMETHOD.

  METHOD setStatusToOpen.
    READ ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
     ENTITY managefile
       FIELDS ( status )
       WITH CORRESPONDING #( keys )
     RESULT DATA(lt_file).

    "If Status is already set, do nothing
    DELETE lt_file WHERE status IS NOT INITIAL.
    DELETE lt_file WHERE status = 'X'.

    CHECK lt_file IS NOT INITIAL.

    DATA lv_cnt1 TYPE i.
    DATA lv_cnt2 TYPE i.
    DATA lv_next TYPE i.

    " lấy max không cộng sẵn
    SELECT SINGLE MAX( zcount )
      FROM ztb_m_mco_so_upl
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt1.

    SELECT SINGLE MAX( zcount )
      FROM ztbm_mco_so_up_d
      WHERE createdbyuser = @sy-uname
      INTO @lv_cnt2.

    lv_next = COND i( WHEN lv_cnt1 >= lv_cnt2 THEN lv_cnt1 + 1 ELSE lv_cnt2 + 1 ).

    MODIFY ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
      ENTITY managefile
        UPDATE FIELDS ( status zcount )
        WITH VALUE #( FOR ls_file IN lt_file ( %tky   = ls_file-%tky
                                               status = file_status-open
                                               zcount = lv_next ) ).
  ENDMETHOD.

  METHOD getExcelData.
    DATA: lt_file TYPE STANDARD TABLE OF ty_file_upload.

    " ── 1. Read parent instance ───────────────────────────────────
    READ ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
      ENTITY managefile
      ALL FIELDS WITH
      CORRESPONDING #( keys )
      RESULT FINAL(lt_record).

    IF lt_record IS INITIAL.
      RETURN.
    ENDIF.

    FINAL(lv_filecontent) = lt_record[ 1 ]-attachment.

    CHECK sy-subrc = 0.

    " ── 2. Parse Excel ────────────────────────────────────────────
    FINAL(lo_xlsx) = xco_cp_xlsx=>document->for_file_content(
                       iv_file_content = lv_filecontent
                     )->read_access( ).
    FINAL(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).
    FINAL(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).
    FINAL(lo_execute) = lo_worksheet->select( lo_selection_pattern
      )->row_stream(
      )->operation->write_to( REF #( lt_file ) ).

    lo_execute->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    )->if_xco_xlsx_ra_operation~execute( ).

    " Bỏ các dòng header
    IF lt_file IS NOT INITIAL.
      DO c_header_rows TIMES.
        DELETE lt_file INDEX 1.
      ENDDO.
    ENDIF.

    DELETE lt_file WHERE salesorder IS INITIAL AND salesorderitem IS INITIAL.

    IF lt_file IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE lt_record ASSIGNING FIELD-SYMBOL(<f_file>) INDEX 1.

    " ── 3. Process data Raw ───────────────────────────────────────
    DATA: lt_data_file TYPE TABLE OF zi_d_mch_so_u_data.

    LOOP AT lt_file INTO DATA(ls_file).
      APPEND INITIAL LINE TO lt_data_file ASSIGNING FIELD-SYMBOL(<lfs_data_file>).

      " TODO: template hiện chưa có cột "Type" (I/M/D) - mặc định 'M'
      " (Modify) vì mục đích file này là Mass CHANGE. Nếu sau này template
      " có thêm cột Type riêng, đổi lại chỗ này cho đúng.
      <lfs_data_file>-Type                  = 'M'.

      <lfs_data_file>-SalesOrder            = |{ ls_file-SalesOrder ALPHA = IN }|.
      <lfs_data_file>-SalesOrderItem        = |{ ls_file-SalesOrderItem ALPHA = IN }|.
      <lfs_data_file>-Material              = |{ ls_file-Material ALPHA = IN }|.
      <lfs_data_file>-Plant                 = |{ ls_file-Plant ALPHA = IN }|.
      <lfs_data_file>-OrderQuantity         = ls_file-OrderQuantity.
      <lfs_data_file>-ConditionType         = ls_file-ConditionType.
      <lfs_data_file>-ConditionAmount       = ls_file-ConditionAmount.
      <lfs_data_file>-Currency              = ls_file-Currency.
      <lfs_data_file>-ConditionPricingUnit  = ls_file-ConditionPricingUnit.
      <lfs_data_file>-TextPriceApproval     = ls_file-TextPriceApproval.
      <lfs_data_file>-TextOrderTolerance    = ls_file-TextOrderTolerance.
      <lfs_data_file>-TextSalesNoteCustomer = ls_file-TextSalesNoteCustomer.
      <lfs_data_file>-CustomerReference     = ls_file-CustomerReference.
    ENDLOOP.

*    " ── 4. Xóa duplicate trong file ──────────────────────────────
*    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
*
*    LOOP AT lt_data_file INTO DATA(ls_seen_dup).
*      DATA(lv_key) =
*        ls_seen_dup-Type
*        && ls_seen_dup-SalesOrder
*        && ls_seen_dup-SalesOrderItem
*        && ls_seen_dup-Material
*        && ls_seen_dup-Plant
*        && ls_seen_dup-OrderQuantity
*        && ls_seen_dup-ConditionType
*        && ls_seen_dup-ConditionAmount
*        && ls_seen_dup-Currency
*        && ls_seen_dup-ConditionPricingUnit
*        && ls_seen_dup-CustomerReference.
*
*      INSERT lv_key INTO TABLE lt_seen.
*      IF sy-subrc <> 0.
*        " Trùng → xóa khỏi table
*        DELETE lt_data_file.
*      ENDIF.
*    ENDLOOP.
*
*    IF lt_data_file IS INITIAL.
*      RETURN.
*    ENDIF.

    " ── 5. Build lt_file_c để create DataFile ────────────────────
    DATA lt_file_c TYPE TABLE FOR CREATE zi_d_mch_so_u_file\_datafile.
    DATA ls_file_c LIKE LINE OF lt_file_c.
    DATA lv_index TYPE i.

    LOOP AT lt_data_file INTO DATA(ls_data_file).
      lv_index = lv_index + 1.

      ls_file_c = VALUE #(
          %tky    = <f_file>-%tky
          %target = VALUE #( (
            %cid                  = |CID_D_{ lv_index }|

            Type                  = ls_data_file-Type
            SalesOrder            = ls_data_file-SalesOrder
            SalesOrderItem        = ls_data_file-SalesOrderItem
            Material              = ls_data_file-Material
            Plant                 = ls_data_file-Plant
            OrderQuantity         = ls_data_file-OrderQuantity
            ConditionType         = ls_data_file-ConditionType
            ConditionAmount       = ls_data_file-ConditionAmount
            Currency              = ls_data_file-Currency
            ConditionPricingUnit  = ls_data_file-ConditionPricingUnit
            TextPriceApproval     = ls_data_file-TextPriceApproval
            TextOrderTolerance    = ls_data_file-TextOrderTolerance
            TextSalesNoteCustomer = ls_data_file-TextSalesNoteCustomer
            CustomerReference     = ls_data_file-CustomerReference

            message               = ls_data_file-message
            messagetype           = ls_data_file-messagetype
          ) )
      ).

      APPEND ls_file_c TO lt_file_c.
      CLEAR ls_file_c.
    ENDLOOP.

    IF lt_file_c IS INITIAL.
      RETURN.
    ENDIF.

    " ── 6. Create DataFile records ────────────────────────────────
    MODIFY ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
      ENTITY managefile
      CREATE BY \_datafile
      FIELDS (
        Type
        SalesOrder
        SalesOrderItem
        Material
        Plant
        OrderQuantity
        ConditionType
        ConditionAmount
        Currency
        ConditionPricingUnit
        TextPriceApproval
        TextOrderTolerance
        TextSalesNoteCustomer
        CustomerReference

        message
        messagetype
      )
      WITH lt_file_c
      MAPPED   DATA(lt_mapped_create)
      REPORTED DATA(lt_mapped_reported)
      FAILED   DATA(lt_failed_create).
  ENDMETHOD.

  METHOD getinstancefeatures.
    READ ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
      ENTITY managefile
      FIELDS ( status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file).

    result = VALUE #( FOR ls_file IN lt_file
    ( %tky    = ls_file-%tky
    %features-%update = COND #( WHEN ls_file-status = file_status-completed
    THEN if_abap_behv=>fc-o-disabled
    ELSE if_abap_behv=>fc-o-enabled )
    %features-%delete = COND #( WHEN ls_file-status = file_status-completed
  THEN if_abap_behv=>fc-o-disabled
  ELSE if_abap_behv=>fc-o-enabled )
) ).

  ENDMETHOD.

ENDCLASS.


CLASS lhc_DataFile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF file_status,
        open      TYPE c LENGTH 1 VALUE 'M', "Not process
        accepted  TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected  TYPE c LENGTH 1 VALUE 'X', "Rejected
        completed TYPE c LENGTH 1 VALUE 'D', "Done
        inprocess TYPE c LENGTH 1 VALUE 'P', "In Process
        error     TYPE c LENGTH 1 VALUE 'E', "Error
        success   TYPE c LENGTH 1 VALUE 'S', "Success
      END OF file_status.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR DataFile RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR DataFile RESULT result.

    METHODS PostConfirm FOR MODIFY
      IMPORTING keys FOR ACTION DataFile~PostConfirm RESULT result.

    METHODS setStatusToUpdate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR DataFile~setStatusToUpdate.

ENDCLASS.

CLASS lhc_DataFile IMPLEMENTATION.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD PostConfirm.
    " ── 1. SELECT toàn bộ record cần xử lý ─────────────────────────
    SELECT * FROM ztb_d_mch_so_upl
      WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @keys
      WHERE uuid = @keys-uuid
        AND messagetype NE 'S'
      INTO TABLE @DATA(lt_data).

    IF lt_data IS INITIAL.
      RETURN.
    ENDIF.

    " ── 2. Nếu > 10 record → KHÔNG xử lý đồng bộ, chuyển background ─
    IF lines( lt_data ) > 0.

      MODIFY ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
        ENTITY datafile
        UPDATE FIELDS ( messagetype message )
        WITH VALUE #( FOR ls_data IN lt_data (
          %tky-uuid     = ls_data-uuid
          %tky-uuidfile = ls_data-uuidfile
          messagetype   = 'J'   " J = Job pending, save_modified sẽ đọc cờ này
          message       = 'Processing in the background'
        ) )
        FAILED   DATA(lt_job_failed)
        REPORTED DATA(lt_job_reported).

      MODIFY ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
        ENTITY managefile
        UPDATE FIELDS ( status )
        WITH VALUE #( (
          %tky-uuid = lt_data[ 1 ]-uuidfile
          %is_draft = if_abap_behv=>mk-off
          status    = file_status-inprocess
        ) )
        FAILED   DATA(lt_hdr_failed)
        REPORTED DATA(lt_hdr_reported).

      DATA(lv_uuidfile) = lt_data[ 1 ]-uuidfile.   " lấy từ record đã xử lý
      result = VALUE #( FOR ls_key IN keys
  ( %tky      = ls_key-%tky
    %param-%tky = VALUE #( uuid = lv_uuidfile ) ) ).

      RETURN.  " Không xử lý API ngay, save_modified sẽ schedule job
    ENDIF.

    " ── 3. <= 10 record → xử lý ĐỒNG BỘ như cũ ──────────────────────
    DATA(lt_data_insert) = lt_data.
    DELETE lt_data_insert WHERE type <> 'I'.
    DATA(lt_data_update) = lt_data.
    DELETE lt_data_update WHERE type <> 'M'.
    DATA(lt_data_delete) = lt_data.
    DELETE lt_data_delete WHERE type <> 'D'.

    zcl_call_api_ud_so=>update( CHANGING ct_data = lt_data_update ).

    LOOP AT lt_data_insert ASSIGNING FIELD-SYMBOL(<fs_ins>).
      <fs_ins>-messagetype = 'E'.
      <fs_ins>-message     = 'Insert chưa được hỗ trợ ở phiên bản hiện tại'.
    ENDLOOP.
    LOOP AT lt_data_delete ASSIGNING FIELD-SYMBOL(<fs_del>).
      <fs_del>-messagetype = 'E'.
      <fs_del>-message     = 'Delete chưa được hỗ trợ ở phiên bản hiện tại'.
    ENDLOOP.

    LOOP AT lt_data_update INTO DATA(ls_udt_result).
      READ TABLE lt_data ASSIGNING FIELD-SYMBOL(<fs_merge>)
           WITH KEY uuid = ls_udt_result-uuid uuidfile = ls_udt_result-uuidfile.
      IF sy-subrc = 0.
        <fs_merge>-messagetype = ls_udt_result-messagetype.
        <fs_merge>-message     = ls_udt_result-message.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_data_insert INTO DATA(ls_ins_result).
      READ TABLE lt_data ASSIGNING <fs_merge>
           WITH KEY uuid = ls_ins_result-uuid uuidfile = ls_ins_result-uuidfile.
      IF sy-subrc = 0.
        <fs_merge>-messagetype = ls_ins_result-messagetype.
        <fs_merge>-message     = ls_ins_result-message.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_data_delete INTO DATA(ls_del_result).
      READ TABLE lt_data ASSIGNING <fs_merge>
           WITH KEY uuid = ls_del_result-uuid uuidfile = ls_del_result-uuidfile.
      IF sy-subrc = 0.
        <fs_merge>-messagetype = ls_del_result-messagetype.
        <fs_merge>-message     = ls_del_result-message.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
      ENTITY datafile
      UPDATE FIELDS ( messagetype message )
      WITH VALUE #( FOR ls_data IN lt_data (
        %tky-uuid     = ls_data-uuid
        %tky-uuidfile = ls_data-uuidfile
        messagetype   = ls_data-messagetype
        message       = ls_data-message
      ) )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    DATA(lv_all_success) = abap_true.
    DATA(lv_count_done) = 0.
    LOOP AT lt_data INTO DATA(ls_child).
      IF ls_child-messagetype <> 'S'.
*        lv_all_success = abap_false.
      ELSE.
        lv_count_done += 1.
      ENDIF.
    ENDLOOP.

    DATA(lv_new_status) = COND #(
      WHEN lv_all_success = abap_true THEN file_status-completed
      ELSE file_status-inprocess ).

    MODIFY ENTITIES OF zi_d_mch_so_u_file IN LOCAL MODE
      ENTITY managefile
      UPDATE FIELDS ( status ZcountDone )
      WITH VALUE #( (
        %tky-uuid = lt_data[ 1 ]-uuidfile
        %is_draft = if_abap_behv=>mk-off
        status    = lv_new_status
        ZcountDone = lv_count_done
      ) )
      FAILED   lt_hdr_failed
      REPORTED lt_hdr_reported.


  ENDMETHOD.


  METHOD setStatusToUpdate.
  ENDMETHOD.

ENDCLASS.


CLASS lsc_ZI_D_MCH_SO_U_FILE DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZI_D_MCH_SO_U_FILE IMPLEMENTATION.

  METHOD save_modified.
    IF update-datafile IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_found    TYPE abap_boolean.
    DATA lv_uuidfile TYPE sysuuid_x16.

    LOOP AT update-datafile ASSIGNING FIELD-SYMBOL(<upd>)
      WHERE messagetype = 'J'.

      lv_found    = abap_true.
      lv_uuidfile = <upd>-uuidfile.
      EXIT.
    ENDLOOP.

    CHECK lv_found = abap_true.

    GET TIME STAMP FIELD DATA(ls_ts).

    TRY.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = 'ZJT_MCH_SO_UPLOAD'
            iv_job_text            = |Mass Change SO - Background { ls_ts TIMESTAMP = ISO }|
            is_start_info          = VALUE #(
              timestamp = cl_abap_tstmp=>add( tstmp = ls_ts secs = 1 )
            )
            is_end_info            = VALUE #( type = 'NUM' max_iterations = 1 )
            is_scheduling_info     = VALUE #(
              periodic_value = 1
              test_mode      = abap_false
              timezone       = 'CET'
            )
            it_job_parameter_value = VALUE #( (
              name    = 'HDR_ID'
              t_value = VALUE #( (
                sign = 'I' option = 'EQ' low = lv_uuidfile
              ) )
            ) )
          IMPORTING
            ev_jobname = DATA(lv_jobname)
        ).

      CATCH cx_apj_rt INTO DATA(lx_apj).
        APPEND VALUE #(
          uuid     = <upd>-uuid
          uuidfile = <upd>-uuidfile
          %msg     = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = lx_apj->get_longtext( )
                     )
        ) TO reported-datafile.
    ENDTRY.
  ENDMETHOD.


  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
