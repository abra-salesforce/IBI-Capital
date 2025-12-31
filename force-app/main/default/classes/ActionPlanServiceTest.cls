@IsTest
public with sharing class ActionPlanServiceTest {

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u1 = new User(ProfileId = p.Id, Username = 'u1.plan.test.' + System.currentTimeMillis() + '@example.com', Email = 'u1@example.com', LastName = 'Owner1', Alias = 'own1', TimeZoneSidKey = 'Asia/Jerusalem', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
        insert u1;
        User u2 = new User(ProfileId = p.Id, Username = 'u2.plan.test.' + System.currentTimeMillis() + '@example.com', Email = 'u2@example.com', LastName = 'Owner2', Alias = 'own2', TimeZoneSidKey = 'Asia/Jerusalem', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
        insert u2;
        Account acc = new Account(Name = 'Acc For Plan', Account_Executive__c = u2.Id);
        insert acc;
        Case c = new Case(Subject = 'Case For Plan', AccountId = acc.Id, Origin = 'Phone', Status = 'New', OwnerId = u1.Id);
        insert c;
        Plan_Template__c tpl = new Plan_Template__c(Name = 'TPL 1', Description__c = 'desc', Default_Owner_Type__c = 'Field API Name', Owner_API_Name__c = 'Account.Account_Executive__c');
        insert tpl;
        Plan_Template_Item__c pti1 = new Plan_Template_Item__c(Name = 'Step 1', Plan_Template__c = tpl.Id, Step_Order__c = 1, Is_Mandatory__c = true, Instructions__c = 'Do 1', Duration_Days__c = 0, Default_Owner_Type__c = 'Field API Name', Owner_API_Name__c = 'OwnerId');
        insert pti1;
        Plan_Template_Item__c pti2 = new Plan_Template_Item__c(Name = 'Step 2', Plan_Template__c = tpl.Id, Step_Order__c = 2, Is_Mandatory__c = true, Instructions__c = 'Do 2', Duration_Days__c = 3, Previous_Plan_Template_Item__c = pti1.Id, Default_Owner_Type__c = 'User', Owner_User__c = u2.Id);
        insert pti2;
    }

    private static Id createPlanForSetupData() {
        Plan_Template__c tpl = [SELECT Id FROM Plan_Template__c WHERE Name = 'TPL 1' LIMIT 1];
        Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Plan' LIMIT 1];

        PlanCreationService.PlanInput input = new PlanCreationService.PlanInput();
        input.planTemplateId = tpl.Id;
        input.recordId = c.Id;
        input.lookupFieldApiName = 'Case__c';

        Test.startTest();
        PlanCreationService.createPlan(new List<PlanCreationService.PlanInput>{ input });
        Test.stopTest();

        Plan__c createdPlan = [SELECT Id FROM Plan__c WHERE Plan_Template__c = :tpl.Id AND Case__c = :c.Id ORDER BY CreatedDate DESC LIMIT 1];
        return createdPlan.Id;
    }

    @IsTest
    static void createPlanAndPlanItemsTest() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u2 = [SELECT Id FROM User WHERE ProfileId = :p.Id AND Alias = 'own2' LIMIT 1];
        Plan_Template__c tpl = [SELECT Id FROM Plan_Template__c WHERE Name = 'TPL 1' LIMIT 1];
        Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Plan' LIMIT 1];

        PlanCreationService.PlanInput input = new PlanCreationService.PlanInput();
        input.planTemplateId = tpl.Id;
        input.recordId = c.Id;
        input.startDate = Date.today();
        input.lookupFieldApiName = 'Case__c';

        Test.startTest();
        PlanCreationService.createPlan(new List<PlanCreationService.PlanInput>{ input });
        Test.stopTest();

        List<Plan__c> plans = [SELECT Id, Name, Plan_Template__c, OwnerId, Notes__c, Case__c FROM Plan__c WHERE Plan_Template__c = :tpl.Id AND Case__c = :c.Id];
        Assert.isTrue(plans.size() == 1);
        Plan__c createdPlan = plans[0];
        Assert.isTrue(c.Id == createdPlan.Case__c);
        Assert.isTrue(u2.Id == createdPlan.OwnerId);

        List<Plan_Item__c> planItems = [SELECT Id, Plan__c, Step_Order__c, Previous_Plan_Item__c FROM Plan_Item__c WHERE Plan__c = :createdPlan.Id ORDER BY Step_Order__c];
        Assert.isTrue(planItems.size() == 2);

        Plan_Item__c pi1 = planItems[0];
        Plan_Item__c pi2 = planItems[1];
        Assert.isTrue(pi1.Previous_Plan_Item__c == null);
        Assert.isTrue(pi1.Id == pi2.Previous_Plan_Item__c);

        List<Task> tasks = [SELECT Id, Subject, Status, OwnerId, WhatId, Plan_Item__c, ActivityDate FROM Task WHERE WhatId = :c.Id];
        Assert.isTrue(tasks.size() == 2);

        for (Task t : tasks) {
            Assert.isTrue(t.Plan_Item__c != null);
        }
    }

    @IsTest
    static void statusSyncsFromTaskToPlanItem() {
        Id planId = createPlanForSetupData();

        Plan_Item__c pi = [SELECT Id, Task_Id__c, Task_Status__c FROM Plan_Item__c WHERE Plan__c = :planId AND Task_Id__c != null LIMIT 1];
        Assert.isTrue(pi.Task_Id__c != null);

        Task t = [SELECT Id, Status FROM Task WHERE Id = :pi.Task_Id__c LIMIT 1];
        t.Status = 'Waiting in Dependency';
        update t;

        Plan_Item__c piAfter = [SELECT Id, Task_Status__c FROM Plan_Item__c WHERE Id = :pi.Id LIMIT 1];
        Assert.isTrue(piAfter.Task_Status__c == 'Waiting in Dependency');
    }

    @IsTest
    static void updateTaskToCompletedTest() {
        Id planId = createPlanForSetupData();

        List<Plan_Item__c> items = [SELECT Id, Previous_Plan_Item__c, Task_Id__c, Step_Order__c FROM Plan_Item__c WHERE Plan__c = :planId ORDER BY Step_Order__c];
        Assert.isTrue(items.size() == 2);

        Plan_Item__c pi1 = items[0];
        Plan_Item__c pi2 = items[1];

        Task parent = [SELECT Id, Status FROM Task WHERE Id = :pi1.Task_Id__c LIMIT 1];
        parent.Status = 'Completed';
        update parent;

        Task dependentAfter = [SELECT Id, Status FROM Task WHERE Id = :pi2.Task_Id__c LIMIT 1];
        Assert.isTrue(dependentAfter.Status == 'Open');
    }

    @IsTest
    static void updateTaskToReopenTest() {
        Id planId = createPlanForSetupData();

        List<Plan_Item__c> items = [SELECT Id, Previous_Plan_Item__c, Task_Id__c, Step_Order__c FROM Plan_Item__c WHERE Plan__c = :planId ORDER BY Step_Order__c];
        Assert.isTrue(items.size() == 2);

        Plan_Item__c pi1 = items[0];
        Plan_Item__c pi2 = items[1];

        Task parent = [SELECT Id, Status FROM Task WHERE Id = :pi1.Task_Id__c LIMIT 1];
        parent.Status = 'Completed';
        update parent;

        parent = [SELECT Id, Status FROM Task WHERE Id = :pi1.Task_Id__c LIMIT 1];
        parent.Status = 'Reopen';
        update parent;

        Task childAfter = [SELECT Id, Status FROM Task WHERE Id = :pi2.Task_Id__c LIMIT 1];
        Assert.isTrue(childAfter.Status == 'Waiting in Dependency');
    }

    //ActionPlanPanelController
    @IsTest
    static void actionPlanPanelControllerTest() {
        Id planId = createPlanForSetupData();
        Case c = [SELECT Id FROM Case WHERE Subject = 'Case For Plan' LIMIT 1];
        ActionPlanPanelController.getPlans(c.Id, 'Case__c');
        ActionPlanPanelController.getPlanTasks(planId);
        Task t = [SELECT Id, Status FROM Task LIMIT 1];
        ActionPlanPanelController.updateTaskStatus(t.Id, 'Completed');
        ActionPlanPanelController.getPlanById(planId);
        ActionPlanPanelController.updateTaskDescription(t.Id, 'test');
    }

    //PlanItemTriggerHandler
    @IsTest
    static void deletePlanItem() {
        Id planId = createPlanForSetupData();
        Plan_Item__c planItem = [SELECT Id FROM Plan_Item__c LIMIT 1];
        delete planItem;

    }

}
