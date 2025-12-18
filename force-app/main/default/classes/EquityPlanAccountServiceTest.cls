@isTest
public with sharing class EquityPlanAccountServiceTest {
    @TestSetup
    static void setupTestData() {
        RecordType epRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Equity_Plans_Business_Account' limit 1];
        Account accOther = new Account (Name = 'Test Account other', RecordTypeId = epRecordType.Id, Service_Type__c = '103', ID__c = '337348031');
        insert accOther;
        Account acc102 = new Account(Name = 'Test Account 102', RecordTypeId = epRecordType.Id, Service_Type__c = '102', ID__c = '339927808');
        insert acc102;
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
}