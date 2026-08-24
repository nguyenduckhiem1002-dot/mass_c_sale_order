*"* use this source file for your ABAP unit test classes
*&---------------------------------------------------------------------*
*& Test class ZCL_CALL_API_UD_SO
*&
*& !!! INTEGRATION TEST - GỌI API THẬT (API_SALES_ORDER_SRV) !!!
*& RISK LEVEL DANGEROUS vì sẽ PATCH/POST dữ liệu thật lên Sales Order
*& 10001275 (item 10, 20) trên hệ thống test/sandbox đang kết nối qua
*& ZCL_CALL_API. KHÔNG chạy test này trên hệ thống Production, và chỉ
*& chạy khi chắc chắn SO 10001275 tồn tại và việc ghi đè dữ liệu là
*& chấp nhận được trên môi trường đó.
*&
*& test_update_existing_so_item : dùng 2 dòng dữ liệu mẫu do người
*&   dùng cung cấp (SO 10001275 - Item 10 & 20), kỳ vọng update thành
*&   công (messagetype = 'S').
*& test_validate_non_existing_so : SO/Item giả (không tồn tại) - chỉ
*&   chạm CDS view I_SalesOrderItem (không gọi HTTP), kỳ vọng bị chặn
*&   ngay ở bước validate (messagetype = 'E').
*&---------------------------------------------------------------------*
CLASS ltc_call_api_ud_so DEFINITION FINAL FOR TESTING
  DURATION LONG
  RISK LEVEL DANGEROUS.

  PRIVATE SECTION.

    METHODS test_update_existing_so_item FOR TESTING RAISING cx_static_check.
    METHODS test_validate_non_existing_so FOR TESTING RAISING cx_static_check.

    METHODS build_mock_data
      RETURNING VALUE(rt_data) TYPE zcl_call_api_ud_so=>tt_mch_so_upl.

ENDCLASS.


CLASS ltc_call_api_ud_so IMPLEMENTATION.

  METHOD build_mock_data.

    rt_data = VALUE #(
      ( uuid                      = cl_system_uuid=>create_uuid_x16_static( )
        uuidfile                  = cl_system_uuid=>create_uuid_x16_static( )
        type                      = 'M'
        sales_order               = '10001275'
        sales_order_item          = '10'
        order_quantity            = '15'
        text_price_approval       = 'AS323232322'
        text_order_tolerance      = '8%'
        text_sales_note_customer  =
          |Căn cứ Bộ Luật Dân Sự số 91/2015/QH13 đã được Quốc hội | &&
          |nước Cộng Hòa Xã Hội Chủ Nghĩa Việt Nam khóa XIII, kỳ | &&
          |họp thứ 10 thông qua ngày 24/11/2015.L15|
        customer_reference        = 'KHSX-000001' )

      ( uuid                      = cl_system_uuid=>create_uuid_x16_static( )
        uuidfile                  = cl_system_uuid=>create_uuid_x16_static( )
        type                      = 'M'
        sales_order               = '10001275'
        sales_order_item          = '20'
        order_quantity            = '25'
        text_price_approval       = 'AS3232354848'
        customer_reference        = 'KHSX-000002' )
    ).

  ENDMETHOD.


  METHOD test_update_existing_so_item.

    " ── Arrange ──────────────────────────────────────────────────
    DATA(lt_data) = build_mock_data( ).

    " ── Act ──────────────────────────────────────────────────────
    zcl_call_api_ud_so=>update( CHANGING ct_data = lt_data ).

    " ── Assert ───────────────────────────────────────────────────
    " Cả 2 dòng đều là SO/Item được cho là tồn tại thật trên hệ thống
    " test -> kỳ vọng update thành công (messagetype = 'S').
    " Nếu SO/Item không còn tồn tại trên hệ thống bạn đang chạy test,
    " assertion này sẽ fail - kiểm tra lại message trả về để biết lý do
    " thật (SO không tồn tại / API lỗi / field mapping sai...).
    LOOP AT lt_data INTO DATA(ls_data).
      cl_abap_unit_assert=>assert_equals(
        act = ls_data-messagetype
        exp = 'S'
        msg = |SO { ls_data-sales_order } Item { ls_data-sales_order_item }: | &&
              |kỳ vọng messagetype = S, thực tế = { ls_data-messagetype }, | &&
              |message = { ls_data-message }| ).
    ENDLOOP.

  ENDMETHOD.


  METHOD test_validate_non_existing_so.

    " ── Arrange ──────────────────────────────────────────────────
    " SO/Item không tồn tại - chỉ đụng CDS view I_SalesOrderItem,
    " KHÔNG gọi HTTP API nên an toàn để chạy thường xuyên hơn test kia.
    DATA(lt_data) = VALUE zcl_call_api_ud_so=>tt_mch_so_upl(
      ( uuid              = cl_system_uuid=>create_uuid_x16_static( )
        uuidfile          = cl_system_uuid=>create_uuid_x16_static( )
        type              = 'M'
        sales_order       = '99999999'
        sales_order_item  = '999'
        order_quantity    = '1' )
    ).

    " ── Act ──────────────────────────────────────────────────────
    zcl_call_api_ud_so=>update( CHANGING ct_data = lt_data ).

    " ── Assert ───────────────────────────────────────────────────
    cl_abap_unit_assert=>assert_equals(
      act = lt_data[ 1 ]-messagetype
      exp = 'E'
      msg = 'SO/Item không tồn tại phải bị chặn với messagetype = E' ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lt_data[ 1 ]-message
      exp = '*không tồn tại*'
      msg = 'Message phải nêu rõ lý do SO/Item không tồn tại' ).

  ENDMETHOD.

ENDCLASS.
