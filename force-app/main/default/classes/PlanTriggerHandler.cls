public without sharing class PlanTriggerHandler {
    public static void handleBeforeDelete(List<Plan__c> plans) {
        Set<Id> planIds = new Set<Id>();
        for (Plan__c p : plans) {
            planIds.add(p.Id);
        }

        Set<Id> tasksToDelete = new Set<Id>();
        for (Plan_Item__c pi : [SELECT Task_ID__c FROM Plan_Item__c WHERE Plan__c IN :planIds]) {
            if (pi.Task_ID__c != null) {
                tasksToDelete.add(pi.Task_ID__c);
            }
        }

        if(tasksToDelete.size() > 0) {
            deleteFuture(tasksToDelete);
        }
    }

    @future
    public static void deleteFuture(Set<Id> tasks) {
        List<Task> tasksToDelete = new List<Task>();
        for (Id t : tasks) {
            tasksToDelete.add(new Task(Id = t));
        }
        delete tasksToDelete;
    }
}