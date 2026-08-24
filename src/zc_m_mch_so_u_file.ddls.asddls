@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proj.View Mange Upload File'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define root view entity ZC_M_MCH_SO_U_FILE
  provider contract transactional_query
  as projection on ZI_D_MCH_SO_U_FILE
{
  key Uuid,
      Zcount,
      ZcountDone,
      @ObjectModel.text.element: ['OverallStatusText']
      Status,

      Criticality,

      @EndUserText.label: 'Status'
      @Semantics.text: true
      _OverallStatus.description as OverallStatusText,

      @Semantics.largeObject: {
        mimeType: 'Mimetype',
        fileName: 'Filename',
        contentDispositionPreference: #ATTACHMENT
      }
      Attachment,
      @Semantics.mimeType: true
      Mimetype,
      Filename,
      Countline,
      createdbyuser,
      createddate,
      changedbyuser,
      changeddate,
      /* Associations */
      _DataFile : redirected to composition child ZC_D_MCH_SO_U_DATA,
      _OverallStatus
}
