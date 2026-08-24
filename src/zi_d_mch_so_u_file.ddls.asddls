@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Int.View Manage upload file'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_D_MCH_SO_U_FILE
  as select from ztb_m_mco_so_upl
  association [0..1] to zi_req_sta_crud_poc_vh as _OverallStatus on $projection.Status = _OverallStatus.Status
  composition [0..*] of ZI_D_MCH_SO_U_DATA     as _DataFile
{
  key uuid       as Uuid,
      zcount     as Zcount,
      zcount_done as ZcountDone,
      status     as Status,
      case status
      when '' then 0
      when 'P' then 2
      when 'D' then 3
      else 0
      end        as Criticality,
      attachment as Attachment,
      mimetype   as Mimetype,
      filename   as Filename,
      countline  as Countline,
      @Semantics.user.createdBy: true
      createdbyuser,
      @Semantics.systemDateTime.createdAt: true
      createddate,
      @Semantics.user.localInstanceLastChangedBy: true
      changedbyuser,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      changeddate,
      _DataFile,
      _OverallStatus
}
