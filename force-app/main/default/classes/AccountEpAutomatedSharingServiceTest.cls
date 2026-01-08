@IsTest
private class AccountEpAutomatedSharingServiceTest {

    private static Id businessRtId;

    private static Id getBusinessRtId() {
        if (businessRtId == null) {
            businessRtId = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account'
                  AND DeveloperName = 'Equity_Plans_Business_Account'
                LIMIT 1
            ].Id;
        }
        return businessRtId;
    }

    @TestSetup
    static void setupData() {
         Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User owner1 = new User(
            Alias = 'own1',
            Email = 'own1@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Owner One',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Jerusalem',
            Username = 'own1' + Datetime.now().getTime() + '@example.com',
            ProfileId = p.Id
        );

        User owner2 = new User(
            Alias = 'own2',
            Email = 'own2@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Owner Two',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Jerusalem',
            Username = 'own2' + Datetime.now().getTime() + '@example.com',
            ProfileId = p.Id
        );

        insert new List<User>{ owner1, owner2 };
    }
    @isTest
    static void insertAccountsForSharingTest() {
        Id runningUserId = UserInfo.getUserId();
        User owner1 = [SELECT Id FROM User WHERE Alias = 'own1' LIMIT 1];
        User owner2 = [SELECT Id FROM User WHERE Alias = 'own2' LIMIT 1];
        Account acc1 = new Account(
            Name = 'Test Account',
            RecordTypeId = getBusinessRtId(),
            ID__c = '237630074',
            Service_Type__c = '102',
            OwnerId = owner1.Id
        );

        Account acc2 = new Account(
            Name = 'Test Account',
            RecordTypeId = getBusinessRtId(),
            ID__c = '237630074',
            Service_Type__c = '103',
            OwnerId = owner2.Id
        );

        Test.startTest();
        insert new List<Account>{ acc1, acc2 };
        Test.stopTest();

        Account master = [SELECT Id FROM Account WHERE ID__c = '237630074' AND Record_Type_Developer_Name__c = 'Equity_Plans_Business_Account' LIMIT 1];
        List<AccountShare> masterShare = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :master.Id];
        Set<Id> masterUserIds = new Set<Id>();
        for (AccountShare s : masterShare) {
            masterUserIds.add(s.UserOrGroupId);
        }

        system.debug('masterShare: ' + masterShare);   

        Assert.isTrue(masterShare.size() == 2);
        Assert.isTrue(masterUserIds.contains(owner1.Id));
        Assert.isTrue(masterUserIds.contains(owner2.Id));

        List<AccountShare> acc1Share = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :acc1.Id];
        Set<Id> child1UserIds = new Set<Id>();
        for (AccountShare s : acc1Share) {
            child1UserIds.add(s.UserOrGroupId);
        }
        Assert.isTrue(child1UserIds.size() == 2);
        Assert.isTrue(child1UserIds.contains(owner1.Id));
        Assert.isTrue(child1UserIds.contains(owner2.Id));

        List<AccountShare> acc2Share = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :acc2.Id];
        Set<Id> child2UserIds = new Set<Id>();
        for (AccountShare s : acc2Share) {
            child2UserIds.add(s.UserOrGroupId);
        }
        Assert.isTrue(child2UserIds.size() == 2);
        Assert.isTrue(child2UserIds.contains(owner1.Id));
        Assert.isTrue(child2UserIds.contains(owner2.Id));

    }

    @isTest
    static void updateAccountOwner() {
        Id runningUserId = UserInfo.getUserId();
        User owner1 = [SELECT Id FROM User WHERE Alias = 'own1' LIMIT 1];
        User owner2 = [SELECT Id FROM User WHERE Alias = 'own2' LIMIT 1];
        Account acc1 = new Account(
            Name = 'Test Account',
            RecordTypeId = getBusinessRtId(),
            ID__c = '237630074',
            Service_Type__c = '102',
            OwnerId = owner1.Id
        );

        Account acc2 = new Account(
            Name = 'Test Account',
            RecordTypeId = getBusinessRtId(),
            ID__c = '237630074',
            Service_Type__c = '103',
            OwnerId = owner2.Id
        );

        Test.startTest();
        insert new List<Account>{ acc1, acc2 };
        acc1.OwnerId = owner2.Id;
        update acc1;
        Test.stopTest();

        Account master = [SELECT Id FROM Account WHERE ID__c = '237630074' AND Record_Type_Developer_Name__c = 'Equity_Plans_Business_Account' LIMIT 1];
        List<AccountShare> masterShare = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :master.Id];
        Set<Id> masterUserIds = new Set<Id>();
        for (AccountShare s : masterShare) {
            masterUserIds.add(s.UserOrGroupId);
        }

        system.debug('masterShare: ' + masterShare);   

        Assert.isTrue(masterShare.size() == 1);
        Assert.isTrue(masterUserIds.contains(owner2.Id));

        List<AccountShare> acc1Share = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :acc1.Id];
        Set<Id> child1UserIds = new Set<Id>();
        for (AccountShare s : acc1Share) {
            child1UserIds.add(s.UserOrGroupId);
        }
        Assert.isTrue(child1UserIds.size() == 1);
        Assert.isTrue(child1UserIds.contains(owner2.Id));

        List<AccountShare> acc2Share = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :acc2.Id];
        Set<Id> child2UserIds = new Set<Id>();
        for (AccountShare s : acc2Share) {
            child2UserIds.add(s.UserOrGroupId);
        }
        Assert.isTrue(child2UserIds.size() == 1);
        Assert.isTrue(child2UserIds.contains(owner2.Id));

    }

    @isTest
    static void deleteAccountSharingTest() {
        Id runningUserId = UserInfo.getUserId();
        User owner1 = [SELECT Id FROM User WHERE Alias = 'own1' LIMIT 1];
        User owner2 = [SELECT Id FROM User WHERE Alias = 'own2' LIMIT 1];
        Account acc1 = new Account(
            Name = 'Test Account',
            RecordTypeId = getBusinessRtId(),
            ID__c = '237630074',
            Service_Type__c = '102',
            OwnerId = owner1.Id
        );

        Account acc2 = new Account(
            Name = 'Test Account',
            RecordTypeId = getBusinessRtId(),
            ID__c = '237630074',
            Service_Type__c = '103',
            OwnerId = owner2.Id
        );

        Test.startTest();
        insert new List<Account>{ acc1, acc2 };
        delete acc1;
        Test.stopTest();

        Account master = [SELECT Id FROM Account WHERE ID__c = '237630074' AND Record_Type_Developer_Name__c = 'Equity_Plans_Business_Account' LIMIT 1];
        List<AccountShare> masterShare = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :master.Id];
        Set<Id> masterUserIds = new Set<Id>();
        for (AccountShare s : masterShare) {
            masterUserIds.add(s.UserOrGroupId);
        }

        system.debug('masterShare: ' + masterShare);   

        Assert.isTrue(masterShare.size() == 1);
        Assert.isTrue(masterUserIds.contains(owner2.Id));

        List<AccountShare> acc2Share = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :acc2.Id];
        Set<Id> child2UserIds = new Set<Id>();
        for (AccountShare s : acc2Share) {
            child2UserIds.add(s.UserOrGroupId);
        }
        Assert.isTrue(child2UserIds.size() == 1);
        Assert.isTrue(child2UserIds.contains(owner2.Id));

    }

    @isTest
    static void undeleteAccountSharingTest() {
        Id runningUserId = UserInfo.getUserId();
        User owner1 = [SELECT Id FROM User WHERE Alias = 'own1' LIMIT 1];
        User owner2 = [SELECT Id FROM User WHERE Alias = 'own2' LIMIT 1];
        Account acc1 = new Account(
            Name = 'Test Account',
            RecordTypeId = getBusinessRtId(),
            ID__c = '237630074',
            Service_Type__c = '102',
            OwnerId = owner1.Id
        );

        Account acc2 = new Account(
            Name = 'Test Account',
            RecordTypeId = getBusinessRtId(),
            ID__c = '237630074',
            Service_Type__c = '103',
            OwnerId = owner2.Id
        );

        Test.startTest();
        insert new List<Account>{ acc1, acc2 };
        delete acc1;
        undelete acc1;
        Test.stopTest();

        Account master = [SELECT Id FROM Account WHERE ID__c = '237630074' AND Record_Type_Developer_Name__c = 'Equity_Plans_Business_Account' LIMIT 1];
        List<AccountShare> masterShare = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :master.Id];
        Set<Id> masterUserIds = new Set<Id>();
        for (AccountShare s : masterShare) {
            masterUserIds.add(s.UserOrGroupId);
        }

        system.debug('masterShare: ' + masterShare);   

        Assert.isTrue(masterShare.size() == 2);
        Assert.isTrue(masterUserIds.contains(owner1.Id));
        Assert.isTrue(masterUserIds.contains(owner2.Id));

        List<AccountShare> acc1Share = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :acc1.Id];
        Set<Id> child1UserIds = new Set<Id>();
        for (AccountShare s : acc1Share) {
            child1UserIds.add(s.UserOrGroupId);
        }
        Assert.isTrue(child1UserIds.size() == 2);
        Assert.isTrue(child1UserIds.contains(owner1.Id));
        Assert.isTrue(child1UserIds.contains(owner2.Id));

        List<AccountShare> acc2Share = [SELECT Id, UserOrGroupId, AccountAccessLevel FROM AccountShare WHERE AccountId = :acc2.Id];
        Set<Id> child2UserIds = new Set<Id>();
        for (AccountShare s : acc2Share) {
            child2UserIds.add(s.UserOrGroupId);
        }
        Assert.isTrue(child2UserIds.size() == 2);
        Assert.isTrue(child2UserIds.contains(owner1.Id));
        Assert.isTrue(child2UserIds.contains(owner2.Id));

    }
}