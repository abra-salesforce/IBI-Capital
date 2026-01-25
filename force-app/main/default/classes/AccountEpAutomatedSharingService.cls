public without sharing class AccountEpAutomatedSharingService {

    public static void sharingProcess(List<Account> records, Map<Id, Account> oldAccounts) {
        // Identify relevant EP child accounts from the trigger and collect related Master Account Ids and PersonContactIds
        Set<Id> masterIdsToProcess = new Set<Id>();
        Set<Id> personContactIdsFromTrigger = new Set<Id>();

        for (Account acc : records) {
            Boolean isEpRt = acc.Record_Type_Developer_Name__c == 'Equity_Plans_Person_Account' || acc.Record_Type_Developer_Name__c == 'Equity_Plans_Business_Account';
            Boolean isOwnerOrIdChanged = Trigger.isUpdate && oldAccounts != null && oldAccounts.containsKey(acc.Id) &&
                                    (acc.OwnerId != oldAccounts.get(acc.Id).OwnerId || acc.ID__c   != oldAccounts.get(acc.Id).ID__c);
            Boolean isRelevantEvent = Trigger.isInsert || Trigger.isDelete || Trigger.isUndelete || isOwnerOrIdChanged;

            if (!isEpRt || !isRelevantEvent) {
                continue;
            }

            if (acc.Record_Type_Developer_Name__c == 'Equity_Plans_Business_Account' && acc.ParentId != null) {
                masterIdsToProcess.add(acc.ParentId);
            }

            if (acc.Record_Type_Developer_Name__c == 'Equity_Plans_Person_Account' && acc.PersonContactId != null) {
                personContactIdsFromTrigger.add(acc.PersonContactId);
            }
        }

        if (masterIdsToProcess.isEmpty() && personContactIdsFromTrigger.isEmpty()) return;

        Map<Id, Id> contactIdToMasterId = new Map<Id, Id>();

        if (!personContactIdsFromTrigger.isEmpty()) {
            for (AccountContactRelation acr : [SELECT AccountId, ContactId FROM AccountContactRelation WHERE ContactId IN :personContactIdsFromTrigger AND Account.Record_Type_Developer_Name__c = 'Person_Account_Master']) {
                masterIdsToProcess.add(acr.AccountId);
                contactIdToMasterId.put(acr.ContactId, acr.AccountId);
            }
        }

        Set<Id> personAccountIdsFromAcr = new Set<Id>();

        for (AccountContactRelation acr : [SELECT Contact.AccountId FROM AccountContactRelation WHERE AccountId IN :masterIdsToProcess AND Contact.IsPersonAccount = true]) {
            personAccountIdsFromAcr.add(acr.Contact.AccountId);
        }

        List<Account> allChildren = [SELECT Id, OwnerId, ParentId, PersonContactId, Record_Type_Developer_Name__c FROM Account
                                    WHERE (
                                        ParentId IN :masterIdsToProcess
                                        OR Id IN :personAccountIdsFromAcr
                                    )
                                    AND Record_Type_Developer_Name__c IN (
                                        'Equity_Plans_Person_Account',
                                        'Equity_Plans_Business_Account'
                                    )
        ];

        if (!allChildren.isEmpty()) {
            Set<Id> currentChildrenContacts = new Set<Id>();
            for (Account child : allChildren) {
                if (child.PersonContactId != null) {
                    currentChildrenContacts.add(child.PersonContactId);
                }
            }

            if (!currentChildrenContacts.isEmpty()) {
                for (AccountContactRelation acr : [SELECT AccountId, ContactId FROM AccountContactRelation WHERE ContactId IN :currentChildrenContacts AND AccountId IN :masterIdsToProcess]) {
                    contactIdToMasterId.put(acr.ContactId, acr.AccountId);
                }
            }
        }

        Map<Id, List<Account>> masterToAllChildren = new Map<Id, List<Account>>();
        for (Account child : allChildren) {
            Id masterId;
            if (child.Record_Type_Developer_Name__c == 'Equity_Plans_Business_Account') {
                masterId = child.ParentId;
            } else {
                masterId = contactIdToMasterId.get(child.PersonContactId);
            }

            if (masterId == null || !masterIdsToProcess.contains(masterId)) {
                continue;
            }

            if (!masterToAllChildren.containsKey(masterId)) {
                masterToAllChildren.put(masterId, new List<Account>());
            }

            masterToAllChildren.get(masterId).add(child);
        }

        // Collect current OwnerIds for each master based on all its child accounts
        Map<Id, Set<Id>> masterToCurrentOwners = new Map<Id, Set<Id>>();

        for (Id masterId : masterToAllChildren.keySet()) {
            List<Account> children = masterToAllChildren.get(masterId);

            if (children == null || children.isEmpty()) {
                continue;
            }

            for (Account child : children) {
                if (child.OwnerId == null) {
                    continue;
                }

                if (!masterToCurrentOwners.containsKey(masterId)) {
                    masterToCurrentOwners.put(masterId, new Set<Id>());
                }

                masterToCurrentOwners.get(masterId).add(child.OwnerId);
            }
        }

        // Collect previous OwnerIds (before update/delete) and create keys for potential share removal.
        Map<Id, Set<Id>> masterToPreviousOwners = new Map<Id, Set<Id>>();
        Set<String> previousOwnerKeys = new Set<String>();

        if ((Trigger.isUpdate || Trigger.isDelete) && oldAccounts != null) {
            for (Account acc : records) {
                Account oldAcc = oldAccounts.get(acc.Id);
                if (oldAcc == null) continue;

                Id masterId;
                if (oldAcc.Record_Type_Developer_Name__c == 'Equity_Plans_Business_Account') {
                    masterId = oldAcc.ParentId;
                } else if (oldAcc.Record_Type_Developer_Name__c == 'Equity_Plans_Person_Account' && oldAcc.PersonContactId != null) {
                    masterId = contactIdToMasterId.get(oldAcc.PersonContactId);
                }

                if (masterId == null || !masterIdsToProcess.contains(masterId)) {
                    continue;
                }

                if (!masterToPreviousOwners.containsKey(masterId)) {
                    masterToPreviousOwners.put(masterId, new Set<Id>());
                }
                masterToPreviousOwners.get(masterId).add(oldAcc.OwnerId);
            }

            for (Id masterId : masterToPreviousOwners.keySet()) {
                Set<Id> prevOwners = masterToPreviousOwners.get(masterId);
                if (prevOwners == null || prevOwners.isEmpty()) continue;

                for (Id userId : prevOwners) {
                    previousOwnerKeys.add(masterId + '-' + userId);
                }

                List<Account> children = masterToAllChildren.get(masterId);
                if (children == null || children.isEmpty()) continue;

                for (Account child : children) {
                    for (Id userId : prevOwners) {
                        previousOwnerKeys.add(child.Id + '-' + userId);
                    }
                }
            }
        }

        // Collect all account Ids (masters + children) to query existing AccountShare records.
        Set<Id> allAccountIdsInvolved = new Set<Id>(masterIdsToProcess);

        for (Id masterId : masterToAllChildren.keySet()) {
            List<Account> children = masterToAllChildren.get(masterId);
            if (children == null || children.isEmpty()) continue;

            for (Account child : children) {
                allAccountIdsInvolved.add(child.Id);
            }
        }

        Map<String, AccountShare> existingShares = new Map<String, AccountShare>();

        if (!allAccountIdsInvolved.isEmpty()) {
            for (AccountShare ash : [SELECT Id, AccountId, UserOrGroupId, RowCause FROM AccountShare WHERE AccountId IN :allAccountIdsInvolved]) {
                String key = ash.AccountId + '-' + ash.UserOrGroupId;
                existingShares.put(key, ash);
            }
        }

        // Build desired AccountShare map based on current owners of each master and all its children
        Map<String, AccountShare> desiredShares = new Map<String, AccountShare>();

        for (Id masterId : masterToCurrentOwners.keySet()) {
            Set<Id> owners = masterToCurrentOwners.get(masterId);
            if (owners == null || owners.isEmpty()) continue;

            List<Id> accountsUnderMaster = new List<Id>();
            accountsUnderMaster.add(masterId);

            if (masterToAllChildren.containsKey(masterId)) {
                for (Account child : masterToAllChildren.get(masterId)) {
                    accountsUnderMaster.add(child.Id);
                }
            }

            for (Id ownerId : owners) {

                for (Id accId : accountsUnderMaster) {
                    String key = accId + '-' + ownerId;

                    if (!desiredShares.containsKey(key)) {

                        desiredShares.put(key, new AccountShare(
                                                AccountId = accId,
                                                UserOrGroupId = ownerId,
                                                AccountAccessLevel = 'Read',
                                                OpportunityAccessLevel = 'None'
                                                )
                        );
                    }
                }
            }
        }

        // Compare desired to existing shares to determine which to insert and which to delete
        Map<Id, Account> mastersMap = new Map<Id, Account>([SELECT Id, OwnerId FROM Account WHERE Id IN :masterIdsToProcess]);
        List<AccountShare> toInsert = new List<AccountShare>();
        List<AccountShare> toDelete = new List<AccountShare>();

        for (String key : desiredShares.keySet()) {
            if (!existingShares.containsKey(key)) {
                toInsert.add(desiredShares.get(key));
            }
        }

        for (String key : previousOwnerKeys) {
            if (!desiredShares.containsKey(key) && existingShares.containsKey(key)) {
                AccountShare ash = existingShares.get(key);
                
                if (mastersMap.containsKey(ash.AccountId)) {
                    Id masterOwnerId = mastersMap.get(ash.AccountId).OwnerId;
                    
                    if (ash.UserOrGroupId == masterOwnerId) {
                        continue; 
                    }
                }
                
                toDelete.add(ash);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        if (!toDelete.isEmpty()) {
            System.debug('delete: ' + toDelete);
            delete toDelete;
        }

    }   
}
