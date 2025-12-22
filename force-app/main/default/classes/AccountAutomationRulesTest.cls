@isTest
public with sharing class AccountAutomationRulesTest {
    @TestSetup
    static void setupTestData() {
        RecordType epRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Equity_Plans_Business_Account' limit 1];
        Account accOther = new Account (Name = 'Test Account other', RecordTypeId = epRecordType.Id, Service_Type__c = '103', ID__c = '337348031');
        insert accOther;
        Account acc102 = new Account(Name = 'Test Account 102', RecordTypeId = epRecordType.Id, Service_Type__c = '102', ID__c = '339927808');
        insert acc102;

        RecordType masterPersonRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Person_Account_Master' limit 1];
        RecordType masterBusinessRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Business_Account_Master' limit 1];
        Account masterPerson = new Account(FirstName = 'Test',LastName = 'Person Master', RecordTypeId = masterPersonRecordType.Id, ID__c = '333824746');
        insert masterPerson;
        Account masterBusiness = new Account(Name = 'Test', RecordTypeId = masterBusinessRecordType.Id, ID__c = '333824746');
        insert masterBusiness;
    }

    @isTest
    static void testValidateEP() {
        List<Account>accs = new List<Account>();
        RecordType epRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Equity_Plans_Business_Account' limit 1];
        accs.add(new Account (Name = 'Test Account other test', RecordTypeId = epRecordType.Id, Service_Type__c = '104', ID__c = '337348031'));
        accs.add(new Account (Name = 'Test Account other test 2', RecordTypeId = epRecordType.Id, Service_Type__c = 'IPO', ID__c = '337348031'));
        accs.add(new Account (Name = 'Test Account 102 test', RecordTypeId = epRecordType.Id, Service_Type__c = '102', ID__c = '339927808'));
        accs.add(new Account (Name = 'Test Account 102 test', RecordTypeId = epRecordType.Id, Service_Type__c = '102', ID__c = '224612234'));
        Database.SaveResult[] srList;
        try{
            Test.startTest();
            srList = Database.insert(accs, false);
            Test.stopTest();
        } catch (DmlException e) {
            Assert.isTrue(!srList[0].isSuccess());
            Assert.isTrue(!srList[1].isSuccess());
            Assert.isTrue(!srList[2].isSuccess());
            Assert.isTrue(srList[3].isSuccess());
        }
    }

    @isTest
    static void testMasterLinkingCreatePersonAccount() {
        List<Account> accs = new List<Account>();
        RecordType epRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Equity_Plans_Person_Account' limit 1];
        accs.add(new Account (FirstName = 'Account1', LastName = 'Test', RecordTypeId = epRecordType.Id, ID__c = '333824746'));
        accs.add(new Account (FirstName = 'Account2', LastName = 'Test', RecordTypeId = epRecordType.Id, ID__c = '333824746'));

        Test.startTest();
        insert accs;
        Test.stopTest();

        Account master = [SELECT Id, ID__c FROM Account WHERE RecordType.DeveloperName = 'Person_Account_Master' AND ID__c = '333824746' LIMIT 1];

        Integer masterCount = [SELECT COUNT() FROM Account WHERE RecordType.DeveloperName = 'Person_Account_Master' AND ID__c = '333824746'];
        Assert.isTrue(masterCount == 1);

        Integer acrCount = [SELECT COUNT() FROM AccountContactRelation WHERE AccountId = :master.Id];
        Assert.isTrue(acrCount == 2);
    }

    @isTest
    static void testMasterLinkingUpdatePersonAccount() {
        List<Account> accs = new List<Account>();
        RecordType epRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Equity_Plans_Person_Account' limit 1];
        accs.add(new Account (FirstName = 'Account1', LastName = 'Test', RecordTypeId = epRecordType.Id, ID__c = '333824746'));
        accs.add(new Account (FirstName = 'Account2', LastName = 'Test', RecordTypeId = epRecordType.Id, ID__c = '333824746'));

        Test.startTest();
        insert accs;
        accs[0].ID__c = '224680645';
        update accs[0];
        Test.stopTest();

        Account originalMaster = [SELECT Id, ID__c FROM Account WHERE RecordType.DeveloperName = 'Person_Account_Master' AND ID__c = '333824746' LIMIT 1];
        Account newMaster = [SELECT Id, ID__c FROM Account WHERE RecordType.DeveloperName = 'Person_Account_Master' AND ID__c = '224680645' LIMIT 1];
        Integer newMasterCount = [SELECT COUNT() FROM Account WHERE RecordType.DeveloperName = 'Person_Account_Master' AND ID__c = '224680645'];
        Assert.isTrue(newMasterCount == 1);
        Integer newAcrCount = [SELECT COUNT() FROM AccountContactRelation WHERE AccountId = :newMaster.Id];
        Assert.isTrue(newAcrCount == 1);
        Integer originalAcrCount = [SELECT COUNT() FROM AccountContactRelation WHERE AccountId = :originalMaster.Id];
        Assert.isTrue(originalAcrCount == 1);
    }

    @isTest
    static void testMasterLinkingCreateBusinessAccount() {
        List<Account> accs = new List<Account>();
        RecordType epRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Equity_Plans_Business_Account' limit 1];
        accs.add(new Account (Name = 'Account1', RecordTypeId = epRecordType.Id, ID__c = '333824746'));
        accs.add(new Account (Name = 'Account2', RecordTypeId = epRecordType.Id, ID__c = '333824746'));

        Test.startTest();
        insert accs;
        Test.stopTest();

        Account master = [SELECT Id, ID__c FROM Account WHERE RecordType.DeveloperName = 'Business_Account_Master' AND ID__c = '333824746' LIMIT 1];

        Integer masterCount = [SELECT COUNT() FROM Account WHERE RecordType.DeveloperName = 'Business_Account_Master' AND ID__c = '333824746'];
        Assert.isTrue(masterCount == 1);

        Account acc1After = [SELECT Id, ParentId FROM Account WHERE Id = :accs[0].Id LIMIT 1];
        Account acc2After = [SELECT Id, ParentId FROM Account WHERE Id = :accs[1].Id LIMIT 1];

        Assert.isTrue(acc1After.ParentId == master.Id);
        Assert.isTrue(acc2After.ParentId == master.Id);
    }

    @isTest
    static void testMasterLinkingUpdateBusinessAccount() {
        List<Account> accs = new List<Account>();
        RecordType epRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Equity_Plans_Business_Account' limit 1];
        accs.add(new Account (Name = 'Account1', RecordTypeId = epRecordType.Id, ID__c = '333824746'));
        accs.add(new Account (Name = 'Account2', RecordTypeId = epRecordType.Id, ID__c = '220008734'));

        Test.startTest();
        insert accs;
        accs[0].ID__c = '321031528';
        update accs[0];
        Test.stopTest();

        Account originalMaster = [SELECT Id, ID__c FROM Account WHERE RecordType.DeveloperName = 'Business_Account_Master' AND ID__c = '333824746' LIMIT 1];
        Account secondMaster  = [SELECT Id, ID__c FROM Account WHERE RecordType.DeveloperName = 'Business_Account_Master' AND ID__c = '220008734' LIMIT 1];
        Account newMaster     = [SELECT Id, ID__c FROM Account WHERE RecordType.DeveloperName = 'Business_Account_Master' AND ID__c = '321031528' LIMIT 1];
        Integer newMasterCount = [SELECT COUNT() FROM Account WHERE RecordType.DeveloperName = 'Business_Account_Master' AND ID__c = '321031528'];
        Account acc1After = [SELECT Id, ParentId FROM Account WHERE Id = :accs[0].Id LIMIT 1];
        Account acc2After = [SELECT Id, ParentId FROM Account WHERE Id = :accs[1].Id LIMIT 1];

        Assert.isTrue(newMasterCount == 1);
        Assert.isTrue(acc2After.ParentId == secondMaster.Id);
        Assert.isTrue(acc1After.ParentId == newMaster.Id);
        Assert.isTrue(acc1After.ParentId != originalMaster.Id);
    }
}