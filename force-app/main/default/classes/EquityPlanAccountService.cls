public with sharing class EquityPlanAccountService {
    public static final Set<String> SERVICE_TYPES_102 = new Set<String>{
        '102'
    };
    public static final Set<String> SERVICE_TYPES_OTHER = new Set<String>{
        '103', '104', 'Shareholder', 'IPO'
    };
    public static final Id EP_RECORDTYPE = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Equity_Plans_Business_Account').getRecordTypeId();

    public static void serviceTypeValidation(List<Account> newAccounts, Map<Id, Account> oldAccounts) {
        Set<Id> accountIds = new Set<Id>();
        Map<String, Account> serviceTypeBucketToAccount = new Map<String, Account>();
        Set<Id> newOrUpdatedIds = new Set<Id>();

        for(Account acc : newAccounts) {
            if(acc.Service_Type__c != null &&
                acc.RecordTypeId == EP_RECORDTYPE &&
                bucket(acc.Service_Type__c) != null &&
                acc.ParentId != null &&
                (
                    (oldAccounts != null && oldAccounts.containsKey(acc.Id) &&
                        (
                            oldAccounts.get(acc.Id).ParentId != acc.ParentId ||
                            oldAccounts.get(acc.Id).Service_Type__c != acc.Service_Type__c
                        )
                    ) || acc.Id == null
            )) {
                system.debug('acc: ' + acc);
                String key = bucket(acc.Service_Type__c) + '-' + acc.ParentId;
                system.debug('key: ' + key);
                if(serviceTypeBucketToAccount.containsKey(key)) {
                    acc.addError('במערכת כבר קיימת חברה עם סוג שירות זה');
                }
                else {
                    serviceTypeBucketToAccount.put(key, acc);
                }
                accountIds.add(acc.ParentId);
                if(acc.Id != null) newOrUpdatedIds.add(acc.Id);
            }
        }
        if(accountIds.isEmpty()) return;

        for(Account ea : [SELECT ParentId, Service_Type__c FROM Account WHERE ParentId IN :AccountIds and Service_Type__c != null and RecordTypeId = :EP_RECORDTYPE AND Id NOT IN :newOrUpdatedIds]) {
            String eaKey = bucket(ea.Service_Type__c) + '-' + ea.ParentId;
            if(serviceTypeBucketToAccount.containsKey(eaKey)) {
                Account newAccount = serviceTypeBucketToAccount.get(eaKey);
                newAccount.addError('במערכת כבר קיימת חברה עם סוג שירות זה');
            }
		}
    }

    private static String bucket(String serviceType) {
        if (SERVICE_TYPES_102.contains(serviceType)) return '102';
        if (SERVICE_TYPES_OTHER.contains(serviceType)) return 'OTHER';
        return null;
    }
}