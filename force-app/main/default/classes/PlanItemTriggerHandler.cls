public with sharing class PlanItemTriggerHandler {
    public static void handleAfterDelete(List <Plan_Item__c> planItems){
        Set<Id> tasksIds = new Set<Id>();
        for(Plan_Item__c pi : planItems) {
            tasksIds.add(pi.Task_ID__c);
        }
        List<Task> tasksToDelete = [SELECT Id FROM Task WHERE Id in :tasksIds];
        if(tasksToDelete.size() > 0) {
            delete tasksToDelete;
        }
    }
}