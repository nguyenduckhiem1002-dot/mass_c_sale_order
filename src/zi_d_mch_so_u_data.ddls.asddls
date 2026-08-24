@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View Data upload mass change SO'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_D_MCH_SO_U_DATA
  as select from ztb_d_mch_so_upl
  association [0..1] to zi_msg_sta_crud_poc_vh    as _OverallStatus on $projection.Messagetype = _OverallStatus.Status
  association        to parent ZI_D_MCH_SO_U_FILE as _ManageFile    on $projection.Uuidfile = _ManageFile.Uuid
{
  key uuid                                            as Uuid,
  key uuidfile                                        as Uuidfile,
      status                                          as Status,
      type                                            as Type,
      sales_order                                     as SalesOrder,
      sales_order_item                                as SalesOrderItem,
      ltrim( cast( material as abap.char(40) ), '0' ) as Material,
      plant                                           as Plant,
      @Semantics.quantity.unitOfMeasure : 'SalesUnit'
      order_quantity                                  as OrderQuantity,
      sales_unit                                      as SalesUnit,
      condition_type                                  as ConditionType,
      @Semantics.amount.currencyCode: 'Currency'
      condition_amount                                as ConditionAmount,
      currency                                        as Currency,
      condition_pricing_unit                          as ConditionPricingUnit,
      text_price_approval                             as TextPriceApproval,
      text_order_tolerance                            as TextOrderTolerance,
      text_sales_note_customer                        as TextSalesNoteCustomer,
      customer_reference                              as CustomerReference,
      messagetype                                     as Messagetype,
      case messagetype
      when '' then 0
      when 'E' then 1
      when 'S' then 3
      else 0
      end                                             as Criticality,
      message                                         as Message,
      @Semantics.user.createdBy: true
      created_by                                      as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      created_at                                      as CreatedAt,

      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by                                 as LastChangedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at                           as LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                                 as LastChangedAt,
      _ManageFile,
      _OverallStatus
}
