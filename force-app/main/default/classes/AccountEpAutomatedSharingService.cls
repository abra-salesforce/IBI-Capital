public without sharing class AccountEpAutomatedSharingService {

    public static void sharingProcess(List<Account> records, Map<Id, Account> oldAccounts) {
        Set<Id> masterIdsToProcess = new Set<Id>();
        Set<Id> personContactIds = new Set<Id>();
        Map<Id, Id> contactIdToMasterId = new Map<Id, Id>();

        for (Account acc : records) {
            Boolean isEpRt = acc.Record_Type_Developer_Name__c == 'Equity_Plans_Person_Account' ||
                             acc.Record_Type_Developer_Name__c == 'Equity_Plans_Business_Account';
            
            Boolean isOwnerChanged = Trigger.isUpdate && oldAccounts != null && acc.OwnerId != oldAccounts.get(acc.Id).OwnerId;
            
            if (isEpRt && (Trigger.isInsert || Trigger.isDelete || Trigger.isUndelete || isOwnerChanged)) {
                if (acc.Record_Type_Developer_Name__c == 'Equity_Plans_Business_Account' && acc.ParentId != null) {
                    masterIdsToProcess.add(acc.ParentId);
                }
                if (acc.Record_Type_Developer_Name__c == 'Equity_Plans_Person_Account' && acc.PersonContactId != null) {
                    personContactIds.add(acc.PersonContactId);
                }
            }
        }

        if (!personContactIds.isEmpty()) {
            for (AccountContactRelation acr : [SELECT AccountId, ContactId FROM AccountContactRelation WHERE ContactId IN :personContactIds]) {
                masterIdsToProcess.add(acr.AccountId);
                contactIdToMasterId.put(acr.ContactId, acr.AccountId);
            }
        }

        if (masterIdsToProcess.isEmpty()) return;

        Set<Id> personAccountIdsFromAcr = new Set<Id>();
        for (AccountContactRelation acr : [SELECT Contact.AccountId FROM AccountContactRelation WHERE AccountId IN :masterIdsToProcess AND Contact.IsPersonAccount = true]) {
            personAccountIdsFromAcr.add(acr.Contact.AccountId);
        }

        List<Account> allChildren = [SELECT Id, OwnerId, ParentId, PersonContactId, Record_Type_Developer_Name__c 
                                    FROM Account 
                                    WHERE (ParentId IN :masterIdsToProcess OR Id IN :personAccountIdsFromAcr)
                                    AND (Record_Type_Developer_Name__c = 'Equity_Plans_Person_Account' 
                                         OR Record_Type_Developer_Name__c = 'Equity_Plans_Business_Account')];

        Map<Id, List<Account>> masterToAllChildren = new Map<Id, List<Account>>();
        Map<Id, Set<Id>> masterToAllOwners = new Map<Id, Set<Id>>();
        Set<Id> allAccountIdsInvolved = new Set<Id>(masterIdsToProcess);

        if (!allChildren.isEmpty()) {
            Set<Id> currentChildrenContacts = new Set<Id>();
            for(Account child : allChildren) {
                if(child.PersonContactId != null) currentChildrenContacts.add(child.PersonContactId);
            }
            for (AccountContactRelation acr : [SELECT AccountId, ContactId FROM AccountContactRelation WHERE ContactId IN :currentChildrenContacts AND AccountId IN :masterIdsToProcess]) {
                contactIdToMasterId.put(acr.ContactId, acr.AccountId);
            }
        }

        for (Account child : allChildren) {
             Id mId = (child.Record_Type_Developer_Name__c == 'Equity_Plans_Business_Account') ? child.ParentId : contactIdToMasterId.get(child.PersonContactId);
             
             if (mId != null && masterIdsToProcess.contains(mId)) {
                if (!masterToAllChildren.containsKey(mId)) masterToAllChildren.put(mId, new List<Account>());
                if (!masterToAllOwners.containsKey(mId)) masterToAllOwners.put(mId, new Set<Id>());
                
                masterToAllChildren.get(mId).add(child);
                masterToAllOwners.get(mId).add(child.OwnerId);
                allAccountIdsInvolved.add(child.Id);
             }
        }

        Map<Id, Account> mastersMap = new Map<Id, Account>([SELECT Id, OwnerId FROM Account WHERE Id IN :masterIdsToProcess]);

        Map<String, AccountShare> existingShares = new Map<String, AccountShare>();
        for (AccountShare ash : [SELECT Id, AccountId, UserOrGroupId FROM AccountShare 
                                 WHERE AccountId IN :allAccountIdsInvolved AND RowCause = 'Manual']) {
            existingShares.put(ash.AccountId + '-' + ash.UserOrGroupId, ash);
        }

        Map<String, AccountShare> desiredShares = new Map<String, AccountShare>();
        for (Id mId : masterIdsToProcess) {
            Set<Id> owners = masterToAllOwners.get(mId);
            if (owners == null) continue;

            for (Id ownerId : owners) {
                if (ownerId != mastersMap.get(mId).OwnerId) {
                    desiredShares.put(mId + '-' + ownerId, createManualShare(mId, ownerId));
                }
                
                if (masterToAllChildren.containsKey(mId)) {
                    for (Account child : masterToAllChildren.get(mId)) {
                        if (ownerId != child.OwnerId) {
                            desiredShares.put(child.Id + '-' + ownerId, createManualShare(child.Id, ownerId));
                        }
                    }
                }
            }
        }

        List<AccountShare> toInsert = new List<AccountShare>();
        List<AccountShare> toDelete = new List<AccountShare>();

        for (String key : desiredShares.keySet()) {
            if (!existingShares.containsKey(key)) toInsert.add(desiredShares.get(key));
        }
        for (String key : existingShares.keySet()) {
            if (!desiredShares.containsKey(key)) toDelete.add(existingShares.get(key));
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toDelete.isEmpty()) delete toDelete;
    }

    private static AccountShare createManualShare(Id accId, Id userId) {
        return new AccountShare(
            AccountId = accId,
            UserOrGroupId = userId,
            AccountAccessLevel = 'Read',
            OpportunityAccessLevel = 'None',
            RowCause = 'Manual'
        );
    }
}