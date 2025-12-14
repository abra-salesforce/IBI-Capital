public with sharing class TaskHandler {
    public static void updatePlanItemStatus(Map <Id,Task> oldTasks, List <Task> newTasks){
        List<Plan_Item__c> planItemsToUpdate = new List<Plan_Item__c>();
        for(Task t : newTasks){
            Task oldT = (oldTasks == null) ? null : oldTasks.get(t.Id);
            if((oldT == null || t.Status != oldTasks.get(t.Id).Status) && t.Plan_Item__c != null){
                Plan_Item__c pi = new Plan_Item__c(Id = t.Plan_Item__c);
                pi.Task_Status__c = t.Status;
                if(oldT == null){
                    pi.Task_Id__c = t.Id;
                }
                planItemsToUpdate.add(pi);
            }
        }
        
        if(planItemsToUpdate.size() > 0){
            update planItemsToUpdate;
        }
    }
}