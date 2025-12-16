@isTest
public with sharing class ActionPlanServiceTest {
    @TestSetup
    static void setupTestData() {
        Case c = new Case(Subject = 'Test Case for Plan Creation', Origin = 'Email');
        insert c;
        Plan_Template__c pt = new Plan_Template__c(Name = 'Test Plan Template',
                                                    Description__c = 'Test',
                                                    Active__c = true,
                                                    Default_Owner_Type__c = 'Field API Name',
                                                    Owner_API_Name__c = 'OwnerId');
        insert pt;
        List<Plan_Template_Item__c> templateItems = new List<Plan_Template_Item__c>();
        for(Integer i = 0; i < 3; i++) {
            Plan_Template_Item__c pti = new Plan_Template_Item__c(Name = 'Template Item ' + i,
                                                                Plan_Template__c = pt.Id,
                                                                Duration_Days__c = 1 + i,
                                                                Default_Owner_Type__c = 'Field API Name',
                                                                Owner_API_Name__c = 'OwnerId',
                                                                Step_Order__c = i + 1,
                                                                Is_Mandatory__c = true,
                                                                Instructions__c = 'Instructions for item ' + i);
            templateItems.add(pti);
        }
        insert templateItems;
        for(Plan_Template_Item__c pti : templateItems) {
            if(pti.Step_Order__c > 1) {
                Integer idx = Integer.valueOf(pti.Step_Order__c) - 2;
                pti.Previous_Plan_Template_Item__c = templateItems[idx].Id;
            }
        }
        update templateItems;
    }

    @isTest
    static void testCreateAndUpdateTask() {
        PlanCreationService.PlanInput input = new PlanCreationService.PlanInput();
        input.planTemplateId = [SELECT Id FROM Plan_Template__c LIMIT 1].Id;
        input.recordId = [SELECT Id FROM Case LIMIT 1].Id;
        input.lookupFieldApiName = 'Case__c';
        List<PlanCreationService.PlanInput> planInputs = new List<PlanCreationService.PlanInput>();
        planInputs.add(input);

        Test.startTest();
        PlanCreationService.createPlan(planInputs);

        Task newTask = new Task(Subject = 'Test Task',
                                    Status = 'Open',
                                    Priority = 'Normal',
                                    Plan_Item__c = [SELECT Id FROM Plan_Item__c LIMIT 1].Id);
        
        insert newTask;

        newTask.Status = 'Completed';
        update newTask;
        newTask.Status = 'Reopen';
        update newTask;
        newTask.Status = 'Completed';
        update newTask;
        Test.stopTest();



    }
}