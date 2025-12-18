public with sharing class AccountMasterLinkingService {
    public static final Id BUSINESS_MASTER_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business_Account_Master').getRecordTypeId();
    public static final Id PERSON_MASTER_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Person_Account_Master').getRecordTypeId();

    public static void master(List<Account> newAccounts, Map<Id, Account> oldAccounts){
        Map<String, List<Account>> idToAccount = new Map<String, List<Account>>();
        for(Account acc : newAccounts) {
            if (acc.RecordTypeId != BUSINESS_MASTER_RT && acc.RecordTypeId != PERSON_MASTER_RT && (oldAccounts.get(acc.Id).ID__c != acc.ID__c || acc.Id == null)){
                if(idToAccount.containsKey(acc.ID__c)) {
                    idToAccount.get(acc.ID__c).add(acc);
                }
                else {
                    idToAccount.put(acc.ID__c, new List<Account>{ acc });
                }
            }
        }

        List<Account> masters = [SELECT id from Account WHERE ID__c IN :idToAccount.keySet() and (RecordTypeId = :BUSINESS_MASTER_RT or RecordTypeId = :PERSON_MASTER_RT)];
        
    }
}