public with sharing class AccountTriggerHandler {
    public static void handleBeforeInsert(List <Account> accounts){
        AccountMasterLinkingService.linkMasterBeforeSave(accounts, null);
        EquityPlanAccountService.serviceTypeValidation(accounts, null);
    }    
    public static void handleBeforeUpdate(List <Account> accounts, Map <Id,Account> oldAccs){
        AccountMasterLinkingService.linkMasterBeforeSave(accounts, oldAccs);
        EquityPlanAccountService.serviceTypeValidation(accounts, oldAccs);
    }
    public static void handleAfterInsert(List <Account> accounts){
        AccountMasterLinkingService.linkMasterAfterSave(accounts, null);
        AccountEpAutomatedSharingService.sharingProcess(accounts, null);
    }   
    public static void handleAfterUpdate(List <Account> accounts, Map <Id,Account> oldAccs){
        AccountMasterLinkingService.linkMasterAfterSave(accounts, oldAccs);
        AccountEpAutomatedSharingService.sharingProcess(accounts, oldAccs);
    }
    public static void handleAfterDelete(List<Account> accounts, Map<Id, Account> oldAccs){
        AccountEpAutomatedSharingService.sharingProcess(accounts, oldAccs);
    }
    public static void handleAfterUndelete(List <Account> accounts){
        AccountEpAutomatedSharingService.sharingProcess(accounts, null);
    }
}