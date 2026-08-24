CLASS zcl_job_mch_so_upload DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_apj_dt_exec_object .
    INTERFACES if_apj_rt_exec_object .

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
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_JOB_MCH_SO_UPLOAD IMPLEMENTATION.


  METHOD if_apj_rt_exec_object~execute.
    LOOP AT it_parameters INTO DATA(ls_param).
      " ── 1. SELECT ────────────────────────────────────────────────
      SELECT * FROM ztb_d_mch_so_upl
        WITH PRIVILEGED ACCESS
        WHERE uuidfile = @ls_param-low
          AND messagetype = 'J'
        INTO TABLE @DATA(lt_data).

      IF lt_data IS INITIAL.
        RETURN.
      ENDIF.

      " Chỉ hỗ trợ Mass CHANGE (Type = 'M'). Insert/Delete báo lỗi.
      DATA(lt_data_insert) = lt_data.
      DELETE lt_data_insert WHERE type <> 'I'.
      DATA(lt_data_update) = lt_data.
      DELETE lt_data_update WHERE type <> 'M'.
      DATA(lt_data_delete) = lt_data.
      DELETE lt_data_delete WHERE type <> 'D'.

      IF lt_data_insert IS INITIAL
          AND lt_data_update IS INITIAL
          AND lt_data_delete IS INITIAL.
        RETURN.
      ENDIF.

      " ── 2. Gọi API mass update Sales Order (chỉ hỗ trợ Type = 'M') ──
      zcl_call_api_ud_so=>update( CHANGING ct_data = lt_data_update ).

      LOOP AT lt_data_insert ASSIGNING FIELD-SYMBOL(<fs_ins>).
        <fs_ins>-messagetype = 'E'.
        <fs_ins>-message     = 'Insert chưa được hỗ trợ ở phiên bản hiện tại'.
      ENDLOOP.
      LOOP AT lt_data_delete ASSIGNING FIELD-SYMBOL(<fs_del>).
        <fs_del>-messagetype = 'E'.
        <fs_del>-message     = 'Delete chưa được hỗ trợ ở phiên bản hiện tại'.
      ENDLOOP.

      " ── 3.1. Merge kết quả từ lt_data_insert ngược về lt_data ──────
      LOOP AT lt_data_insert INTO DATA(ls_ins_result).
        READ TABLE lt_data ASSIGNING FIELD-SYMBOL(<fs_merge>)
             WITH KEY uuid     = ls_ins_result-uuid
                      uuidfile = ls_ins_result-uuidfile.
        IF sy-subrc = 0.
          <fs_merge>-messagetype = ls_ins_result-messagetype.
          <fs_merge>-message     = ls_ins_result-message.
        ENDIF.
      ENDLOOP.
      " ── 3.2. Merge kết quả từ lt_data_update ngược về lt_data ──────
      LOOP AT lt_data_update INTO DATA(ls_udt_result).
        READ TABLE lt_data ASSIGNING <fs_merge>
             WITH KEY uuid     = ls_udt_result-uuid
                      uuidfile = ls_udt_result-uuidfile.
        IF sy-subrc = 0.
          <fs_merge>-messagetype = ls_udt_result-messagetype.
          <fs_merge>-message     = ls_udt_result-message.
        ENDIF.
      ENDLOOP.
      " ── 3.3. Merge kết quả từ lt_data_delete ngược về lt_data ──────
      LOOP AT lt_data_delete INTO DATA(ls_del_result).
        READ TABLE lt_data ASSIGNING <fs_merge>
             WITH KEY uuid     = ls_del_result-uuid
                      uuidfile = ls_del_result-uuidfile.
        IF sy-subrc = 0.
          <fs_merge>-messagetype = ls_del_result-messagetype.
          <fs_merge>-message     = ls_del_result-message.
        ENDIF.
      ENDLOOP.

      " ── 4. Update status ─────────────────────────────────────
      MODIFY ENTITIES OF zi_d_mch_so_u_file
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

      COMMIT WORK AND WAIT.

      " ── 5. Update parent status ─────────────────────────────────────
      DATA(lv_all_success) = abap_true.
      DATA(lv_count_done) = 0.
      LOOP AT lt_data INTO DATA(ls_child).
        IF ls_child-messagetype <> 'S'.
*          lv_all_success = abap_false.
        ELSE.
          lv_count_done = lv_count_done + 1.
        ENDIF.
      ENDLOOP.

      DATA(lv_new_status) = COND #(
        WHEN lv_all_success = abap_true
        THEN file_status-completed    " D = Done
        ELSE file_status-inprocess    " P = In process
      ).

      MODIFY ENTITIES OF zi_d_mch_so_u_file
        ENTITY managefile
        UPDATE FIELDS ( status ZcountDone )
        WITH VALUE #( (
          %tky-uuid = lt_data[ 1 ]-uuidfile
          %is_draft = if_abap_behv=>mk-off
          status    = lv_new_status
          ZcountDone = lv_count_done
        ) )
        FAILED   DATA(lt_hdr_failed)
        REPORTED DATA(lt_hdr_reported).

      COMMIT WORK AND WAIT.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = 'HDR_ID'
        kind = if_apj_dt_exec_object=>select_option
        datatype = 'C'
        length = 50
        param_text = 'HDR ID'
        changeable_ind = abap_true )
    ).
  ENDMETHOD.
ENDCLASS.
