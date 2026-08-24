@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proj.View Data Mass Change SO'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_D_MCH_SO_U_DATA
  as projection on ZI_D_MCH_SO_U_DATA
{
  key Uuid,
  key Uuidfile,
      Status,
      Type,
      SalesOrder,
      SalesOrderItem,
      Material,
      Plant,
      @Semantics.quantity.unitOfMeasure : 'SalesUnit'
      OrderQuantity,
      SalesUnit,
      ConditionType,
      @Semantics.amount.currencyCode: 'Currency'
      ConditionAmount,
      Currency,
      ConditionPricingUnit,
      TextPriceApproval,
      TextOrderTolerance,
      TextSalesNoteCustomer,
      CustomerReference,
      @ObjectModel.text.element: ['OverallStatusText']
      Messagetype,
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,
      Criticality,
      Message,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      /* Associations */
      _ManageFile : redirected to parent ZC_M_MCH_SO_U_FILE,
      _OverallStatus
}
