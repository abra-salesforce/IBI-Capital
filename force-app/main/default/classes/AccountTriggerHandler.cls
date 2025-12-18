public with sharing class AccountTriggerHandler {
    public static void handleBeforeInsert(List <Account> accounts){
        EquityPlanAccountService.serviceTypeValidation(accounts, null);
    }    
    public static void handleBeforeUpdate(List <Account> accounts, Map <Id,Account> oldAccs){
        EquityPlanAccountService.serviceTypeValidation(accounts, oldAccs);
    }
}