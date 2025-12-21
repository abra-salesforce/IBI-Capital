public with sharing class AccountMasterLinkingService {
    public static final Id BUSINESS_MASTER_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business_Account_Master').getRecordTypeId();
    public static final Id PERSON_MASTER_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Person_Account_Master').getRecordTypeId();    
    
    private class Maps {
        Map<String, List<Account>> idToAccounts = new Map<String, List<Account>>();
        Map<String, Account> idToMaster = new Map<String, Account>();
    }
    
    public static void linkMasterAfterSave(List<Account> newAccounts, Map<Id, Account> oldAccounts){
        Maps m = buildMaps(newAccounts, oldAccounts, true);
        if(m != null) {
            Map<String, List<Account>> idToAccounts = m.idToAccounts;
            Map<String, Account> idToMaster = m.idToMaster;

            idToMaster = createMasters(idToAccounts, idToMaster, true);

            if (oldAccounts != null) {
                Set<String> oldIds = new Set<String>();
                Set<Id> contactIds = new Set<Id>();

                for (String id : idToAccounts.keySet()) {
                    for (Account acc : idToAccounts.get(id)) {
                        Account oldAcc = oldAccounts.get(acc.Id);
                        if (oldAcc != null && oldAcc.ID__c != acc.ID__c && oldAcc.ID__c != null) {
                            oldIds.add(oldAcc.ID__c);
                            contactIds.add(acc.PersonContactId);
                        }
                    }
                }

                if (!oldIds.isEmpty() && !contactIds.isEmpty()) {
                    Set<Id> oldMasterIds = new Set<Id>();
                    for (Account oldMaster : [SELECT Id FROM Account WHERE RecordTypeId = :PERSON_MASTER_RT AND ID__c IN :oldIds]) {
                        oldMasterIds.add(oldMaster.Id);
                    }

                    if (!oldMasterIds.isEmpty()) {
                        List<AccountContactRelation> actToDelete = [SELECT Id FROM AccountContactRelation WHERE AccountId IN :oldMasterIds AND ContactId IN :contactIds];
                        if (actToDelete.size() > 0) {
                            delete actToDelete;
                        }
                    }
                }
            }

            List<AccountContactRelation> actToCreate = new List<AccountContactRelation>();

            for(String id : idToAccounts.keySet()) {
                Account master = idToMaster.get(id);
                for(Account acc : idToAccounts.get(id)) {
                    AccountContactRelation acr = new AccountContactRelation (AccountId = master.Id, ContactId = acc.PersonContactId);
                    actToCreate.add(acr);
                }
            }

            system.debug('actToCreate: ' + actToCreate);

            insert actToCreate;
        }

    }

    public static void linkMasterBeforeSave(List<Account> newAccounts, Map<Id, Account> oldAccounts){
        Maps m = buildMaps(newAccounts, oldAccounts, false);
        system.debug(m);
        if (m != null) {
            Map<String, List<Account>> idToAccounts = m.idToAccounts;
            Map<String, Account> idToMaster = m.idToMaster;

            idToMaster = createMasters(idToAccounts, idToMaster, false);

            for(String id : idToAccounts.keySet()) {
                Account master = idToMaster.get(id);
                for(Account acc : idToAccounts.get(id)) {
                    acc.parentId = master.Id;
                }
            }
        }
    }

    private static Map<String, Account> createMasters(Map<String, List<Account>> idToAccounts, Map<String, Account> idToMaster, Boolean isPerson){
        List<Account> mastersToCreate = new List<Account>();
        for(String id : idToAccounts.keySet()) {
            if(!idToMaster.containsKey(id)) {
                Account acc = idToAccounts.get(id)[0];
                Account masterAccount = new Account (RecordTypeId = isPerson ? PERSON_MASTER_RT : BUSINESS_MASTER_RT, ID__c = acc.ID__c, IDType__c = acc.IDType__c);
                if(isPerson) {
                    masterAccount.FirstName = acc.FirstName;
                    masterAccount.LastName = acc.LastName;
                } else {
                    masterAccount.Name = acc.Name;
                }
                mastersToCreate.add(masterAccount);
            }
        }

        insert mastersToCreate;

        for(Account m : mastersToCreate) {
            idToMaster.put(m.ID__c, m);
        }

        return idToMaster;
    }



    private static Maps buildMaps(List<Account> newAccounts, Map<Id, Account> oldAccounts, Boolean isPersonAccount) {
        Map<String, List<Account>> idToAccount = new Map<String, List<Account>>();
        for(Account acc : newAccounts) {
            if (acc.IsPersonAccount == isPersonAccount && acc.RecordTypeId != BUSINESS_MASTER_RT && acc.RecordTypeId != PERSON_MASTER_RT && acc.ID__c != null && (oldAccounts == null || (oldAccounts.containsKey(acc.Id) && oldAccounts.get(acc.Id).ID__c != acc.ID__c))){
                if(idToAccount.containsKey(acc.ID__c)) {
                    idToAccount.get(acc.ID__c).add(acc);
                }
                else {
                    idToAccount.put(acc.ID__c, new List<Account>{ acc });
                }
            }
        }

        if (!(idToAccount.size() > 0)) {
            return null;
        }

        String rtId = String.valueOf(isPersonAccount ? PERSON_MASTER_RT : BUSINESS_MASTER_RT);
        Set<String> ids = idToAccount.keySet();
        String query ='SELECT Id, ID__c FROM Account ' + 'WHERE ID__c IN :ids ' + 'AND RecordTypeId = \'' + rtId + '\'';
        List<Account> masters = Database.query(query);
        Map<String, Account> idToMaster = new Map<String, Account>();

        for(Account master : masters) {
            idToMaster.put(master.ID__c, master);
        }

        Maps mapsToReturn = new Maps();
        mapsToReturn.idToAccounts = idToAccount;
        mapsToReturn.idToMaster = idToMaster;
        return mapsToReturn;
    }

}